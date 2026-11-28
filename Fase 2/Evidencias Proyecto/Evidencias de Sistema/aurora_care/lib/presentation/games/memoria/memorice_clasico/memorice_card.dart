// lib/presentation/games/memoria/memorice_clasico/memorice_card.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

/// Una carta del tablero. 100% presentación: todo su estado (boca
/// arriba/abajo, emparejada) llega desde fuera — no tiene lógica propia.
class MemoriceCard extends StatelessWidget {
  const MemoriceCard({
    super.key,
    required this.cardNumber,
    required this.face,
    required this.isFaceUp,
    required this.isMatched,
    required this.onTap,
  });

  /// Posición de la carta en el tablero (1-based), solo para la etiqueta
  /// de accesibilidad — no identifica el contenido.
  final int cardNumber;
  final MemoriceFace face;
  final bool isFaceUp;
  final bool isMatched;
  final VoidCallback? onTap;

  String get _semanticLabel {
    if (isMatched) return 'Carta $cardNumber, ${face.name}, par encontrado';
    if (isFaceUp) return 'Carta $cardNumber, ${face.name}';
    return 'Carta $cardNumber, boca abajo';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      label: _semanticLabel,
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _buildFace(radius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFace(BorderRadius radius) {
    if (!isFaceUp) {
      return Container(
        key: const ValueKey('face_down'),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
      );
    }
    return Container(
      key: ValueKey('face_up_${face.name}'),
      decoration: BoxDecoration(
        color: isMatched ? AppColors.successBackground : AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: isMatched ? AppColors.success : AppColors.border,
          width: isMatched ? 2 : 1,
        ),
      ),
      child: Center(
        child: Icon(face.icon, color: face.color, size: 32),
      ),
    );
  }
}
