// lib/presentation/games/praxias/colorear_contorno/colorear_contorno_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'colorear_contorno_config.dart';
import 'colorear_contorno_logic.dart';

/// Última secuencia de figuras jugada por nivel (en memoria), para no repetir
/// la misma al volver a jugar. Se reinicia al cerrar la app.
final Map<GameLevel, List<ColorearFigure>> _ultimaSesion = {};

/// Color con que se pinta (y se rellena al terminar) cada figura.
Color _colorFigura(ColorearFigure f) {
  final colores = <Color>[
    Colors.lightBlue.shade400,
    Colors.orange.shade500,
    Colors.green.shade500,
    Colors.pink.shade300,
    Colors.teal.shade400,
    Colors.red.shade400,
    Colors.cyan.shade500,
    Colors.purple.shade300,
    Colors.indigo.shade300,
    Colors.amber.shade600,
  ];
  return colores[f.index % colores.length];
}

/// Colorear dentro del contorno. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y confirmación de salida. Cada sesión sortea 3
/// figuras distintas del nivel y este widget las juega una tras otra. Al
/// pintar suficiente del interior, la figura se rellena de color, "salta" y
/// suelta destellos con un ¡Muy bien!; al terminar la última, llama a
/// run.finish().
class ColorearContornoScreen extends ConsumerStatefulWidget {
  const ColorearContornoScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<ColorearContornoScreen> createState() =>
      _ColorearContornoScreenState();
}

class _ColorearContornoScreenState extends ConsumerState<ColorearContornoScreen>
    with SingleTickerProviderStateMixin {
  static const _margen = 24.0;

  late final List<ColorearFigure> _figuras;
  late final double _tolerancia = toleranciaColorearPx(widget.run.nivel);

  late final AnimationController _celebracion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _pop = CurvedAnimation(
    parent: _celebracion,
    curve: const Interval(0, 0.5, curve: Curves.elasticOut),
  );

  int _indice = 0;
  ColorearEvaluator? _eval;
  Size? _size;
  int? _pointer;
  Timer? _timer;
  bool _felicitando = false;
  bool _finished = false;

  // Acumulado de las figuras ya completadas.
  int _dentro = 0;
  int _total = 0;
  int _correcciones = 0;
  int _tiempoMs = 0;
  double _area = 0;

  @override
  void initState() {
    super.initState();
    final nivel = widget.run.nivel;
    _figuras = elegirFigurasColorear(
      nivel,
      math.Random(),
      anterior: _ultimaSesion[nivel],
    );
    _ultimaSesion[nivel] = _figuras;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _celebracion.dispose();
    super.dispose();
  }

  void _ensureEvaluator(Size size) {
    // Mientras se celebra no se recalcula nada: se perdería la figura lista.
    if (_felicitando || _finished) return;
    if (_eval != null && _size == size) return;
    _size = size;
    final lado = math.max(0.0, math.min(size.width, size.height) - 2 * _margen);
    final area = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: lado,
      height: lado,
    );
    _eval = ColorearEvaluator(
      poligono: escalarPuntos(_figuras[_indice].puntosUnitarios, area),
      tolerancePx: _tolerancia,
      brushRadiusPx: radioPincelPx(widget.run.nivel),
      coberturaObjetivo: coberturaObjetivo(widget.run.nivel),
    );
  }

  bool get _bloqueado => _felicitando || _finished;

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _eval == null || _bloqueado) return;
    _pointer = e.pointer;
    _eval!.pointerDown(e.localPosition, DateTime.now());
    setState(() {});
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _bloqueado) return;
    _eval?.pointerMove(e.localPosition, DateTime.now());
    setState(() {});
    _checkDone();
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _eval?.pointerUp();
    setState(() {});
  }

  void _checkDone() {
    final e = _eval;
    if (e == null || !e.completed || _bloqueado) return;

    _dentro += e.puntosDentro;
    _total += e.puntosTotales;
    _correcciones += e.correcciones;
    _tiempoMs += e.tiempoMs;
    _area += _figuras[_indice].areaUnitaria;
    _pointer = null;

    // Celebración: la figura se rellena, salta y suelta destellos. Con
    // "reducir animaciones" activado en el teléfono se muestra ya terminada.
    final reducir = MediaQuery.of(context).disableAnimations;
    ref.read(exerciseVibrationProvider)();
    setState(() => _felicitando = true);
    if (reducir) {
      _celebracion.value = 1;
    } else {
      _celebracion.forward(from: 0);
    }

    final esUltima = _indice == _figuras.length - 1;
    // trazado_completo al cerrar una figura intermedia; en la última no
    // suena nada propio (ya suena el resultado de GameShell).
    if (!esUltima && ref.read(soundsEnabledProvider)) {
      unawaited(
        ref.read(soundServiceProvider).play(SoundEffect.trazadoCompleto),
      );
    }
    _timer = Timer(Duration(milliseconds: reducir ? 1400 : 2000), () {
      if (!mounted) return;
      if (esUltima) {
        _finished = true;
        widget.run.finish(
          PraxiasMetrics(
            precisionPct: _total == 0 ? 0.0 : _dentro / _total * 100,
            correcciones: _correcciones,
            tiempoSegundos: tiempoNormalizadoColorearSeg(
              _tiempoMs,
              _area,
              widget.run.nivel,
            ),
          ),
        );
        return;
      }
      _celebracion.reset();
      setState(() {
        _indice++;
        _eval = null;
        _felicitando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final figura = _figuras[_indice];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Figura ${_indice + 1} de ${_figuras.length}: ${figura.nombre}',
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Alto fijo: así el mensaje de felicitación no mueve el tablero.
          SizedBox(
            height: 76,
            child: Center(
              child: _felicitando
                  ? ScaleTransition(
                      scale: _pop,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '¡Muy bien! \u{1F31F}',
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Coloreó ${figura.nombreConArticulo}.',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      'Pinte con el dedo todo el interior de la figura, '
                      'sin salirse del borde.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Avance de la figura',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: _felicitando ? 1 : (_eval?.avance ?? 0),
                color: _colorFigura(figura),
                backgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _ensureEvaluator(size);
                final eval = _eval!;
                return Listener(
                  key: const ValueKey('colorear_contorno_board'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onDown,
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: CustomPaint(
                    size: size,
                    painter: _ColorearPainter(
                      eval: eval,
                      celebration: _celebracion,
                      color: _colorFigura(figura),
                      brushRadius: radioPincelPx(widget.run.nivel),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorearPainter extends CustomPainter {
  _ColorearPainter({
    required this.eval,
    required this.celebration,
    required this.color,
    required this.brushRadius,
  }) : super(repaint: celebration);

  final ColorearEvaluator eval;
  final Animation<double> celebration;
  final Color color;
  final double brushRadius;

  Path _figura() {
    final pts = eval.poligono;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final figura = _figura();
    if (eval.completed) {
      _paintCelebracion(canvas, figura);
    } else {
      _paintJuego(canvas, size, figura);
    }
  }

  void _paintJuego(Canvas canvas, Size size, Path figura) {
    // Fondo de la figura.
    canvas.drawPath(figura, Paint()..color = Colors.white);

    // Pintura: solo se ve dentro del contorno.
    canvas.save();
    canvas.clipPath(figura);
    final pintura = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = brushRadius * 2
      ..color = color.withValues(alpha: 0.85);
    for (final stroke in eval.strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          brushRadius,
          Paint()..color = color.withValues(alpha: 0.85),
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, pintura);
    }
    canvas.restore();

    // Huella del dedo cuando se sale del contorno (suave, solo por fuera).
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        figura,
      ),
    );
    final huella = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4
      ..color = Colors.deepOrange.withValues(alpha: 0.45);
    for (final stroke in eval.strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, huella);
    }
    canvas.restore();

    // Contorno encima de todo.
    canvas.drawPath(
      figura,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 6
        ..color = AppColors.primary,
    );
  }

  void _paintCelebracion(Canvas canvas, Path figura) {
    final t = celebration.value;
    final pts = eval.poligono;
    final centro = Offset(
      pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length,
      pts.map((p) => p.dy).reduce((a, b) => a + b) / pts.length,
    );

    // La figura se rellena por completo y da un saltito.
    final relleno = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0));
    final salto = 1 + 0.10 * math.sin(math.pi * (t / 0.6).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.scale(salto);
    canvas.translate(-centro.dx, -centro.dy);
    canvas.drawPath(figura, Paint()..color = Colors.white);
    canvas.drawPath(
      figura,
      Paint()..color = color.withValues(alpha: 0.9 * math.max(relleno, 0.85)),
    );
    canvas.drawPath(
      figura,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 6
        ..color = Color.lerp(AppColors.primary, color, t.clamp(0.0, 1.0))!,
    );
    canvas.restore();

    // Destellos que salen desde el centro.
    if (t > 0.05) {
      final radioBase = pts.map((p) => (p - centro).distance).reduce(math.max);
      final avance = Curves.easeOut.transform(t);
      final opacidad = (1 - t).clamp(0.0, 1.0);
      const cantidad = 10;
      for (var k = 0; k < cantidad; k++) {
        final angulo = 2 * math.pi * k / cantidad + 0.3;
        final distancia = radioBase * (0.5 + 0.7 * avance);
        final pos = centro + Offset.fromDirection(angulo, distancia);
        final tamano = (9.0 + 5.0 * (k % 3)) * (1 - 0.4 * t);
        canvas.drawPath(
          _estrella(pos, tamano),
          Paint()
            ..color = (k.isEven ? Colors.amber.shade600 : color).withValues(
              alpha: opacidad,
            ),
        );
      }
    }
  }

  /// Estrella de 5 puntas centrada en [c] con radio [r].
  Path _estrella(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radio = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + math.pi * i / 5;
      final p = c + Offset(radio * math.cos(a), radio * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ColorearPainter oldDelegate) => true;
}
