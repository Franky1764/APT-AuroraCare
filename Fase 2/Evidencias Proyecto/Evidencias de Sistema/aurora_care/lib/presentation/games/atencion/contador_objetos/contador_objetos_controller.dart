// lib/presentation/games/atencion/contador_objetos/contador_objetos_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

/// Rondas por partida.
const int contadorRondasPorPartida = 6;

/// Las figuras aparecen en una cuadrícula de 4 x 4 casillas.
const int contadorColumnas = 4;
const int contadorCasillas = contadorColumnas * contadorColumnas;

/// Cuántos tipos de figura hay (índices de `contadorFiguras` en la pantalla).
const int contadorCantidadFiguras = 5;

/// Cuántas opciones de respuesta se muestran.
const int contadorOpciones = 3;

/// Pausa antes de mostrar las figuras ("Prepárese para contar…").
const Duration contadorPausaInicial = Duration(milliseconds: 1500);

/// Cuánto se ve el mensaje de acierto o de ánimo antes de la ronda siguiente.
const Duration contadorPausaRetro = Duration(milliseconds: 1800);

/// Parámetros de un nivel (plantilla SCORING §2.5). Propuesta del dueño del
/// dominio, a calibrar en la sesión con usuarios.
class ContadorNivel {
  const ContadorNivel({
    required this.minimo,
    required this.maximo,
    required this.tiempoVisible,
  });

  /// Rango de figuras por ronda (ambos incluidos).
  final int minimo;
  final int maximo;

  /// Cuánto se ven las figuras antes de taparse.
  final Duration tiempoVisible;
}

ContadorNivel contadorNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const ContadorNivel(
        minimo: 3,
        maximo: 5,
        tiempoVisible: Duration(milliseconds: 3000),
      );
    case GameLevel.intermedio:
      return const ContadorNivel(
        minimo: 5,
        maximo: 8,
        tiempoVisible: Duration(milliseconds: 2500),
      );
    case GameLevel.avanzado:
      return const ContadorNivel(
        minimo: 7,
        maximo: 10,
        tiempoVisible: Duration(milliseconds: 2000),
      );
  }
}

enum ContadorFase {
  /// Antes de mostrar las figuras de la ronda.
  preparando,

  /// Las figuras están a la vista: hay que contarlas.
  mostrando,

  /// Las figuras se taparon: hay que elegir cuántas había.
  respondiendo,

  /// Se muestra si acertó, con la cantidad correcta.
  retro,

  /// Terminaron todas las rondas. `metrics` ya no es null.
  terminado,
}

class ContadorObjetosState {
  const ContadorObjetosState({
    required this.ronda,
    required this.cantidad,
    required this.figura,
    required this.casillas,
    required this.opciones,
    required this.fase,
    required this.rondasMal,
    required this.tiemposRespuestaMs,
    required this.alcance,
    this.respuesta,
    this.metrics,
  });

  /// Ronda actual, empieza en 1.
  final int ronda;

  /// Cuántas figuras hay en esta ronda (la respuesta correcta).
  final int cantidad;

  /// Qué figura se usa en esta ronda (0..contadorCantidadFiguras-1).
  final int figura;

  /// Casillas de la cuadrícula (0..15) donde aparece cada figura.
  final List<int> casillas;

  /// Las 3 opciones de respuesta, de menor a mayor.
  final List<int> opciones;
  final ContadorFase fase;
  final int rondasMal;

  /// Tiempo desde que se tapan las figuras hasta que se elige una opción.
  final List<int> tiemposRespuestaMs;

  /// Mayor cantidad contada correctamente (SCORING §2.3, "alcance").
  final int alcance;

  /// Opción que eligió la persona en esta ronda.
  final int? respuesta;
  final AtencionMetrics? metrics;

  bool get acerto => respuesta == cantidad;
  bool get isFinished => metrics != null;

  ContadorObjetosState copyWith({
    int? ronda,
    int? cantidad,
    int? figura,
    List<int>? casillas,
    List<int>? opciones,
    ContadorFase? fase,
    int? rondasMal,
    List<int>? tiemposRespuestaMs,
    int? alcance,
    int? Function()? respuesta,
    AtencionMetrics? metrics,
  }) {
    return ContadorObjetosState(
      ronda: ronda ?? this.ronda,
      cantidad: cantidad ?? this.cantidad,
      figura: figura ?? this.figura,
      casillas: casillas ?? this.casillas,
      opciones: opciones ?? this.opciones,
      fase: fase ?? this.fase,
      rondasMal: rondasMal ?? this.rondasMal,
      tiemposRespuestaMs: tiemposRespuestaMs ?? this.tiemposRespuestaMs,
      alcance: alcance ?? this.alcance,
      respuesta: respuesta != null ? respuesta() : this.respuesta,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Generador para armar las rondas. Sobreescribible en tests.
final contadorRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir el tiempo de respuesta. Sobreescribible en tests.
final contadorClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Si es true, los temporizadores avanzan el juego solos. En tests se pone
/// en false y se llama a mostrar() / ocultar() / continuar() a mano.
final contadorAutoPlayProvider = Provider<bool>((ref) => true);

class ContadorObjetosController
    extends AutoDisposeFamilyNotifier<ContadorObjetosState, GameLevel> {
  Timer? _timer;
  DateTime? _inicioRespuesta;

  @override
  ContadorObjetosState build(GameLevel arg) {
    ref.onDispose(() => _timer?.cancel());
    _programar(contadorPausaInicial, mostrar);
    return _nuevaRonda(
      ronda: 1,
      rondasMal: 0,
      tiempos: const [],
      alcance: 0,
    );
  }

  ContadorObjetosState _nuevaRonda({
    required int ronda,
    required int rondasMal,
    required List<int> tiempos,
    required int alcance,
  }) {
    final random = ref.read(contadorRandomProvider);
    final nivel = contadorNivel(arg);
    final cantidad =
        nivel.minimo + random.nextInt(nivel.maximo - nivel.minimo + 1);
    final casillas = List<int>.generate(contadorCasillas, (i) => i)
      ..shuffle(random);
    return ContadorObjetosState(
      ronda: ronda,
      cantidad: cantidad,
      figura: random.nextInt(contadorCantidadFiguras),
      casillas: casillas.take(cantidad).toList(),
      opciones: _opciones(cantidad, random),
      fase: ContadorFase.preparando,
      rondasMal: rondasMal,
      tiemposRespuestaMs: tiempos,
      alcance: alcance,
    );
  }

  /// La cantidad correcta y dos cercanas (±1 o ±2), todas mayores que 0,
  /// ordenadas de menor a mayor para que sea fácil encontrar el número.
  List<int> _opciones(int correcta, Random random) {
    final cercanas = [
      for (final d in const [-2, -1, 1, 2])
        if (correcta + d > 0) correcta + d,
    ]..shuffle(random);
    return [correcta, ...cercanas.take(contadorOpciones - 1)]..sort();
  }

  void _programar(Duration espera, void Function() accion) {
    _timer?.cancel();
    if (!ref.read(contadorAutoPlayProvider)) return;
    _timer = Timer(espera, accion);
  }

  /// Muestra las figuras de la ronda.
  void mostrar() {
    if (state.fase != ContadorFase.preparando) return;
    state = state.copyWith(fase: ContadorFase.mostrando);
    _programar(contadorNivel(arg).tiempoVisible, ocultar);
  }

  /// Tapa las figuras y muestra las opciones.
  void ocultar() {
    if (state.fase != ContadorFase.mostrando) return;
    _inicioRespuesta = ref.read(contadorClockProvider)();
    state = state.copyWith(fase: ContadorFase.respondiendo);
  }

  /// La persona elige cuántas figuras había.
  void responder(int valor) {
    final s = state;
    if (s.fase != ContadorFase.respondiendo) return;

    final ahora = ref.read(contadorClockProvider)();
    final tiempo =
        ahora.difference(_inicioRespuesta ?? ahora).inMilliseconds;
    final acerto = valor == s.cantidad;

    state = s.copyWith(
      fase: ContadorFase.retro,
      respuesta: () => valor,
      tiemposRespuestaMs: [...s.tiemposRespuestaMs, tiempo],
      rondasMal: acerto ? s.rondasMal : s.rondasMal + 1,
      alcance: acerto ? max(s.alcance, s.cantidad) : s.alcance,
    );
    _programar(contadorPausaRetro, continuar);
  }

  /// Pasa a la ronda siguiente o termina la partida.
  void continuar() {
    final s = state;
    if (s.fase != ContadorFase.retro) return;

    if (s.ronda >= contadorRondasPorPartida) {
      state = s.copyWith(fase: ContadorFase.terminado, metrics: _metricas(s));
      return;
    }
    state = _nuevaRonda(
      ronda: s.ronda + 1,
      rondasMal: s.rondasMal,
      tiempos: s.tiemposRespuestaMs,
      alcance: s.alcance,
    );
    _programar(contadorPausaInicial, mostrar);
  }

  /// Métricas de SCORING §2.3 para Contador de objetos.
  AtencionMetrics _metricas(ContadorObjetosState s) {
    final promedio = s.tiemposRespuestaMs.isEmpty
        ? 0
        : (s.tiemposRespuestaMs.reduce((a, b) => a + b) /
                  s.tiemposRespuestaMs.length)
              .round();
    return AtencionMetrics(
      tiempoRespuestaMs: promedio,
      tasaErrorPct: s.rondasMal / contadorRondasPorPartida * 100,
      alcance: s.alcance,
    );
  }
}

final contadorObjetosControllerProvider = NotifierProvider.autoDispose
    .family<ContadorObjetosController, ContadorObjetosState, GameLevel>(
      ContadorObjetosController.new,
    );
