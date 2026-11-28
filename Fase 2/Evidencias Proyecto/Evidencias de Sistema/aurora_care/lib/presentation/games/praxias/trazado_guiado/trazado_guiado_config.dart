// lib/presentation/games/praxias/trazado_guiado/trazado_guiado_config.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/entities/game_level.dart';

/// Las 10 figuras de Trazado guiado, ordenadas de más simple a más compleja.
/// El orden importa: cada nivel toma una ventana de 5 figuras consecutivas
/// (igual que Conecta los puntos y Colorear dentro del contorno).
enum TrazadoFigure {
  recta,
  curva,
  onda,
  zigzag,
  circulo,
  cuadrado,
  triangulo,
  casita,
  estrella,
  espiral,
}

/// Cuántas figuras se trazan en cada sesión.
const int figurasPorSesionTrazado = 3;

/// Figuras que puede sacar cada nivel (5 consecutivas de las 10). Las
/// ventanas se solapan a propósito para que la dificultad suba de a poco.
///
/// - Fácil: línea recta, línea curva, onda, zigzag y círculo.
/// - Intermedio: onda, zigzag, círculo, cuadrado y triángulo.
/// - Avanzado: cuadrado, triángulo, casita, estrella y espiral.
List<TrazadoFigure> figurasDelNivelTrazado(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return TrazadoFigure.values.sublist(0, 5);
    case GameLevel.intermedio:
      return TrazadoFigure.values.sublist(3, 8);
    case GameLevel.avanzado:
      return TrazadoFigure.values.sublist(5, 10);
  }
}

/// Elige las figuras de una sesión: [figurasPorSesionTrazado] distintas, al
/// azar, de las que corresponden al [nivel]. Si se pasa la sesión [anterior],
/// evita repetir la misma secuencia y que parta con la misma figura.
List<TrazadoFigure> elegirFigurasTrazado(
  GameLevel nivel,
  math.Random random, {
  List<TrazadoFigure>? anterior,
}) {
  final pool = figurasDelNivelTrazado(nivel);
  late List<TrazadoFigure> candidata;
  for (var intento = 0; intento < 20; intento++) {
    candidata = (List.of(pool)..shuffle(random))
        .take(figurasPorSesionTrazado)
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

bool _mismaSecuencia(List<TrazadoFigure> a, List<TrazadoFigure> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Tolerancia del trazo en píxeles lógicos (SCORING.md §2.4):
/// ±15 px, ±10 px y ±7 px.
double toleranciaPx(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 15;
    case GameLevel.intermedio:
      return 10;
    case GameLevel.avanzado:
      return 7;
  }
}

/// Tiempo máximo de la sesión completa (3 figuras). Propuesta; se calibra
/// con usuarios.
Duration tiempoMaximoTrazado(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 90);
    case GameLevel.intermedio:
      return const Duration(seconds: 135);
    case GameLevel.avanzado:
      return const Duration(seconds: 180);
  }
}

/// Longitud de referencia del nivel: 3 × la longitud media de sus figuras
/// (en unidades del cuadrado unitario). Sirve para que el tiempo sea
/// comparable aunque a una sesión le toquen figuras más largas o más cortas.
double longitudReferenciaTrazado(GameLevel nivel) {
  final pool = figurasDelNivelTrazado(nivel);
  final media =
      pool.map((f) => f.longitudUnitaria).reduce((a, b) => a + b) /
      pool.length;
  return figurasPorSesionTrazado * media;
}

/// Tiempo de la sesión normalizado a la longitud de referencia del nivel:
/// tiempo × (longitudReferencia / longitudSesión).
int tiempoNormalizadoTrazadoSeg(
  int tiempoMs,
  double longitudSesion,
  GameLevel nivel,
) {
  if (longitudSesion <= 0) return 0;
  return (tiempoMs / 1000 * longitudReferenciaTrazado(nivel) / longitudSesion)
      .round();
}

extension TrazadoFigureShape on TrazadoFigure {
  String get nombre {
    switch (this) {
      case TrazadoFigure.recta:
        return 'línea recta';
      case TrazadoFigure.curva:
        return 'línea curva';
      case TrazadoFigure.onda:
        return 'onda';
      case TrazadoFigure.zigzag:
        return 'zigzag';
      case TrazadoFigure.circulo:
        return 'círculo';
      case TrazadoFigure.cuadrado:
        return 'cuadrado';
      case TrazadoFigure.triangulo:
        return 'triángulo';
      case TrazadoFigure.casita:
        return 'casita';
      case TrazadoFigure.estrella:
        return 'estrella';
      case TrazadoFigure.espiral:
        return 'espiral';
    }
  }

  String get nombreConArticulo {
    switch (this) {
      case TrazadoFigure.recta:
      case TrazadoFigure.curva:
      case TrazadoFigure.onda:
      case TrazadoFigure.casita:
      case TrazadoFigure.estrella:
      case TrazadoFigure.espiral:
        return 'la $nombre';
      default:
        return 'el $nombre';
    }
  }

  /// Largo del trazo en unidades del cuadrado unitario.
  double get longitudUnitaria {
    final p = puntosUnitarios;
    var total = 0.0;
    for (var i = 1; i < p.length; i++) {
      total += (p[i] - p[i - 1]).distance;
    }
    return total;
  }

  /// Puntos de la figura en coordenadas unitarias (0..1) dentro de un
  /// cuadrado. El primero es el inicio y el último el final del trazo. En
  /// las figuras cerradas el último punto coincide con el primero.
  List<Offset> get puntosUnitarios {
    switch (this) {
      case TrazadoFigure.recta:
        return const [Offset(0.1, 0.5), Offset(0.9, 0.5)];
      case TrazadoFigure.curva:
        return [
          for (var i = 0; i <= 40; i++)
            Offset(
              0.1 + 0.8 * (i / 40),
              0.65 - 0.3 * math.sin(math.pi * (i / 40)),
            ),
        ];
      case TrazadoFigure.onda:
        return [
          for (var i = 0; i <= 48; i++)
            Offset(
              0.1 + 0.8 * (i / 48),
              0.5 - 0.2 * math.sin(2 * math.pi * (i / 48)),
            ),
        ];
      case TrazadoFigure.zigzag:
        return const [
          Offset(0.1, 0.72),
          Offset(0.3, 0.28),
          Offset(0.5, 0.72),
          Offset(0.7, 0.28),
          Offset(0.9, 0.72),
        ];
      case TrazadoFigure.circulo:
        return [
          for (var i = 0; i <= 72; i++)
            Offset(
              0.5 + 0.35 * math.cos(-math.pi / 2 + 2 * math.pi * (i / 72)),
              0.5 + 0.35 * math.sin(-math.pi / 2 + 2 * math.pi * (i / 72)),
            ),
        ];
      case TrazadoFigure.cuadrado:
        return const [
          Offset(0.2, 0.2),
          Offset(0.8, 0.2),
          Offset(0.8, 0.8),
          Offset(0.2, 0.8),
          Offset(0.2, 0.2),
        ];
      case TrazadoFigure.triangulo:
        return const [
          Offset(0.5, 0.15),
          Offset(0.85, 0.8),
          Offset(0.15, 0.8),
          Offset(0.5, 0.15),
        ];
      case TrazadoFigure.casita:
        return const [
          Offset(0.2, 0.85),
          Offset(0.2, 0.5),
          Offset(0.5, 0.2),
          Offset(0.8, 0.5),
          Offset(0.8, 0.85),
          Offset(0.2, 0.85),
        ];
      case TrazadoFigure.estrella:
        final vertices = [
          for (var i = 0; i < 10; i++)
            Offset(
              0.5 +
                  (i.isEven ? 0.42 : 0.18) *
                      math.cos(-math.pi / 2 + math.pi * i / 5),
              0.55 +
                  (i.isEven ? 0.42 : 0.18) *
                      math.sin(-math.pi / 2 + math.pi * i / 5),
            ),
        ];
        return [...vertices, vertices.first];
      case TrazadoFigure.espiral:
        // Dos vueltas desde el centro hacia afuera.
        return [
          for (var i = 0; i <= 160; i++)
            Offset(
              0.5 +
                  (0.04 + 0.38 * (i / 160)) * math.cos(4 * math.pi * (i / 160)),
              0.5 +
                  (0.04 + 0.38 * (i / 160)) * math.sin(4 * math.pi * (i / 160)),
            ),
        ];
    }
  }
}