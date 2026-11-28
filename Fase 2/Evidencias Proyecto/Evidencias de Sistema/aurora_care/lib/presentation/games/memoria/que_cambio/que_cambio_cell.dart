// lib/presentation/games/memoria/que_cambio/que_cambio_cell.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

enum QueCambioCellEstado { normal, encontrada, incorrecta }

/// Una celda de alguna de las dos grillas (arriba/abajo). 100%
/// presentación: todo su estado llega desde fuera.
class QueCambioCell extends StatelessWidget {
  const QueCambioCell({
    super.key,
    required this.esArriba,
    required this.fila,
    required this.columna,
    required this.face,
    required this.estado,
    required this.onTap,
  });

  final bool esArriba;

  /// 1-based, solo para la etiqueta de accesibilidad.
  final int fila;
  final int columna;

  final MemoriceFace face;
  final QueCambioCellEstado estado;
  final VoidCallback? onTap;

  String get _semanticLabel {
    final grilla = esArriba ? 'Imagen de arriba' : 'Imagen de abajo';
    final base = '$grilla, fila $fila, columna $columna: ${face.name}';
    switch (estado) {
      case QueCambioCellEstado.encontrada:
        return '$base, diferencia encontrada';
      case QueCambioCellEstado.incorrecta:
        return '$base, no es una diferencia';
      case QueCambioCellEstado.normal:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);

    final Color borderColor;
    final Color backgroundColor;
    final double borderWidth;
    switch (estado) {
      case QueCambioCellEstado.encontrada:
        borderColor = AppColors.success;
        backgroundColor = AppColors.successBackground;
        borderWidth = 3;
      case QueCambioCellEstado.incorrecta:
        borderColor = AppColors.border;
        backgroundColor = AppColors.background;
        borderWidth = 1;
      case QueCambioCellEstado.normal:
        borderColor = AppColors.border;
        backgroundColor = AppColors.surface;
        borderWidth = 1;
    }

    return Semantics(
      label: _semanticLabel,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: radius,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    face.icon,
                    color: estado == QueCambioCellEstado.incorrecta
                        ? AppColors.textSecondary
                        : face.color,
                    size: 26,
                  ),
                  if (estado == QueCambioCellEstado.encontrada)
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                    ),
                  if (estado == QueCambioCellEstado.incorrecta)
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
