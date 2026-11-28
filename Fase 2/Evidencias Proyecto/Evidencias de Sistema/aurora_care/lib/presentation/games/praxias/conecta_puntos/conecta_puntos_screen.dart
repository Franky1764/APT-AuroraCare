import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';
import 'conecta_puntos_config.dart';
import 'conecta_puntos_controller.dart';
import 'conecta_puntos_logic.dart';

class ConectaPuntosScreen extends ConsumerStatefulWidget {
  const ConectaPuntosScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<ConectaPuntosScreen> createState() =>
      _ConectaPuntosScreenState();
}

class _ConectaPuntosScreenState extends ConsumerState<ConectaPuntosScreen>
    with WidgetsBindingObserver {
  Rect? _scheduledArea;
  ConectaEvaluator? _shownFor;

  /// alcanzados/correcciones viven en un ConectaEvaluator MUTABLE
  /// compartido entre estados consecutivos (igual que en Trazado
  /// guiado): comparar previous/next en ref.listen no detecta nada,
  /// porque ambos acaban leyendo el mismo objeto ya mutado. Se
  /// rastrean a mano, reiniciando junto con la racha cuando aparece un
  /// evaluador distinto (figura nueva o "Empezar de nuevo").
  ConectaEvaluator? _trackedEvaluator;
  int _lastAlcanzados = 0;
  int _lastCorrecciones = 0;

  /// Para no sonar trazado_completo dos veces para la misma figura ya
  /// cerrada (mismo patrón que _shownFor, pero para el sonido).
  ConectaEvaluator? _soundClosedFor;

  /// Aciertos consecutivos (puntos alcanzados sin cerrar la figura),
  /// para SoundEffect.acierto(_racha). Se reinicia a 0 en cada toque
  /// fuera de orden (silencioso: nunca error_suave en Praxias) y al
  /// empezar una figura o intento nuevo.
  int _racha = 0;

  ConnectDotsController get _controller =>
      ref.read(connectDotsProvider(widget.run.nivel).notifier);

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

  Future<void> _showDemo() async {
    final controller = _controller;
    final state = ref.read(connectDotsProvider(widget.run.nivel));
    if (state.completed || state.demonstrating || state.evaluator == null) {
      return;
    }
    controller.beginDemo();
    try {
      await showDialog<void>(
        context: context,
        barrierColor: AppColors.primaryDark.withValues(alpha: .24),
        builder: (context) => _PracticeDialog(
          title: 'Cómo unir los puntos',
          description:
              'Comience en el 1 y siga los números en orden. '
              'Vuelva al 1 para cerrar la figura. Puede levantar el dedo y continuar donde quedó.',
          illustration: SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(seconds: 4),
              builder: (context, progress, _) => CustomPaint(
                painter: _DemoPainter(state.figure, progress),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver a practicar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) controller.endDemo();
    }
  }

  Future<void> _restart() async {
    final controller = _controller;
    final state = ref.read(connectDotsProvider(widget.run.nivel));
    if (state.evaluator == null || state.demonstrating || state.finished) {
      return;
    }
    if (state.evaluator!.strokes.isEmpty) {
      controller.restart();
      return;
    }
    final wasPaused = state.paused;
    controller.pause();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => _PracticeDialog(
        title: '¿Empezar esta figura de nuevo?',
        description:
            'Puede volver a practicar desde el inicio. '
            'Este intento se conserva como parte de su práctica.',
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir con mi figura'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      controller.restart();
    } else if (!wasPaused) {
      controller.resume();
    }
  }

  Future<void> _completion(ConectaEvaluator evaluator) async {
    if (!mounted || _shownFor == evaluator) return;
    final controller = _controller;
    final state = ref.read(connectDotsProvider(widget.run.nivel));
    if (state.evaluator != evaluator || !state.completed || state.finished) {
      return;
    }
    _shownFor = evaluator;
    final last = state.index == state.figures.length - 1;
    final next = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => _PracticeDialog(
        title: 'Figura completada',
        description:
            'Formó ${state.figure.nombreConArticulo}. '
            '${last ? '¿Desea ver su resumen o practicar esta figura otra vez?' : '¿Desea continuar o practicar esta figura otra vez?'}',
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(last ? 'Ver mi resumen' : 'Siguiente figura'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Practicar otra vez'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (next == false) {
      controller.restart();
    } else if (next == true && last) {
      final metrics = controller.finish();
      if (metrics != null) widget.run.finish(metrics);
    } else if (next == true) {
      controller.next();
    } else {
      _shownFor = null;
    }
  }

  String _instruction(ConnectDotsState state) {
    if (state.completed) return 'Recorrido completado';
    if (state.paused) return 'Práctica en pausa. Su recorrido se conserva.';
    final evaluator = state.evaluator;
    if (evaluator == null || evaluator.alcanzados == 0) {
      return 'Comience en el punto 1.';
    }
    if (evaluator.siguiente == evaluator.points.length - 1) {
      return 'Vuelva al punto 1 para cerrar la figura.';
    }
    if (!evaluator.isDrawing) return 'Puede continuar donde levantó el dedo.';
    return 'Siga hasta el punto ${evaluator.siguiente + 1}, a su ritmo.';
  }

  @override
  Widget build(BuildContext context) {
    final provider = connectDotsProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = _controller;
    final name = state.figure.nombre;

    ref.listen(provider, (previous, next) {
      final evaluator = next.evaluator;
      if (evaluator == null) return;
      if (!identical(evaluator, _trackedEvaluator)) {
        _trackedEvaluator = evaluator;
        _lastAlcanzados = evaluator.alcanzados;
        _lastCorrecciones = evaluator.correcciones;
        _racha = 0;
      }
      if (evaluator.correcciones > _lastCorrecciones) {
        _lastCorrecciones = evaluator.correcciones;
        _racha = 0; // Fuera de orden: silencioso, nunca error_suave.
      }
      if (evaluator.alcanzados > _lastAlcanzados) {
        _lastAlcanzados = evaluator.alcanzados;
        if (evaluator.completed && !identical(evaluator, _soundClosedFor)) {
          _soundClosedFor = evaluator;
          // Cierra la figura: trazado_completo en las intermedias, nada
          // propio en la última (ya suena el resultado de GameShell).
          // No suena también el acierto del último punto: se pisarían.
          final esUltima = next.index == next.figures.length - 1;
          if (!esUltima && ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.trazadoCompleto),
            );
          }
        } else {
          _racha++;
          if (ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
            );
          }
        }
      }
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardHeight = math.min(
          420.0,
          math.max(280.0, constraints.maxWidth - 40),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Figura ${state.index + 1} de ${state.figures.length}',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                  for (var i = 0; i < state.figures.length; i++)
                    Container(
                      width: 12,
                      height: 5,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: i <= state.index
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${name[0].toUpperCase()}${name.substring(1)}',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 8),
              Text(
                'Una los puntos en orden, con calma.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              Container(
                height: boardHeight,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: _board(state, controller),
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: state.completed
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        state.completed
                            ? Icons.check_circle_outline
                            : state.paused
                            ? Icons.pause_circle_outline
                            : Icons.touch_app_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _instruction(state),
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!state.completed) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              state.evaluator == null || state.demonstrating
                              ? null
                              : _restart,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Empezar de nuevo',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.demonstrating
                              ? null
                              : state.paused
                              ? controller.resume
                              : controller.pause,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            minimumSize: const Size(0, 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 16,
                            ),
                          ),
                          child: Text(
                            state.paused
                                ? 'Continuar práctica'
                                : 'Pausar práctica',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: state.evaluator == null || state.demonstrating
                      ? null
                      : _showDemo,
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: const Text('Ver cómo hacerlo'),
                ),
              ] else
                TextButton(
                  onPressed: () {
                    _shownFor = null;
                    _completion(state.evaluator!);
                  },
                  child: const Text('Elegir cómo continuar'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _board(
    ConnectDotsState state,
    ConnectDotsController controller,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final side = math.max(1.0, math.min(size.width, size.height) - 52);
      final area = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      );
      if (_scheduledArea != area) {
        _scheduledArea = area;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scheduledArea == area) controller.layout(area);
        });
      }
      final evaluator = state.evaluator;
      return Semantics(
        label: 'Área para unir puntos. ${_instruction(state)}',
        child: RawGestureDetector(
          key: const ValueKey('connect_dots_board'),
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                  (_) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                controller.down(event.pointer, event.localPosition),
            onPointerMove: (event) =>
                controller.move(event.pointer, event.localPosition),
            onPointerUp: (event) => controller.up(event.pointer),
            onPointerCancel: (event) =>
                controller.up(event.pointer, cancelled: true),
            child: TweenAnimationBuilder<double>(
              key: ObjectKey(evaluator),
              tween: Tween(begin: 0, end: state.completed ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              onEnd: () {
                if (evaluator == null || !evaluator.completed) return;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _completion(evaluator),
                );
              },
              builder: (context, completion, _) => CustomPaint(
                painter: evaluator == null
                    ? null
                    : _BoardPainter(
                        evaluator,
                        textScaler: MediaQuery.textScalerOf(context),
                        paused: state.paused,
                        completion: state.completed ? completion : 0,
                      ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PracticeDialog extends StatelessWidget {
  const _PracticeDialog({
    required this.title,
    required this.description,
    required this.actions,
    this.illustration,
  });
  final String title, description;
  final List<Widget> actions;
  final Widget? illustration;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    scrollable: true,
    title: Text(title, style: AppTextStyles.heading),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(description, style: AppTextStyles.bodySecondary),
        if (illustration != null) ...[
          const SizedBox(height: 16),
          illustration!,
        ],
      ],
    ),
    actions: [
      for (final action in actions)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(width: double.infinity, child: action),
        ),
    ],
  );
}

void _drawDot(
  Canvas canvas,
  Offset center,
  int number, {
  required bool reached,
  required bool target,
  TextScaler textScaler = TextScaler.noScaling,
  double radius = 24,
}) {
  if (target) {
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()..color = AppColors.primaryLight,
    );
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );
  }
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = target
          ? AppColors.primary
          : reached
          ? AppColors.primaryLight
          : AppColors.surface,
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = target ? 2 : 1.5
      ..color = reached || target ? AppColors.primary : AppColors.border,
  );
  final text = TextPainter(
    text: TextSpan(
      text: '$number',
      style: AppTextStyles.body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: target ? AppColors.textOnPrimary : AppColors.textPrimary,
      ),
    ),
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(
    this.evaluator, {
    required this.textScaler,
    required this.paused,
    required this.completion,
  });
  final ConectaEvaluator evaluator;
  final TextScaler textScaler;
  final bool paused;
  final double completion;
  @override
  void paint(Canvas canvas, Size size) {
    final points = evaluator.points;
    final guide = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      guide.lineTo(point.dx, point.dy);
    }
    if (evaluator.completed) {
      canvas.drawPath(
        guide,
        Paint()..color = AppColors.primaryLight.withValues(alpha: completion),
      );
      canvas.drawPath(
        guide,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 4
          ..color = AppColors.primary.withValues(alpha: completion),
      );
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4
      ..color = AppColors.primary.withValues(alpha: paused ? .35 : .85);
    for (final stroke in evaluator.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    for (var i = 0; i < points.length - 1; i++) {
      final target =
          !evaluator.completed &&
          (i == evaluator.siguiente ||
              (i == 0 && evaluator.siguiente == points.length - 1));
      _drawDot(
        canvas,
        points[i],
        i + 1,
        reached: i < evaluator.alcanzados,
        target: target,
        textScaler: textScaler,
      );
    }
    if (!evaluator.isDrawing &&
        !evaluator.completed &&
        evaluator.strokes.isNotEmpty) {
      final point = evaluator.strokes.last.last;
      if ((point - evaluator.ancla).distance > evaluator.hitRadiusPx) {
        canvas.drawCircle(point, 7, Paint()..color = AppColors.accent);
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.primary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.figure, this.progress);
  final ConectaFigure figure;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.max(1.0, math.min(size.width, size.height) - 48);
    final area = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final points = scalePoints(figure.puntosUnitarios, area);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in [...points.skip(1), points.first]) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.border,
    );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary,
    );
    for (var i = 0; i < points.length; i++) {
      _drawDot(
        canvas,
        points[i],
        i + 1,
        reached: false,
        target: false,
        radius: 17,
      );
    }
    final position =
        metric.getTangentForOffset(metric.length * progress)?.position ??
        points.first;
    canvas.drawCircle(position, 8, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant _DemoPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.figure != figure;
}
