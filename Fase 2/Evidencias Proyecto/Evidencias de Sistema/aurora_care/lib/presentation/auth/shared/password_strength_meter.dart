// lib/presentation/auth/shared/password_strength_meter.dart

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'password_policy.dart';

/// Medidor visual de seguridad de la contraseña: 4 barras de color más
/// una etiqueta de texto, para que el nivel nunca dependa solo del
/// color. Widget puramente presentacional — recibe la evaluación ya
/// calculada (ver password_policy.dart), sin acoplarse a ninguna
/// pantalla ni formulario en particular.
///
/// Los 4 colores son los únicos tokens semánticos con nombre que ya
/// define el tema (AppColors.error/warning/success), más primary para
/// "Muy fuerte" — ninguno es un color nuevo.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.strength});

  final PasswordStrength strength;

  static const int _niveles = 4;

  int get _barrasActivas => switch (strength) {
    PasswordStrength.empty => 0,
    PasswordStrength.weak => 1,
    PasswordStrength.medium => 2,
    PasswordStrength.strong => 3,
    PasswordStrength.veryStrong => 4,
  };

  Color get _color => switch (strength) {
    PasswordStrength.empty => AppColors.border,
    PasswordStrength.weak => AppColors.error,
    PasswordStrength.medium => AppColors.warning,
    PasswordStrength.strong => AppColors.success,
    PasswordStrength.veryStrong => AppColors.primary,
  };

  String get _etiqueta => switch (strength) {
    PasswordStrength.empty => '',
    PasswordStrength.weak => 'Débil',
    PasswordStrength.medium => 'Media',
    PasswordStrength.strong => 'Fuerte',
    PasswordStrength.veryStrong => 'Muy fuerte',
  };

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();
    final activas = _barrasActivas;
    final color = _color;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < _niveles; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < activas ? color : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            label: 'Seguridad de la contraseña: $_etiqueta',
            child: ExcludeSemantics(
              child: Text(
                'Seguridad: $_etiqueta',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
