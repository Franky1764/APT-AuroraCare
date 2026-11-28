import 'dart:math';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/buscar_en_lista/buscar_en_lista_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PhoneListController.resetHistory);

  for (final level in GameLevel.values) {
    test('search choices, scrolling and assistance at ${level.name}', () {
      final controller = PhoneListController(level, random: Random(7));
      addTearDown(controller.dispose);
      controller.select(-1);
      expect(controller.state.attempts, 0);
      final wrong = List.generate(
        controller.items.length,
        (i) => i,
      ).firstWhere((i) => i != controller.targetIndex);
      controller.select(wrong);
      expect(controller.state.wrongSelection, isTrue);
      expect(controller.state.wrongIndex, wrong);
      expect(controller.state.wrongTick, 1);
      expect(controller.state.found, 0);
      controller.pause();
      controller.select(controller.targetIndex);
      controller.recordScroll();
      controller.reveal();
      expect(controller.state.scrolls, 0);
      expect(controller.state.reveals, 0);
      controller.resume();
      controller.reveal();
      controller.reveal();
      controller.select(controller.targetIndex);
      expect(controller.state.assisted, 1);
      controller.recordScroll();
      controller.select(controller.targetIndex);
      controller.recordScroll();
      controller.select(controller.targetIndex);
      final metrics = controller.finish()!;
      expect(metrics.completedSearches, 3);
      expect(metrics.selectionAttempts, 4);
      expect(metrics.otherSelections, 1);
      expect(metrics.scrollGestures, 2);
      expect(metrics.revealRequests, 2);
      expect(metrics.searchesWithHelp, 1);
      expect(metrics.listLength, controller.items.length);
      expect(controller.finish(), isNull);
    });
  }

  for (final level in GameLevel.values) {
    test('cada partida sortea lugares distintos y exige deslizar en ${level.name}',
        () {
      final seen = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        PhoneListController.resetHistory();
        final controller = PhoneListController(level, random: Random(seed));
        addTearDown(controller.dispose);
        expect(controller.items.toSet().length, controller.items.length);
        final targets = <int>[];
        for (var step = 0; step < 3; step++) {
          targets.add(controller.targetIndex);
          controller.select(controller.targetIndex);
        }
        expect(targets.toSet().length, 3);
        // Al menos una búsqueda queda fuera de las primeras filas visibles.
        expect(targets.any((i) => i >= 5), isTrue);
        expect(controller.state.foundItems, targets);
        seen.add(controller.items.join(','));
      }
      expect(seen.length, greaterThan(1));
    });
  }

  test('la partida siguiente no empieza con el mismo lugar', () {
    PhoneListController.resetHistory();
    for (var seed = 0; seed < 40; seed++) {
      final first = PhoneListController(GameLevel.facil, random: Random(seed));
      addTearDown(first.dispose);
      final firstName = first.target;
      final second = PhoneListController(
        GameLevel.facil,
        random: Random(seed),
      );
      addTearDown(second.dispose);
      expect(second.target, isNot(firstName));
    }
  });

  test('un error marca la fila y un acierto la limpia y la agrega a encontrados',
      () {
    final controller = PhoneListController(
      GameLevel.facil,
      random: Random(3),
    );
    addTearDown(controller.dispose);
    final wrong = List.generate(
      controller.items.length,
      (i) => i,
    ).firstWhere((i) => i != controller.targetIndex);
    controller.select(wrong);
    controller.select(wrong);
    expect(controller.state.wrongTick, 2);
    final target = controller.targetIndex;
    controller.select(target);
    expect(controller.state.wrongIndex, isNull);
    expect(controller.state.foundItems, [target]);
  });
}
