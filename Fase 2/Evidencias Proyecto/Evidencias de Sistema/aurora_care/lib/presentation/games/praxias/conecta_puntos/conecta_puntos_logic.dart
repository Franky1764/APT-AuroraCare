// lib/presentation/games/praxias/conecta_puntos/conecta_puntos_logic.dart
//
// Lógica pura de Conecta los puntos (sin widgets), para poder testearla.
import 'dart:math' as math;
import 'dart:ui';

/// Distancia de [p] al segmento [a]-[b].
double distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2)
      .clamp(0.0, 1.0)
      .toDouble();
  return (p - (a + ab * t)).distance;
}

/// Escala los puntos unitarios (0..1) al [area].
List<Offset> scalePoints(List<Offset> unit, Rect area) => [
  for (final u in unit)
    Offset(area.left + u.dx * area.width, area.top + u.dy * area.height),
];

/// Evalúa el trazo del dedo uniendo puntos numerados en orden.
///
/// - Se empieza tocando el punto 1 y se arrastra hasta el 2, el 3, etc.
///   Si levanta el dedo, retoma tocando el último punto alcanzado.
/// - Precisión: proporción de distancia dibujada a no más de [tolerancePx]
///   del tramo actual (o dentro de uno de sus dos puntos). Los movimientos
///   estacionarios no alteran la precisión por frecuencia de muestreo.
/// - Corrección (según SCORING): puntos tocados fuera de orden. Cada vez que
///   el dedo entra en un punto que todavía no toca, cuenta una; quedarse
///   encima no suma de nuevo.
/// - Tiempo activo: desde el primer toque válido; excluye pausas y demostraciones.
class ConectaEvaluator {
  ConectaEvaluator({
    required this.points,
    required this.tolerancePx,
    required this.hitRadiusPx,
  }) : assert(points.length >= 2);

  List<Offset> points;
  final double tolerancePx;
  final double hitRadiusPx;

  /// Trazos del dedo (uno por cada vez que apoya y levanta), para dibujar.
  final List<List<Offset>> strokes = [];

  /// Índice del próximo punto a alcanzar (0 = aún no empezó).
  int _next = 0;
  int _inside = 0;
  int _total = 0;
  int _fueraDeOrden = 0;
  int? _overDot;
  DateTime? _start;
  DateTime? _end;
  bool _down = false;
  Offset? _last;
  DateTime? _activeSince;
  int _activeMs = 0;
  int lifts = 0;
  double insideDistance = 0;
  double totalDistance = 0;
  bool get isDrawing => _down;

  int activeTimeMs(DateTime now) =>
      _activeMs +
      (_activeSince == null
          ? 0
          : math.max(0, now.difference(_activeSince!).inMilliseconds));

  void _closeTime(DateTime now) {
    _activeMs = activeTimeMs(now);
    _activeSince = null;
  }

  void pause(DateTime now) {
    pointerUp(countLift: false);
    _closeTime(now);
  }

  void resume(DateTime now) {
    if (_start != null && !completed) _activeSince = now;
  }

  /// Ajusta el dibujo al área nueva sin perder puntos, intentos ni medidas.
  void reframe(Rect previous, Rect next, DateTime now) {
    Offset transform(Offset point) => Offset(
      next.left + (point.dx - previous.left) / previous.width * next.width,
      next.top + (point.dy - previous.top) / previous.height * next.height,
    );
    points = points.map(transform).toList();
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length; i++) {
        stroke[i] = transform(stroke[i]);
      }
    }
    if (_last != null) _last = transform(_last!);
    pointerUp(countLift: false);
  }

  int get totalPuntos => points.length;

  /// Cantidad de puntos ya unidos (el primero cuenta al tocarlo).
  int get alcanzados => _next;
  int get siguiente => _next;
  bool get completed => _next >= points.length;
  int get correcciones => _fueraDeOrden;
  int get puntosDentro => _inside;
  int get puntosTotales => _total;
  double get precisionPct => totalDistance > 0
      ? insideDistance / totalDistance * 100
      : (_total == 0 ? 0 : 100);
  int get tiempoMs => (_start == null || _end == null)
      ? 0
      : _end!.difference(_start!).inMilliseconds;

  /// Punto desde el que hay que retomar el trazo.
  Offset get ancla => points[math.max(0, _next - 1)];

  void pointerDown(Offset p, DateTime now) {
    if (completed) return;
    // Permite retomar donde levantó el dedo o desde el último punto unido.
    final nearAnchor = (p - ancla).distance <= hitRadiusPx * 1.3;
    final nearLast =
        _last != null && (p - _last!).distance <= hitRadiusPx * 1.3;
    if (!nearAnchor && !nearLast) return;
    _activeSince ??= now;
    _down = true;
    _last = p;
    _overDot = null;
    strokes.add([p]);
    if (_next == 0) {
      _start = now;
      _next = 1;
      _inside++;
      _total++;
      return;
    }
    _sample(p, now);
  }

  void pointerMove(Offset p, DateTime now) {
    if (completed || !_down) return;
    final last = _last!;
    final distance = (p - last).distance;
    // Se interpola entre muestras para que la precisión no dependa de la
    // velocidad del dedo.
    final steps = math.max(1, (distance / 4).ceil());
    var sampled = last;
    for (var k = 1; k <= steps; k++) {
      sampled = last + (p - last) * (k / steps);
      _sample(sampled, now, distance / steps);
      if (completed) break;
    }
    if (distance > 0) strokes.last.add(sampled);
    _last = sampled;
  }

  void pointerUp({bool countLift = true}) {
    if (_down && !completed && countLift) lifts++;
    _down = false;
    _overDot = null;
  }

  void _sample(Offset p, DateTime now, [double distance = 0]) {
    final a = points[_next - 1];
    final b = points[_next];

    _total++;
    totalDistance += distance;
    if (distanceToSegment(p, a, b) <= tolerancePx ||
        (p - a).distance <= hitRadiusPx ||
        (p - b).distance <= hitRadiusPx) {
      _inside++;
      insideDistance += distance;
    }

    // ¿Llegó al punto que tocaba?
    if ((p - b).distance <= hitRadiusPx) {
      _next++;
      _overDot = null;
      if (completed) {
        _end = now;
        _closeTime(now);
        _down = false;
      }
      return;
    }

    // ¿Entró a un punto que todavía no le tocaba?
    int? over;
    for (var i = _next + 1; i < points.length; i++) {
      // El punto de cierre coincide con el inicio: salir de él no es un error.
      if (points.take(_next).contains(points[i])) continue;
      if ((p - points[i]).distance <= hitRadiusPx) {
        over = i;
        break;
      }
    }
    if (over != null && over != _overDot) _fueraDeOrden++;
    _overDot = over;
  }
}
