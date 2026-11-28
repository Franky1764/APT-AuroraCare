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
import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'trazado_guiado_config.dart';
import 'trazado_guiado_controller.dart';
import 'trazado_guiado_logic.dart';

ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.textOnPrimary,
  elevation: 0,
  minimumSize: const Size(0, 56),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

ButtonStyle _secondaryStyle() => OutlinedButton.styleFrom(
  foregroundColor: AppColors.primary,
  backgroundColor: AppColors.surface,
  side: BorderSide(color: AppColors.border, width: 1.5),
  minimumSize: const Size(0, 56),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

ButtonStyle _quietStyle() => TextButton.styleFrom(
  foregroundColor: AppColors.primary,
  minimumSize: const Size(48, 48),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  textStyle: AppTextStyles.body,
);

class TrazadoGuiadoScreen extends ConsumerStatefulWidget {
  const TrazadoGuiadoScreen({super.key, required this.run});
  final GameRun run;

  @override
  ConsumerState<TrazadoGuiadoScreen> createState() =>
      _TrazadoGuiadoScreenState();
}

class _TrazadoGuiadoScreenState extends ConsumerState<TrazadoGuiadoScreen>
    with WidgetsBindingObserver {
  Rect? _scheduledArea;
  TraceEvaluator? _completionShownFor;

  /// Evaluador para el que ya sonó trazado_completo. completed es un
  /// getter sobre un evaluador MUTABLE compartido entre estados
  /// consecutivos (ver TraceEvaluator): comparar previous.completed
  /// contra next.completed en ref.listen no detecta el cambio, porque
  /// ambos leen del mismo objeto ya mutado. Este campo es el
  /// equivalente de _completionShownFor, pero para el sonido.
  TraceEvaluator? _soundPlayedFor;
  GameLevel get _level => widget.run.nivel;
  TrazadoGuiadoController get _controller =>
      ref.read(trazadoGuiadoProvider(_level).notifier);

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

  Future<void> _restart() async {
    final controller = _controller;
    controller.pause();
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => _PracticeDialog(
        icon: Icons.restart_alt_rounded,
        title: '¿Volver a empezar?',
        description: 'Comenzará este recorrido desde el inicio.',
        actions: [
          ElevatedButton(
            style: _primaryStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empezar de nuevo', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: _quietStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Continuar recorrido',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted == true) controller.restart();
    controller.resume();
  }

  Future<void> _demo() async {
    final controller = _controller;
    final figure = ref.read(trazadoGuiadoProvider(_level)).figure;
    controller.beginDemo();
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (_) => _Demo(figure: figure),
    );
    if (mounted) controller.endDemo();
  }

  void _advance() {
    final state = ref.read(trazadoGuiadoProvider(_level));
    if (state.index < state.figures.length - 1) {
      _controller.next();
    } else {
      final metrics = _controller.finish();
      if (metrics != null) widget.run.finish(metrics);
    }
  }

  Future<void> _completionChoices(TraceEvaluator evaluator) async {
    if (!mounted || _completionShownFor == evaluator) return;
    final state = ref.read(trazadoGuiadoProvider(_level));
    if (state.evaluator != evaluator || !state.completed || state.finished) {
      return;
    }
    _completionShownFor = evaluator;
    final last = state.index == state.figures.length - 1;
    final next = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => _PracticeDialog(
        icon: Icons.check_circle_outline_rounded,
        title: 'Recorrido completado',
        description: last
            ? '¿Desea terminar la práctica o repetir esta figura?'
            : '¿Desea seguir con otra figura o practicar esta otra vez?',
        actions: [
          ElevatedButton(
            style: _primaryStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: Text(last ? 'Terminar práctica' : 'Siguiente recorrido'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: _secondaryStyle(),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Practicar otra vez'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (next == true) {
      _advance();
    } else if (next == false) {
      _controller.restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trazadoGuiadoProvider(_level));
    final controller = _controller;

    ref.listen(trazadoGuiadoProvider(_level), (previous, next) {
      if (next.completed && next.evaluator != _soundPlayedFor) {
        _soundPlayedFor = next.evaluator;
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.trazadoCompleto),
          );
        }
      }
    });
    final name = state.figure.nombre;
    final title = '${name[0].toUpperCase()}${name.substring(1)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(0.0, constraints.maxWidth - 40);
        final boardHeight = math
            .min(availableWidth, 380.0)
            .clamp(250.0, 380.0)
            .toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recorrido ${state.index + 1} de ${state.figures.length}',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < state.figures.length; i++)
                          Container(
                            width: 18,
                            height: 5,
                            margin: const EdgeInsets.only(left: 5),
                            decoration: BoxDecoration(
                              color: i <= state.index
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: AppTextStyles.greeting),
              const SizedBox(height: 6),
              Text(
                'Siga la línea a su ritmo.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: boardHeight,
                    child: _board(state, controller),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _status(state, controller),
              const SizedBox(height: 20),
              if (state.completed) ...[
                ElevatedButton(
                  style: _primaryStyle(),
                  onPressed: state.finished ? null : _advance,
                  child: Text(
                    state.index == state.figures.length - 1
                        ? 'Terminar práctica'
                        : 'Siguiente recorrido',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: _quietStyle(),
                  onPressed: state.finished ? null : _restart,
                  icon: const Icon(Icons.replay_rounded, size: 22),
                  label: const Text(
                    'Practicar otra vez',
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: _secondaryStyle(),
                          onPressed: state.evaluator == null ? null : _restart,
                          child: const Text(
                            'Empezar de nuevo',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: _primaryStyle(),
                          onPressed: state.paused
                              ? controller.resume
                              : controller.pause,
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
                const SizedBox(height: 12),
                TextButton.icon(
                  style: _quietStyle(),
                  onPressed: state.paused ? null : _demo,
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                  label: const Text('Ver cómo hacerlo'),
                ),
                if (!state.blocked && (state.evaluator?.canUndo ?? false))
                  TextButton.icon(
                    style: _quietStyle(),
                    onPressed: controller.undo,
                    icon: const Icon(Icons.undo_rounded, size: 22),
                    label: const Text(
                      'Deshacer último tramo',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _status(TrazadoGuiadoState state, TrazadoGuiadoController controller) {
    final text = state.completed
        ? 'Recorrido completado'
        : state.paused
        ? 'Su recorrido se conserva. Continúe cuando quiera.'
        : controller.destinationEarly
        ? 'Queda una parte por recorrer. Retome desde el punto marcado, sin borrar su intento.'
        : (state.evaluator?.progress ?? 0) > 0 &&
              state.evaluator?.isDrawing == false
        ? 'Puede continuar desde el punto marcado.'
        : 'Puede levantar el dedo y continuar.';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: state.completed || state.paused
              ? AppColors.primaryLight
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              state.completed
                  ? Icons.check_circle_outline_rounded
                  : state.paused
                  ? Icons.pause_circle_outline_rounded
                  : Icons.touch_app_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: state.completed || state.paused
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(
    TrazadoGuiadoState state,
    TrazadoGuiadoController controller,
  ) => LayoutBuilder(
    builder: (context, board) {
      final size = board.biggest;
      final side = math.max(1.0, math.min(size.width, size.height) - 96);
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
      final e = state.evaluator;
      return Semantics(
        label:
            'Área de trazado. ${e?.guide.isClosed == true ? 'Inicio y final en el mismo punto; recorra toda la figura.' : 'Recorra la línea desde Inicio hasta Final.'}',
        child: RawGestureDetector(
          key: const ValueKey('trazado_board'),
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
            onPointerCancel: (event) => controller.up(event.pointer),
            child: TweenAnimationBuilder<double>(
              key: ObjectKey(e),
              tween: Tween(begin: 0, end: state.completed ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 1100),
              onEnd: () {
                // Sin animaciones, onEnd puede ocurrir durante build.
                // El diálogo se abre al terminar el cuadro, también en ese caso.
                if (e != null && e.completed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _completionChoices(e);
                  });
                }
              },
              builder: (context, completion, _) => CustomPaint(
                painter: e == null
                    ? null
                    : _GuidePainter(
                        guide: e.guide,
                        tolerance: e.tolerancePx,
                        strokes: e.strokes,
                        textScaler: MediaQuery.textScalerOf(context),
                        completionProgress: state.completed ? completion : null,
                        resumePoint:
                            !state.blocked && !e.isDrawing && e.progress > 0
                            ? e.progressPoint
                            : null,
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

/// Diálogo compacto y desplazable: conserva texto legible sin espacios vacíos.
class _PracticeDialog extends StatelessWidget {
  const _PracticeDialog({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
    this.illustration,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? illustration;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTextStyles.heading)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: AppTextStyles.bodySecondary),
            if (illustration != null) ...[
              const SizedBox(height: 16),
              illustration!,
            ],
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

class _Demo extends StatefulWidget {
  const _Demo({required this.figure});
  final TrazadoFigure figure;
  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (!_animation.isAnimating && _animation.value == 0) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PracticeDialog(
    icon: Icons.play_circle_outline_rounded,
    title: 'Cómo recorrer la figura',
    description:
        (widget.figure.puntosUnitarios.first -
                    widget.figure.puntosUnitarios.last)
                .distance <
            1e-6
        ? 'Dé la vuelta completa y vuelva al punto de inicio.'
        : 'Comience en Inicio y siga la línea hasta Final.',
    illustration: Center(
      child: SizedBox(
        width: 220,
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                // Escala uniforme: un círculo debe seguir siendo un círculo.
                final side = math.max(
                  1.0,
                  math.min(box.maxWidth, box.maxHeight) - 80,
                );
                final guide = GuidePath.fromUnitPoints(
                  widget.figure.puntosUnitarios,
                  Rect.fromCenter(
                    center: Offset(box.maxWidth / 2, box.maxHeight / 2),
                    width: side,
                    height: side,
                  ),
                );
                return AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => CustomPaint(
                    key: const ValueKey('trazado_demo_canvas'),
                    painter: _GuidePainter(
                      guide: guide,
                      tolerance: 8,
                      strokes: const [],
                      demoProgress: _animation.value,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
    actions: [
      ElevatedButton(
        style: _primaryStyle(),
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver al recorrido', textAlign: TextAlign.center),
      ),
    ],
  );
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.guide,
    required this.tolerance,
    required this.strokes,
    required this.textScaler,
    this.demoProgress,
    this.completionProgress,
    this.resumePoint,
  });
  final GuidePath guide;
  final double tolerance;
  final List<List<Offset>> strokes;
  final TextScaler textScaler;
  final double? demoProgress;
  final double? completionProgress;
  final Offset? resumePoint;
  Path _path(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  Paint _pen(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(guide.points);
    canvas.drawPath(path, _pen(AppColors.primaryLight, tolerance * 2));
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          3,
          Paint()..color = AppColors.primaryDark,
        );
      } else {
        canvas.drawPath(_path(stroke), _pen(AppColors.primaryDark, 5));
      }
    }
    // La guía se dibuja sobre el trazo para permanecer visible.
    canvas.drawPath(path, _pen(AppColors.primary, 2));
    if (demoProgress != null) {
      canvas.drawPath(
        _path(guide.pointsUpTo(guide.length * demoProgress!)),
        _pen(AppColors.primaryDark, 5),
      );
    }
    if (completionProgress != null) {
      // Una sola animación recorre la figura; el trazo real permanece visible.
      canvas.drawPath(
        _path(guide.pointsUpTo(guide.length * completionProgress!)),
        _pen(AppColors.primary, 5),
      );
    }
    if (resumePoint != null) {
      canvas.drawCircle(resumePoint!, 12, Paint()..color = AppColors.surface);
      canvas.drawCircle(resumePoint!, 9, _pen(AppColors.primary, 3));
      canvas.drawCircle(resumePoint!, 4, Paint()..color = AppColors.primary);
    }
    canvas.drawCircle(guide.start, 7, Paint()..color = AppColors.primary);
    if (!guide.isClosed) {
      canvas.drawRect(
        Rect.fromCenter(center: guide.end, width: 12, height: 12),
        Paint()..color = AppColors.primaryDark,
      );
    }
    _label(
      canvas,
      size,
      guide.start,
      guide.isClosed ? 'Inicio y final' : 'Inicio',
      -32,
    );
    if (!guide.isClosed) _label(canvas, size, guide.end, 'Final', 16);
  }

  void _label(Canvas canvas, Size size, Offset point, String text, double dy) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    final position = Offset(
      (point.dx - painter.width / 2)
          .clamp(3, math.max(3, size.width - painter.width - 3))
          .toDouble(),
      (point.dy + dy)
          .clamp(3, math.max(3, size.height - painter.height - 3))
          .toDouble(),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (position & painter.size).inflate(2),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.surface,
    );
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) => true;
}
