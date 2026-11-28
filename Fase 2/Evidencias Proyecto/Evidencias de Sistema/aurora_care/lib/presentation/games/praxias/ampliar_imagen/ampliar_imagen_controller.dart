import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import 'ampliar_imagen_scenes.dart';

final phoneZoomProvider = StateNotifierProvider.autoDispose
    .family<PhoneZoomController, PhoneZoomState, GameLevel>(
      (ref, level) => PhoneZoomController(level),
    );

enum PhoneZoomFeedback { ready, twoFingers, retry, achieved }

class PhoneZoomState {
  const PhoneZoomState({
    this.pinches = 0,
    this.attempts = 0,
    this.assisted = 0,
    this.troubleOnStep = 0,
    this.scale = 1,
    this.maxScale = 1,
    this.gestureActive = false,
    this.paused = false,
    this.finished = false,
    this.feedback = PhoneZoomFeedback.ready,
  });
  final int pinches, attempts, assisted;

  /// Gestos que no lograron el paso actual (incluye intentos con un solo
  /// dedo). Se reinicia al lograrlo.
  final int troubleOnStep;
  static const troubleToOfferAssist = 3;
  bool get offerAssist => troubleOnStep >= troubleToOfferAssist;
  final double scale, maxScale;
  final bool gestureActive, paused, finished;
  final PhoneZoomFeedback feedback;
  int get completedActions => pinches + assisted;
  bool get enlarging => completedActions == 0;
  bool get completed => completedActions == 2;
  bool get blocked => paused || completed || finished;
  PhoneZoomState copyWith({
    int? pinches,
    int? attempts,
    int? assisted,
    int? troubleOnStep,
    double? scale,
    double? maxScale,
    bool? gestureActive,
    bool? paused,
    bool? finished,
    PhoneZoomFeedback? feedback,
  }) => PhoneZoomState(
    pinches: pinches ?? this.pinches,
    attempts: attempts ?? this.attempts,
    assisted: assisted ?? this.assisted,
    troubleOnStep: troubleOnStep ?? this.troubleOnStep,
    scale: scale ?? this.scale,
    maxScale: maxScale ?? this.maxScale,
    gestureActive: gestureActive ?? this.gestureActive,
    paused: paused ?? this.paused,
    finished: finished ?? this.finished,
    feedback: feedback ?? this.feedback,
  );
}

/// Solo cuenta gestos con dos dedos y movimiento en la dirección solicitada.
/// Cada gesto puede completar una acción al levantar los dedos; no dos.
class PhoneZoomController extends StateNotifier<PhoneZoomState> {
  PhoneZoomController(this.level, {math.Random? random})
    : super(const PhoneZoomState()) {
    final rng = random ?? math.Random();
    // Cada partida sortea una escena, distinta de la anterior.
    final options = [
      for (var i = 0; i < zoomScenes.length; i++)
        if (i != _lastScene) i,
    ];
    scene = options[rng.nextInt(options.length)];
    _lastScene = scene;
  }
  final GameLevel level;

  /// Posición de la escena de la partida en [zoomScenes].
  late final int scene;
  static int? _lastScene;

  @visibleForTesting
  static void resetHistory() => _lastScene = null;

  /// Avance del paso actual hacia la meta (0 a 1): hacia el tamaño exigido al
  /// ampliar, y hacia el tamaño inicial al reducir.
  double get goalProgress {
    if (state.enlarging) {
      return ((state.scale - 1) / (targetScale - 1)).clamp(0.0, 1.0);
    }
    final span = state.maxScale - 1.08;
    if (span <= 0) return 1;
    return ((state.maxScale - state.scale) / span).clamp(0.0, 1.0);
  }

  double get targetScale => switch (level) {
    GameLevel.facil => 1.6,
    GameLevel.intermedio => 1.9,
    GameLevel.avanzado => 2.2,
  };
  bool get readyToRelease =>
      state.enlarging ? state.scale >= targetScale : state.scale <= 1.08;
  bool _twoActive = false,
      _hadTwo = false,
      _changed = false,
      _goalMovement = false;
  double _lastRelative = 1;
  void begin([int pointers = 2]) {
    if (state.blocked) return;
    _twoActive = _hadTwo = _changed = _goalMovement = false;
    _twoActive = _hadTwo = pointers == 2;
    _lastRelative = 1;
    state = state.copyWith(
      gestureActive: true,
      feedback: PhoneZoomFeedback.ready,
    );
  }

  void update(double relativeScale, int pointers) {
    if (state.blocked ||
        !state.gestureActive ||
        !relativeScale.isFinite ||
        relativeScale <= 0) {
      return;
    }
    if (pointers != 2) {
      _twoActive = false;
      return;
    }
    _hadTwo = true;
    if (!_twoActive) {
      _twoActive = true;
      _lastRelative = relativeScale;
      return;
    }
    final next = (state.scale * relativeScale / _lastRelative).clamp(1.0, 3.0);
    _lastRelative = relativeScale;
    if ((next - state.scale).abs() > .0001) _changed = true;
    if (state.enlarging ? next > state.scale : next < state.scale) {
      _goalMovement = true;
    }
    state = state.copyWith(
      scale: next,
      maxScale: math.max(state.maxScale, next),
    );
  }

  void end() {
    if (!state.gestureActive || state.blocked) return;
    final attempt = _hadTwo && _changed;
    final achieved = attempt && _goalMovement && readyToRelease;
    state = state.copyWith(
      gestureActive: false,
      attempts: state.attempts + (attempt ? 1 : 0),
      pinches: state.pinches + (achieved ? 1 : 0),
      troubleOnStep: achieved ? 0 : state.troubleOnStep + 1,
      feedback: achieved
          ? PhoneZoomFeedback.achieved
          : attempt
          ? PhoneZoomFeedback.retry
          : PhoneZoomFeedback.twoFingers,
    );
  }

  void cancel() => state = state.copyWith(gestureActive: false);
  void pause() {
    cancel();
    state = state.copyWith(paused: true);
  }

  void resume() => state = state.copyWith(paused: false);
  void useButton() {
    if (state.blocked || state.gestureActive) return;
    final scale = state.enlarging ? math.max(state.scale, targetScale) : 1.0;
    state = state.copyWith(
      scale: scale,
      maxScale: math.max(state.maxScale, scale),
      assisted: state.assisted + 1,
      troubleOnStep: 0,
      feedback: PhoneZoomFeedback.achieved,
    );
  }

  PhoneZoomMetrics? finish() {
    if (!state.completed || state.finished) return null;
    state = state.copyWith(finished: true);
    return PhoneZoomMetrics(
      completedActions: state.completedActions,
      totalActions: 2,
      successfulPinches: state.pinches,
      pinchAttempts: state.attempts,
      assistedActions: state.assisted,
      maxScaleReached: state.maxScale,
      targetScale: targetScale,
    );
  }
}
