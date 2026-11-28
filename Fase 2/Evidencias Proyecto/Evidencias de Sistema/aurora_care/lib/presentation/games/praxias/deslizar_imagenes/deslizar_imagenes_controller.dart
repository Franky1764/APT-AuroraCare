import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import '../../../../domain/usecases/evaluate_phone_swipe.dart';

final phoneSwipeProvider = StateNotifierProvider.autoDispose
    .family<PhoneSwipeController, PhoneSwipeState, GameLevel>(
      (ref, level) => PhoneSwipeController(level),
    );

class PhoneSwipeState {
  const PhoneSwipeState({
    this.index = 0,
    this.imageIndex = 0,
    this.swipes = 0,
    this.attempts = 0,
    this.assisted = 0,
    this.dragDx = 0,
    this.dragProgress = 0,
    this.failuresOnStep = 0,
    this.dragging = false,
    this.acknowledged = false,
    this.paused = false,
    this.finished = false,
    this.feedback = SwipeOutcome.ready,
  });
  static const directions = [
    SwipeDirection.left,
    SwipeDirection.left,
    SwipeDirection.right,
    SwipeDirection.right,
  ];
  final int index;
  final int imageIndex;
  final int swipes;
  final int attempts;
  final int assisted;
  final double dragDx;

  /// Avance del dedo hacia el recorrido exigido (0 a 1), solo en la dirección
  /// pedida. Con 1 ya se puede soltar.
  final double dragProgress;

  /// Intentos fallidos en la acción actual; se reinicia al lograrla.
  final int failuresOnStep;
  final bool dragging;
  final bool acknowledged;
  final bool paused;
  final bool finished;
  final SwipeOutcome feedback;
  SwipeDirection get direction => directions[index];
  int get completedActions => swipes + assisted;
  bool get completed => completedActions == directions.length;
  bool get blocked => completed || paused || finished;
  bool get readyToRelease => dragging && dragProgress >= 1;

  /// Tras varios intentos fallidos se ofrece el apoyo con botón a la vista.
  static const failuresToOfferAssist = 3;
  bool get offerAssist => failuresOnStep >= failuresToOfferAssist;
  PhoneSwipeState copyWith({
    int? index,
    int? imageIndex,
    int? swipes,
    int? attempts,
    int? assisted,
    double? dragDx,
    double? dragProgress,
    int? failuresOnStep,
    bool? dragging,
    bool? acknowledged,
    bool? paused,
    bool? finished,
    SwipeOutcome? feedback,
  }) => PhoneSwipeState(
    index: index ?? this.index,
    imageIndex: imageIndex ?? this.imageIndex,
    swipes: swipes ?? this.swipes,
    attempts: attempts ?? this.attempts,
    assisted: assisted ?? this.assisted,
    dragDx: dragDx ?? this.dragDx,
    dragProgress: dragProgress ?? this.dragProgress,
    failuresOnStep: failuresOnStep ?? this.failuresOnStep,
    dragging: dragging ?? this.dragging,
    acknowledged: acknowledged ?? this.acknowledged,
    paused: paused ?? this.paused,
    finished: finished ?? this.finished,
    feedback: feedback ?? this.feedback,
  );
}

class PhoneSwipeController extends StateNotifier<PhoneSwipeState> {
  PhoneSwipeController(this.level) : super(const PhoneSwipeState());
  final GameLevel level;
  double get distanceRatio => switch (level) {
    GameLevel.facil => .25,
    GameLevel.intermedio => .35,
    GameLevel.avanzado => .45,
  };
  int? _pointer;
  double _startX = 0, _startY = 0, _lastX = 0, _lastY = 0;
  double _pathLength = 0, _dy = 0, _width = 0;

  void down(int pointer, double x, double y, double width) {
    if (state.blocked || _pointer != null || !width.isFinite || width <= 0) {
      return;
    }
    _pointer = pointer;
    _startX = _lastX = x;
    _startY = _lastY = y;
    _pathLength = _dy = 0;
    _width = width;
    state = state.copyWith(
      dragging: true,
      dragDx: 0,
      dragProgress: 0,
      feedback: SwipeOutcome.ready,
    );
  }

  void move(int pointer, double x, double y) {
    if (pointer != _pointer || state.blocked) return;
    _pathLength += math.sqrt(math.pow(x - _lastX, 2) + math.pow(y - _lastY, 2));
    _lastX = x;
    _lastY = y;
    _dy = y - _startY;
    final dx = x - _startX;
    final rightWay = state.direction == SwipeDirection.left ? dx < 0 : dx > 0;
    final required = _width * distanceRatio;
    state = state.copyWith(
      dragDx: dx,
      dragProgress: rightWay ? math.min(1.0, dx.abs() / required) : 0.0,
    );
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    final outcome = evaluatePhoneSwipe(
      dx: state.dragDx,
      dy: _dy,
      pathLength: _pathLength,
      viewportWidth: _width,
      requiredDistanceRatio: distanceRatio,
      direction: state.direction,
    );
    final attempts = state.attempts + (outcome == SwipeOutcome.tap ? 0 : 1);
    if (outcome == SwipeOutcome.achieved) {
      _advance(assisted: false, attempts: attempts);
    } else {
      state = state.copyWith(
        dragging: false,
        dragDx: 0,
        dragProgress: 0,
        feedback: outcome,
        attempts: attempts,
        // Un toque sin desplazamiento no es un intento fallido.
        failuresOnStep:
            state.failuresOnStep + (outcome == SwipeOutcome.tap ? 0 : 1),
      );
    }
  }

  void cancel([int? pointer]) {
    if (pointer != null && pointer != _pointer) return;
    _pointer = null;
    state = state.copyWith(dragging: false, dragDx: 0, dragProgress: 0);
  }

  void _advance({required bool assisted, required int attempts}) {
    // Al levantar el dedo queda listo el siguiente gesto. No hay un botón
    // intermedio ni un temporizador que obligue a esperar o apurarse.
    state = state.copyWith(
      index: math.min(state.index + 1, PhoneSwipeState.directions.length - 1),
      imageIndex:
          state.imageIndex + (state.direction == SwipeDirection.left ? 1 : -1),
      swipes: state.swipes + (assisted ? 0 : 1),
      assisted: state.assisted + (assisted ? 1 : 0),
      attempts: attempts,
      dragDx: 0,
      dragProgress: 0,
      failuresOnStep: 0,
      dragging: false,
      acknowledged: true,
      feedback: SwipeOutcome.achieved,
    );
  }

  /// El apoyo accesible cambia la imagen, pero no se registra como un gesto.
  void changeWithButton() {
    if (state.blocked) return;
    cancel();
    _advance(assisted: true, attempts: state.attempts);
  }

  void pause() {
    cancel();
    state = state.copyWith(paused: true);
  }

  void resume() => state = state.copyWith(paused: false);

  PhoneSwipeMetrics? finish() {
    if (!state.completed || state.finished) return null;
    state = state.copyWith(finished: true);
    return PhoneSwipeMetrics(
      completedActions: state.completedActions,
      totalActions: PhoneSwipeState.directions.length,
      successfulSwipes: state.swipes,
      gestureAttempts: state.attempts,
      assistedActions: state.assisted,
      requiredDistanceRatio: distanceRatio,
    );
  }
}
