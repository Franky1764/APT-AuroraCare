import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_config.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_controller.dart';

void main() {
  late DateTime now;
  late ConnectDotsController controller;

  void complete() {
    final points = controller.state.evaluator!.points;
    controller.down(1, points.first);
    for (final point in points.skip(1)) {
      now = now.add(const Duration(seconds: 1));
      controller.move(1, point);
    }
  }

  setUp(() {
    now = DateTime(2026);
    controller = ConnectDotsController(
      GameLevel.facil,
      figures: [ConectaFigure.pentagono],
      clock: () => now,
    );
    controller.layout(const Rect.fromLTWH(20, 20, 300, 300));
  });
  tearDown(() => controller.dispose());

  test('la figura requiere volver al inicio, sin cierre automático', () {
    final points = controller.state.evaluator!.points;
    controller.down(1, points.first);
    for (final point in points.skip(1).take(points.length - 2)) {
      controller.move(1, point);
    }
    expect(controller.state.completed, isFalse);
    expect(controller.finish(), isNull);
    controller.move(1, points.first);
    expect(controller.state.completed, isTrue);
    expect(controller.state.evaluator!.correcciones, 0);
    final metrics = controller.finish()!;
    expect(metrics.connectionVersion, 'connect-dots-v2');
    expect(metrics.precisionPct, closeTo(100, .001));
    expect(metrics.connectionAttempts.single.completed, isTrue);
    expect(controller.finish(), isNull);
  });

  test('retoma a mitad de un tramo sin borrar lo realizado', () {
    final evaluator = controller.state.evaluator!;
    final first = evaluator.points.first;
    final midway = Offset.lerp(first, evaluator.points[1], .5)!;
    controller.down(1, first);
    controller.move(1, midway);
    controller.up(1);
    expect(evaluator.lifts, 1);
    controller.down(2, midway);
    controller.move(2, evaluator.points[1]);
    expect(evaluator.alcanzados, 2);
    expect(evaluator.strokes.length, 2);
    expect(evaluator.correcciones, 0);
  });

  test('pausa excluye la espera del tiempo real de práctica', () {
    final evaluator = controller.state.evaluator!;
    controller.down(1, evaluator.points.first);
    now = now.add(const Duration(seconds: 2));
    controller.pause();
    final reached = evaluator.alcanzados;
    now = now.add(const Duration(minutes: 5));
    controller.down(2, evaluator.points[1]);
    expect(evaluator.alcanzados, reached);
    controller.resume();
    complete();
    final metrics = controller.finish()!;
    expect(metrics.tiempoSegundos, 7);
    expect(metrics.connectionAttempts.single.activeTimeMs, 7000);
    expect(evaluator.lifts, 0);
  });

  test('la demostración no completa puntos ni se cuenta como movimiento', () {
    final evaluator = controller.state.evaluator!;
    controller.down(1, evaluator.points.first);
    final distance = evaluator.totalDistance;
    controller.beginDemo();
    now = now.add(const Duration(minutes: 3));
    controller.move(1, evaluator.points[1]);
    expect(evaluator.totalDistance, distance);
    expect(evaluator.alcanzados, 1);
    controller.endDemo();
    complete();
    final metrics = controller.finish()!;
    expect(metrics.connectionAttempts.single.demonstrationViews, 1);
    expect(metrics.tiempoSegundos, 5);
  });

  test('al cerrar la ayuda se conserva una pausa que ya existía', () {
    controller.pause();
    controller.beginDemo();
    controller.endDemo();
    expect(controller.state.paused, isTrue);
  });

  test('reiniciar conserva el intento incompleto y el tiempo dedicado', () {
    final first = controller.state.evaluator!.points.first;
    controller.down(1, first);
    now = now.add(const Duration(seconds: 3));
    controller.restart();
    expect(controller.attempts.single.completed, isFalse);
    expect(controller.attempts.single.activeTimeMs, 3000);
    complete();
    final metrics = controller.finish()!;
    expect(metrics.connectionAttempts.length, 2);
    expect(metrics.connectionAttempts.last.attempt, 2);
    expect(metrics.tiempoSegundos, 8);
    expect(metrics.precisionPct, closeTo(100, .001));
  });

  test('repetir una figura conserva los intentos sin duplicar el cierre', () {
    complete();
    controller.restart();
    complete();
    final metrics = controller.finish()!;
    expect(metrics.connectionAttempts.length, 2);
    expect(
      metrics.connectionAttempts.every((attempt) => attempt.completed),
      isTrue,
    );
  });

  test(
    'el cambio de área conserva el progreso y reubica el punto de retoma',
    () {
      final evaluator = controller.state.evaluator!;
      controller.down(1, evaluator.points.first);
      final middle = Offset.lerp(evaluator.points[0], evaluator.points[1], .5)!;
      controller.move(1, middle);
      controller.up(1);
      final reached = evaluator.alcanzados;
      controller.layout(const Rect.fromLTWH(20, 20, 600, 600));
      expect(identical(controller.state.evaluator, evaluator), isTrue);
      expect(evaluator.alcanzados, reached);
      controller.down(2, evaluator.strokes.last.last);
      controller.move(2, evaluator.points[1]);
      expect(evaluator.alcanzados, 2);
    },
  );

  test('un segundo dedo y la cancelación no producen correcciones ni alzadas falsas', () {
    final evaluator = controller.state.evaluator!;
    controller.down(1, evaluator.points.first);
    controller.down(2, evaluator.points[1]);
    controller.move(2, evaluator.points[1]);
    controller.up(2);
    expect(evaluator.alcanzados, 1);
    controller.up(1, cancelled: true);
    expect(evaluator.lifts, 0);
    expect(evaluator.correcciones, 0);
  });
}
