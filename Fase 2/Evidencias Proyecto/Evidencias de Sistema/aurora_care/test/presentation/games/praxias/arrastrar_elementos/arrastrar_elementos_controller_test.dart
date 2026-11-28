import 'dart:math';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_controller.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_images.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PhoneDragController.resetHistory);

  for (final level in GameLevel.values) {
    test(
      'failed drops, cancellations and support are distinct at ${level.name}',
      () {
        final controller = PhoneDragController(level);
        addTearDown(controller.dispose);
        controller.touch();
        expect(controller.state.dragging, isFalse);
        controller.begin(onItem: false);
        expect(controller.state.dragging, isFalse);
        controller.begin(onItem: true);
        controller.move(100, 100);
        controller.pause();
        controller.drop(insideTarget: true);
        expect(controller.state.attempts, 0);
        controller.resume();
        controller.begin(onItem: true);
        controller.drop(insideTarget: false);
        expect(controller.state.index, 0);
        expect(controller.state.misses, 1);
        for (var step = 0; step < 3; step++) {
          controller.begin(onItem: true);
          controller.drop(insideTarget: true);
          controller.drop(insideTarget: true);
          expect(controller.state.completedActions, step + 1);
          expect(controller.finish(), isNull);
        }
        controller.placeWithButton();
        final metrics = controller.finish()!;
        expect(metrics.completedActions, 4);
        expect(metrics.successfulDrags, 3);
        expect(metrics.dragAttempts, 4);
        expect(metrics.dropsOutsideTarget, 1);
        expect(metrics.assistedActions, 1);
        expect(metrics.targetSizeDp, controller.targetSize);
        expect(controller.finish(), isNull);
      },
    );
  }

  test('el catálogo tiene más imágenes que las que usa una partida', () {
    expect(dragImagePool.length, greaterThan(PhoneDragState.targetCount * 2));
    expect(dragImagePool.map((i) => i.name).toSet().length,
        dragImagePool.length);
  });

  test('cada partida sortea cuatro imágenes distintas y disposiciones sin '
      'repetir seguidas', () {
    final seen = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      PhoneDragController.resetHistory();
      final controller = PhoneDragController(
        GameLevel.facil,
        random: Random(seed),
      );
      addTearDown(controller.dispose);
      expect(controller.sequence.length, PhoneDragState.targetCount);
      expect(controller.sequence.toSet().length, PhoneDragState.targetCount);
      expect(controller.layouts.length, PhoneDragState.targetCount);
      for (var i = 1; i < controller.layouts.length; i++) {
        expect(controller.layouts[i], isNot(controller.layouts[i - 1]));
      }
      seen.add(controller.sequence.join(','));
    }
    expect(seen.length, greaterThan(1));
  });

  test('la partida siguiente no empieza con la misma imagen', () {
    PhoneDragController.resetHistory();
    for (var seed = 0; seed < 40; seed++) {
      final first = PhoneDragController(GameLevel.facil, random: Random(seed));
      addTearDown(first.dispose);
      final second = PhoneDragController(GameLevel.facil, random: Random(seed));
      addTearDown(second.dispose);
      expect(second.sequence.first, isNot(first.sequence.first));
    }
  });

  test('tras tres dificultades en la misma imagen se ofrece el apoyo', () {
    final controller = PhoneDragController(
      GameLevel.facil,
      random: Random(1),
    );
    addTearDown(controller.dispose);
    controller.touch(); // intento de mover sin esperar el agarre
    controller.begin(onItem: true);
    controller.drop(insideTarget: false);
    expect(controller.state.offerAssist, isFalse);
    controller.begin(onItem: true);
    controller.drop(insideTarget: false);
    expect(controller.state.troubleOnStep, 3);
    expect(controller.state.offerAssist, isTrue);
    // Al colocarla, la dificultad se reinicia para la imagen siguiente.
    controller.placeWithButton();
    expect(controller.state.troubleOnStep, 0);
    expect(controller.state.offerAssist, isFalse);
    controller.begin(onItem: true);
    controller.drop(insideTarget: true);
    expect(controller.state.troubleOnStep, 0);
  });
}
