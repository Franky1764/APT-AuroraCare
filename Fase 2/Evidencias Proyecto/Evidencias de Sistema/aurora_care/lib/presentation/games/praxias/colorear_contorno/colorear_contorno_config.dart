// lib/presentation/games/praxias/colorear_contorno/colorear_contorno_config.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/entities/game_level.dart';

/// Las 10 figuras de Colorear dentro del contorno, ordenadas de más simple a
/// más compleja. El orden importa: cada nivel toma una ventana de 5 figuras
/// consecutivas (igual que Conecta los puntos).
enum ColorearFigure {
  circulo,
  cuadrado,
  triangulo,
  casita,
  gota,
  corazon,
  pez,
  flor,
  luna,
  estrella,
}

/// Cuántas figuras se colorean en cada sesión.
const int figurasPorSesionColorear = 3;

/// Figuras que puede sacar cada nivel (5 consecutivas de las 10).
///
/// - Fácil: círculo, cuadrado, triángulo, casita, gota.
/// - Intermedio: casita, gota, corazón, pez, flor.
/// - Avanzado: corazón, pez, flor, luna, estrella.
List<ColorearFigure> figurasDelNivelColorear(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return ColorearFigure.values.sublist(0, 5);
    case GameLevel.intermedio:
      return ColorearFigure.values.sublist(3, 8);
    case GameLevel.avanzado:
      return ColorearFigure.values.sublist(5, 10);
  }
}

/// Elige las figuras de una sesión: [figurasPorSesionColorear] distintas, al
/// azar, de las que corresponden al [nivel]. Si se pasa la sesión [anterior],
/// evita repetir la misma secuencia y que parta con la misma figura.
List<ColorearFigure> elegirFigurasColorear(
  GameLevel nivel,
  math.Random random, {
  List<ColorearFigure>? anterior,
}) {
  final pool = figurasDelNivelColorear(nivel);
  late List<ColorearFigure> candidata;
  for (var intento = 0; intento < 20; intento++) {
    candidata = (List.of(pool)..shuffle(random))
        .take(figurasPorSesionColorear)
        .toList();
    final repite =
        anterior != null &&
        anterior.isNotEmpty &&
        (candidata.first == anterior.first ||
            _mismaSecuencia(candidata, anterior));
    if (!repite) break;
  }
  return candidata;
}

bool _mismaSecuencia(List<ColorearFigure> a, List<ColorearFigure> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Parámetros por nivel
// ---------------------------------------------------------------------------

/// Margen (px) que se tolera fuera del borde antes de contar una salida.
/// Es el mismo que usan Trazado guiado y Conecta (15 / 10 / 7), para que la
/// dificultad sea comparable entre los 3 juegos de Motricidad.
double toleranciaColorearPx(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 15;
    case GameLevel.intermedio:
      return 10;
    case GameLevel.avanzado:
      return 7;
  }
}

/// Radio del pincel (px). Más fino = más pasadas = más precisión necesaria.
double radioPincelPx(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 18;
    case GameLevel.intermedio:
      return 14;
    case GameLevel.avanzado:
      return 11;
  }
}

/// Fracción del interior que hay que pintar para dar la figura por lista.
double coberturaObjetivo(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 0.80;
    case GameLevel.intermedio:
      return 0.85;
    case GameLevel.avanzado:
      return 0.90;
  }
}

/// Tiempo máximo de la sesión completa (3 figuras), en segundos.
const Map<GameLevel, int> _tiempoMaximo = {
  GameLevel.facil: 150,
  GameLevel.intermedio: 210,
  GameLevel.avanzado: 270,
};

int tiempoMaximoColorearSeg(GameLevel nivel) => _tiempoMaximo[nivel]!;

/// Para GameDefinition.maxDuration (función de nivel → duración).
Duration tiempoMaximoColorear(GameLevel nivel) =>
    Duration(seconds: tiempoMaximoColorearSeg(nivel));

/// Área de referencia del nivel: 3 × el área media de sus figuras (en
/// unidades del cuadrado unitario). Sirve para que el tiempo sea comparable
/// aunque a una sesión le toquen figuras más grandes o más chicas.
double areaReferencia(GameLevel nivel) {
  final pool = figurasDelNivelColorear(nivel);
  final media = pool.map((f) => f.areaUnitaria).reduce((a, b) => a + b) /
      pool.length;
  return figurasPorSesionColorear * media;
}

/// Tiempo de la sesión normalizado al área de referencia del nivel:
/// tiempo × (areaReferencia / areaSesion).
int tiempoNormalizadoColorearSeg(
  int tiempoMs,
  double areaSesion,
  GameLevel nivel,
) {
  if (areaSesion <= 0) return 0;
  return (tiempoMs / 1000 * areaReferencia(nivel) / areaSesion).round();
}

// ---------------------------------------------------------------------------
// Geometría de las figuras (coordenadas en el cuadrado unitario 0..1)
// ---------------------------------------------------------------------------

extension ColorearFigureShape on ColorearFigure {
  String get nombre {
    switch (this) {
      case ColorearFigure.circulo:
        return 'círculo';
      case ColorearFigure.cuadrado:
        return 'cuadrado';
      case ColorearFigure.triangulo:
        return 'triángulo';
      case ColorearFigure.casita:
        return 'casita';
      case ColorearFigure.gota:
        return 'gota';
      case ColorearFigure.corazon:
        return 'corazón';
      case ColorearFigure.pez:
        return 'pez';
      case ColorearFigure.flor:
        return 'flor';
      case ColorearFigure.luna:
        return 'luna';
      case ColorearFigure.estrella:
        return 'estrella';
    }
  }

  String get nombreConArticulo {
    switch (this) {
      case ColorearFigure.casita:
      case ColorearFigure.gota:
      case ColorearFigure.flor:
      case ColorearFigure.luna:
      case ColorearFigure.estrella:
        return 'la $nombre';
      default:
        return 'el $nombre';
    }
  }

  /// Área del polígono en unidades del cuadrado unitario (fórmula de Gauss).
  double get areaUnitaria {
    final p = puntosUnitarios;
    var suma = 0.0;
    for (var i = 0; i < p.length; i++) {
      final a = p[i];
      final b = p[(i + 1) % p.length];
      suma += a.dx * b.dy - b.dx * a.dy;
    }
    return suma.abs() / 2;
  }

  /// Contorno de la figura como polígono cerrado (sin repetir el primer
  /// punto), en coordenadas 0..1. Ninguno se cruza consigo mismo.
  List<Offset> get puntosUnitarios {
    switch (this) {
      case ColorearFigure.circulo:
        return [
          for (var i = 0; i < 48; i++)
            Offset(
              0.5 + 0.47 * math.cos(2 * math.pi * i / 48 - math.pi / 2),
              0.5 + 0.47 * math.sin(2 * math.pi * i / 48 - math.pi / 2),
            ),
        ];
      case ColorearFigure.cuadrado:
        return const [
          Offset(0.1, 0.1),
          Offset(0.9, 0.1),
          Offset(0.9, 0.9),
          Offset(0.1, 0.9),
        ];
      case ColorearFigure.triangulo:
        return const [Offset(0.5, 0.08), Offset(0.93, 0.88), Offset(0.07, 0.88)];
      case ColorearFigure.casita:
        return const [
          Offset(0.06, 0.48),
          Offset(0.5, 0.08),
          Offset(0.94, 0.48),
          Offset(0.82, 0.48),
          Offset(0.82, 0.92),
          Offset(0.18, 0.92),
          Offset(0.18, 0.48),
        ];
      case ColorearFigure.gota:
        return _gota();
      case ColorearFigure.corazon:
        return _corazon();
      case ColorearFigure.pez:
        return _pez();
      case ColorearFigure.flor:
        return [
          for (var i = 0; i < 72; i++) _petalo(2 * math.pi * i / 72),
        ];
      case ColorearFigure.luna:
        return _luna();
      case ColorearFigure.estrella:
        return [
          for (var i = 0; i < 10; i++)
            Offset(
              0.5 +
                  (i.isEven ? 0.48 : 0.21) *
                      math.cos(-math.pi / 2 + math.pi * i / 5),
              0.52 +
                  (i.isEven ? 0.48 : 0.21) *
                      math.sin(-math.pi / 2 + math.pi * i / 5),
            ),
        ];
    }
  }
}

/// Gota: punta arriba y panza redonda (arco tangente a la punta).
List<Offset> _gota() {
  const cx = 0.5, cy = 0.64, r = 0.30;
  const topY = 0.06;
  final a = math.acos(r / (cy - topY));
  final a0 = -math.pi / 2 + a;
  final a1 = 3 * math.pi / 2 - a;
  const n = 36;
  return [
    const Offset(0.5, topY),
    for (var i = 0; i <= n; i++)
      Offset(
        cx + r * math.cos(a0 + (a1 - a0) * i / n),
        cy + r * math.sin(a0 + (a1 - a0) * i / n),
      ),
  ];
}

/// Corazón (curva clásica), centrado y escalado al cuadrado unitario.
List<Offset> _corazon() {
  const n = 48;
  const escala = 0.44 / 16;
  const yMedio = (-17.0 + 11.921778271432984) / 2;
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = 2 * math.pi * i / n;
        final sen = math.sin(t);
        final x = 16 * sen * sen * sen;
        final y =
            13 * math.cos(t) -
            5 * math.cos(2 * t) -
            2 * math.cos(3 * t) -
            math.cos(4 * t);
        return Offset(0.5 + x * escala, 0.52 - (y - yMedio) * escala);
      }(),
  ];
}

/// Pez: cuerpo ovalado con cola triangular a la derecha.
List<Offset> _pez() {
  const pasos = 32;
  const t0 = 0.5;
  final t1 = 2 * math.pi - 0.5;
  return [
    for (var i = 0; i <= pasos; i++)
      Offset(
        0.40 + 0.32 * math.cos(t0 + (t1 - t0) * i / pasos),
        0.5 + 0.24 * math.sin(t0 + (t1 - t0) * i / pasos),
      ),
    const Offset(0.93, 0.22),
    const Offset(0.82, 0.5),
    const Offset(0.93, 0.78),
  ];
}

/// Flor de 5 pétalos redondeados.
Offset _petalo(double t) {
  final r = 0.31 + 0.12 * math.cos(5 * t);
  return Offset(
    0.5 + r * math.cos(t - math.pi / 2),
    0.5 + r * math.sin(t - math.pi / 2),
  );
}

/// Luna creciente: arco exterior (círculo grande) más arco interior
/// (círculo chico recortado), con las puntas en las intersecciones.
List<Offset> _luna() {
  const ox = 0.5, oy = 0.5, ro = 0.42;
  const ix = 0.66, iy = 0.42, ri = 0.33;
  // Ángulos de las intersecciones, calculados con anterioridad.
  const e0 = 0.38343923443811634, e1 = 4.972450854739858;
  const i0 = 4.55415048656681, i1 = 0.8017396026111642;
  const nE = 40, nI = 24;
  return [
    for (var k = 0; k <= nE; k++)
      Offset(
        ox + ro * math.cos(e0 + (e1 - e0) * k / nE),
        oy + ro * math.sin(e0 + (e1 - e0) * k / nE),
      ),
    for (var k = 1; k < nI; k++)
      Offset(
        ix + ri * math.cos(i0 + (i1 - i0) * k / nI),
        iy + ri * math.sin(i0 + (i1 - i0) * k / nI),
      ),
  ];
}