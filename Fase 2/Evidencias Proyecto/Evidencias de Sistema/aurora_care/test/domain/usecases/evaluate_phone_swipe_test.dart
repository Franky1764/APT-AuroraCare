import 'package:aurora_care/domain/usecases/evaluate_phone_swipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SwipeOutcome evaluate(
    double dx,
    double dy, {
    double? path,
    SwipeDirection direction = SwipeDirection.left,
  }) => evaluatePhoneSwipe(
    dx: dx,
    dy: dy,
    pathLength: path ?? dx.abs() + dy.abs(),
    viewportWidth: 300,
    requiredDistanceRatio: .25,
    direction: direction,
  );
  test(
    'distance and direction determine the gesture without a speed requirement',
    () {
      expect(evaluate(-75, 10), SwipeOutcome.achieved);
      expect(
        evaluate(75, 10, direction: SwipeDirection.right),
        SwipeOutcome.achieved,
      );
      expect(evaluate(-74, 0), SwipeOutcome.short);
      expect(evaluate(75, 0), SwipeOutcome.wrongDirection);
      expect(evaluate(-20, 100), SwipeOutcome.vertical);
      expect(evaluate(0, 0), SwipeOutcome.tap);
      expect(evaluate(-10, 0, path: 200), SwipeOutcome.short);
    },
  );
}
