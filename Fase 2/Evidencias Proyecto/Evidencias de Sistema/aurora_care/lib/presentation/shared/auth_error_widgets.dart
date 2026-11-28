// lib/presentation/shared/auth_error_widgets.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Mensaje de error bajo un campo de formulario — ícono + texto, para no
/// depender solo del color del borde.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppTextStyles.fieldError)),
        ],
      ),
    );
  }
}

/// Error general (sin conexión, demasiados intentos, etc.) que va sobre el
/// botón principal del formulario.
class GeneralErrorBanner extends StatelessWidget {
  const GeneralErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
