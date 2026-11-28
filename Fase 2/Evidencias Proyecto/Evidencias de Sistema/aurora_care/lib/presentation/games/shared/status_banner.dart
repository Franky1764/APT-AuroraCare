// lib/presentation/games/shared/status_banner.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

/// Banner de retroalimentación por estado (acierto, error, neutro...).
/// Mismo look que ya usan toque_preciso_screen.dart y
/// buscar_en_lista_screen.dart: ícono coloreado + texto secundario en una
/// fila, con Semantics(liveRegion: true) para que el lector de pantalla
/// anuncie el cambio de estado sin releer cada segundo.
///
/// [color] lo elige quien llama (ej. AppColors.success, AppColors.error,
/// AppColors.primary) — debe mantener contraste 4.5:1 contra el fondo.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: AppTextStyles.bodySecondary),
            ),
          ],
        ),
      ),
    );
  }
}
