import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import 'arrastrar_elementos_images.dart';

final phoneDragProvider = StateNotifierProvider.autoDispose
    .family<PhoneDragController, PhoneDragState, GameLevel>(
      (ref, level) => PhoneDragController(level),
    );

enum PhoneDragFeedback { ready, hold, moving, retry, achieved }

class PhoneDragState {
  const PhoneDragState({
    this.drags = 0,
    this.attempts = 0,
    this.misses = 0,
    this.assisted = 0,
    this.troubleOnStep = 0,
    this.dragDx = 0,
    this.dragDy = 0,
    this.dragging = false,
    this.paused = false,
    this.finished = false,
    this.feedback = PhoneDragFeedback.ready,
  });
  static const targetCount = 4;
  final int drags, attempts, misses, assisted;

  /// Dificultades en la imagen actual: soltar fuera del destino o intentar
  /// moverla sin esperar el agarre. Se reinicia al colocarla.
  final int troubleOnStep;
  static const troubleToOfferAssist = 3;
  bool get offerAssist => troubleOnStep >= troubleToOfferAssist;
  final double dragDx, dragDy;
  final bool dragging, paused, finished;
  final PhoneDragFeedback feedback;
  int get completedActions => drags + assisted;
  int get index => completedActions.clamp(0, targetCount - 1);
  bool get completed => completedActions == targetCount;
  bool get blocked => paused || finished || completed;
  PhoneDragState copyWith({
    int? drags,
    int? attempts,
    int? misses,
    int? assisted,
    int? troubleOnStep,
    double? dragDx,
    double? dragDy,
    bool? dragging,
    bool? paused,
    bool? finished,
    PhoneDragFeedback? feedback,
  }) => PhoneDragState(
    drags: drags ?? this.drags,
    attempts: attempts ?? this.attempts,
    misses: misses ?? this.misses,
    assisted: assisted ?? this.assisted,
    troubleOnStep: troubleOnStep ?? this.troubleOnStep,
    dragDx: dragDx ?? this.dragDx,
    dragDy: dragDy ?? this.dragDy,
    dragging: dragging ?? this.dragging,
    paused: paused ?? this.paused,
    finished: finished ?? this.finished,
    feedback: feedback ?? this.feedback,
  );
}

/// Espera una pulsación mantenida para empezar; soltar fuera permite retomar
/// con la misma imagen. Cada acierto deja listo el siguiente intento.
class PhoneDragController extends StateNotifier<PhoneDragState> {
  PhoneDragController(this.level, {math.Random? random})
    : super(const PhoneDragState()) {
    final rng = random ?? math.Random();
    // Cada partida sortea cuatro imágenes distintas, y para cada una una
    // disposición (sin repetir la misma dos veces seguidas).
    final pool = List.generate(dragImagePool.length, (i) => i)..shuffle(rng);
    if (pool.first == _lastFirst) pool.add(pool.removeAt(0));
    sequence = pool.take(PhoneDragState.targetCount).toList();
    _lastFirst = sequence.first;
    final chosen = <int>[];
    for (var step = 0; step < PhoneDragState.targetCount; step++) {
      final options = [
        for (var i = 0; i < dragLayouts.length; i++)
          if (chosen.isEmpty || i != chosen.last) i,
      ];
      chosen.add(options[rng.nextInt(options.length)]);
    }
    layouts = chosen;
  }
  final GameLevel level;

  /// Posiciones en [dragImagePool] de las cuatro imágenes de la partida.
  late final List<int> sequence;

  /// Posición en [dragLayouts] de la disposición de cada imagen.
  late final List<int> layouts;

  /// Primera imagen de la partida anterior (solo en memoria): la siguiente
  /// partida empieza con otra.
  static int? _lastFirst;

  @visibleForTesting
  static void resetHistory() => _lastFirst = null;

  DragImage imageAt(int step) => dragImagePool[sequence[step]];
  DragLayout layoutAt(int step) => dragLayouts[layouts[step]];
  static const double itemSize = 88;
  static const double minimumOverlapRatio = .65;
  double get targetSize => switch (level) {
    GameLevel.facil => 136,
    GameLevel.intermedio => 120,
    GameLevel.avanzado => 104,
  };
  void touch() {
    if (state.blocked || state.dragging) return;
    state = state.copyWith(
      feedback: PhoneDragFeedback.hold,
      troubleOnStep: state.troubleOnStep + 1,
    );
  }

  void begin({required bool onItem}) {
    if (state.blocked || state.dragging) return;
    if (!onItem) {
      touch();
      return;
    }
    state = state.copyWith(
      dragging: true,
      dragDx: 0,
      dragDy: 0,
      feedback: PhoneDragFeedback.moving,
    );
  }

  void move(double dx, double dy) {
    if (!state.dragging || state.blocked) return;
    state = state.copyWith(dragDx: dx, dragDy: dy);
  }

  void drop({required bool insideTarget}) {
    if (!state.dragging || state.blocked) return;
    state = state.copyWith(
      attempts: state.attempts + 1,
      drags: state.drags + (insideTarget ? 1 : 0),
      misses: state.misses + (insideTarget ? 0 : 1),
      troubleOnStep: insideTarget ? 0 : state.troubleOnStep + 1,
      dragDx: 0,
      dragDy: 0,
      dragging: false,
      feedback: insideTarget
          ? PhoneDragFeedback.achieved
          : PhoneDragFeedback.retry,
    );
  }

  void cancel() =>
      state = state.copyWith(dragging: false, dragDx: 0, dragDy: 0);
  void pause() {
    cancel();
    state = state.copyWith(paused: true);
  }

  void resume() => state = state.copyWith(paused: false);
  void placeWithButton() {
    if (state.blocked || state.dragging) return;
    state = state.copyWith(
      assisted: state.assisted + 1,
      troubleOnStep: 0,
      feedback: PhoneDragFeedback.achieved,
    );
  }

  PhoneDragMetrics? finish() {
    if (!state.completed || state.finished) return null;
    state = state.copyWith(finished: true);
    return PhoneDragMetrics(
      completedActions: state.completedActions,
      totalActions: PhoneDragState.targetCount,
      successfulDrags: state.drags,
      dragAttempts: state.attempts,
      dropsOutsideTarget: state.misses,
      assistedActions: state.assisted,
      itemSizeDp: itemSize,
      targetSizeDp: targetSize,
      minimumOverlapRatio: minimumOverlapRatio,
    );
  }
}
