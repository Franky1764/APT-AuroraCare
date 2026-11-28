import 'dart:math' as math;

/// Se exige que el centro esté en el destino y la mayor parte de la imagen
/// quede dentro. El resaltado antes de soltar usa exactamente esta regla.
/// Es una condición de interacción; no mide una habilidad clínica.
bool evaluatePhoneDrop({
  required double itemCenterX,
  required double itemCenterY,
  required double itemSize,
  required double targetCenterX,
  required double targetCenterY,
  required double targetSize,
  double minimumOverlapRatio = .65,
}) {
  if (itemSize <= 0 || targetSize <= 0) return false;
  if ((itemCenterX - targetCenterX).abs() > targetSize / 2 ||
      (itemCenterY - targetCenterY).abs() > targetSize / 2) {
    return false;
  }
  final width = math.max(
    0.0,
    math.min(itemCenterX + itemSize / 2, targetCenterX + targetSize / 2) -
        math.max(itemCenterX - itemSize / 2, targetCenterX - targetSize / 2),
  );
  final height = math.max(
    0.0,
    math.min(itemCenterY + itemSize / 2, targetCenterY + targetSize / 2) -
        math.max(itemCenterY - itemSize / 2, targetCenterY - targetSize / 2),
  );
  return width * height / (itemSize * itemSize) >= minimumOverlapRatio;
}
