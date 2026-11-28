// lib/presentation/games/atencion/secuencias_colores/secuencias_colores_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

/// Cantidad de colores en el tablero (2 x 2).
const int secuenciasCantidadColores = 4;

/// Rondas por partida. Cada ronda es una secuencia que la persona repite.
const int secuenciasRondasPorPartida = 5;

/// Largo máximo que puede alcanzar una secuencia dentro de una partida.
const int secuenciasLongitudMaxima = 9;

/// Pausa con todos los colores apagados entre un estímulo y el siguiente.
const Duration secuenciasPausaEntreEstimulos = Duration(milliseconds: 400);

/// Pausa antes de empezar a mostrar una secuencia ("Mire con atención").
const Duration secuenciasPausaInicial = Duration(milliseconds: 1000);

/// Cuánto se muestra el mensaje de acierto o error antes de la ronda siguiente.
const Duration secuenciasPausaRetroalimentacion = Duration(milliseconds: 1500);

/// En qué momento de la ronda está el juego.
enum SecuenciaFase {
  /// El juego está mostrando la secuencia. No se puede tocar.
  mostrando,

  /// La persona debe tocar los colores en el mismo orden.
  turno,

  /// Repitió la secuencia completa sin equivocarse.
  acierto,

  /// Tocó un color que no correspondía.
  error,

  /// Terminaron todas las rondas. `metrics` ya no es null.
  terminado,
}

/// Largo de la primera secuencia por nivel (SCORING.md §2.3): 3/5/7.
int longitudInicialParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 3;
    case GameLevel.intermedio:
      return 5;
    case GameLevel.avanzado:
      return 7;
  }
}

/// Cuánto se ilumina cada color por nivel (SCORING.md §2.3): 1,5/1,0/0,7 s.
Duration duracionEstimuloParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(milliseconds: 1500);
    case GameLevel.intermedio:
      return const Duration(milliseconds: 1000);
    case GameLevel.avanzado:
      return const Duration(milliseconds: 700);
  }
}

class SecuenciasColoresState {
  const SecuenciasColoresState({
    required this.secuencia,
    required this.fase,
    required this.ronda,
    required this.pasoMostrado,
    required this.posicionEntrada,
    required this.toquesTotales,
    required this.toquesIncorrectos,
    required this.tiemposRespuestaMs,
    required this.alcance,
    this.iluminado,
    this.metrics,
  });

  /// Colores de la ronda actual, en orden (cada valor es 0..3).
  final List<int> secuencia;

  final SecuenciaFase fase;

  /// Ronda actual, empieza en 1.
  final int ronda;

  /// Cuántos colores de la secuencia ya se mostraron (fase mostrando).
  final int pasoMostrado;

  /// Color encendido en este momento, o null si todos están apagados.
  final int? iluminado;

  /// Cuántos colores ya repitió bien la persona en esta ronda (fase turno).
  final int posicionEntrada;

  final int toquesTotales;
  final int toquesIncorrectos;

  /// Tiempo de cada toque: desde que empieza el turno (primer toque) o
  /// desde el toque anterior (los siguientes).
  final List<int> tiemposRespuestaMs;

  /// Secuencia más larga repetida sin error (SCORING §2.3, "alcance").
  final int alcance;

  /// No-null cuando terminó la última ronda: la partida terminó.
  final AtencionMetrics? metrics;

  bool get isFinished => metrics != null;
  int get longitud => secuencia.length;

  SecuenciasColoresState copyWith({
    List<int>? secuencia,
    SecuenciaFase? fase,
    int? ronda,
    int? pasoMostrado,
    int? Function()? iluminado,
    int? posicionEntrada,
    int? toquesTotales,
    int? toquesIncorrectos,
    List<int>? tiemposRespuestaMs,
    int? alcance,
    AtencionMetrics? metrics,
  }) {
    return SecuenciasColoresState(
      secuencia: secuencia ?? this.secuencia,
      fase: fase ?? this.fase,
      ronda: ronda ?? this.ronda,
      pasoMostrado: pasoMostrado ?? this.pasoMostrado,
      iluminado: iluminado != null ? iluminado() : this.iluminado,
      posicionEntrada: posicionEntrada ?? this.posicionEntrada,
      toquesTotales: toquesTotales ?? this.toquesTotales,
      toquesIncorrectos: toquesIncorrectos ?? this.toquesIncorrectos,
      tiemposRespuestaMs: tiemposRespuestaMs ?? this.tiemposRespuestaMs,
      alcance: alcance ?? this.alcance,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Generador para armar las secuencias. Sobreescribible en tests.
final secuenciasRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir los tiempos de respuesta. Sobreescribible en tests.
final secuenciasClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Si es true, los temporizadores avanzan el juego solos. En tests se pone
/// en false y se llama a avanzarEstimulo() / continuar() a mano.
final secuenciasAutoPlayProvider = Provider<bool>((ref) => true);

class SecuenciasColoresController
    extends AutoDisposeFamilyNotifier<SecuenciasColoresState, GameLevel> {
  Timer? _timer;
  DateTime? _ultimoMarcador;

  @override
  SecuenciasColoresState build(GameLevel arg) {
    ref.onDispose(() => _timer?.cancel());
    _programar(secuenciasPausaInicial, avanzarEstimulo);
    return SecuenciasColoresState(
      secuencia: _nuevaSecuencia(longitudInicialParaNivel(arg)),
      fase: SecuenciaFase.mostrando,
      ronda: 1,
      pasoMostrado: 0,
      posicionEntrada: 0,
      toquesTotales: 0,
      toquesIncorrectos: 0,
      tiemposRespuestaMs: const [],
      alcance: 0,
    );
  }

  /// Secuencia al azar sin el mismo color dos veces seguidas: un color
  /// repetido se ve como uno solo encendido más tiempo y confunde.
  List<int> _nuevaSecuencia(int longitud) {
    final random = ref.read(secuenciasRandomProvider);
    final result = <int>[];
    while (result.length < longitud) {
      final color = random.nextInt(secuenciasCantidadColores);
      if (result.isNotEmpty && result.last == color) continue;
      result.add(color);
    }
    return result;
  }

  void _programar(Duration espera, void Function() accion) {
    _timer?.cancel();
    if (!ref.read(secuenciasAutoPlayProvider)) return;
    _timer = Timer(espera, accion);
  }

  /// Avanza un paso mientras se muestra la secuencia: enciende el color
  /// siguiente, lo apaga, y al terminar le da el turno a la persona.
  void avanzarEstimulo() {
    final s = state;
    if (s.fase != SecuenciaFase.mostrando) return;

    if (s.iluminado != null) {
      // Apagar el color actual y pasar al siguiente.
      state = s.copyWith(
        iluminado: () => null,
        pasoMostrado: s.pasoMostrado + 1,
      );
      _programar(secuenciasPausaEntreEstimulos, avanzarEstimulo);
      return;
    }

    if (s.pasoMostrado < s.longitud) {
      // Encender el color siguiente.
      state = s.copyWith(iluminado: () => s.secuencia[s.pasoMostrado]);
      _programar(duracionEstimuloParaNivel(arg), avanzarEstimulo);
      return;
    }

    // Ya se mostró todo: turno de la persona.
    _ultimoMarcador = ref.read(secuenciasClockProvider)();
    state = s.copyWith(fase: SecuenciaFase.turno, posicionEntrada: 0);
  }

  /// La persona toca el color [color] (0..3). Ignorado fuera de su turno.
  void tocarColor(int color) {
    final s = state;
    if (s.fase != SecuenciaFase.turno) return;

    final ahora = ref.read(secuenciasClockProvider)();
    final tiempo = ahora.difference(_ultimoMarcador ?? ahora).inMilliseconds;
    _ultimoMarcador = ahora;

    final tiempos = [...s.tiemposRespuestaMs, tiempo];
    final toquesTotales = s.toquesTotales + 1;

    if (color != s.secuencia[s.posicionEntrada]) {
      state = s.copyWith(
        fase: SecuenciaFase.error,
        toquesTotales: toquesTotales,
        toquesIncorrectos: s.toquesIncorrectos + 1,
        tiemposRespuestaMs: tiempos,
      );
      _programar(secuenciasPausaRetroalimentacion, continuar);
      return;
    }

    final posicion = s.posicionEntrada + 1;
    if (posicion < s.longitud) {
      state = s.copyWith(
        posicionEntrada: posicion,
        toquesTotales: toquesTotales,
        tiemposRespuestaMs: tiempos,
      );
      return;
    }

    // Repitió la secuencia completa.
    state = s.copyWith(
      fase: SecuenciaFase.acierto,
      posicionEntrada: posicion,
      toquesTotales: toquesTotales,
      tiemposRespuestaMs: tiempos,
      alcance: max(s.alcance, s.longitud),
    );
    _programar(secuenciasPausaRetroalimentacion, continuar);
  }

  /// Después del mensaje de acierto o error: pasa a la ronda siguiente o
  /// termina la partida. Si acertó, la secuencia siguiente tiene un color
  /// más; si se equivocó, mantiene el mismo largo.
  void continuar() {
    final s = state;
    if (s.fase != SecuenciaFase.acierto && s.fase != SecuenciaFase.error) {
      return;
    }

    if (s.ronda >= secuenciasRondasPorPartida) {
      state = s.copyWith(fase: SecuenciaFase.terminado, metrics: _metricas(s));
      return;
    }

    final siguienteLongitud = s.fase == SecuenciaFase.acierto
        ? min(s.longitud + 1, secuenciasLongitudMaxima)
        : s.longitud;

    state = s.copyWith(
      secuencia: _nuevaSecuencia(siguienteLongitud),
      fase: SecuenciaFase.mostrando,
      ronda: s.ronda + 1,
      pasoMostrado: 0,
      iluminado: () => null,
      posicionEntrada: 0,
    );
    _programar(secuenciasPausaInicial, avanzarEstimulo);
  }

  /// Métricas de SCORING §2.3 para Secuencias de colores.
  AtencionMetrics _metricas(SecuenciasColoresState s) {
    final tasaError =
        s.toquesTotales == 0 ? 0.0 : s.toquesIncorrectos / s.toquesTotales * 100;
    final promedio = s.tiemposRespuestaMs.isEmpty
        ? 0
        : (s.tiemposRespuestaMs.reduce((a, b) => a + b) /
                  s.tiemposRespuestaMs.length)
              .round();
    return AtencionMetrics(
      tiempoRespuestaMs: promedio,
      tasaErrorPct: tasaError,
      alcance: s.alcance,
    );
  }
}

final secuenciasColoresControllerProvider = NotifierProvider.autoDispose
    .family<SecuenciasColoresController, SecuenciasColoresState, GameLevel>(
      SecuenciasColoresController.new,
    );
