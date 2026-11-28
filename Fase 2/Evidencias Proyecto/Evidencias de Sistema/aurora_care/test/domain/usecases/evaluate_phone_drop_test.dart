import 'package:aurora_care/domain/usecases/evaluate_phone_drop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool inside(double x, double y) => evaluatePhoneDrop(
    itemCenterX: x,
    itemCenterY: y,
    itemSize: 88,
    targetCenterX: 0,
    targetCenterY: 0,
    targetSize: 136,
  );
  test('the same overlap rule highlights and accepts an intentional drop', () {
    expect(inside(0, 0), isTrue);
    expect(inside(48, 0), isTrue);
    expect(inside(56, 0), isFalse);
    expect(inside(48, 48), isFalse);
    expect(inside(90, 0), isFalse);
  });
}
