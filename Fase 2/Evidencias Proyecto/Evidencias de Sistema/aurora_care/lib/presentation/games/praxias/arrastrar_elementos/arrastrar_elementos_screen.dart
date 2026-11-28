import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/usecases/evaluate_phone_drop.dart';
import '../../shared/game_definition.dart';
import '../../shared/stable_height.dart';
import 'arrastrar_elementos_controller.dart';
import 'arrastrar_elementos_images.dart';

class PhoneDragScreen extends ConsumerStatefulWidget {
  const PhoneDragScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<PhoneDragScreen> createState() => _PhoneDragScreenState();
}

class _PhoneDragScreenState extends ConsumerState<PhoneDragScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _completionShown = false;
  bool _wasReady = false;

  /// Aciertos consecutivos (colocaciones logradas), para
  /// SoundEffect.acierto(_racha). Se reinicia a 0 cuando se suelta sin
  /// lograrlo y empieza en 0 al abrir la partida.
  int _racha = 0;

  void _sonarEfecto(SoundEffect effect) {
    if (ref.read(soundsEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).play(effect));
    }
  }

  // Anillo que se llena durante la pulsación mantenida, para que se vea que
  // hay que esperar antes de mover la imagen.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: kLongPressTimeout,
  );

  static const _messages = [
    'Su práctica se conserva. Continúe cuando quiera.',
    'Mantenga presionada la imagen. Después arrástrela al destino.',
    'Mantenga el dedo quieto sobre la imagen hasta que se destaque. Después muévala.',
    'Suelte la imagen cuando el recuadro se resalte.',
    'Puede intentarlo de nuevo con la misma imagen.',
    'Muy bien. Puede mover la siguiente imagen.',
    'Colocó las cuatro imágenes.',
  ];
  static final _headings = [
    for (final image in dragImagePool) 'Lleve ${image.label} al recuadro',
  ];

  PhoneDragController get _controller =>
      ref.read(phoneDragProvider(widget.run.nivel).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _hold.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hold.reset();
      _controller.pause();
    }
  }

  @override
  void didChangeMetrics() {
    _hold.reset();
    _controller.cancel();
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
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Práctica completada', style: AppTextStyles.heading),
        content: Text(
          'Colocó las cuatro imágenes. Puede consultar cómo fue su práctica.',
          style: AppTextStyles.body,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) _finish();
              },
              child: const Text('Ver mi resumen'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _help() async {
    _controller.pause();
    final useButton = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text('Cómo arrastrar', style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mantenga un dedo sobre la imagen hasta que se destaque. Sin levantarlo, muévala al recuadro. Cuando el recuadro se resalte, levante el dedo.',
              textAlign: TextAlign.justify,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            const _DragDemo(),
            const SizedBox(height: 12),
            Text(
              'Puede repetirlo despacio. También puede usar el botón de apoyo para colocar la imagen.',
              textAlign: TextAlign.justify,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver a practicar'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Colocar con un botón'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      _controller.resume();
      if (useButton == true) _controller.placeWithButton();
    }
  }

  bool _inside(Offset center, Rect target) => evaluatePhoneDrop(
    itemCenterX: center.dx,
    itemCenterY: center.dy,
    itemSize: PhoneDragController.itemSize,
    targetCenterX: target.center.dx,
    targetCenterY: target.center.dy,
    targetSize: target.width,
    minimumOverlapRatio: PhoneDragController.minimumOverlapRatio,
  );

  String _message(PhoneDragState state) {
    if (state.paused) return _messages[0];
    return switch (state.feedback) {
      PhoneDragFeedback.ready => _messages[1],
      PhoneDragFeedback.hold => _messages[2],
      PhoneDragFeedback.moving => _messages[3],
      PhoneDragFeedback.retry => _messages[4],
      PhoneDragFeedback.achieved =>
        state.completed ? _messages[6] : _messages[5],
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = phoneDragProvider(widget.run.nivel);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.completed && previous?.completed != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _completed());
      }
      if (next.completedActions > (previous?.completedActions ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      } else if (next.misses > (previous?.misses ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      } else if (next.dragging && previous?.dragging != true) {
        ref.read(exerciseVibrationProvider)();
      }
      // arrastrar_tomar al empezar a arrastrar (una vez por arrastre,
      // no en cada movimiento: move() nunca cambia "dragging").
      if (next.dragging && previous?.dragging != true) {
        _sonarEfecto(SoundEffect.arrastrarTomar);
      }
      // Si se suelta y se logra (o se coloca con el botón de apoyo,
      // que también deja feedback en "achieved"): acierto con racha,
      // nunca arrastrar_soltar. Nunca error_suave en Praxias: un
      // intento fallido no es un error que castigar, por eso
      // "retry" suena arrastrar_soltar, no error_suave.
      if (next.feedback == PhoneDragFeedback.achieved &&
          previous?.feedback != PhoneDragFeedback.achieved) {
        _racha++;
        _sonarEfecto(SoundEffect.acierto(_racha));
      } else if (next.feedback == PhoneDragFeedback.retry &&
          previous?.feedback != PhoneDragFeedback.retry) {
        _racha = 0;
        _sonarEfecto(SoundEffect.arrastrarSoltar);
      }
    });
    final image = _controller.imageAt(state.index);
    final layout = _controller.layoutAt(state.index);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practicar con mi teléfono', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          Text(
            'Imagen ${state.index + 1} de ${PhoneDragState.targetCount}',
            style: AppTextStyles.greeting,
          ),
          const SizedBox(height: 12),
          _PlacedTray(
            placed: state.completedActions,
            images: [
              for (var i = 0; i < PhoneDragState.targetCount; i++)
                _controller.imageAt(i),
            ],
          ),
          const SizedBox(height: 16),
          StableHeight(
            candidates: _headings,
            style: AppTextStyles.heading,
            child: Text(
              'Lleve ${image.label} al recuadro',
              style: AppTextStyles.heading,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: StableHeight(
              candidates: _messages,
              style: AppTextStyles.bodySecondary,
              child: Text(_message(state), style: AppTextStyles.bodySecondary),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 340,
              child: LayoutBuilder(
                builder: (context, box) {
                  final area = Rect.fromLTWH(
                    16,
                    16,
                    box.maxWidth - 32,
                    box.maxHeight - 64,
                  );
                  final source = layout.source.inscribe(
                    const Size.square(PhoneDragController.itemSize),
                    area,
                  );
                  final target = layout.target.inscribe(
                    Size.square(_controller.targetSize),
                    area,
                  );
                  final movedCenter =
                      source.center + Offset(state.dragDx, state.dragDy);
                  final ready = state.dragging && _inside(movedCenter, target);
                  if (ready != _wasReady) {
                    _wasReady = ready;
                    if (ready) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) ref.read(exerciseVibrationProvider)();
                      });
                    }
                  }
                  return Semantics(
                    label:
                        'Área de arrastre. Mantenga presionada la imagen de ${image.name} y muévala al destino.',
                    customSemanticsActions: state.blocked || state.dragging
                        ? null
                        : {
                            const CustomSemanticsAction(
                              label: 'Colocar la imagen con apoyo',
                            ): _controller.placeWithButton,
                          },
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (e) {
                        if (!state.blocked &&
                            !state.dragging &&
                            !MediaQuery.disableAnimationsOf(context) &&
                            source.contains(e.localPosition)) {
                          _hold.forward(from: 0);
                        }
                      },
                      onPointerUp: (_) => _hold.reset(),
                      onPointerCancel: (_) => _hold.reset(),
                      child: GestureDetector(
                        key: const ValueKey('phone_drag_board'),
                        behavior: HitTestBehavior.opaque,
                        onTap: state.blocked ? null : _controller.touch,
                        // Mover el dedo antes de tiempo no agarra la imagen:
                        // se explica en vez de ignorarlo en silencio.
                        onPanStart: state.blocked || state.dragging
                            ? null
                            : (_) {
                                _hold.reset();
                                _controller.touch();
                              },
                        onLongPressStart: state.blocked
                            ? null
                            : (e) => _controller.begin(
                                onItem: source.contains(e.localPosition),
                              ),
                        onLongPressMoveUpdate: state.blocked
                            ? null
                            : (e) => _controller.move(
                                e.offsetFromOrigin.dx,
                                e.offsetFromOrigin.dy,
                              ),
                        onLongPressEnd: state.blocked
                            ? null
                            : (_) {
                                final current = ref.read(provider);
                                _controller.drop(
                                  insideTarget: _inside(
                                    source.center +
                                        Offset(current.dragDx, current.dragDy),
                                    target,
                                  ),
                                );
                              },
                        onLongPressCancel: _controller.cancel,
                        child: Stack(
                          children: [
                            Positioned.fromRect(
                              rect: target,
                              child: Semantics(
                                liveRegion: true,
                                label: ready
                                    ? 'Está en el destino. Puede levantar el dedo.'
                                    : 'Destino de la imagen',
                                child: AnimatedContainer(
                                  key: const ValueKey('phone_drag_destination'),
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 160),
                                  decoration: BoxDecoration(
                                    color: ready
                                        ? AppColors.primaryLight
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: ready
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: ready ? 3 : 2,
                                    ),
                                  ),
                                  child: Icon(
                                    ready
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: ready
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: target.left - 12,
                              top: target.bottom + 8,
                              width: target.width + 24,
                              child: Text(
                                'Destino',
                                style: AppTextStyles.bodySecondary,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (!state.completed)
                              AnimatedPositioned(
                                key: ValueKey(
                                  'phone_drag_position_${state.index}',
                                ),
                                left: source.left + state.dragDx,
                                top: source.top + state.dragDy,
                                width: PhoneDragController.itemSize,
                                height: PhoneDragController.itemSize,
                                duration:
                                    state.dragging ||
                                        MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                child: Container(
                                  key: const ValueKey('phone_drag_item'),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: state.dragging ? 3 : 1,
                                    ),
                                    boxShadow: state.dragging
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: .18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Icon(
                                    image.icon,
                                    size: 52,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            if (!state.completed && !state.dragging)
                              Positioned(
                                left: source.left - 8,
                                top: source.top - 8,
                                width: PhoneDragController.itemSize + 16,
                                height: PhoneDragController.itemSize + 16,
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: AnimatedBuilder(
                                      animation: _hold,
                                      builder: (context, _) => _hold.value == 0
                                          ? const SizedBox.shrink()
                                          : CircularProgressIndicator(
                                              value: _hold.value,
                                              strokeWidth: 5,
                                              color: AppColors.primary,
                                              backgroundColor:
                                                  AppColors.primaryLight,
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
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (state.offerAssist && !state.blocked && !state.dragging) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('phone_drag_assist'),
              onPressed: _controller.placeWithButton,
              child: const Text('Colocar la imagen con un botón'),
            ),
          ],
          const SizedBox(height: 20),
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
            onPressed: state.blocked || state.dragging ? null : _help,
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Ver cómo hacerlo'),
          ),
        ],
      ),
    );
  }
}

/// Las cuatro imágenes de la práctica: las ya colocadas aparecen llenas, con
/// un pequeño destello al colocarse. Reemplaza a una barra de progreso.
class _PlacedTray extends StatelessWidget {
  const _PlacedTray({required this.placed, required this.images});
  final int placed;
  final List<DragImage> images;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Imágenes colocadas: $placed de ${images.length}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < images.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              TweenAnimationBuilder<double>(
                key: ValueKey('slot_${i}_${i < placed}'),
                tween: Tween(begin: 0, end: 1),
                duration: still || i >= placed
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                builder: (_, v, child) => Transform.scale(
                  scale: 1 + .18 * math.sin(math.pi * v),
                  child: child,
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: i < placed
                        ? AppColors.successBackground
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i < placed ? AppColors.success : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    i < placed
                        ? images[i].icon
                        : Icons.add_photo_alternate_outlined,
                    color: i < placed
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DragDemo extends StatelessWidget {
  const _DragDemo();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 128,
    child: LayoutBuilder(
      builder: (context, box) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(seconds: 2),
        builder: (_, progress, _) => Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              width: 72,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            Positioned(
              left: (box.maxWidth - 60) * progress,
              top: 4 + 60 * progress,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_florist_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
