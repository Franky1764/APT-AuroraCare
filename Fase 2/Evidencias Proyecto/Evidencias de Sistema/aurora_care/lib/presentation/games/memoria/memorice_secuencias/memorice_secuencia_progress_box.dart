// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencia_progress_box.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../memoria_faces.dart';

enum MemoriceSecuenciaProgressBoxEstado { vacio, correcto, incorrecto }

/// Un casillero de la fila de progreso: muestra, en orden, lo que la
/// persona ya tocó en esta ronda (no la casilla del tablero que tocó,
/// sino su posición dentro de la secuencia). 100% presentación.
class MemoriceSecuenciaProgressBox extends StatelessWidget {
  const MemoriceSecuenciaProgressBox({
    super.key,
    required this.orden,
    required this.face,
    required this.estado,
  });

  /// Posición en la secuencia (1-based): número de orden y etiqueta.
  final int orden;

  /// La imagen a mostrar: la correcta si ya se acertó, o la tocada por
  /// error si este es el casillero donde la ronda terminó mal. null si
  /// todavía está vacío.
  final MemoriceFace? face;

  final MemoriceSecuenciaProgressBoxEstado estado;

  String get _semanticLabel {
    switch (estado) {
      case MemoriceSecuenciaProgressBoxEstado.vacio:
        return 'Casillero $orden, vacío';
      case MemoriceSecuenciaProgressBoxEstado.correcto:
        return 'Casillero $orden, ${face!.name}';
      case MemoriceSecuenciaProgressBoxEstado.incorrecto:
        return 'Casillero $orden, no coincide, tocó ${face!.name}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    final Color borderColor;
    final Color backgroundColor;
    final double borderWidth;
    switch (estado) {
      case MemoriceSecuenciaProgressBoxEstado.vacio:
        borderColor = AppColors.border;
        backgroundColor = AppColors.surface;
        borderWidth = 1;
      case MemoriceSecuenciaProgressBoxEstado.correcto:
        borderColor = AppColors.primary;
        backgroundColor = AppColors.primaryLight;
        borderWidth = 2;
      case MemoriceSecuenciaProgressBoxEstado.incorrecto:
        // Tono suave (no AppColors.error): la diferencia se marca con el
        // ícono de abajo, no solo con el color.
        borderColor = AppColors.warning;
        backgroundColor = AppColors.warningBackground;
        borderWidth = 2;
    }

    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Container(
            key: ValueKey('${estado.name}_${face?.name}'),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (estado) {
      case MemoriceSecuenciaProgressBoxEstado.vacio:
        return Center(
          child: FittedBox(
            child: Text('$orden', style: AppTextStyles.body),
          ),
        );
      case MemoriceSecuenciaProgressBoxEstado.correcto:
        return Center(child: Icon(face!.icon, color: face!.color, size: 20));
      case MemoriceSecuenciaProgressBoxEstado.incorrecto:
        return Stack(
          children: [
            Center(child: Icon(face!.icon, color: face!.color, size: 20)),
            Positioned(
              top: 1,
              right: 1,
              child: Icon(
                Icons.priority_high,
                color: AppColors.warning,
                size: 12,
              ),
            ),
          ],
        );
    }
  }
}
