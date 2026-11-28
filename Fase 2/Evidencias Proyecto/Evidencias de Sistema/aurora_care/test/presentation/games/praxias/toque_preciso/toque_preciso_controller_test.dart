import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/toque_preciso/toque_preciso_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final level in GameLevel.values) {
    test('manual progression, pause and real counts at ${level.name}', () {
      final controller = PhoneTouchController(level);
      addTearDown(controller.dispose);
      expect(controller.finish(), isNull);
      controller.next();
      expect(controller.state.index, 0);
      controller.touchOutside();
      expect(controller.state.hits, 0);
      expect(controller.state.misses, 1);
      controller.pause();
      controller.touchTarget();
      controller.touchOutside();
      expect(controller.state.hits, 0);
      expect(controller.state.misses, 1);
      controller.resume();
      for (var index = 0; index < PhoneTouchState.targetCount; index++) {
        expect(controller.state.imageTarget, index.isOdd);
        controller.touchTarget();
        controller.touchTarget();
        controller.touchOutside();
        expect(controller.state.hits, index + 1);
        expect(controller.state.index, index);
        if (index < PhoneTouchState.targetCount - 1) {
          controller.next();
          expect(controller.state.missesOnStep, 0);
        }
      }
      final metrics = controller.finish()!;
      expect(metrics.completedTargets, 6);
      expect(metrics.totalTargets, 6);
      expect(metrics.touchesOnTarget, 6);
      expect(metrics.touchesOutsideTarget, 1);
      expect(metrics.buttonHeightDp, greaterThanOrEqualTo(64));
      expect(metrics.imageSizeDp, greaterThanOrEqualTo(112));
      expect(controller.finish(), isNull);
    });
  }
}
