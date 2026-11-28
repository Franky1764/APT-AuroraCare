// lib/presentation/games/memoria/recuerde_numero/recuerde_numero_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

// Constantes de calibración (Memoria — planilla de Daniela). Agrupadas
// acá, con nombre, para poder consultarlas de un vistazo; los
// providers de abajo solo las devuelven, así que overridearlos en
// tests sigue funcionando igual que antes.

/// Dígitos del número por nivel: Fácil 3, Intermedio 4, Avanzado 5.
const int recuerdeNumeroDigitosFacil = 3;
const int recuerdeNumeroDigitosIntermedio = 4;
const int recuerdeNumeroDigitosAvanzado = 5;

/// Condición de fin de partida: lo que ocurra primero (igual en los 3
/// niveles, mismo patrón que Memorice de secuencias). Fija el rango de
/// `intentos` (rondasJugadas): mínimo
/// [recuerdeNumeroRondasCorrectasParaGanar], máximo
/// [recuerdeNumeroMaxRondasJugadas].
const int recuerdeNumeroRondasCorrectasParaGanar = 5;
const int recuerdeNumeroMaxRondasJugadas = 8;

/// Cuánto se muestra el número antes de ocultarse, por nivel. Provisorio
/// — fácil de ajustar sin tocar el resto del controller.
const Duration recuerdeNumeroVisualizacionFacil = Duration(
  milliseconds: 3000,
);
const Duration recuerdeNumeroVisualizacionIntermedio = Duration(
  milliseconds: 4000,
);
const Duration recuerdeNumeroVisualizacionAvanzado = Duration(
  milliseconds: 5000,
);

/// Cuánto se muestra la retroalimentación (acierto o el número correcto
/// tras un error) antes de empezar la siguiente ronda. No se aplica tras
/// la ronda que termina la partida (ver `_terminarRonda`).
const Duration recuerdeNumeroDuracionRetroalimentacion = Duration(
  milliseconds: 1800,
);

/// Dígitos del número por nivel: Fácil 3, Intermedio 4, Avanzado 5.
int digitosParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return recuerdeNumeroDigitosFacil;
    case GameLevel.intermedio:
      return recuerdeNumeroDigitosIntermedio;
    case GameLevel.avanzado:
      return recuerdeNumeroDigitosAvanzado;
  }
}

/// Cuánto se muestra el número antes de ocultarse, por nivel.
/// Sobreescribible en tests.
final recuerdeNumeroTiempoVisualizacionProvider =
    Provider.family<Duration, GameLevel>((ref, nivel) {
      switch (nivel) {
        case GameLevel.facil:
          return recuerdeNumeroVisualizacionFacil;
        case GameLevel.intermedio:
          return recuerdeNumeroVisualizacionIntermedio;
        case GameLevel.avanzado:
          return recuerdeNumeroVisualizacionAvanzado;
      }
    });

/// Cuánto se muestra la retroalimentación (acierto o el número correcto
/// tras un error) antes de empezar la siguiente ronda. Sobreescribible en
/// tests para no esperar tiempo real.
final recuerdeNumeroFeedbackDurationProvider = Provider<Duration>(
  (ref) => recuerdeNumeroDuracionRetroalimentacion,
);

/// Generador para el número de cada ronda. Sobreescribible en tests.
final recuerdeNumeroRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir tiempoSegundos. Sobreescribible en tests.
final recuerdeNumeroClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// true si [numero] es trivial: todos los dígitos iguales, o una
/// secuencia consecutiva ascendente o descendente (ej. 123, 4321).
bool esNumeroTrivial(String numero) {
  final digitos = numero.split('').map(int.parse).toList();
  if (digitos.toSet().length == 1) return true;

  var ascendente = true;
  var descendente = true;
  for (var i = 1; i < digitos.length; i++) {
    if (digitos[i] != digitos[i - 1] + 1) ascendente = false;
    if (digitos[i] != digitos[i - 1] - 1) descendente = false;
  }
  return ascendente || descendente;
}

String _generarNumero(int digitos, Random random) {
  while (true) {
    final buffer = StringBuffer()..write(1 + random.nextInt(9));
    for (var i = 1; i < digitos; i++) {
      buffer.write(random.nextInt(10));
    }
    final numero = buffer.toString();
    if (!esNumeroTrivial(numero)) return numero;
  }
}

enum RecuerdeNumeroFase {
  /// Se muestra el número completo.
  mostrando,

  /// La persona escribe el número con el teclado.
  esperandoRespuesta,

  /// La ronda terminó (acierto o error); mensaje breve antes de la
  /// siguiente ronda o del cierre de la partida.
  retroalimentacion,
}

class RecuerdeNumeroState {
  const RecuerdeNumeroState({
    required this.numero,
    required this.fase,
    required this.respuesta,
    required this.rondasJugadas,
    required this.rondasCorrectas,
    required this.rondasConError,
    this.ultimaRondaCorrecta,
    this.metrics,
  });

  /// El número correcto de esta ronda.
  final String numero;

  final RecuerdeNumeroFase fase;

  /// Dígitos que la persona ya escribió en esta ronda (longitud 0..N).
  final String respuesta;

  final int rondasJugadas;
  final int rondasCorrectas;
  final int rondasConError;

  /// null mientras no hay retroalimentación que mostrar.
  final bool? ultimaRondaCorrecta;

  /// No-null cuando la partida terminó (5 rondas correctas u 8 jugadas).
  final MemoriaMetrics? metrics;

  bool get isFinished => metrics != null;
  int get digitos => numero.length;

  RecuerdeNumeroState copyWith({String? respuesta}) {
    return RecuerdeNumeroState(
      numero: numero,
      fase: fase,
      respuesta: respuesta ?? this.respuesta,
      rondasJugadas: rondasJugadas,
      rondasCorrectas: rondasCorrectas,
      rondasConError: rondasConError,
      ultimaRondaCorrecta: ultimaRondaCorrecta,
      metrics: metrics,
    );
  }
}

class RecuerdeNumeroController
    extends AutoDisposeFamilyNotifier<RecuerdeNumeroState, GameLevel> {
  Timer? _timer;
  DateTime? _startTime;

  /// Instante en que empezó la pausa actual, o null si no está pausado.
  DateTime? _pausaInicio;

  /// Suma de todas las pausas anteriores, para restarla de tiempoSegundos.
  Duration _pausaAcumulada = Duration.zero;

  @override
  RecuerdeNumeroState build(GameLevel arg) {
    ref.onDispose(() => _timer?.cancel());
    _startTime = ref.read(recuerdeNumeroClockProvider)();
    final inicial = _nuevaRonda(
      arg,
      rondasJugadas: 0,
      rondasCorrectas: 0,
      rondasConError: 0,
    );
    _timer = Timer(
      ref.read(recuerdeNumeroTiempoVisualizacionProvider(arg)),
      _ocultarNumero,
    );
    return inicial;
  }

  RecuerdeNumeroState _nuevaRonda(
    GameLevel nivel, {
    required int rondasJugadas,
    required int rondasCorrectas,
    required int rondasConError,
  }) {
    final digitos = digitosParaNivel(nivel);
    final random = ref.read(recuerdeNumeroRandomProvider);
    return RecuerdeNumeroState(
      numero: _generarNumero(digitos, random),
      fase: RecuerdeNumeroFase.mostrando,
      respuesta: '',
      rondasJugadas: rondasJugadas,
      rondasCorrectas: rondasCorrectas,
      rondasConError: rondasConError,
    );
  }

  void _ocultarNumero() {
    final current = state;
    state = RecuerdeNumeroState(
      numero: current.numero,
      fase: RecuerdeNumeroFase.esperandoRespuesta,
      respuesta: current.respuesta,
      rondasJugadas: current.rondasJugadas,
      rondasCorrectas: current.rondasCorrectas,
      rondasConError: current.rondasConError,
    );
  }

  /// Pausa la medición de tiempo y, si se está mostrando el número, el
  /// Timer que lo esconde (para que no siga avanzando de fondo mientras
  /// se lee el tutorial "Ver cómo se juega"). En "esperandoRespuesta" no
  /// hay ningún Timer corriendo, así que solo queda pendiente retomar.
  void pausar() {
    if (state.isFinished || _pausaInicio != null) return;
    _pausaInicio = ref.read(recuerdeNumeroClockProvider)();
    _timer?.cancel();
  }

  /// Reanuda la medición de tiempo. Si el número se estaba mostrando,
  /// reinicia el tiempo de visualización completo (para que la persona
  /// lo vea entero, no solo lo que faltaba al pausar). Idempotente si
  /// no estaba pausado.
  void reanudar() {
    if (_pausaInicio == null) return;
    final ahora = ref.read(recuerdeNumeroClockProvider)();
    _pausaAcumulada += ahora.difference(_pausaInicio!);
    _pausaInicio = null;

    final current = state;
    if (current.isFinished) return;
    if (current.fase == RecuerdeNumeroFase.mostrando) {
      _timer = Timer(
        ref.read(recuerdeNumeroTiempoVisualizacionProvider(arg)),
        _ocultarNumero,
      );
    }
    // esperandoRespuesta: no había Timer corriendo; solo se retoma.
  }

  /// La persona toca el dígito [digito] (0-9) del teclado.
  void tocarDigito(int digito) {
    final current = state;
    if (current.fase != RecuerdeNumeroFase.esperandoRespuesta) return;
    if (current.respuesta.length >= current.digitos) return;
    state = current.copyWith(respuesta: current.respuesta + digito.toString());
  }

  /// Quita el último dígito escrito.
  void borrar() {
    final current = state;
    if (current.fase != RecuerdeNumeroFase.esperandoRespuesta) return;
    if (current.respuesta.isEmpty) return;
    state = current.copyWith(
      respuesta: current.respuesta.substring(0, current.respuesta.length - 1),
    );
  }

  /// Botón "Listo": solo actúa cuando ya se escribieron todos los
  /// dígitos.
  void confirmar() {
    final current = state;
    if (current.fase != RecuerdeNumeroFase.esperandoRespuesta) return;
    if (current.respuesta.length != current.digitos) return;
    _terminarRonda(exito: current.respuesta == current.numero);
  }

  void _terminarRonda({required bool exito}) {
    final current = state;
    final rondasJugadas = current.rondasJugadas + 1;
    final rondasCorrectas = current.rondasCorrectas + (exito ? 1 : 0);
    final rondasConError = current.rondasConError + (exito ? 0 : 1);

    final terminada =
        rondasCorrectas >= recuerdeNumeroRondasCorrectasParaGanar ||
        rondasJugadas >= recuerdeNumeroMaxRondasJugadas;

    MemoriaMetrics? metrics;
    if (terminada) {
      final ahora = ref.read(recuerdeNumeroClockProvider)();
      final tiempoSegundos =
          ahora.difference(_startTime!) - _pausaAcumulada;
      metrics = MemoriaMetrics(
        errores: rondasConError,
        intentos: rondasJugadas,
        tiempoSegundos: tiempoSegundos.inSeconds,
        tasaAciertoPct: rondasCorrectas / rondasJugadas * 100,
      );
    }

    state = RecuerdeNumeroState(
      numero: current.numero,
      fase: RecuerdeNumeroFase.retroalimentacion,
      respuesta: current.respuesta,
      rondasJugadas: rondasJugadas,
      rondasCorrectas: rondasCorrectas,
      rondasConError: rondasConError,
      ultimaRondaCorrecta: exito,
      metrics: metrics,
    );

    if (terminada) return;

    _timer?.cancel();
    _timer = Timer(ref.read(recuerdeNumeroFeedbackDurationProvider), () {
      state = _nuevaRonda(
        arg,
        rondasJugadas: rondasJugadas,
        rondasCorrectas: rondasCorrectas,
        rondasConError: rondasConError,
      );
      _timer = Timer(
        ref.read(recuerdeNumeroTiempoVisualizacionProvider(arg)),
        _ocultarNumero,
      );
    });
  }
}

final recuerdeNumeroControllerProvider = NotifierProvider.autoDispose
    .family<RecuerdeNumeroController, RecuerdeNumeroState, GameLevel>(
      RecuerdeNumeroController.new,
    );
