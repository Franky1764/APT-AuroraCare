// lib/presentation/games/memoria/shared/memoria_help_dialog.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';

/// Diálogo de "cómo se juega" para los juegos de Memoria, con el mismo
/// aspecto que usa la Dani en los ejercicios de uso del teléfono:
/// esquinas redondeadas de 24, barrera atenuada, título con insignia
/// redondeada opcional junto al ícono, una ilustración opcional y un
/// solo botón ancho para volver. Pensado como plantilla para copiarse
/// en los otros juegos de Memoria sin cambios.
///
/// No reutiliza showPhonePracticeHelp (games/shared/phone_practice_
/// dialogs.dart): ese diálogo fija el texto del botón principal
/// ("Volver a practicar") y siempre agrega un botón secundario de
/// apoyo, sin forma de quitarlos ni cambiar el texto. Acá se necesita
/// un solo botón ("Volver al juego"), así que este diálogo es propio,
/// con el mismo aspecto visual pero sin ese segundo botón.
Future<void> showMemoriaHelpDialog({
  required BuildContext context,
  required String title,
  required List<String> puntos,
  IconData? badgeIcon,
  Widget? illustration,
  GameRun? run,
}) async {
  run?.pauseClock?.call();
  try {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (badgeIcon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          badgeIcon,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(title, style: AppTextStyles.heading)),
                  ],
                ),
                const SizedBox(height: 12),
                // Un Text por punto, con espacio entre ellos: un párrafo
                // corrido con varias frases se lee muy junto (misma
                // lección que el aviso de consentimiento del QR).
                for (var i = 0; i < puntos.length; i++) ...[
                  Text(puntos[i], style: AppTextStyles.body),
                  if (i < puntos.length - 1) const SizedBox(height: 8),
                ],
                if (illustration != null) ...[
                  const SizedBox(height: 16),
                  illustration,
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Volver al juego',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    run?.resumeClock?.call();
  }
}
