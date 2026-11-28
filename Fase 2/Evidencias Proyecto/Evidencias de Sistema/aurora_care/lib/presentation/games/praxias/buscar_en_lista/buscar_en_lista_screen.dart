import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';
import '../../shared/phone_practice_dialogs.dart';
import '../../shared/stable_height.dart';
import 'buscar_en_lista_controller.dart';

class PhoneListScreen extends ConsumerStatefulWidget {
  const PhoneListScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<PhoneListScreen> createState() => _PhoneListScreenState();
}

class _PhoneListScreenState extends ConsumerState<PhoneListScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _keys = List.generate(16, (_) => GlobalKey());
  bool _completionShown = false;

  // Indica si la lista continúa más abajo (flecha al pie de la lista).
  bool _moreBelow = true;

  static const _completedHeading = 'Encontró los tres lugares';
  static const _messages = [
    'Su práctica se conserva.',
    'Puede seguir buscando el nombre indicado.',
    'Muy bien. Ahora puede buscar el siguiente lugar.',
    'Muy bien. Terminó la práctica.',
    'Deslice la lista para ver más lugares.',
  ];
  static final _headings = [
    _completedHeading,
    for (final name in PhoneListController.allItems) 'Busque y toque: $name',
  ];

  PhoneListController get _controller =>
      ref.read(phoneListProvider(widget.run.nivel).notifier);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_updateMoreBelow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMoreBelow());
  }

  void _updateMoreBelow() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final more = position.pixels < position.maxScrollExtent - 8;
    if (more != _moreBelow) setState(() => _moreBelow = more);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _pause() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
    _controller.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _finish() {
    final metrics = _controller.finish();
    if (metrics != null) widget.run.finish(metrics);
  }

  Future<void> _completed() async {
    if (!mounted || _completionShown) return;
    _completionShown = true;
    final show = await showPhonePracticeCompletion(
      context: context,
      description: 'Encontró los tres elementos de esta práctica. Puede consultar su resumen.',
    );
    if (mounted && show) _finish();
  }

  Future<void> _help() async {
    _pause();
    final reveal = await showPhonePracticeHelp(
      context: context,
      title: 'Cómo buscar',
      description:
          'Mueva un dedo sobre la lista para ver los lugares que están más arriba o abajo. '
          'Busque el nombre que aparece en la indicación y tóquelo. Puede repetirlo con calma.',
      supportLabel: 'Mostrar dónde está',
    );
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _controller.resume();
    if (reveal && _scroll.hasClients) {
      final targetContext = _keys[_controller.targetIndex].currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      final object = targetContext.findRenderObject();
      if (object == null) return;
      _controller.reveal();
      await _scroll.position.ensureVisible(
        object,
        alignment: .3,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 400),
      );
    }
  }

  Widget _row(int i, String name, PhoneListState state) {
    final found = state.foundItems.contains(i);
    final base = found
        ? AppColors.successBackground
        : state.helpForTarget && i == _controller.targetIndex
        ? AppColors.primaryLight
        : AppColors.surface;
    Widget tile(Color color) => Material(
      color: color,
      child: InkWell(
        key: ValueKey('phone_list_item_$i'),
        onTap: state.blocked ? null : () => _controller.select(i),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                found
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        semanticLabel: 'Encontrado',
                      )
                    : Icon(Icons.place_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: AppTextStyles.body)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
    if (state.wrongIndex != i) return tile(base);
    // Destello suave que se apaga solo; no usa temporizadores.
    return TweenAnimationBuilder<double>(
      key: ValueKey('wrong_${state.wrongTick}_$i'),
      tween: Tween(begin: 1, end: 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1200),
      builder: (_, v, _) =>
          tile(Color.lerp(base, AppColors.errorBackground, v)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = phoneListProvider(widget.run.nivel);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.found > (previous?.found ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      } else if (next.wrongTick > (previous?.wrongTick ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      }
      if (next.completed && previous?.completed != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _completed());
      }
      // Encontrar el lugar correcto SIEMPRE cierra esa búsqueda (no hay
      // una acción fina separada del cierre, a diferencia de
      // colorear_contorno/conecta_puntos): nivel_completado en las
      // búsquedas intermedias (1 y 2), nada propio en la última (ya
      // suena el resultado de GameShell). Un elemento incorrecto queda
      // silencioso (wrongTick arriba, sin sonido).
      if (next.found > (previous?.found ?? 0) &&
          next.found < PhoneListState.searchCount) {
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.nivelCompletado),
          );
        }
      }
    });
    final items = _controller.items;
    final heading = state.completed
        ? _completedHeading
        : 'Busque y toque: ${_controller.target}';
    final message = state.paused
        ? _messages[0]
        : state.wrongSelection
        ? _messages[1]
        : state.completed
        ? _messages[3]
        : state.found > 0
        ? _messages[2]
        : _messages[4];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practicar con mi teléfono', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          Text(
            'Búsqueda ${state.found.clamp(0, 2) + 1} de 3',
            style: AppTextStyles.greeting,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.found / PhoneListState.searchCount,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
            semanticsLabel:
                'Lugares encontrados: ${state.found} de ${PhoneListState.searchCount}',
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: StableHeight(
                          candidates: _headings,
                          style: AppTextStyles.heading,
                          child: Text(heading, style: AppTextStyles.heading),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: StableHeight(
                          candidates: _messages,
                          style: AppTextStyles.bodySecondary,
                          child: Text(
                            message,
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                SizedBox(
                  height: 320,
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: state.blocked,
                        child: NotificationListener<ScrollStartNotification>(
                          onNotification: (notification) {
                            if (notification.depth == 0 &&
                                notification.dragDetails != null) {
                              _controller.recordScroll();
                            }
                            return false;
                          },
                          child: Scrollbar(
                            controller: _scroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              key: const ValueKey('phone_list_scroll'),
                              controller: _scroll,
                              child: Column(
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    KeyedSubtree(
                                      key: _keys[i],
                                      child: _row(i, items[i], state),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (state.paused)
                        Positioned.fill(
                          child: ColoredBox(
                            color: AppColors.surface,
                            child: Center(
                              child: Text(
                                'Práctica en pausa',
                                style: AppTextStyles.heading,
                              ),
                            ),
                          ),
                        ),
                      if (_moreBelow && !state.blocked)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _MoreBelowHint(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: state.finished
                ? null
                : state.paused
                ? _controller.resume
                : _pause,
            child: Text(
              state.paused ? 'Continuar práctica' : 'Pausar práctica',
            ),
          ),
          TextButton.icon(
            onPressed: state.blocked ? null : _help,
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('Ver cómo buscar'),
          ),
        ],
      ),
    );
  }
}

/// Degradado con una flecha al pie de la lista: avisa que hay más lugares
/// abajo. No intercepta toques ni se lee con lector de pantalla.
class _MoreBelowHint extends StatelessWidget {
  const _MoreBelowHint();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Container(
        height: 56,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0),
              AppColors.surface.withValues(alpha: .95),
            ],
          ),
        ),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}
