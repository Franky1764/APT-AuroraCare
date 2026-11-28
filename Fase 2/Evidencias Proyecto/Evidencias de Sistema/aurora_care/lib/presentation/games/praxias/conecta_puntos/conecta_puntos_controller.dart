import 'dart:math';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import 'conecta_puntos_config.dart';
import 'conecta_puntos_logic.dart';

final connectDotsRandomProvider = Provider<Random>((ref) => Random());
final connectDotsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final _historyProvider = Provider((ref) => <GameLevel, List<ConectaFigure>>{});

final connectDotsProvider = StateNotifierProvider.autoDispose
    .family<ConnectDotsController, ConnectDotsState, GameLevel>((ref, level) {
      final history = ref.read(_historyProvider);
      final figures = elegirFigurasSesion(
        level,
        ref.read(connectDotsRandomProvider),
        anterior: history[level],
      );
      history[level] = figures;
      return ConnectDotsController(
        level,
        figures: figures,
        clock: ref.read(connectDotsClockProvider),
      );
    });

class ConnectDotsState {
  const ConnectDotsState({
    required this.figures,
    this.index = 0,
    this.evaluator,
    this.paused = false,
    this.demonstrating = false,
    this.finished = false,
  });
  final List<ConectaFigure> figures;
  final int index;
  final ConectaEvaluator? evaluator;
  final bool paused, demonstrating, finished;
  ConectaFigure get figure => figures[index];
  bool get completed => evaluator?.completed ?? false;
  bool get blocked => paused || demonstrating || completed || finished;
}

class ConnectDotsController extends StateNotifier<ConnectDotsState> {
  ConnectDotsController(
    this.level, {
    required List<ConectaFigure> figures,
    required this.clock,
  }) : super(ConnectDotsState(figures: List.unmodifiable(figures)));

  final GameLevel level;
  final DateTime Function() clock;
  final List<ConnectionAttemptMetrics> _attempts = [];
  final Map<int, ({double inside, double total})> _finalPrecision = {};
  List<ConnectionAttemptMetrics> get attempts => List.unmodifiable(_attempts);
  Rect? _area;
  int? _pointer;
  int _attempt = 1, _demos = 0;
  bool _saved = false, _pausedBeforeDemo = false;

  void _emit({
    ConectaEvaluator? evaluator,
    int? index,
    bool? paused,
    bool? demonstrating,
    bool? finished,
  }) {
    state = ConnectDotsState(
      figures: state.figures,
      index: index ?? state.index,
      evaluator: evaluator ?? state.evaluator,
      paused: paused ?? state.paused,
      demonstrating: demonstrating ?? state.demonstrating,
      finished: finished ?? state.finished,
    );
  }

  ConectaEvaluator _newEvaluator(ConectaFigure figure) {
    final points = scalePoints(figure.puntosUnitarios, _area!);
    // El cierre también se practica: nunca se completa un tramo por el usuario.
    return ConectaEvaluator(
      points: [...points, points.first],
      tolerancePx: toleranciaConectaPx(level),
      hitRadiusPx: conectaHitRadiusPx,
    );
  }

  void layout(Rect area) {
    if (area.width <= 0 || area.height <= 0 || area == _area) return;
    final previous = _area;
    _area = area;
    final evaluator = state.evaluator;
    if (evaluator == null) {
      _emit(evaluator: _newEvaluator(state.figure));
    } else {
      evaluator.reframe(previous!, area, clock());
      _pointer = null;
      _emit();
    }
  }

  void down(int pointer, Offset position) {
    if (state.blocked || _pointer != null || state.evaluator == null) return;
    _pointer = pointer;
    state.evaluator!.pointerDown(position, clock());
    _emit();
  }

  void move(int pointer, Offset position) {
    if (state.blocked || _pointer != pointer) return;
    state.evaluator!.pointerMove(position, clock());
    if (state.completed) {
      _pointer = null;
      _saveAttempt();
    }
    _emit();
  }

  void up(int pointer, {bool cancelled = false}) {
    if (_pointer != pointer) return;
    _pointer = null;
    state.evaluator?.pointerUp(countLift: !cancelled);
    _emit();
  }

  void pause() {
    if (state.finished) return;
    state.evaluator?.pause(clock());
    _pointer = null;
    _emit(paused: true);
  }

  void resume() {
    if (state.demonstrating || state.finished) return;
    state.evaluator?.resume(clock());
    _emit(paused: false);
  }

  void beginDemo() {
    if (state.demonstrating || state.finished || state.completed) return;
    _pausedBeforeDemo = state.paused;
    pause();
    _demos++;
    _emit(demonstrating: true);
  }

  void endDemo() {
    if (!state.demonstrating) return;
    _emit(demonstrating: false, paused: _pausedBeforeDemo);
    if (!_pausedBeforeDemo) state.evaluator?.resume(clock());
  }

  void _saveAttempt() {
    final evaluator = state.evaluator;
    if (_saved || evaluator == null) return;
    if (evaluator.strokes.isEmpty && _demos == 0) return;
    _saved = true;
    _attempts.add(
      ConnectionAttemptMetrics(
        figure: state.figure.name,
        attempt: _attempt,
        completed: evaluator.completed,
        precisionPct: evaluator.totalDistance == 0
            ? null
            : evaluator.precisionPct,
        connectedPoints: evaluator.alcanzados,
        totalPoints: evaluator.totalPuntos,
        activeTimeMs: evaluator.activeTimeMs(clock()),
        tolerancePx: evaluator.tolerancePx,
        outOfOrderTouches: evaluator.correcciones,
        lifts: evaluator.lifts,
        demonstrationViews: _demos,
      ),
    );
    if (evaluator.completed) {
      _finalPrecision[state.index] = (
        inside: evaluator.insideDistance,
        total: evaluator.totalDistance,
      );
    }
  }

  void restart() {
    if (state.finished || state.demonstrating || _area == null) return;
    state.evaluator?.pause(clock());
    _saveAttempt();
    _pointer = null;
    _attempt++;
    _demos = 0;
    _saved = false;
    _emit(evaluator: _newEvaluator(state.figure), paused: false);
  }

  void next() {
    if (!state.completed ||
        state.finished ||
        state.index >= state.figures.length - 1) {
      return;
    }
    final next = state.index + 1;
    _pointer = null;
    _attempt = 1;
    _demos = 0;
    _saved = false;
    _emit(
      index: next,
      evaluator: _newEvaluator(state.figures[next]),
      paused: false,
    );
  }

  PraxiasMetrics? finish() {
    if (!state.completed ||
        state.finished ||
        state.index != state.figures.length - 1) {
      return null;
    }
    _saveAttempt();
    final inside = _finalPrecision.values.fold(
      0.0,
      (sum, value) => sum + value.inside,
    );
    final distance = _finalPrecision.values.fold(
      0.0,
      (sum, value) => sum + value.total,
    );
    final time = _attempts.fold(
      0,
      (sum, attempt) => sum + attempt.activeTimeMs,
    );
    _emit(finished: true);
    return PraxiasMetrics(
      precisionPct: distance == 0 ? 0 : inside / distance * 100,
      correcciones: _attempts.fold(
        0,
        (sum, attempt) => sum + attempt.outOfOrderTouches,
      ),
      tiempoSegundos: (time / 1000).round(),
      connectionVersion: 'connect-dots-v2',
      connectionAttempts: List.unmodifiable(_attempts),
    );
  }
}
