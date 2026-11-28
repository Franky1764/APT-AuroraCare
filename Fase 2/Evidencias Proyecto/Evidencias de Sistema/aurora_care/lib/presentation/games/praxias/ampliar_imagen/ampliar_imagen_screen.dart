import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';
import '../../shared/phone_practice_dialogs.dart';
import '../../shared/stable_height.dart';
import 'ampliar_imagen_controller.dart';
import 'ampliar_imagen_scenes.dart';

class PhoneZoomScreen extends ConsumerStatefulWidget {
  const PhoneZoomScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<PhoneZoomScreen> createState() => _PhoneZoomScreenState();
}

class _PhoneZoomScreenState extends ConsumerState<PhoneZoomScreen>
    with WidgetsBindingObserver {
  bool _completionShown = false;

  /// Aciertos consecutivos (gestos logrados), para
  /// SoundEffect.acierto(_racha). Se reinicia a 0 en cada gesto fallido
  /// real (silencioso: nunca error_suave en Praxias) y empieza en 0 al
  /// abrir la partida. Un gesto que ni siquiera cuenta como intento
  /// (feedback == twoFingers) no reinicia la racha: es un toque
  /// ignorado, no un fallo.
  int _racha = 0;

  static const _captions = [
    'Imagen de práctica · Tamaño inicial',
    'Imagen de práctica · Vista ampliada',
  ];
  static const _reduceHeading = 'Vuelva al tamaño inicial';
  static final _headings = [
    _reduceHeading,
    for (final scene in zoomScenes)
      'Amplíe ${scene.label} para ver sus detalles',
  ];
  static final _messages = [
    'Su práctica se conserva.',
    'Ya puede levantar los dedos.',
    'Volvió al tamaño inicial.',
    for (final scene in zoomScenes)
      'Muy bien. ¿Alcanza a ver ${scene.detail}? Ahora junte los dedos para volver al tamaño inicial.',
    'Para cambiar el tamaño, apoye dos dedos sobre la imagen.',
    'Puede separar un poco más los dedos o realizar otro gesto.',
    'Puede acercar un poco más los dedos o realizar otro gesto.',
    'Separe dos dedos sobre la imagen, a su ritmo.',
    'Junte dos dedos sobre la imagen, a su ritmo.',
  ];

  PhoneZoomController get _controller =>
      ref.read(phoneZoomProvider(widget.run.nivel).notifier);
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

  @override
  void didChangeMetrics() => _controller.cancel();
  void _finish() {
    final metrics = _controller.finish();
    if (metrics != null) widget.run.finish(metrics);
  }

  Future<void> _completed() async {
    if (!mounted || _completionShown) return;
    _completionShown = true;
    final show = await showPhonePracticeCompletion(
      context: context,
      description: 'Amplió la imagen y volvió al tamaño inicial. Puede consultar su resumen.',
    );
    if (mounted && show) _finish();
  }

  Future<void> _help() async {
    final enlarging = ref.read(phoneZoomProvider(widget.run.nivel)).enlarging;
    _controller.pause();
    final support = await showPhonePracticeHelp(
      context: context,
      title: enlarging ? 'Cómo ampliar' : 'Cómo reducir',
      description: enlarging
          ? 'Apoye dos dedos sobre la imagen y sepárelos despacio, sin levantarlos. Así puede ver los detalles más grandes. Puede hacerlo en varios gestos.'
          : 'Apoye dos dedos separados sobre la imagen y acérquelos despacio. Así vuelve al tamaño inicial. Puede hacerlo en varios gestos.',
      supportLabel: enlarging ? 'Ampliar con un botón' : 'Reducir con un botón',
      illustration: _ZoomDemo(enlarging: enlarging),
    );
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      _controller.resume();
      if (support) _controller.useButton();
    }
  }

  bool _ready(PhoneZoomState s) =>
      s.enlarging ? s.scale >= _controller.targetScale : s.scale <= 1.08;

  @override
  Widget build(BuildContext context) {
    final provider = phoneZoomProvider(widget.run.nivel);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.completed && previous?.completed != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _completed());
      }
      if (next.completedActions > (previous?.completedActions ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      } else if (next.gestureActive &&
          _ready(next) &&
          !(previous != null && previous.gestureActive && _ready(previous))) {
        // Se alcanzó el tamaño pedido: ya se pueden levantar los dedos.
        ref.read(exerciseVibrationProvider)();
      }
      // Gesto logrado (pellizco real o botón de apoyo): acierto con
      // racha, en los 2 pasos (incluido el último). Un gesto fallido
      // real (retry) queda silencioso, solo reinicia la racha;
      // twoFingers (ni siquiera un intento válido) se ignora del todo.
      if (next.completedActions > (previous?.completedActions ?? 0)) {
        _racha++;
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
          );
        }
      } else if (next.feedback == PhoneZoomFeedback.retry &&
          previous?.feedback != PhoneZoomFeedback.retry) {
        _racha = 0;
      }
    });
    final scene = zoomScenes[_controller.scene];
    final ready = state.gestureActive && _ready(state);
    final feedback = state.paused
        ? _messages[0]
        : ready
        ? _messages[1]
        : switch (state.feedback) {
            PhoneZoomFeedback.achieved =>
              state.completed
                  ? _messages[2]
                  : 'Muy bien. ¿Alcanza a ver ${scene.detail}? Ahora junte los dedos para volver al tamaño inicial.',
            PhoneZoomFeedback.twoFingers =>
              'Para cambiar el tamaño, apoye dos dedos sobre la imagen.',
            PhoneZoomFeedback.retry =>
              state.enlarging
                  ? 'Puede separar un poco más los dedos o realizar otro gesto.'
                  : 'Puede acercar un poco más los dedos o realizar otro gesto.',
            PhoneZoomFeedback.ready =>
              state.enlarging
                  ? 'Separe dos dedos sobre la imagen, a su ritmo.'
                  : 'Junte dos dedos sobre la imagen, a su ritmo.',
          };
    final heading = state.enlarging
        ? 'Amplíe ${scene.label} para ver sus detalles'
        : _reduceHeading;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practicar con mi teléfono', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          Text(
            'Paso ${state.completedActions.clamp(0, 1) + 1} de 2',
            style: AppTextStyles.greeting,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.completedActions / 2,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
            semanticsLabel: 'Pasos completados: ${state.completedActions} de 2',
          ),
          const SizedBox(height: 16),
          StableHeight(
            candidates: _headings,
            style: AppTextStyles.heading,
            child: Text(heading, style: AppTextStyles.heading),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: StableHeight(
              candidates: _messages,
              style: AppTextStyles.bodySecondary,
              child: Text(feedback, style: AppTextStyles.bodySecondary),
            ),
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
                  child: StableHeight(
                    candidates: _captions,
                    style: AppTextStyles.bodySecondary,
                    child: Text(
                      state.scale <= 1.08 ? _captions[0] : _captions[1],
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.05,
                  child: Semantics(
                    image: true,
                    label:
                        'Imagen ${scene.of}. ${state.enlarging ? 'Separe' : 'Junte'} dos dedos para cambiar su tamaño.',
                    customSemanticsActions: state.blocked || state.gestureActive
                        ? null
                        : {
                            CustomSemanticsAction(
                              label: state.enlarging
                                  ? 'Ampliar con apoyo'
                                  : 'Reducir con apoyo',
                            ): _controller.useButton,
                          },
                    child: GestureDetector(
                      key: const ValueKey('phone_zoom_board'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) =>
                          _controller.begin(details.pointerCount),
                      onScaleUpdate: (details) => _controller.update(
                        details.scale,
                        details.pointerCount,
                      ),
                      onScaleEnd: (details) {
                        if (details.pointerCount >= 2) {
                          _controller.cancel();
                        } else {
                          _controller.end();
                        }
                      },
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.scale(
                              scale: state.scale,
                              child: CustomPaint(painter: scene.painter),
                            ),
                            if (!state.blocked && !state.gestureActive)
                              _PinchGuide(
                                key: ValueKey('guide_${state.enlarging}'),
                                enlarging: state.enlarging,
                              ),
                            if (!state.blocked)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ExcludeSemantics(
                                  child: LinearProgressIndicator(
                                    value: _controller.goalProgress,
                                    minHeight: 12,
                                    color: ready
                                        ? AppColors.success
                                        : AppColors.primary,
                                    backgroundColor: AppColors.border,
                                  ),
                                ),
                              ),
                            if (state.paused)
                              ColoredBox(
                                color: AppColors.surface,
                                child: Center(
                                  child: Text(
                                    'Práctica en pausa',
                                    style: AppTextStyles.heading,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.offerAssist && !state.blocked && !state.gestureActive) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('phone_zoom_assist'),
              onPressed: _controller.useButton,
              child: Text(
                state.enlarging
                    ? 'Ampliar la imagen con un botón'
                    : 'Reducir la imagen con un botón',
              ),
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
            onPressed: state.blocked || state.gestureActive ? null : _help,
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Ver cómo hacerlo'),
          ),
        ],
      ),
    );
  }
}

/// Dos dedos con flechas sobre la imagen: se mueven una vez hacia donde hay
/// que llevarlos y quedan quietos. Desaparecen mientras se hace el gesto.
class _PinchGuide extends StatelessWidget {
  const _PinchGuide({super.key, required this.enlarging});
  final bool enlarging;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: enlarging ? .25 : .8, end: enlarging ? .45 : .55),
          duration: still ? Duration.zero : const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
          builder: (_, distance, _) {
            Widget badge(IconData icon, double x) => Align(
              alignment: Alignment(x, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface.withValues(alpha: .85),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(icon, size: 32, color: AppColors.primary),
                ),
              ),
            );
            // Al ampliar, las flechas apuntan hacia afuera; al reducir, hacia
            // adentro.
            final arrowGap = enlarging ? .35 : -.35;
            return Stack(
              fit: StackFit.expand,
              children: [
                badge(Icons.touch_app_rounded, -distance),
                badge(Icons.touch_app_rounded, distance),
                badge(
                  enlarging
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  -(distance + arrowGap),
                ),
                badge(
                  enlarging
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  distance + arrowGap,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ZoomDemo extends StatelessWidget {
  const _ZoomDemo({required this.enlarging});
  final bool enlarging;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 90,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: enlarging ? .15 : .7, end: enlarging ? .7 : .15),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1500),
      builder: (_, distance, _) => Stack(
        children: [
          Align(
            alignment: Alignment(-distance, 0),
            child: Icon(
              Icons.touch_app_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          Align(
            alignment: Alignment(distance, 0),
            child: Icon(
              Icons.touch_app_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ],
      ),
    ),
  );
}
