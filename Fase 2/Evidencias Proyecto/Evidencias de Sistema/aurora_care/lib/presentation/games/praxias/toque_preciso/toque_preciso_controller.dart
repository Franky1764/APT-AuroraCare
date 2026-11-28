import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

final phoneTouchProvider = StateNotifierProvider.autoDispose
    .family<PhoneTouchController, PhoneTouchState, GameLevel>(
      (ref, level) => PhoneTouchController(level),
    );

class PhoneTouchState {
  const PhoneTouchState({
    this.index = 0,
    this.started = false,
    this.hits = 0,
    this.misses = 0,
    this.missesOnStep = 0,
    this.acknowledged = false,
    this.paused = false,
    this.finished = false,
  });
  static const targetCount = 6;
  final int index;
  final bool started;
  final int hits;
  final int misses;
  final int missesOnStep;
  final bool acknowledged;
  final bool paused;
  final bool finished;
  bool get imageTarget => index.isOdd;
  bool get completed => hits == targetCount;
  bool get blocked => paused || acknowledged || finished;

  PhoneTouchState copyWith({
    int? index,
    bool? started,
    int? hits,
    int? misses,
    int? missesOnStep,
    bool? acknowledged,
    bool? paused,
    bool? finished,
  }) => PhoneTouchState(
    index: index ?? this.index,
    started: started ?? this.started,
    hits: hits ?? this.hits,
    misses: misses ?? this.misses,
    acknowledged: acknowledged ?? this.acknowledged,
    paused: paused ?? this.paused,
    finished: finished ?? this.finished,
    missesOnStep: missesOnStep ?? this.missesOnStep,
  );
}

/// Se prioriza completar una acción precisa. No hay reloj, penalización ni
/// avance automático que obligue a responder antes de estar preparado.
class PhoneTouchController extends StateNotifier<PhoneTouchState> {
  PhoneTouchController(this.level) : super(const PhoneTouchState());
  final GameLevel level;
  double get imageSize => switch (level) {
    GameLevel.facil => 144,
    GameLevel.intermedio => 128,
    GameLevel.avanzado => 112,
  };
  double get buttonWidth => imageSize + 32;
  double get buttonHeight => 72;

  void start() => state = state.copyWith(started: true);

  void touchTarget() {
    if (state.blocked) return;
    state = state.copyWith(hits: state.hits + 1, acknowledged: true);
  }

  void touchOutside() {
    if (state.blocked) return;
    state = state.copyWith(
      misses: state.misses + 1,
      missesOnStep: state.missesOnStep + 1,
    );
  }

  void next() {
    if (!state.acknowledged ||
        state.completed ||
        state.paused ||
        state.finished) {
      return;
    }
    state = state.copyWith(
      index: state.index + 1,
      acknowledged: false,
      missesOnStep: 0,
    );
  }

  void pause() => state = state.copyWith(paused: true);
  void resume() => state = state.copyWith(paused: false);

  PhoneTouchMetrics? finish() {
    if (!state.completed || state.finished) return null;
    state = state.copyWith(finished: true);
    return PhoneTouchMetrics(
      completedTargets: state.hits,
      totalTargets: PhoneTouchState.targetCount,
      touchesOnTarget: state.hits,
      touchesOutsideTarget: state.misses,
      buttonWidthDp: buttonWidth,
      buttonHeightDp: buttonHeight,
      imageSizeDp: imageSize,
    );
  }
}
