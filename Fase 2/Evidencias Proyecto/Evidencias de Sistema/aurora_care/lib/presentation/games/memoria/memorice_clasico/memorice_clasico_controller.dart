// lib/presentation/games/memoria/memorice_clasico/memorice_clasico_controller.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

/// Una carta del tablero: su posición, qué cara tiene y su estado visible.
class MemoriceCardModel {
  const MemoriceCardModel({
    required this.id,
    required this.faceIndex,
    this.isFaceUp = false,
    this.isMatched = false,
  });

  final int id;

  /// Índice en `memoriceFaces`. Dos cartas con el mismo valor son pareja.
  final int faceIndex;
  final bool isFaceUp;
  final bool isMatched;

  MemoriceCardModel copyWith({bool? isFaceUp, bool? isMatched}) {
    return MemoriceCardModel(
      id: id,
      faceIndex: faceIndex,
      isFaceUp: isFaceUp ?? this.isFaceUp,
      isMatched: isMatched ?? this.isMatched,
    );
  }
}

class MemoriceClasicoState {
  const MemoriceClasicoState({
    required this.cards,
    required this.revealedIndices,
    required this.locked,
    required this.errores,
    required this.intentos,
    required this.paresEncontrados,
    required this.totalPares,
    required this.isPreviewPhase,
    this.metrics,
  });

  final List<MemoriceCardModel> cards;

  /// Índices de las cartas boca arriba a la espera de compararse (0, 1 o 2).
  final List<int> revealedIndices;

  /// true mientras se muestran 2 cartas que no coinciden, antes de
  /// voltearlas de nuevo: bloquea tocar una tercera carta.
  final bool locked;

  final int errores;
  final int intentos;
  final int paresEncontrados;
  final int totalPares;

  /// true mientras se muestran TODAS las cartas boca arriba al empezar (o
  /// reiniciar) la partida, para memorizar dónde está cada imagen. Los
  /// toques se ignoran y el reloj de la partida todavía no arrancó
  /// (_firstFlipTime se fija recién dentro de flipCard, que no corre
  /// durante esta fase).
  final bool isPreviewPhase;

  /// No-null cuando se encontró el último par: la partida terminó.
  final MemoriaMetrics? metrics;

  bool get isFinished => metrics != null;

  MemoriceClasicoState copyWith({
    List<MemoriceCardModel>? cards,
    List<int>? revealedIndices,
    bool? locked,
    int? errores,
    int? intentos,
    int? paresEncontrados,
    bool? isPreviewPhase,
    MemoriaMetrics? metrics,
  }) {
    return MemoriceClasicoState(
      cards: cards ?? this.cards,
      revealedIndices: revealedIndices ?? this.revealedIndices,
      locked: locked ?? this.locked,
      errores: errores ?? this.errores,
      intentos: intentos ?? this.intentos,
      paresEncontrados: paresEncontrados ?? this.paresEncontrados,
      totalPares: totalPares,
      isPreviewPhase: isPreviewPhase ?? this.isPreviewPhase,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Pares por nivel (SCORING.md §2.2): 6/8/10. Es el único parámetro que
/// cambia entre niveles, además del maxDuration de la definición.
int paresParaNivel(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return 6;
    case GameLevel.intermedio:
      return 8;
    case GameLevel.avanzado:
      return 10;
  }
}

/// Vista previa al empezar (o reiniciar) la partida: todas las cartas se
/// muestran boca arriba este tiempo, para memorizar dónde está cada
/// imagen, antes de que empiece el juego de buscar parejas. Más pares,
/// más tiempo para mirar el tablero.
const memoricePreviewBaseSeconds = 3;
const memoricePreviewSecondsPerPair = 1;

Duration memoricePreviewDuration(GameLevel nivel) {
  final pares = paresParaNivel(nivel);
  return Duration(
    seconds: memoricePreviewBaseSeconds + memoricePreviewSecondsPerPair * pares,
  );
}

/// Generador para mezclar el mazo. Sobreescribible en tests.
final memoriceShuffleRandomProvider = Provider<Random>((ref) => Random());

/// Cuánto quedan visibles 2 cartas que no coinciden antes de voltearlas de
/// nuevo. Sobreescribible en tests para no esperar tiempo real.
final memoriceMismatchDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1500),
);

/// Reloj para medir tiempoSegundos (desde la primera carta volteada hasta
/// encontrar el último par). Sobreescribible en tests.
final memoriceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Crea el Timer que termina la vista previa. Sobreescribible en tests:
/// una versión de prueba puede guardar el callback y dispararlo a mano,
/// sin esperar la duración real (hasta 13 s en Avanzado).
final memoricePreviewTimerFactoryProvider =
    Provider<Timer Function(Duration, void Function())>((ref) => Timer.new);

class MemoriceClasicoController
    extends AutoDisposeFamilyNotifier<MemoriceClasicoState, GameLevel> {
  /// Cuándo arrancó el reloj de la partida: al taparse las cartas (fin
  /// de la vista previa), no al primer volteo — así la persona no pierde
  /// tiempo solo por mirar el tablero.
  DateTime? _clockStartTime;
  Timer? _resolveTimer;
  Timer? _previewTimer;

  /// Instante en que empezó la pausa actual (p. ej. "Ver cómo se
  /// juega"), o null si no está pausado.
  DateTime? _pausaInicio;

  /// Suma de todas las pausas anteriores, para restarla de tiempoSegundos.
  Duration _pausaAcumulada = Duration.zero;

  @override
  MemoriceClasicoState build(GameLevel arg) {
    ref.onDispose(() {
      _resolveTimer?.cancel();
      _previewTimer?.cancel();
    });
    return _newGame(arg);
  }

  MemoriceClasicoState _newGame(GameLevel nivel) {
    final totalPares = paresParaNivel(nivel);
    final faceIndices = <int>[
      for (var i = 0; i < totalPares; i++) ...[i, i],
    ];
    faceIndices.shuffle(ref.read(memoriceShuffleRandomProvider));

    _clockStartTime = null;
    _pausaInicio = null;
    _pausaAcumulada = Duration.zero;
    _previewTimer?.cancel();
    _previewTimer = ref.read(memoricePreviewTimerFactoryProvider)(
      memoricePreviewDuration(nivel),
      _endPreview,
    );

    return MemoriceClasicoState(
      cards: [
        for (var i = 0; i < faceIndices.length; i++)
          MemoriceCardModel(id: i, faceIndex: faceIndices[i], isFaceUp: true),
      ],
      revealedIndices: const [],
      locked: false,
      errores: 0,
      intentos: 0,
      paresEncontrados: 0,
      totalPares: totalPares,
      isPreviewPhase: true,
    );
  }

  /// Tapa todas las cartas y pasa al juego normal. El reloj de la
  /// partida arranca en este mismo instante, aunque todavía no se haya
  /// tocado ninguna carta.
  void _endPreview() {
    final current = state;
    _clockStartTime = ref.read(memoriceClockProvider)();
    state = current.copyWith(
      cards: [for (final c in current.cards) c.copyWith(isFaceUp: false)],
      isPreviewPhase: false,
    );
  }

  /// Pausa la medición de tiempo mientras se muestra "Ver cómo se
  /// juega" (solo puede abrirse después de la vista previa, nunca
  /// durante). No hay ningún Timer de fondo que detener en la fase de
  /// juego: el único efecto es que ese rato no cuenta en tiempoSegundos.
  void pausar() {
    if (state.isFinished || _pausaInicio != null) return;
    _pausaInicio = ref.read(memoriceClockProvider)();
  }

  /// Reanuda la medición de tiempo. Idempotente si no estaba pausado.
  void reanudar() {
    if (_pausaInicio == null) return;
    final ahora = ref.read(memoriceClockProvider)();
    _pausaAcumulada += ahora.difference(_pausaInicio!);
    _pausaInicio = null;
  }

  /// La persona toca la carta en [index]. Ignorado durante la vista
  /// previa, si la partida ya terminó, si está bloqueado mostrando un
  /// error, o si esa carta ya está volteada o emparejada.
  void flipCard(int index) {
    final current = state;
    if (current.isFinished || current.locked || current.isPreviewPhase) {
      return;
    }

    final card = current.cards[index];
    if (card.isFaceUp || card.isMatched) return;
    if (current.revealedIndices.length >= 2) return;

    final cards = List<MemoriceCardModel>.of(current.cards);
    cards[index] = card.copyWith(isFaceUp: true);
    final revealed = [...current.revealedIndices, index];
    final intentos = current.intentos + 1;

    if (revealed.length < 2) {
      state = current.copyWith(
        cards: cards,
        revealedIndices: revealed,
        intentos: intentos,
      );
      return;
    }

    final first = cards[revealed[0]];
    final second = cards[revealed[1]];

    if (first.faceIndex == second.faceIndex) {
      cards[revealed[0]] = first.copyWith(isMatched: true);
      cards[revealed[1]] = second.copyWith(isMatched: true);
      final paresEncontrados = current.paresEncontrados + 1;

      MemoriaMetrics? metrics;
      if (paresEncontrados == current.totalPares) {
        final ahora = ref.read(memoriceClockProvider)();
        final tiempoSegundos =
            (ahora.difference(_clockStartTime!) - _pausaAcumulada).inSeconds;
        metrics = MemoriaMetrics(
          errores: current.errores,
          intentos: intentos,
          tiempoSegundos: tiempoSegundos,
          tasaAciertoPct:
              paresEncontrados / (paresEncontrados + current.errores) * 100,
        );
      }

      state = current.copyWith(
        cards: cards,
        revealedIndices: const [],
        intentos: intentos,
        paresEncontrados: paresEncontrados,
        metrics: metrics,
      );
      return;
    }

    // No coinciden: quedan visibles y bloquean una tercera carta hasta que
    // el temporizador las vuelva a tapar.
    final errores = current.errores + 1;
    state = current.copyWith(
      cards: cards,
      revealedIndices: revealed,
      intentos: intentos,
      errores: errores,
      locked: true,
    );

    _resolveTimer?.cancel();
    _resolveTimer = Timer(ref.read(memoriceMismatchDelayProvider), () {
      final s = state;
      final resetCards = List<MemoriceCardModel>.of(s.cards);
      for (final i in s.revealedIndices) {
        resetCards[i] = resetCards[i].copyWith(isFaceUp: false);
      }
      state = s.copyWith(
        cards: resetCards,
        revealedIndices: const [],
        locked: false,
      );
    });
  }
}

final memoriceClasicoControllerProvider = NotifierProvider.autoDispose
    .family<MemoriceClasicoController, MemoriceClasicoState, GameLevel>(
      MemoriceClasicoController.new,
    );
