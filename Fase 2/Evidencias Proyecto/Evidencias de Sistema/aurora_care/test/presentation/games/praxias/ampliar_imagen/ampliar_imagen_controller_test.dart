import 'dart:math';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_controller.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_scenes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PhoneZoomController.resetHistory);

  for (final level in GameLevel.values) {
    test('two-finger zoom in and out at ${level.name}', () {
      final controller = PhoneZoomController(level);
      addTearDown(controller.dispose);
      controller.begin(1);
      controller.update(2, 1);
      controller.end();
      expect(controller.state.scale, 1);
      expect(controller.state.attempts, 0);
      controller.begin(2);
      controller.update(1.2, 2);
      controller.end();
      expect(controller.state.completedActions, 0);
      controller.begin(2);
      controller.update(2, 2);
      controller.end();
      expect(controller.state.completedActions, 1);
      expect(controller.state.enlarging, isFalse);
      controller.begin(2);
      controller.update(.3, 2);
      controller.end();
      final metrics = controller.finish()!;
      expect(metrics.completedActions, 2);
      expect(metrics.successfulPinches, 2);
      expect(metrics.pinchAttempts, 3);
      expect(metrics.assistedActions, 0);
      expect(controller.state.scale, 1);
      expect(metrics.maxScaleReached, closeTo(2.4, .001));
      expect(controller.finish(), isNull);
    });
  }
  test('cancellation preserves the displayed size without a result; support stays separate', () {
    final controller = PhoneZoomController(GameLevel.facil);
    addTearDown(controller.dispose);
    controller.begin(2);
    controller.update(2, 2);
    controller.pause();
    controller.end();
    expect(controller.state.pinches, 0);
    expect(controller.state.attempts, 0);
    expect(controller.state.scale, 2);
    controller.resume();
    controller.useButton();
    expect(controller.state.scale, 2);
    controller.useButton();
    final metrics = controller.finish()!;
    expect(metrics.successfulPinches, 0);
    expect(metrics.assistedActions, 2);
    expect(metrics.pinchAttempts, 0);
    expect(metrics.maxScaleReached, 2);
  });

  test('hay varias escenas y cada partida sortea una distinta de la anterior',
      () {
    expect(zoomScenes.length, greaterThan(1));
    PhoneZoomController.resetHistory();
    for (var seed = 0; seed < 40; seed++) {
      final first = PhoneZoomController(GameLevel.facil, random: Random(seed));
      addTearDown(first.dispose);
      final second = PhoneZoomController(
        GameLevel.facil,
        random: Random(seed + 100),
      );
      addTearDown(second.dispose);
      expect(second.scene, isNot(first.scene));
      expect(first.scene, inInclusiveRange(0, zoomScenes.length - 1));
    }
  });

  test('el avance hacia la meta sube al ampliar y al reducir', () {
    final controller = PhoneZoomController(GameLevel.facil);
    addTearDown(controller.dispose);
    expect(controller.goalProgress, 0);
    controller.begin(2);
    controller.update(1, 2); // primer evento fija la referencia
    controller.update(1.3, 2);
    expect(controller.goalProgress, greaterThan(0));
    expect(controller.goalProgress, lessThan(1));
    controller.update(2, 2);
    expect(controller.goalProgress, 1);
    controller.end();
    expect(controller.state.enlarging, isFalse);
    // Al reducir, el avance parte de 0 con la imagen ampliada.
    expect(controller.goalProgress, 0);
    controller.begin(2);
    controller.update(1, 2);
    controller.update(.8, 2);
    expect(controller.goalProgress, greaterThan(0));
    controller.update(.3, 2);
    expect(controller.goalProgress, 1);
  });

  test('tras tres gestos que no logran el paso se ofrece el apoyo', () {
    final controller = PhoneZoomController(GameLevel.facil);
    addTearDown(controller.dispose);
    for (var i = 0; i < 3; i++) {
      expect(controller.state.offerAssist, isFalse);
      controller.begin(1); // un solo dedo
      controller.update(1.5, 1);
      controller.end();
    }
    expect(controller.state.troubleOnStep, 3);
    expect(controller.state.offerAssist, isTrue);
    controller.useButton();
    expect(controller.state.troubleOnStep, 0);
    expect(controller.state.offerAssist, isFalse);
  });
}
