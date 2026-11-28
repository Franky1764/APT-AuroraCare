import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

Future<void> showDetailDialog({
  required BuildContext context,
  required String title,
  required Widget content,
}) => showDialog<void>(
  context: context,
  barrierColor: AppColors.primaryDark.withValues(alpha: .24),
  builder: (context) => AlertDialog(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    scrollable: true,
    title: Text(title, style: AppTextStyles.heading),
    content: content,
    actions: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            minimumSize: const Size(48, 56),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar detalle'),
        ),
      ),
    ],
  ),
);
