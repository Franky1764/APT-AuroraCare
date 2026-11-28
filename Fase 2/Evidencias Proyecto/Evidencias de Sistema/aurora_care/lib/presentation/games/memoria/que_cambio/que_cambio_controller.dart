// lib/presentation/games/memoria/que_cambio/que_cambio_controller.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import '../memoria_faces.dart';

// Constantes de calibración (Memoria — planilla de Daniela). Agrupadas
// acá, con nombre, para poder consultarlas de un vistazo.

/// Columnas por nivel (SCORING §2.2): siempre 3 filas, solo cambian las
/// columnas. Fácil 3, Intermedio 4, Avanzado 5.
const int queCambioColumnasFacil = 3;
const int queCambioColumnasIntermedio = 4;
const int queCambioColumnasAvanzado = 5;

/// Filas de la grilla: igual en los 3 niveles.
const int queCambioFilas = 3;

/// Cantidad de diferencias por nivel (SCORING §2.2): 3/4/5. Fija el
/// mínimo de `intentos` (si no se toca ninguna celda de más). El máximo
/// de `intentos` y de `errores` es columnas × [queCambioFilas] (9/12/15):
/// cada celda cuenta como máximo una vez (`esMarcada` bloquea re-toques).
const int queCambioDiferenciasFacil = 3;
const int queCambioDiferenciasIntermedio = 4;
const int queCambioDiferenciasAvanzado = 5;

/// Columnas por nivel (SCORING §2.2): siempre 3 filas, solo cambian las
/// columnas. Fácil 3, Intermedio 4, Avanzado 5.
int columnasParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return queCambioColumnasFacil;
    case GameLevel.intermedio:
      return queCambioColumnasIntermedio;
    case GameLevel.avanzado:
      return queCambioColumnasAvanzado;
  }
}

/// Cantidad de diferencias por nivel (SCORING §2.2): 3/4/5.
int diferenciasParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return queCambioDiferenciasFacil;
    case GameLevel.intermedio:
      return queCambioDiferenciasIntermedio;
    case GameLevel.avanzado:
      return queCambioDiferenciasAvanzado;
  }
}

/// Generador para armar la grilla y elegir las diferencias. Sobreescribible
/// en tests.
final queCambioRandomProvider = Provider<Random>((ref) => Random());

/// Reloj para medir tiempoSegundos (desde que se genera la partida hasta
/// que termina). Sobreescribible en tests.
final queCambioClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum QueCambioResultado { ninguno, acierto, error }

class QueCambioState {
  const QueCambioState({
    required this.columnas,
    required this.original,
    required this.modificada,
    required this.diferenciaIndices,
    required this.encontradas,
    required this.marcadasIncorrectas,
    required this.intentos,
    required this.ultimoResultado,
    this.metrics,
  });

  final int columnas;

  /// Íconos (índices en memoriceFaces) de la grilla de arriba, fila por
  /// fila (orden de GridView.count), longitud columnas * queCambioFilas.
  final List<int> original;

  /// Íconos de la grilla de abajo: igual a `original` salvo en las
  /// posiciones de `diferenciaIndices`.
  final List<int> modificada;

  /// Posiciones (0-based, fila-mayor) donde original y modificada
  /// difieren.
  final Set<int> diferenciaIndices;

  /// Diferencias ya encontradas (subconjunto de diferenciaIndices).
  final Set<int> encontradas;

  /// Posiciones que NO son diferencia pero la persona tocó por error.
  final Set<int> marcadasIncorrectas;

  final int intentos;

  /// Resultado del último toque, para el mensaje/anuncio de accesibilidad.
  final QueCambioResultado ultimoResultado;

  /// No-null cuando la partida terminó (todas encontradas, o declarada
  /// terminada por la persona).
  final MemoriaMetrics? metrics;

  bool get isFinished => metrics != null;
  int get totalDiferencias => diferenciaIndices.length;

  bool esMarcada(int i) =>
      encontradas.contains(i) || marcadasIncorrectas.contains(i);

  QueCambioState copyWith({
    Set<int>? encontradas,
    Set<int>? marcadasIncorrectas,
    int? intentos,
    QueCambioResultado? ultimoResultado,
    MemoriaMetrics? metrics,
  }) {
    return QueCambioState(
      columnas: columnas,
      original: original,
      modificada: modificada,
      diferenciaIndices: diferenciaIndices,
      encontradas: encontradas ?? this.encontradas,
      marcadasIncorrectas: marcadasIncorrectas ?? this.marcadasIncorrectas,
      intentos: intentos ?? this.intentos,
      ultimoResultado: ultimoResultado ?? this.ultimoResultado,
      metrics: metrics ?? this.metrics,
    );
  }
}

class QueCambioController
    extends AutoDisposeFamilyNotifier<QueCambioState, GameLevel> {
  DateTime? _startTime;

  /// Instante en que empezó la pausa actual, o null si no está pausado.
  DateTime? _pausaInicio;

  /// Suma de todas las pausas anteriores, para restarla de tiempoSegundos.
  Duration _pausaAcumulada = Duration.zero;

  @override
  QueCambioState build(GameLevel arg) {
    _startTime = ref.read(queCambioClockProvider)();
    return _generarPartida(arg);
  }

  /// Pausa la medición de tiempo mientras se muestra el tutorial "Ver
  /// cómo se juega". No hay ningún Timer de fondo que detener en este
  /// juego (a diferencia de Secuencias/Número): el único efecto es que
  /// el tiempo pausado no cuenta en tiempoSegundos.
  void pausar() {
    if (state.isFinished || _pausaInicio != null) return;
    _pausaInicio = ref.read(queCambioClockProvider)();
  }

  /// Reanuda la medición de tiempo. Idempotente si no estaba pausado.
  void reanudar() {
    if (_pausaInicio == null) return;
    final ahora = ref.read(queCambioClockProvider)();
    _pausaAcumulada += ahora.difference(_pausaInicio!);
    _pausaInicio = null;
  }

  QueCambioState _generarPartida(GameLevel nivel) {
    final columnas = columnasParaNivel(nivel);
    final totalCeldas = columnas * queCambioFilas;
    final totalDiferencias = diferenciasParaNivel(nivel);
    final random = ref.read(queCambioRandomProvider);

    final original = List<int>.generate(
      totalCeldas,
      (_) => random.nextInt(memoriceFaces.length),
    );

    final posiciones = List<int>.generate(totalCeldas, (i) => i)
      ..shuffle(random);
    final diferenciaIndices = posiciones.take(totalDiferencias).toSet();

    final modificada = List<int>.of(original);
    for (final i in diferenciaIndices) {
      int nuevo;
      do {
        nuevo = random.nextInt(memoriceFaces.length);
      } while (nuevo == original[i]);
      modificada[i] = nuevo;
    }

    return QueCambioState(
      columnas: columnas,
      original: original,
      modificada: modificada,
      diferenciaIndices: diferenciaIndices,
      encontradas: const {},
      marcadasIncorrectas: const {},
      intentos: 0,
      ultimoResultado: QueCambioResultado.ninguno,
    );
  }

  /// La persona toca la celda [indice] (0-based, fila-mayor) en cualquiera
  /// de las dos grillas. Un re-toque sobre una celda ya marcada (correcta
  /// o incorrecta) no cuenta.
  void tapCelda(int indice) {
    final current = state;
    if (current.isFinished) return;
    if (current.esMarcada(indice)) return;

    final intentos = current.intentos + 1;
    final esDiferencia = current.diferenciaIndices.contains(indice);

    if (esDiferencia) {
      final encontradas = {...current.encontradas, indice};
      state = current.copyWith(
        encontradas: encontradas,
        intentos: intentos,
        ultimoResultado: QueCambioResultado.acierto,
      );
      if (encontradas.length == current.totalDiferencias) {
        _terminar();
      }
      return;
    }

    final marcadas = {...current.marcadasIncorrectas, indice};
    state = current.copyWith(
      marcadasIncorrectas: marcadas,
      intentos: intentos,
      ultimoResultado: QueCambioResultado.error,
    );
  }

  /// Botón "Ya no encuentro más": termina la partida; lo que falte por
  /// encontrar cuenta como omisión.
  void declararTerminado() {
    if (state.isFinished) return;
    _terminar();
  }

  void _terminar() {
    final s = state;
    final omisiones = s.totalDiferencias - s.encontradas.length;
    final errores = omisiones + s.marcadasIncorrectas.length;
    final ahora = ref.read(queCambioClockProvider)();
    final tiempoSegundos = ahora.difference(_startTime!) - _pausaAcumulada;
    final metrics = MemoriaMetrics(
      errores: errores,
      intentos: s.intentos,
      tiempoSegundos: tiempoSegundos.inSeconds,
      tasaAciertoPct: s.encontradas.length / s.totalDiferencias * 100,
    );
    state = s.copyWith(metrics: metrics);
  }
}

final queCambioControllerProvider = NotifierProvider.autoDispose
    .family<QueCambioController, QueCambioState, GameLevel>(
      QueCambioController.new,
    );
