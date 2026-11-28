// lib/presentation/auth/shared/password_requirements_list.dart

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'password_policy.dart';

/// Lista de requisitos de la contraseña, con ícono y texto — ✓ cumplido,
/// ○ pendiente — para que ningún requisito dependa solo del color.
/// Widget puramente presentacional, reutilizable en cualquier pantalla
/// que use [PasswordPolicy].
class PasswordRequirementsList extends StatelessWidget {
  const PasswordRequirementsList({super.key, required this.requirements});

  final List<PasswordRequirement> requirements;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final requisito in requirements)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                label:
                    '${requisito.label}: '
                    '${requisito.met ? "cumplido" : "pendiente"}',
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        requisito.met
                            ? Icons.check_circle_outline_rounded
                            : Icons.circle_outlined,
                        size: 20,
                        color: requisito.met
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          requisito.label,
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: requisito.met
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
