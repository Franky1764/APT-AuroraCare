import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';
import 'trazado_guiado_config.dart';
import 'trazado_guiado_logic.dart';

final trazadoRandomProvider = Provider<Random>((ref) => Random());
final trazadoClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final _previous = <GameLevel, List<TrazadoFigure>>{};

final trazadoGuiadoProvider = StateNotifierProvider.autoDispose
    .family<TrazadoGuiadoController, TrazadoGuiadoState, GameLevel>((
      ref,
      level,
    ) {
      return TrazadoGuiadoController(
        level,
        random: ref.read(trazadoRandomProvider),
        clock: ref.read(trazadoClockProvider),
      );
    });

class TrazadoGuiadoState {
  const TrazadoGuiadoState({
    required this.figures,
    this.index = 0,
    this.evaluator,
    this.paused = false,
    this.demonstrating = false,
    this.helpStart,
    this.helpEnd,
    this.finished = false,
  });

  final List<TrazadoFigure> figures;
  final int index;
  final TraceEvaluator? evaluator;
  final bool paused;
  final bool demonstrating;
  final double? helpStart;
  final double? helpEnd;
  final bool finished;
  TrazadoFigure get figure => figures[index];
  bool get completed => evaluator?.completed ?? false;
  bool get blocked => paused || demonstrating || completed || finished;
}

/// Conserva el evaluador durante todo el intento, incluso al cambiar el área.
class TrazadoGuiadoController extends StateNotifier<TrazadoGuiadoState> {
  TrazadoGuiadoController(
    this.level, {
    required Random random,
    required this.clock,
  }) : super(
         TrazadoGuiadoState(
           figures: List.unmodifiable(
             elegirFigurasTrazado(level, random, anterior: _previous[level]),
           ),
         ),
       ) {
    _previous[level] = state.figures;
  }

  final GameLevel level;
  final DateTime Function() clock;
  final List<TracingAttemptMetrics> _attempts = [];
  List<TracingAttemptMetrics> get attempts => List.unmodifiable(_attempts);
  Rect? _area;
  final Map<int, TracingAttemptMetrics> _completedByFigure = {};
  bool get destinationEarly {
    final e = state.evaluator;
    if (state.completed || e == null || e.strokes.isEmpty) return false;
    if (e.guide.isClosed && e.progress < .1) return false;
    return (e.strokes.last.last - e.guide.end).distance <= e.tolerancePx * 2;
  }

  int? _pointer;
  Timer? _helpTimer;
  int _attempt = 1;
  int _helps = 0;
  int _demos = 0;
  bool _saved = false;
  int _undo = 0, _time = 0;
  double _inside = 0, _total = 0;
  double _length = 0;

  void _emit({
    int? index,
    TraceEvaluator? evaluator,
    bool? paused,
    bool? demonstrating,
    double? helpStart,
    double? helpEnd,
    bool? finished,
    bool clearHelp = false,
  }) {
    state = TrazadoGuiadoState(
      figures: state.figures,
      index: index ?? state.index,
      evaluator: evaluator ?? state.evaluator,
      paused: paused ?? state.paused,
      demonstrating: demonstrating ?? state.demonstrating,
      helpStart: clearHelp ? null : helpStart ?? state.helpStart,
      helpEnd: clearHelp ? null : helpEnd ?? state.helpEnd,
      finished: finished ?? state.finished,
    );
  }

  void layout(Rect area) {
    if (area.width <= 0 || area.height <= 0 || area == _area) return;
    final guide = GuidePath.fromUnitPoints(state.figure.puntosUnitarios, area);
    final evaluator = state.evaluator;
    if (evaluator == null) {
      _emit(
        evaluator: TraceEvaluator(
          guide: guide,
          tolerancePx: toleranciaPx(level),
        ),
      );
    } else {
      evaluator.reframe(guide, _area!, area, clock());
      _pointer = null;
      _emit(clearHelp: true);
    }
    _area = area;
  }

  void down(int pointer, Offset position) {
    if (state.blocked || _pointer != null || state.evaluator == null) return;
    _pointer = pointer;
    state.evaluator!.pointerDown(position, clock());
    _changed();
  }

  void move(int pointer, Offset position) {
    if (state.blocked || pointer != _pointer) return;
    state.evaluator!.pointerMove(position, clock());
    _changed();
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    state.evaluator?.pointerUp(clock());
    _changed();
  }

  void _changed() {
    if (state.completed) {
      _pointer = null;
      _save();
    }
    _emit();
  }

  void pause() {
    state.evaluator?.pause(clock());
    _pointer = null;
    _helpTimer?.cancel();
    _emit(paused: true, clearHelp: true);
  }

  void resume() => _emit(paused: false);

  void beginDemo() {
    if (state.blocked) return;
    pause();
    _demos++;
    _emit(demonstrating: true);
  }

  void endDemo() => _emit(demonstrating: false, paused: false);

  void help() {
    final e = state.evaluator;
    if (state.blocked || e == null) return;
    _helps++;
    _helpTimer?.cancel();
    _emit(
      helpStart: e.progressPx,
      helpEnd: min(
        e.guide.length,
        e.progressPx + min(64, e.guide.length * .15),
      ),
    );
    _helpTimer = Timer(
      const Duration(seconds: 3),
      () => _emit(clearHelp: true),
    );
  }

  void undo() {
    if (state.blocked) return;
    _pointer = null;
    state.evaluator?.undoLastStroke(clock());
    _emit();
  }

  void _save() {
    final e = state.evaluator;
    if (e == null || _saved) return;
    e.pause(clock());
    _attempts.add(
      TracingAttemptMetrics(
        figure: state.figure.name,
        attempt: _attempt,
        completed: e.completed,
        precisionPct: e.precisionPct,
        coveragePct: e.progress * 100,
        activeTimeMs: e.tiempoMs,
        tolerancePx: e.tolerancePx,
        helpRequests: _helps,
        demonstrationViews: _demos,
        undoCount: e.correcciones,
        lifts: e.lifts,
        practicePrecisionPct: e.practicePrecisionPct,
      ),
    );
    if (e.completed) {
      _completedByFigure[state.index] = _attempts.last;
      _completedLengths[state.index] = (e.insideLengthPx, e.totalLengthPx);
    }
    _recalculate();
    _saved = true;
  }

  void _recalculate() {
    _inside = 0;
    _total = 0;
    _undo = 0;
    _time = 0;
    _length = 0;
    for (final entry in _completedByFigure.entries) {
      final metrics = entry.value;
      // Las longitudes evaluadas se conservan separadas de los metadatos.
      final lengths = _completedLengths[entry.key]!;
      _inside += lengths.$1;
      _total += lengths.$2;
      _undo += metrics.undoCount;
      _time += metrics.activeTimeMs;
      _length += state.figures[entry.key].longitudUnitaria;
    }
  }

  final Map<int, (double, double)> _completedLengths = {};

  void restart() {
    if (state.finished) return;
    _save();
    _completedByFigure.remove(state.index);
    _completedLengths.remove(state.index);
    _recalculate();
    _attempt++;
    _newEvaluator(state.index);
  }

  void _newEvaluator(int index) {
    _helpTimer?.cancel();
    _pointer = null;
    _helps = 0;
    _demos = 0;
    _saved = false;
    final area = _area;
    state = TrazadoGuiadoState(
      figures: state.figures,
      index: index,
      evaluator: area == null
          ? null
          : TraceEvaluator(
              guide: GuidePath.fromUnitPoints(
                state.figures[index].puntosUnitarios,
                area,
              ),
              tolerancePx: toleranciaPx(level),
            ),
    );
  }

  void next() {
    if (!state.completed || state.index == state.figures.length - 1) return;
    _attempt = 1;
    _newEvaluator(state.index + 1);
  }

  PraxiasMetrics? finish() {
    if (!state.completed ||
        state.index != state.figures.length - 1 ||
        state.finished) {
      return null;
    }
    _emit(finished: true);
    return PraxiasMetrics(
      precisionPct: _total == 0 ? 0 : _inside / _total * 100,
      correcciones: _undo,
      tiempoSegundos: tiempoNormalizadoTrazadoSeg(_time, _length, level),
      tracingAttempts: List.unmodifiable(_attempts),
      tracingVersion: 'tracing-practice-v2',
    );
  }

  @override
  void dispose() {
    _helpTimer?.cancel();
    state.evaluator?.pause(clock());
    super.dispose();
  }
}
