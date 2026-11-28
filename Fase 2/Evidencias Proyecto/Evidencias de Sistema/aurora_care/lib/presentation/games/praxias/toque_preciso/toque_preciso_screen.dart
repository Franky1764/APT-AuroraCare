import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/detail_dialog.dart';
import '../../shared/game_definition.dart';
import 'toque_preciso_controller.dart';

class PhoneTouchScreen extends ConsumerStatefulWidget {
  const PhoneTouchScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<PhoneTouchScreen> createState() => _PhoneTouchScreenState();
}

class _PhoneTouchScreenState extends ConsumerState<PhoneTouchScreen>
    with WidgetsBindingObserver {
  // Se sortea una vez por partida para que los objetivos no se muevan al tocar.
  late final _buttons = [
    ('Abrir', Icons.folder_open_rounded),
    ('Guardar', Icons.download_rounded),
    ('Compartir', Icons.share_rounded),
    ('Volver', Icons.arrow_back_rounded),
    ('Cerrar', Icons.close_rounded),
    ('Siguiente', Icons.arrow_forward_rounded),
    ('Buscar', Icons.search_rounded),
    ('Editar', Icons.edit_rounded),
    ('Llamar', Icons.call_rounded),
    ('Enviar', Icons.send_rounded),
    ('Copiar', Icons.content_copy_rounded),
    ('Pegar', Icons.content_paste_rounded),
    ('Escuchar', Icons.headphones_rounded),
    ('Pausar', Icons.pause_rounded),
    ('Ver fotos', Icons.photo_library_rounded),
    ('Agregar', Icons.add_circle_outline_rounded),
  ]..shuffle();
  late final _images = [
    ('la flor', Icons.local_florist_rounded),
    ('el sol', Icons.wb_sunny_rounded),
    ('la luna', Icons.nightlight_round),
    ('el paisaje', Icons.landscape_rounded),
    ('la casa', Icons.home_rounded),
    ('el árbol', Icons.park_rounded),
    ('la estrella', Icons.star_rounded),
    ('la nube', Icons.cloud_rounded),
    ('el paraguas', Icons.umbrella_rounded),
    ('la bicicleta', Icons.pedal_bike_rounded),
    ('el regalo', Icons.card_giftcard_rounded),
    ('la taza', Icons.coffee_rounded),
    ('el libro', Icons.menu_book_rounded),
    ('la cámara', Icons.photo_camera_rounded),
    ('la campana', Icons.notifications_rounded),
    ('el reloj', Icons.schedule_rounded),
  ]..shuffle();
  late final _targets = _makeOptions(0);
  late final _alternatives = _makeOptions(3);
  final _targetIsUpper = [true, true, true, false, false, false]..shuffle();
  final _horizontalOffsets = [-.65, -.65, 0.0, 0.0, .65, .65]..shuffle();

  List<(String, IconData, String)> _makeOptions(int offset) => [
    for (var index = 0; index < 3; index++) ...[
      (
        _buttons[offset + index].$1,
        _buttons[offset + index].$2,
        'Toque el botón «${_buttons[offset + index].$1}».',
      ),
      (
        _images[offset + index].$1,
        _images[offset + index].$2,
        'Toque ${_images[offset + index].$1}.',
      ),
    ],
  ];

  bool _completionShown = false;

  /// Aciertos consecutivos (toques dentro del objetivo), para
  /// SoundEffect.acierto(_racha). Se reinicia a 0 en cada toque fuera
  /// (silencioso: en Praxias nunca suena error_suave) y empieza en 0
  /// al abrir la partida.
  int _racha = 0;

  PhoneTouchController get _controller =>
      ref.read(phoneTouchProvider(widget.run.nivel).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  void _finish() {
    final metrics = _controller.finish();
    if (metrics != null) widget.run.finish(metrics);
  }

  Future<void> _completed() async {
    if (!mounted || _completionShown) return;
    _completionShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text('Práctica completada', style: AppTextStyles.heading),
        content: Text(
          'Completó las seis acciones de esta práctica. Puede consultar su resumen cuando quiera.',
          style: AppTextStyles.body,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) _finish();
            },
            child: const Text('Ver mi resumen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = phoneTouchProvider(widget.run.nivel);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.misses > (previous?.misses ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      }
      if (next.completed && previous?.completed != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _completed());
      }
      // Toque dentro del objetivo: acierto con racha, en todos los
      // toques (incluido el último). Toque fuera: silencioso, reinicia
      // la racha (nunca error_suave en Praxias).
      if (next.hits > (previous?.hits ?? 0)) {
        _racha++;
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
          );
        }
      } else if (next.misses > (previous?.misses ?? 0)) {
        _racha = 0;
      }
    });
    final (label, icon, instruction) = _targets[state.index];
    final showingPrompt = !state.started || state.acknowledged;
    final prompt = state.acknowledged && !state.completed
        ? _targets[state.index + 1].$3
        : instruction;
    final (otherLabel, otherIcon, _) = _alternatives[state.index];
    final targetIsUpper = _targetIsUpper[state.index];
    final horizontalOffset =
        _horizontalOffsets[state.index] *
        (widget.run.nivel.value == 1 ? .5 : 1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acción ${state.index + 1} de ${PhoneTouchState.targetCount}',
                    style: AppTextStyles.tag,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          (state.index + (state.acknowledged ? 1 : 0)) /
                          PhoneTouchState.targetCount,
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      semanticsLabel: 'Acciones completadas',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!showingPrompt && !state.paused) ...[
            _InstructionBanner(
              key: const ValueKey('phone_touch_instruction'),
              text: instruction,
              missed: state.missesOnStep > 0,
            ),
            const SizedBox(height: 16),
          ],
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              key: const ValueKey('phone_touch_board'),
              behavior: HitTestBehavior.opaque,
              onTap: showingPrompt || state.blocked
                  ? null
                  : _controller.touchOutside,
              child: SizedBox(
                width: double.infinity,
                height:
                    344 +
                    (MediaQuery.textScalerOf(context).scale(80) - 80).clamp(
                      0.0,
                      160.0,
                    ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!showingPrompt && !state.paused)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (final upper in [true, false]) ...[
                              Expanded(
                                child: Align(
                                  alignment: Alignment(
                                    upper == targetIsUpper
                                        ? horizontalOffset
                                        : -horizontalOffset,
                                    0,
                                  ),
                                  child: _TouchOption(
                                    key: ValueKey(
                                      upper == targetIsUpper
                                          ? 'phone_touch_target'
                                          : 'phone_touch_alternative',
                                    ),
                                    label: upper == targetIsUpper
                                        ? label
                                        : otherLabel,
                                    icon: upper == targetIsUpper
                                        ? icon
                                        : otherIcon,
                                    image: state.imageTarget,
                                    highlight:
                                        upper == targetIsUpper &&
                                        state.missesOnStep >= 2,
                                    controller: _controller,
                                    onTap: state.blocked
                                        ? null
                                        : upper == targetIsUpper
                                        ? _controller.touchTarget
                                        : _controller.touchOutside,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (showingPrompt && !state.paused)
                      SizedBox.expand(
                        child: ColoredBox(
                          color: AppColors.primaryLight,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (state.acknowledged) ...[
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: .8, end: 1),
                                      duration:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 300),
                                      builder: (_, scale, child) =>
                                          Transform.scale(
                                            scale: scale,
                                            child: child,
                                          ),
                                      child: Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 48,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '¡Muy bien!',
                                      style: AppTextStyles.heading,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (!state.completed)
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        prompt,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.heading,
                                      ),
                                    ),
                                  // Al completar, el diálogo «Práctica completada»
                                  // ofrece el único botón para ver el resumen.
                                  if (!state.completed) ...[
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            state.paused || state.finished
                                            ? null
                                            : state.started
                                            ? _controller.next
                                            : _controller.start,
                                        child: const Text('Continuar'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (state.paused)
                      SizedBox.expand(
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
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: state.finished
                ? null
                : state.paused
                ? _controller.resume
                : _controller.pause,
            child: Text(
              state.paused ? 'Continuar práctica' : 'Pausar práctica',
            ),
          ),
          TextButton.icon(
            onPressed: () => showDetailDialog(
              context: context,
              title: 'Cómo tocar',
              content: Text(
                'Apoye el dedo dentro del botón o de la imagen y luego levántelo. '
                'Lea la indicación y toque Continuar para ver las dos opciones. '
                'Los botones simulan acciones del teléfono dentro de la práctica.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('Ver cómo hacerlo'),
          ),
        ],
      ),
    );
  }
}

class _TouchOption extends StatelessWidget {
  const _TouchOption({
    super.key,
    required this.label,
    required this.icon,
    required this.image,
    required this.highlight,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool image;

  /// Resalta con un halo suave el elemento correcto tras varios intentos.
  final bool highlight;
  final PhoneTouchController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final option = _build(context);
    if (!highlight) return option;
    // El halo es una sombra: no cambia el tamaño del elemento ni su zona
    // táctil, solo ayuda a ubicarlo.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .45),
            blurRadius: 14,
            spreadRadius: 4,
          ),
        ],
      ),
      child: option,
    );
  }

  Widget _build(BuildContext context) {
    if (!image) {
      return SizedBox(
        width: controller.buttonWidth,
        height: controller.buttonHeight,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }
    const radius = BorderRadius.all(Radius.circular(20));
    return SizedBox.square(
      dimension: controller.imageSize,
      child: Material(
        color: AppColors.primaryLight,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 64,
              color: AppColors.primary,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicación siempre visible mientras se elige, para no depender de la
/// memoria. Tras un error suma un mensaje amable, sin tono de castigo.
class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    super.key,
    required this.text,
    required this.missed,
  });

  final String text;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.touch_app_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: AppTextStyles.cardTitle),
                    // El espacio del aviso se reserva siempre: si apareciera
                    // solo tras un error, el tablero bajaría y los elementos
                    // dejarían de estar quietos.
                    const SizedBox(height: 4),
                    Visibility(
                      visible: missed,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Text(
                        'Casi. Inténtelo de nuevo, sin apuro.',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
