import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/session_feedback.dart';
import '../../shared/detail_dialog.dart';

class SessionFeedbackCard extends StatelessWidget {
  const SessionFeedbackCard({
    super.key,
    required this.feedback,
    this.title = 'Esta partida',
    this.subtitle,
    this.compact = true,
  });
  final SessionFeedback feedback;
  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: compact
          ? () => showDetailDialog(
              context: context,
              title: title,
              content: SessionFeedbackCard(
                feedback: feedback,
                title: title,
                subtitle: subtitle,
                compact: false,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.cardTitle),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppTextStyles.bodySecondary),
            ],
            const SizedBox(height: 12),
            if (feedback.items.isEmpty)
              Text(
                'No hay medidas disponibles para resumir este ejercicio.',
                style: AppTextStyles.bodySecondary,
              ),
            for (final item
                in compact
                    ? feedback.items.entries.take(1)
                    : feedback.items.entries) ...[
              Text('${item.key}: ${item.value}', style: AppTextStyles.body),
              if (!compact && feedback.explanations[item.key] != null) ...[
                const SizedBox(height: 6),
                Text(
                  feedback.explanations[item.key]!,
                  style: AppTextStyles.bodySecondary,
                ),
              ],
              const SizedBox(height: 8),
            ],
            if (compact)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ver detalle',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                ],
              )
            else
              Text(
                'Estos datos describen este ejercicio. Una partida por sí sola no indica cambios en sus habilidades.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.bodySecondary,
              ),
          ],
        ),
      ),
    ),
  );
}
