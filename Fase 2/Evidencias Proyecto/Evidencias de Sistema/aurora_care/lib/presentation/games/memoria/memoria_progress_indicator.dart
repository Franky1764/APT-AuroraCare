// lib/presentation/games/memoria/memoria_progress_indicator.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Un punto del indicador de progreso de un juego de Memoria. 100%
/// presentación — no depende solo del color: el punto logrado lleva
/// además un ícono de check. No es interactivo, así que no necesita el
/// mínimo táctil de 48dp que sí aplica a los botones.
class MemoriaProgressDot extends StatelessWidget {
  const MemoriaProgressDot({super.key, required this.lograda});

  final bool lograda;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lograda ? AppColors.success : AppColors.surface,
        border: Border.all(
          color: lograda ? AppColors.success : AppColors.border,
          width: 2,
        ),
      ),
      child: lograda
          ? Icon(Icons.check, size: 14, color: AppColors.textOnPrimary)
          : null,
    );
  }
}

/// Indicador de progreso compartido entre los juegos de Memoria: un texto
/// ("Pares encontrados: k de N" o "Rondas logradas: k de N", según el
/// llamador) más una fila de N puntos, uno por cada acierto posible. Solo
/// avanza con aciertos — el llamador decide qué cuenta como "logrado" y
/// nunca lo hace retroceder.
///
/// Vive en games/memoria/ (no en games/shared/) porque solo lo usan los
/// juegos de este dominio; cada uno le pasa su propio texto.
class MemoriaProgressIndicator extends StatelessWidget {
  const MemoriaProgressIndicator({
    super.key,
    required this.logrados,
    required this.total,
    required this.etiquetaVisible,
    required this.etiquetaAnuncio,
  });

  final int logrados;
  final int total;

  /// Texto visible, ej. "Pares encontrados: 3 de 6".
  final String etiquetaVisible;

  /// Lo que anuncia el lector de pantalla al avanzar, ej.
  /// "Par encontrado, 3 de 6" — solo cambia (y por lo tanto solo se
  /// anuncia) cuando `logrados` cambia.
  final String etiquetaAnuncio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: etiquetaAnuncio,
      child: ExcludeSemantics(
        child: Column(
          children: [
            // FittedBox: una línea siempre, nunca 2-3 (algunos textos de
            // llamador son largos, ej. "Diferencias encontradas: 0 de 3")
            // — se achica en vez de envolver, para que el alto del
            // indicador sea predecible y los juegos puedan calcular su
            // layout con un presupuesto de espacio fijo.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                etiquetaVisible,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < total; i++)
                  MemoriaProgressDot(lograda: i < logrados),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
