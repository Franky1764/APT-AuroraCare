import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_controller.dart';

void main() {
  late TrazadoGuiadoController controller;
  late DateTime now;
  setUp(() {
    now = DateTime(2026);
    controller = TrazadoGuiadoController(
      GameLevel.facil,
      random: Random(2),
      clock: () => now,
    );
    controller.layout(const Rect.fromLTWH(30, 30, 240, 240));
  });
  tearDown(() => controller.dispose());

  test('resize preserves evaluator and progress; pause excludes idle time', () {
    final evaluator = controller.state.evaluator!;
    controller.down(1, evaluator.guide.start);
    now = now.add(const Duration(milliseconds: 100));
    controller.move(1, evaluator.guide.pointAt(20));
    controller.pause();
    final progress = evaluator.progress;
    final active = evaluator.tiempoMs;
    now = now.add(const Duration(minutes: 2));
    controller.layout(const Rect.fromLTWH(40, 40, 180, 180));
    expect(controller.state.evaluator, same(evaluator));
    expect(evaluator.progress, closeTo(progress, .02));
    expect(evaluator.tiempoMs, active);
    expect(controller.state.paused, isTrue);
  });

  test('restart keeps attempt and help/demo counts', () {
    controller.help();
    controller.beginDemo();
    controller.endDemo();
    controller.restart();
    expect(controller.attempts, hasLength(1));
    expect(controller.attempts.single.completed, isFalse);
    expect(controller.attempts.single.helpRequests, 1);
    expect(controller.attempts.single.demonstrationViews, 1);
    expect(controller.state.evaluator!.progress, 0);
  });

  test('completion is recorded once and requires manual next and finish', () {
    for (var figure = 0; figure < 3; figure++) {
      final evaluator = controller.state.evaluator!;
      controller.down(1, evaluator.guide.start);
      for (final point in evaluator.guide.points) {
        now = now.add(const Duration(milliseconds: 10));
        controller.move(1, point);
      }
      controller.up(1);
      expect(controller.state.completed, isTrue);
      expect(controller.state.index, figure);
      expect(controller.attempts, hasLength(figure + 1));
      if (figure < 2) {
        expect(controller.finish(), isNull);
        controller.next();
      }
    }
    expect(controller.finish(), isNotNull);
    expect(controller.finish(), isNull);
  });
  test('completed retry preserves attempts without duplicating figures', () {
    void complete() {
      final e = controller.state.evaluator!;
      controller.down(1, e.guide.start);
      for (final point in e.guide.points) {
        now = now.add(const Duration(milliseconds: 10));
        controller.move(1, point);
      }
      controller.up(1);
      expect(controller.state.completed, isTrue);
    }

    complete();
    controller.restart();
    expect(controller.state.completed, isFalse);
    expect(controller.attempts, hasLength(1));
    complete();
    controller.next();
    complete();
    controller.next();
    complete();
    final metrics = controller.finish()!;
    expect(metrics.tracingVersion, 'tracing-practice-v2');
    expect(metrics.tracingAttempts, hasLength(4));
    expect(metrics.tracingAttempts.where((a) => a.attempt == 2), hasLength(1));
    expect(metrics.precisionPct, 100);
  });

  test('optional help survives drawing until explicitly cleared', () {
    controller.help();
    final start = controller.state.helpStart;
    final end = controller.state.helpEnd;
    final e = controller.state.evaluator!;
    controller.down(1, e.guide.start);
    controller.move(1, e.guide.pointAt(10));
    expect(controller.state.helpStart, start);
    expect(controller.state.helpEnd, end);
    controller.pause();
    expect(controller.state.helpStart, isNull);
  });
}
