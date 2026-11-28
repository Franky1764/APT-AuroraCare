import 'dart:math' as math;

enum SwipeDirection { left, right }

enum SwipeOutcome { ready, achieved, short, wrongDirection, vertical, tap }

/// Un gesto lento puede completar el recorrido: no se exige velocidad.
/// El recorrido mínimo se adapta al ancho visible y admite desviaciones
/// verticales naturales. Es una regla de interacción, no un umbral clínico.
SwipeOutcome evaluatePhoneSwipe({
  required double dx,
  required double dy,
  required double pathLength,
  required double viewportWidth,
  required double requiredDistanceRatio,
  required SwipeDirection direction,
}) {
  if (pathLength < 8) return SwipeOutcome.tap;
  if (dy.abs() > math.max(40, dx.abs() * .8)) return SwipeOutcome.vertical;
  if (dx.abs() >= 8 && (direction == SwipeDirection.left ? dx > 0 : dx < 0)) {
    return SwipeOutcome.wrongDirection;
  }
  if (dx.abs() < viewportWidth * requiredDistanceRatio) {
    return SwipeOutcome.short;
  }
  return SwipeOutcome.achieved;
}
