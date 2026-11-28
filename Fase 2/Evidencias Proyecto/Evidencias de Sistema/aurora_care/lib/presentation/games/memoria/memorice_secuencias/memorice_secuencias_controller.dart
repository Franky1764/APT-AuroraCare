// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencias_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

// Constantes de calibración (Memoria — planilla de Daniela). Agrupadas
// acá, con nombre, para poder consultarlas de un vistazo; los
// providers de abajo solo las devuelven, así que overridearlos en
// tests sigue funcionando igual que antes.

/// Cuántas imágenes tiene la secuencia de cada ronda, por nivel.
const int memoriceSecuenciaLongitudFacil = 3;
const int memoriceSecuenciaLongitudIntermedio = 4;
const int memoriceSecuenciaLongitudAvanzado = 5;

/// Imágenes disponibles en el panel de respuesta (fijas, mismas posiciones
/// toda la partida). La secuencia de cada ronda es un subconjunto de estas,
/// sin repetir.
const int memoriceSecuenciaPoolSize = 6;

/// Condición de fin de partida: lo que ocurra primero (igual en los 3
/// niveles). Fija el rango de `intentos` (rondasJugadas): mínimo
/// [memoriceSecuenciaRondasCorrectasParaGanar], máximo
/// [memoriceSecuenciaMaxRondasJugadas].
const int memoriceSecuenciaRondasCorrectasParaGanar = 5;
const int memoriceSecuenciaMaxRondasJugadas = 8;

/// Cuánto dura resaltada cada imagen al mostrar la secuencia, por nivel.
/// Provisorio — fácil de ajustar sin tocar el resto del controller.
const Duration memoriceSecuenciaExposicionFacil = Duration(milliseconds: 2000);
const Duration memoriceSecuenciaExposicionIntermedio = Duration(
  milliseconds: 1500,
);
const Duration memoriceSecuenciaExposicionAvanzado = Duration(
  milliseconds: 1200,
);

/// Pausa entre una imagen resaltada y la siguiente (igual en los 3
/// niveles, se aplica tras cada imagen, incluida la última antes de
/// responder).
const Duration memoriceSecuenciaPausaEntreImagenes = Duration(
  milliseconds: 500,
);

/// Cuánto se muestra la retroalimentación (acierto o la secuencia correcta
/// tras un error) antes de empezar la siguiente ronda. No se aplica tras
/// la ronda que termina la partida (ver `_terminarRonda`).
const Duration memoriceSecuenciaDuracionRetroalimentacion = Duration(
  milliseconds: 1800,
);

/// Cuántas imágenes tiene la secuencia de cada ronda, por nivel.
int longitudSecuenciaParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return memoriceSecuenciaLongitudFacil;
    case GameLevel.intermedio:
      return memoriceSecuenciaLongitudIntermedio;
    case GameLevel.avanzado:
      return memoriceSecuenciaLongitudAvanzado;
  }
}

/// Cuánto dura resaltada cada imagen al mostrar la secuencia, por nivel.
/// Sobreescribible en tests.
final memoriceSecuenciaHighlightDurationProvider =
    Provider.family<Duration, GameLevel>((ref, nivel) {
      switch (nivel) {
        case GameLevel.facil:
          return memoriceSecuenciaExposicionFacil;
        case GameLevel.intermedio:
          return memoriceSecuenciaExposicionIntermedio;
        case GameLevel.avanzado:
          return memoriceSecuenciaExposicionAvanzado;
      }
    });

/// Pausa entre una imagen resaltada y la siguiente (igual en los 3
/// niveles). Sobreescribible en tests.
final memoriceSecuenciaPauseDurationProvider = Provider<Duration>(
  (ref) => memoriceSecuenciaPausaEntreImagenes,
);

/// Cuánto se muestra la retroalimentación (acierto o la secuencia correcta
/// tras un error) antes de empezar la siguiente ronda. Sobreescribible en
/// tests para no esperar tiempo real.
final memoriceSecuenciaFeedbackDurationProvider = Provider<Duration>(
  (ref) => memoriceSecuenciaDuracionRetroalimentacion,
);

/// Generador para armar la secuencia de cada ronda. Sobreescribible en
/// tests.
final memoriceSecuenciaRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir tiempoSegundos (desde que arranca la primera ronda
/// hasta que termina la partida). Sobreescribible en tests.
final memoriceSecuenciaClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum MemoriceSecuenciaFase {
  /// Se está mostrando la secuencia, resaltando una imagen a la vez.
  mostrando,

  /// La persona puede tocar las imágenes para reproducirla.
  esperandoRespuesta,

  /// La ronda terminó (acierto o error); se muestra un mensaje breve antes
  /// de la siguiente ronda o del cierre de la partida.
  retroalimentacion,
}

class MemoriceSecuenciaState {
  const MemoriceSecuenciaState({
    required this.secuencia,
    required this.fase,
    required this.pasoResaltado,
    required this.progresoRespuesta,
    required this.rondasJugadas,
    required this.rondasCorrectas,
    required this.rondasConError,
    this.ultimaRondaCorrecta,
    this.indiceTocadoIncorrecto,
    this.metrics,
  });

  /// Los índices (0..5, posición en el panel de 6 imágenes) de la ronda
  /// actual, en el orden que hay que reproducir.
  final List<int> secuencia;

  final MemoriceSecuenciaFase fase;

  /// Durante "mostrando": posición (en `secuencia`) resaltada en este
  /// momento, o -1 si no hay ninguna (pausa entre imágenes).
  final int pasoResaltado;

  /// Durante "esperandoRespuesta": cuántos toques correctos lleva la
  /// persona en esta ronda.
  final int progresoRespuesta;

  final int rondasJugadas;
  final int rondasCorrectas;
  final int rondasConError;

  /// null mientras no hay retroalimentación que mostrar.
  final bool? ultimaRondaCorrecta;

  /// Qué imagen del panel tocó mal la persona (para resaltarla en rojo).
  /// null si la última ronda fue correcta.
  final int? indiceTocadoIncorrecto;

  /// No-null cuando la partida terminó (5 rondas correctas u 8 jugadas).
  final MemoriaMetrics? metrics;

  bool get isFinished => metrics != null;

  MemoriceSecuenciaState copyWith({
    List<int>? secuencia,
    MemoriceSecuenciaFase? fase,
    int? pasoResaltado,
    int? progresoRespuesta,
    int? rondasJugadas,
    int? rondasCorrectas,
    int? rondasConError,
    MemoriaMetrics? metrics,
  }) {
    return MemoriceSecuenciaState(
      secuencia: secuencia ?? this.secuencia,
      fase: fase ?? this.fase,
      pasoResaltado: pasoResaltado ?? this.pasoResaltado,
      progresoRespuesta: progresoRespuesta ?? this.progresoRespuesta,
      rondasJugadas: rondasJugadas ?? this.rondasJugadas,
      rondasCorrectas: rondasCorrectas ?? this.rondasCorrectas,
      rondasConError: rondasConError ?? this.rondasConError,
      ultimaRondaCorrecta: ultimaRondaCorrecta,
      indiceTocadoIncorrecto: indiceTocadoIncorrecto,
      metrics: metrics ?? this.metrics,
    );
  }
}

class MemoriceSecuenciaController
    extends AutoDisposeFamilyNotifier<MemoriceSecuenciaState, GameLevel> {
  Timer? _timer;
  DateTime? _startTime;
  late int _longitud;

  /// Instante en que empezó la pausa actual, o null si no está pausado.
  DateTime? _pausaInicio;

  /// Suma de todas las pausas anteriores, para restarla de tiempoSegundos.
  Duration _pausaAcumulada = Duration.zero;

  @override
  MemoriceSecuenciaState build(GameLevel arg) {
    ref.onDispose(() => _timer?.cancel());
    _longitud = longitudSecuenciaParaNivel(arg);
    _startTime = ref.read(memoriceSecuenciaClockProvider)();

    final inicial = _nuevaRonda(
      rondasJugadas: 0,
      rondasCorrectas: 0,
      rondasConError: 0,
    );
    _timer = Timer(
      ref.read(memoriceSecuenciaHighlightDurationProvider(arg)),
      () => _pauseStep(0),
    );
    return inicial;
  }

  List<int> _generarSecuencia() {
    final random = ref.read(memoriceSecuenciaRandomProvider);
    final indices = List<int>.generate(memoriceSecuenciaPoolSize, (i) => i)
      ..shuffle(random);
    return indices.take(_longitud).toList();
  }

  MemoriceSecuenciaState _nuevaRonda({
    required int rondasJugadas,
    required int rondasCorrectas,
    required int rondasConError,
  }) {
    return MemoriceSecuenciaState(
      secuencia: _generarSecuencia(),
      fase: MemoriceSecuenciaFase.mostrando,
      pasoResaltado: 0,
      progresoRespuesta: 0,
      rondasJugadas: rondasJugadas,
      rondasCorrectas: rondasCorrectas,
      rondasConError: rondasConError,
    );
  }

  void _highlightStep(int paso) {
    state = state.copyWith(
      fase: MemoriceSecuenciaFase.mostrando,
      pasoResaltado: paso,
    );
    _timer?.cancel();
    _timer = Timer(
      ref.read(memoriceSecuenciaHighlightDurationProvider(arg)),
      () => _pauseStep(paso),
    );
  }

  void _pauseStep(int paso) {
    state = state.copyWith(pasoResaltado: -1);
    _timer?.cancel();
    _timer = Timer(ref.read(memoriceSecuenciaPauseDurationProvider), () {
      if (paso + 1 < state.secuencia.length) {
        _highlightStep(paso + 1);
      } else {
        state = state.copyWith(
          fase: MemoriceSecuenciaFase.esperandoRespuesta,
          pasoResaltado: -1,
        );
      }
    });
  }

  /// Pausa la medición de tiempo y, si se está mostrando la secuencia,
  /// el Timer que la va revelando (para que no siga avanzando de fondo
  /// mientras se lee el tutorial "Ver cómo se juega"). En
  /// "esperandoRespuesta" no hay ningún Timer corriendo, así que solo
  /// queda pendiente retomar.
  void pausar() {
    if (state.isFinished || _pausaInicio != null) return;
    _pausaInicio = ref.read(memoriceSecuenciaClockProvider)();
    _timer?.cancel();
  }

  /// Reanuda la medición de tiempo. Si la secuencia se estaba mostrando,
  /// la reinicia desde el primer paso para que la persona la vea
  /// completa (no desde donde quedó al pausar). Idempotente si no
  /// estaba pausado.
  void reanudar() {
    if (_pausaInicio == null) return;
    final ahora = ref.read(memoriceSecuenciaClockProvider)();
    _pausaAcumulada += ahora.difference(_pausaInicio!);
    _pausaInicio = null;

    final current = state;
    if (current.isFinished) return;
    if (current.fase == MemoriceSecuenciaFase.mostrando) {
      state = current.copyWith(pasoResaltado: 0);
      _timer = Timer(
        ref.read(memoriceSecuenciaHighlightDurationProvider(arg)),
        () => _pauseStep(0),
      );
    }
    // esperandoRespuesta: no había Timer corriendo; solo se retoma.
  }

  /// La persona toca la imagen [poolIndex] (0..5) del panel de respuesta.
  /// Ignorado si no es su turno (mostrando la secuencia, en
  /// retroalimentación, o la partida ya terminó).
  void tapImage(int poolIndex) {
    final current = state;
    if (current.fase != MemoriceSecuenciaFase.esperandoRespuesta) return;

    final esperado = current.secuencia[current.progresoRespuesta];
    if (poolIndex == esperado) {
      final progreso = current.progresoRespuesta + 1;
      // Se persiste el progreso ANTES de terminar la ronda (si corresponde):
      // la fila de casilleros necesita ver el último casillero lleno, aunque
      // sea por un instante, antes de pasar a retroalimentación.
      state = current.copyWith(progresoRespuesta: progreso);
      if (progreso == current.secuencia.length) {
        _terminarRonda(exito: true, indiceTocadoIncorrecto: null);
      }
      return;
    }

    _terminarRonda(exito: false, indiceTocadoIncorrecto: poolIndex);
  }

  void _terminarRonda({required bool exito, required int? indiceTocadoIncorrecto}) {
    final current = state;
    final rondasJugadas = current.rondasJugadas + 1;
    final rondasCorrectas = current.rondasCorrectas + (exito ? 1 : 0);
    final rondasConError = current.rondasConError + (exito ? 0 : 1);

    final terminada =
        rondasCorrectas >= memoriceSecuenciaRondasCorrectasParaGanar ||
        rondasJugadas >= memoriceSecuenciaMaxRondasJugadas;

    MemoriaMetrics? metrics;
    if (terminada) {
      final ahora = ref.read(memoriceSecuenciaClockProvider)();
      final tiempoSegundos =
          ahora.difference(_startTime!) - _pausaAcumulada;
      metrics = MemoriaMetrics(
        errores: rondasConError,
        intentos: rondasJugadas,
        tiempoSegundos: tiempoSegundos.inSeconds,
        tasaAciertoPct: rondasCorrectas / rondasJugadas * 100,
      );
    }

    state = MemoriceSecuenciaState(
      secuencia: current.secuencia,
      fase: MemoriceSecuenciaFase.retroalimentacion,
      pasoResaltado: -1,
      progresoRespuesta: current.progresoRespuesta,
      rondasJugadas: rondasJugadas,
      rondasCorrectas: rondasCorrectas,
      rondasConError: rondasConError,
      ultimaRondaCorrecta: exito,
      indiceTocadoIncorrecto: indiceTocadoIncorrecto,
      metrics: metrics,
    );

    if (terminada) return;

    _timer?.cancel();
    _timer = Timer(ref.read(memoriceSecuenciaFeedbackDurationProvider), () {
      state = _nuevaRonda(
        rondasJugadas: rondasJugadas,
        rondasCorrectas: rondasCorrectas,
        rondasConError: rondasConError,
      );
      _timer = Timer(
        ref.read(memoriceSecuenciaHighlightDurationProvider(arg)),
        () => _pauseStep(0),
      );
    });
  }
}

final memoriceSecuenciasControllerProvider = NotifierProvider.autoDispose
    .family<MemoriceSecuenciaController, MemoriceSecuenciaState, GameLevel>(
      MemoriceSecuenciaController.new,
    );
