// lib/presentation/games/praxias/trazado_guiado/trazado_guiado_logic.dart
//
// Lógica pura de Trazado guiado (sin widgets): sirve para testear la
// precisión, las correcciones y la detección de figura completa.
import 'dart:math' as math;
import 'dart:ui';

/// Línea guía de una figura, densificada en puntos cada pocos píxeles.
class GuidePath {
  GuidePath._(this.points, this.cumulative);

  /// Puntos de la guía, en orden y a poca distancia entre sí.
  final List<Offset> points;

  /// Longitud de arco acumulada en cada punto (cumulative.first == 0).
  final List<double> cumulative;

  double get length => cumulative.last;
  Offset get start => points.first;
  Offset get end => points.last;

  /// Una figura cerrada termina donde empezó (círculo, cuadrado, estrella…).
  bool get isClosed => (end - start).distance < 1;

  /// Escala los puntos unitarios (0..1) al [area] y los densifica cada
  /// [step] píxeles.
  factory GuidePath.fromUnitPoints(
    List<Offset> unit,
    Rect area, {
    double step = 3,
  }) {
    final scaled = [
      for (final u in unit)
        Offset(area.left + u.dx * area.width, area.top + u.dy * area.height),
    ];
    final dense = <Offset>[scaled.first];
    for (var i = 1; i < scaled.length; i++) {
      final a = scaled[i - 1];
      final b = scaled[i];
      final steps = math.max(1, ((b - a).distance / step).ceil());
      for (var k = 1; k <= steps; k++) {
        dense.add(a + (b - a) * (k / steps));
      }
    }
    final cumulative = <double>[0];
    for (var i = 1; i < dense.length; i++) {
      cumulative.add(cumulative.last + (dense[i] - dense[i - 1]).distance);
    }
    return GuidePath._(dense, cumulative);
  }

  /// Punto de la guía a [s] píxeles del inicio (el más cercano por abajo).
  Offset pointAt(double s) {
    var i = 0;
    while (i < points.length - 1 && cumulative[i + 1] <= s) {
      i++;
    }
    return points[i];
  }

  /// Puntos de la guía desde el inicio hasta [s] píxeles de recorrido.
  List<Offset> pointsUpTo(double s) {
    final out = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      if (cumulative[i] > s) break;
      out.add(points[i]);
    }
    return out;
  }

  /// Dirección (ángulo en radianes) de la guía a [s] píxeles del inicio.
  double angleAt(double s) {
    var i = 0;
    while (i < points.length - 2 && cumulative[i + 1] <= s) {
      i++;
    }
    final d = points[math.min(i + 3, points.length - 1)] - points[i];
    return d.direction;
  }
}

/// Evalúa una práctica sin premiar atajos ni contar pausas como errores.
/// La precisión se pondera por distancia recorrida, no por eventos del teléfono.
/// Levantar el dedo permite descansar: se registra como contexto, no corrección.
class TraceEvaluator {
  TraceEvaluator({
    required this.guide,
    required this.tolerancePx,
    this.captureFactor = 1.25,
    this.completionRatio = 0.97,
    this.endProgress = 0.97,
    double? endRadiusPx,
    this.lookBackPx = 20,
    double? lookAheadPx,
  }) : endRadiusPx = endRadiusPx ?? math.max(12, 1.5 * tolerancePx),
       lookAheadPx = lookAheadPx ?? math.max(24, 2 * tolerancePx);

  GuidePath guide;
  final double tolerancePx;
  final double captureFactor;
  final double completionRatio;
  final double endProgress;
  final double endRadiusPx;
  final double lookBackPx;
  final double lookAheadPx;
  final List<List<Offset>> strokes = [];
  final List<_TraceCheckpoint> _checkpoints = [];

  int _inside = 0;
  int _total = 0;
  int _undos = 0;
  int _lifts = 0;
  double _maxS = 0;
  double _insideLength = 0;
  double _totalLength = 0;
  double _practiceInsideLength = 0;
  double _practiceTotalLength = 0;
  int _activeMs = 0;
  DateTime? _activeStart;
  DateTime? _lastTime;
  bool _completed = false;
  bool _down = false;
  bool _anchored = false;
  Offset? _last;

  bool get completed => _completed;
  bool get isDrawing => _down;
  bool get canUndo => !_down && strokes.isNotEmpty;
  int get correcciones => _undos;
  int get lifts => _lifts;
  int get puntosDentro => _inside;
  int get puntosTotales => _total;
  double get insideLengthPx => _insideLength;
  double get totalLengthPx => _totalLength;
  double get precisionPct => _totalLength == 0
      ? (_total == 0 ? 0 : _inside / _total * 100)
      : _insideLength / _totalLength * 100;
  double get practicePrecisionPct => _practiceTotalLength == 0
      ? 0
      : _practiceInsideLength / _practiceTotalLength * 100;
  double get progressPx => _maxS;
  double get progress =>
      guide.length == 0 ? 0 : (_maxS / guide.length).clamp(0.0, 1.0).toDouble();
  Offset get progressPoint => guide.pointAt(_maxS);

  /// Tiempo activo hasta el último evento; nunca incluye descansos entre trazos.
  int get tiempoMs =>
      _activeMs +
      (_activeStart == null || _lastTime == null
          ? 0
          : math.max(0, _lastTime!.difference(_activeStart!).inMilliseconds));

  void pointerDown(Offset p, DateTime now) {
    if (_completed || _down) return;
    // El primer toque comienza cerca del inicio. Después se puede retomar
    // sobre la guía sin borrar trazos; el avance espera la zona pendiente.
    final touchRadius = math.max(30, 3 * tolerancePx);
    final nearPending = (p - progressPoint).distance <= touchRadius;
    final nearGuide =
        strokes.isNotEmpty &&
        guide.points.any((point) => (point - p).distance <= touchRadius);
    if (!nearPending && !nearGuide) return;
    _checkpoints.add(
      _TraceCheckpoint(_inside, _total, _maxS, _insideLength, _totalLength),
    );
    _activeStart = now;
    _lastTime = now;
    _down = true;
    _anchored = (p - progressPoint).distance <= captureFactor * tolerancePx;
    _last = p;
    strokes.add([p]);
    _evaluate(p, 0, advance: false);
  }

  void pointerMove(Offset p, DateTime now) {
    if (_completed || !_down) return;
    _lastTime = now;
    final last = _last!;
    final distance = (p - last).distance;
    // Las muestras estacionarias no mejoran artificialmente la precisión.
    if (distance < 0.01) return;
    final steps = math.max(1, (distance / 2).ceil());
    for (var k = 1; k <= steps; k++) {
      final q = last + (p - last) * (k / steps);
      _evaluate(q, distance / steps);
      strokes.last.add(q);
      _checkCompletion(q, now);
      if (_completed) break;
    }
    _last = p;
  }

  bool pointerUp(DateTime now) {
    if (_completed) return true;
    if (!_down) return false;
    _stopClock(now);
    _down = false;
    _lifts++;
    return false;
  }

  /// Pausar o abrir una ayuda no descuenta precisión ni borra el recorrido.
  void pause(DateTime now) {
    if (_down) pointerUp(now);
  }

  bool undoLastStroke(DateTime now) {
    if (!canUndo) return false;
    _stopClock(now);
    final checkpoint = _checkpoints.removeLast();
    strokes.removeLast();
    _inside = checkpoint.inside;
    _total = checkpoint.total;
    _maxS = checkpoint.progress;
    _insideLength = checkpoint.insideLength;
    _totalLength = checkpoint.totalLength;
    _last = null;
    _completed = false;
    _undos++;
    // El tiempo y la precisión de toda la práctica se conservan como contexto;
    // la precisión del recorrido visible se restaura al estado anterior.
    return true;
  }

  /// Reubica trazos y avance al girar la pantalla sin reiniciar la figura.
  void reframe(GuidePath newGuide, Rect oldArea, Rect newArea, DateTime now) {
    if (oldArea.width <= 0 || oldArea.height <= 0) return;
    pause(now);
    Offset map(Offset p) => Offset(
      newArea.left + (p.dx - oldArea.left) / oldArea.width * newArea.width,
      newArea.top + (p.dy - oldArea.top) / oldArea.height * newArea.height,
    );
    final scale = guide.length == 0 ? 1.0 : newGuide.length / guide.length;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length; i++) {
        stroke[i] = map(stroke[i]);
      }
    }
    if (_last != null) _last = map(_last!);
    _maxS *= scale;
    _insideLength *= scale;
    _totalLength *= scale;
    _practiceInsideLength *= scale;
    _practiceTotalLength *= scale;
    for (final checkpoint in _checkpoints) {
      checkpoint.progress *= scale;
      checkpoint.insideLength *= scale;
      checkpoint.totalLength *= scale;
    }
    guide = newGuide;
  }

  void _stopClock(DateTime now) {
    if (_activeStart == null) return;
    _activeMs += math.max(0, now.difference(_activeStart!).inMilliseconds);
    _activeStart = null;
    _lastTime = now;
  }

  void _checkCompletion(Offset p, DateTime now) {
    // Se exige recorrer casi toda la figura Y llegar al destino, no basta
    // con estar cerca del final después de solo el 85 % del recorrido.
    if (progress >= math.max(completionRatio, endProgress) &&
        (p - guide.end).distance <= endRadiusPx) {
      _completed = true;
      _stopClock(now);
      _down = false;
    }
  }

  ({double distance, double s}) _distanceInWindow(Offset p) {
    final lo = _maxS - lookBackPx;
    final hi = _maxS + lookAheadPx;
    var bestDistance = double.infinity;
    var bestS = _maxS;
    for (var i = 0; i < guide.points.length; i++) {
      final s = guide.cumulative[i];
      if (s < lo) continue;
      if (s > hi) break;
      final d = (guide.points[i] - p).distance;
      if (d < bestDistance) {
        bestDistance = d;
        bestS = s;
      }
    }
    return (distance: bestDistance, s: bestS);
  }

  void _evaluate(Offset p, double distance, {bool advance = true}) {
    // Retomar lejos del punto pendiente no permite saltarse un tramo.
    // Primero hay que volver a esa zona, sin borrar el intento.
    if (!_anchored &&
        (p - progressPoint).distance <= captureFactor * tolerancePx) {
      _anchored = true;
    }
    final best = _distanceInWindow(p);
    // Estar sobre la guía y recorrerla en orden son observaciones distintas.
    // Un avance detenido no debe convertir el resto de la guía en "fuera".
    var precisionDistance = double.infinity;
    for (final point in guide.points) {
      precisionDistance = math.min(precisionDistance, (point - p).distance);
    }
    _total++;
    if (precisionDistance <= tolerancePx) {
      _inside++;
      _insideLength += distance;
      _practiceInsideLength += distance;
    }
    _totalLength += distance;
    _practiceTotalLength += distance;
    if (advance &&
        _anchored &&
        best.distance <= captureFactor * tolerancePx &&
        best.s > _maxS) {
      _maxS = best.s;
    }
  }
}

class _TraceCheckpoint {
  _TraceCheckpoint(
    this.inside,
    this.total,
    this.progress,
    this.insideLength,
    this.totalLength,
  );
  final int inside;
  final int total;
  double progress;
  double insideLength;
  double totalLength;
}
