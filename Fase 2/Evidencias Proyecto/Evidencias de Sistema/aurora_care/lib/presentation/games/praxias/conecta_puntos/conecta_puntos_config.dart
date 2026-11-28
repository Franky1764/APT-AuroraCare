// lib/presentation/games/praxias/conecta_puntos/conecta_puntos_config.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/entities/game_level.dart';

/// Las 10 figuras de Conecta los puntos, ordenadas de menos a más puntos.
/// El orden importa: cada nivel toma una ventana de 5 figuras consecutivas.
enum ConectaFigure {
  pentagono, // 5 puntos
  hexagono, // 6
  flecha, // 7
  rayo, // 7
  octogono, // 8
  escalera, // 8
  casita, // 9
  estrella, // 10
  cruz, // 12
  estrellaSeisPuntas, // 12
}

/// Cuántas figuras se conectan en cada sesión.
const int figurasPorSesion = 3;

/// Figuras que puede sacar cada nivel (5 consecutivas de las 10). Las
/// ventanas se solapan a propósito, para que la dificultad suba de a poco.
///
/// - Fácil: pentágono, hexágono, flecha, rayo, octógono (5 a 8 puntos).
/// - Intermedio: rayo, octógono, escalera, casita, estrella (7 a 10).
/// - Avanzado: escalera, casita, estrella, cruz, estrella de 6 puntas (8 a 12).
List<ConectaFigure> figurasDelNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return ConectaFigure.values.sublist(0, 5);
    case GameLevel.intermedio:
      return ConectaFigure.values.sublist(3, 8);
    case GameLevel.avanzado:
      return ConectaFigure.values.sublist(5, 10);
  }
}

/// Elige las figuras de una sesión: [figurasPorSesion] distintas, al azar,
/// de las que corresponden al [nivel].
///
/// Si se pasa la sesión [anterior], evita repetir la misma secuencia y que
/// parta con la misma figura, para que no se sienta igual dos veces seguidas.
List<ConectaFigure> elegirFigurasSesion(
  GameLevel nivel,
  math.Random random, {
  List<ConectaFigure>? anterior,
}) {
  final pool = figurasDelNivel(nivel);
  late List<ConectaFigure> candidata;
  for (var intento = 0; intento < 20; intento++) {
    candidata = (List.of(
      pool,
    )..shuffle(random)).take(figurasPorSesion).toList();
    final repite =
        anterior != null &&
        anterior.isNotEmpty &&
        (candidata.first == anterior.first ||
            _mismaSecuencia(candidata, anterior));
    if (!repite) break;
  }
  return candidata;
}

bool _mismaSecuencia(List<ConectaFigure> a, List<ConectaFigure> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Tolerancia del trazo entre un punto y el siguiente, en píxeles lógicos.
/// Conserva los valores de referencia existentes (±15, ±10 y ±7).
/// Su equivalencia entre juegos queda pendiente de calibración con usuarios.
double toleranciaConectaPx(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 15;
    case GameLevel.intermedio:
      return 10;
    case GameLevel.avanzado:
      return 7;
  }
}

/// Radio de captura de cada punto. Con 24 px el punto mide 48 px de
/// diámetro, el mínimo recomendado para un objetivo táctil accesible.
const double conectaHitRadiusPx = 24;

/// Radio visual usado en la versión anterior; v2 dibuja objetivos de 48 dp.
const double conectaDotRadiusPx = 20;

/// Duración de referencia del cascarón; v2 no muestra cuenta regresiva.
Duration tiempoMaximoConecta(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 120);
    case GameLevel.intermedio:
      return const Duration(seconds: 180);
    case GameLevel.avanzado:
      return const Duration(seconds: 240);
  }
}

/// Puntos de una sesión "típica" del nivel: [figurasPorSesion] veces el
/// promedio de puntos de sus figuras (20, 25 y 31).
int puntosReferencia(GameLevel nivel) {
  final pool = figurasDelNivel(nivel);
  final promedio =
      pool.map((f) => f.puntosUnitarios.length).reduce((a, b) => a + b) /
      pool.length;
  return (promedio * figurasPorSesion).round();
}

/// Transformación histórica para leer pruebas y datos anteriores.
/// La experiencia v2 registra tiempo activo real y no utiliza esta función.
///
/// Como las figuras salen al azar, una sesión puede tener más puntos que
/// otra. Para que el score de tiempo sea comparable entre sesiones, el tiempo
/// real se reescala a los [puntosReferencia] del nivel:
/// tiempo_normalizado = tiempo_real × puntos_referencia / puntos_de_la_sesión.
int tiempoNormalizadoSeg(int tiempoMs, int puntosSesion, GameLevel nivel) {
  if (puntosSesion <= 0) return 0;
  return (tiempoMs / 1000 * puntosReferencia(nivel) / puntosSesion).round();
}

extension ConectaFigureShape on ConectaFigure {
  String get nombre {
    switch (this) {
      case ConectaFigure.pentagono:
        return 'pentágono';
      case ConectaFigure.hexagono:
        return 'hexágono';
      case ConectaFigure.flecha:
        return 'flecha';
      case ConectaFigure.rayo:
        return 'rayo';
      case ConectaFigure.octogono:
        return 'octógono';
      case ConectaFigure.escalera:
        return 'escalera';
      case ConectaFigure.casita:
        return 'casita';
      case ConectaFigure.estrella:
        return 'estrella';
      case ConectaFigure.cruz:
        return 'cruz';
      case ConectaFigure.estrellaSeisPuntas:
        return 'estrella de seis puntas';
    }
  }

  /// Nombre con artículo, para frases como "Formó la casita".
  String get nombreConArticulo {
    switch (this) {
      case ConectaFigure.pentagono:
        return 'el pentágono';
      case ConectaFigure.hexagono:
        return 'el hexágono';
      case ConectaFigure.flecha:
        return 'la flecha';
      case ConectaFigure.rayo:
        return 'el rayo';
      case ConectaFigure.octogono:
        return 'el octógono';
      case ConectaFigure.escalera:
        return 'la escalera';
      case ConectaFigure.casita:
        return 'la casita';
      case ConectaFigure.estrella:
        return 'la estrella';
      case ConectaFigure.cruz:
        return 'la cruz';
      case ConectaFigure.estrellaSeisPuntas:
        return 'la estrella de seis puntas';
    }
  }

  /// Puntos en coordenadas unitarias (0..1), en el orden en que hay que
  /// unirlos. La figura se cierra sola al unir el último con el primero.
  List<Offset> get puntosUnitarios {
    switch (this) {
      case ConectaFigure.pentagono:
        return _poligono(5, 0.40, 0.40);
      case ConectaFigure.hexagono:
        return _poligono(6, 0.38, 0.38);
      case ConectaFigure.flecha:
        return const [
          Offset(0.10, 0.38),
          Offset(0.52, 0.38),
          Offset(0.52, 0.14),
          Offset(0.92, 0.50),
          Offset(0.52, 0.86),
          Offset(0.52, 0.62),
          Offset(0.10, 0.62),
        ];
      case ConectaFigure.rayo:
        return const [
          Offset(0.50, 0.06),
          Offset(0.18, 0.54),
          Offset(0.44, 0.54),
          Offset(0.34, 0.94),
          Offset(0.84, 0.38),
          Offset(0.58, 0.38),
          Offset(0.80, 0.06),
        ];
      case ConectaFigure.octogono:
        return _poligono(8, 0.40, 0.40);
      case ConectaFigure.escalera:
        return const [
          Offset(0.10, 0.90),
          Offset(0.10, 0.62),
          Offset(0.38, 0.62),
          Offset(0.38, 0.34),
          Offset(0.66, 0.34),
          Offset(0.66, 0.08),
          Offset(0.90, 0.08),
          Offset(0.90, 0.90),
        ];
      case ConectaFigure.casita:
        return const [
          Offset(0.12, 0.88),
          Offset(0.12, 0.50),
          Offset(0.50, 0.12),
          Offset(0.88, 0.50),
          Offset(0.88, 0.88),
          Offset(0.64, 0.88),
          Offset(0.64, 0.62),
          Offset(0.36, 0.62),
          Offset(0.36, 0.88),
        ];
      case ConectaFigure.estrella:
        return _poligono(5, 0.42, 0.18);
      case ConectaFigure.cruz:
        return const [
          Offset(0.36, 0.08),
          Offset(0.64, 0.08),
          Offset(0.64, 0.36),
          Offset(0.92, 0.36),
          Offset(0.92, 0.64),
          Offset(0.64, 0.64),
          Offset(0.64, 0.92),
          Offset(0.36, 0.92),
          Offset(0.36, 0.64),
          Offset(0.08, 0.64),
          Offset(0.08, 0.36),
          Offset(0.36, 0.36),
        ];
      case ConectaFigure.estrellaSeisPuntas:
        return _poligono(6, 0.42, 0.242);
    }
  }

  /// Polígono regular (si los dos radios son iguales) o estrella (si el
  /// interno es menor), partiendo desde arriba en sentido horario.
  static List<Offset> _poligono(int lados, double rExterno, double rInterno) {
    final total = rExterno == rInterno ? lados : lados * 2;
    return [
      for (var i = 0; i < total; i++)
        () {
          final r = (rExterno == rInterno || i.isEven) ? rExterno : rInterno;
          final a = -math.pi / 2 + 2 * math.pi * i / total;
          return Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a));
        }(),
    ];
  }
}
