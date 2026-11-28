// lib/presentation/games/praxias/colorear_contorno/colorear_contorno_logic.dart
import 'dart:math' as math;
import 'dart:ui';

/// Distancia de [p] al segmento [a]-[b].
double distanciaASegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final largo2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (largo2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / largo2)
      .clamp(0.0, 1.0)
      .toDouble();
  return (p - Offset(a.dx + t * ab.dx, a.dy + t * ab.dy)).distance;
}

/// ¿Está [p] dentro del polígono? (regla par-impar)
bool puntoEnPoligono(Offset p, List<Offset> poligono) {
  var dentro = false;
  for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    final a = poligono[i];
    final b = poligono[j];
    if ((a.dy > p.dy) != (b.dy > p.dy)) {
      final xCruce = a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
      if (p.dx < xCruce) dentro = !dentro;
    }
  }
  return dentro;
}

/// Distancia de [p] al contorno por fuera: 0 si está dentro del polígono.
double distanciaPorFuera(Offset p, List<Offset> poligono) {
  if (puntoEnPoligono(p, poligono)) return 0;
  var mejor = double.infinity;
  for (var i = 0; i < poligono.length; i++) {
    final d = distanciaASegmento(
      p,
      poligono[i],
      poligono[(i + 1) % poligono.length],
    );
    if (d < mejor) mejor = d;
  }
  return mejor;
}

/// Escala los puntos unitarios (0..1) al cuadrado [area] de la pantalla.
List<Offset> escalarPuntos(List<Offset> unitarios, Rect area) => [
  for (final p in unitarios)
    Offset(area.left + p.dx * area.width, area.top + p.dy * area.height),
];

/// Evalúa un coloreado dentro de un contorno. Lógica pura (sin Flutter), para
/// poder probarla sin pantalla.
///
/// - El pincel pinta al arrastrar. Se interpola cada ~4 px, así la precisión
///   no depende de la velocidad del dedo.
/// - Una muestra está "dentro" si cae en la figura o a no más de
///   [tolerancePx] por fuera del borde.
/// - Corrección = cada vez que el trazo pasa de dentro a fuera (una por
///   salida). Levantar el dedo no es una corrección.
/// - La figura queda lista cuando se pintó al menos [coberturaObjetivo] del
///   interior (fracción 0..1).
class ColorearEvaluator {
  ColorearEvaluator({
    required this.poligono,
    required this.tolerancePx,
    required this.brushRadiusPx,
    required this.coberturaObjetivo,
    this.cellPx = 8,
  }) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in poligono) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    _x0 = minX;
    _y0 = minY;
    _cols = ((maxX - minX) / cellPx).floor() + 1;
    _rows = ((maxY - minY) / cellPx).floor() + 1;
    _interior = List.filled(_cols * _rows, false);
    _pintada = List.filled(_cols * _rows, false);
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (puntoEnPoligono(_centro(r, c), poligono)) {
          _interior[r * _cols + c] = true;
          _celdasTotales++;
        }
      }
    }
  }

  final List<Offset> poligono;
  final double tolerancePx;
  final double brushRadiusPx;
  final double coberturaObjetivo;
  final double cellPx;

  /// Distancia máxima fuera del borde para aceptar el primer toque, en
  /// múltiplos de la tolerancia. Un toque más lejos se ignora.
  static const double _factorToqueInicial = 3;

  late final double _x0;
  late final double _y0;
  late final int _cols;
  late final int _rows;
  late final List<bool> _interior;
  late final List<bool> _pintada;
  int _celdasTotales = 0;
  int _celdasPintadas = 0;

  final List<List<Offset>> _strokes = [];
  Offset? _ultimo;
  bool _estabaDentro = true;
  bool _completed = false;
  int _dentro = 0;
  int _total = 0;
  int _correcciones = 0;
  DateTime? _inicio;
  DateTime? _fin;

  bool get completed => _completed;
  int get puntosDentro => _dentro;
  int get puntosTotales => _total;
  int get correcciones => _correcciones;
  List<List<Offset>> get strokes => _strokes;

  /// Fracción del interior ya pintada (0..1).
  double get cobertura =>
      _celdasTotales == 0 ? 0 : _celdasPintadas / _celdasTotales;

  /// Avance hacia la meta (0..1), para la barra de progreso.
  double get avance => (cobertura / coberturaObjetivo).clamp(0.0, 1.0).toDouble();

  /// % de muestras dentro del contorno (con tolerancia).
  double get precisionPct => _total == 0 ? 0 : _dentro / _total * 100;

  /// Tiempo desde el primer toque hasta completar (o hasta ahora).
  int get tiempoMs {
    final ini = _inicio;
    if (ini == null) return 0;
    return (_fin ?? DateTime.now()).difference(ini).inMilliseconds;
  }

  Offset _centro(int r, int c) =>
      Offset(_x0 + (c + 0.5) * cellPx, _y0 + (r + 0.5) * cellPx);

  void pointerDown(Offset p, DateTime now) {
    if (_completed) return;
    if (distanciaPorFuera(p, poligono) > _factorToqueInicial * tolerancePx) {
      return;
    }
    _inicio ??= now;
    _strokes.add([p]);
    _ultimo = p;
    _estabaDentro = true;
    _muestra(p);
    _revisar(now);
  }

  void pointerMove(Offset p, DateTime now) {
    final u = _ultimo;
    if (_completed || u == null) return;
    final d = (p - u).distance;
    final pasos = math.max(1, (d / 4).ceil());
    for (var i = 1; i <= pasos; i++) {
      final q = Offset.lerp(u, p, i / pasos)!;
      _strokes.last.add(q);
      _muestra(q);
      _revisar(now);
      if (_completed) break;
    }
    _ultimo = p;
  }

  void pointerUp() {
    _ultimo = null;
  }

  void _muestra(Offset p) {
    _total++;
    final dentro = distanciaPorFuera(p, poligono) <= tolerancePx;
    if (dentro) {
      _dentro++;
    } else if (_estabaDentro) {
      _correcciones++;
    }
    _estabaDentro = dentro;

    // Pinta las celdas interiores que quedan bajo el pincel.
    final c0 = ((p.dx - brushRadiusPx - _x0) / cellPx).floor();
    final c1 = ((p.dx + brushRadiusPx - _x0) / cellPx).floor();
    final r0 = ((p.dy - brushRadiusPx - _y0) / cellPx).floor();
    final r1 = ((p.dy + brushRadiusPx - _y0) / cellPx).floor();
    for (var r = math.max(0, r0); r <= math.min(_rows - 1, r1); r++) {
      for (var c = math.max(0, c0); c <= math.min(_cols - 1, c1); c++) {
        final i = r * _cols + c;
        if (_interior[i] &&
            !_pintada[i] &&
            (_centro(r, c) - p).distance <= brushRadiusPx) {
          _pintada[i] = true;
          _celdasPintadas++;
        }
      }
    }
  }

  void _revisar(DateTime now) {
    if (!_completed && cobertura >= coberturaObjetivo) {
      _completed = true;
      _fin = now;
    }
  }
}