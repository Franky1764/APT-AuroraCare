import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

Future<bool> showPhonePracticeHelp({
  required BuildContext context,
  required String title,
  required String description,
  required String supportLabel,
  Widget? illustration,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text(title, style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: AppTextStyles.body),
            if (illustration != null) ...[
              const SizedBox(height: 16),
              illustration,
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver a practicar'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(supportLabel),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> showPhonePracticeCompletion({
  required BuildContext context,
  required String description,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text('Práctica completada', style: AppTextStyles.heading),
        content: Text(description, style: AppTextStyles.body),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ver mi resumen'),
            ),
          ),
        ],
      ),
    ) ??
    false;
