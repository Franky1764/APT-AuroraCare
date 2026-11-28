import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/usecases/evaluate_phone_swipe.dart';
import 'package:aurora_care/presentation/games/praxias/deslizar_imagenes/deslizar_imagenes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final level in GameLevel.values) {
    test(
      'complete four intentional swipes at ${level.name}, independent of elapsed time',
      () {
        final controller = PhoneSwipeController(level);
        addTearDown(controller.dispose);
        expect(controller.finish(), isNull);
        for (var step = 0; step < 4; step++) {
          controller.down(1, 150, 100, 300);
          final dx = controller.state.direction == SwipeDirection.left
              ? -145.0
              : 145.0;
          controller.move(2, 0, 0);
          controller.up(2);
          expect(controller.state.dragging, isTrue);
          controller.move(1, 150 + dx, 110);
          controller.up(1);
          expect(controller.state.acknowledged, isTrue);
          expect(controller.state.index, (step + 1).clamp(0, 3));
          controller.up(1);
          expect(controller.state.completedActions, step + 1);
          expect(controller.state.assisted, 0);
        }
        expect(controller.state.imageIndex, 0);
        final result = controller.finish()!;
        expect(result.successfulSwipes, 4);
        expect(result.gestureAttempts, 4);
        expect(result.assistedActions, 0);
        expect(result.completedActions, 4);
        expect(result.requiredDistanceRatio, controller.distanceRatio);
        expect(controller.finish(), isNull);
      },
    );
  }
  test(
    'pause, pointer cancellation and help never create phantom gestures',
    () {
      final controller = PhoneSwipeController(GameLevel.facil);
      addTearDown(controller.dispose);
      controller.down(1, 150, 100, 300);
      controller.move(1, 40, 100);
      controller.pause();
      controller.up(1);
      expect(controller.state.attempts, 0);
      expect(controller.state.imageIndex, 0);
      controller.down(1, 150, 100, 300);
      expect(controller.state.dragging, isFalse);
      controller.resume();
      controller.down(1, 150, 100, 300);
      controller.cancel(2);
      expect(controller.state.dragging, isTrue);
      controller.cancel(1);
      expect(controller.state.dragging, isFalse);
      controller.changeWithButton();
      expect(controller.state.assisted, 1);
      expect(controller.state.swipes, 0);
      expect(controller.state.attempts, 0);
      expect(controller.state.imageIndex, 1);
    },
  );

  test('el avance hacia el recorrido exigido sube con el dedo y llega a 1', () {
    final controller = PhoneSwipeController(GameLevel.facil);
    addTearDown(controller.dispose);
    // Ancho 400 y 25 % exigido: hacen falta 100 px hacia la izquierda.
    controller.down(1, 200, 100, 400);
    controller.move(1, 150, 100);
    expect(controller.state.dragProgress, closeTo(.5, .001));
    expect(controller.state.readyToRelease, isFalse);
    controller.move(1, 90, 100);
    expect(controller.state.dragProgress, 1);
    expect(controller.state.readyToRelease, isTrue);
    // En la dirección contraria no suma avance.
    controller.move(1, 260, 100);
    expect(controller.state.dragProgress, 0);
    controller.up(1);
    expect(controller.state.dragProgress, 0);
    expect(controller.state.readyToRelease, isFalse);
  });

  test('tras tres intentos fallidos se ofrece el apoyo; un toque no cuenta', () {
    final controller = PhoneSwipeController(GameLevel.facil);
    addTearDown(controller.dispose);
    void failShort() {
      controller.down(1, 200, 100, 400);
      controller.move(1, 180, 100); // 20 px: es poco
      controller.up(1);
    }

    // Un toque sin desplazamiento no es un intento fallido.
    controller.down(1, 200, 100, 400);
    controller.up(1);
    expect(controller.state.failuresOnStep, 0);

    failShort();
    failShort();
    expect(controller.state.offerAssist, isFalse);
    failShort();
    expect(controller.state.failuresOnStep, 3);
    expect(controller.state.offerAssist, isTrue);

    // Al lograr la acción, el contador de la acción siguiente vuelve a 0.
    controller.changeWithButton();
    expect(controller.state.failuresOnStep, 0);
    expect(controller.state.offerAssist, isFalse);
    expect(controller.state.attempts, 3);
    expect(controller.state.assisted, 1);
  });
}
