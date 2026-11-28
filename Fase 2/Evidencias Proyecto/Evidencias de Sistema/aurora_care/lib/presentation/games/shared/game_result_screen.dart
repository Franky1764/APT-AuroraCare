// lib/presentation/games/shared/game_result_screen.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game_level.dart';
import '../../../domain/entities/session_analysis.dart';
import '../../../domain/entities/cognitive_metrics.dart';
import '../../../domain/entities/session_feedback.dart';
import 'session_feedback_card.dart';

/// Resultado de una partida. Siempre positivo: no muestra el score.
class GameResultScreen extends StatelessWidget {
  const GameResultScreen({
    super.key,
    required this.title,
    required this.nivel,
    this.analysis,
    this.metrics,
    this.gameType,
    this.recorded = false,
  });

  final String title;
  final GameLevel nivel;
  final CognitiveMetrics? metrics;
  final String? gameType;
  final bool recorded;

  /// null si la sesión quedó sin analizar.
  final SessionAnalysis? analysis;

  void _goHome(BuildContext context) {
    // La selección de práctica agrega pantallas intermedias. Volver al inicio
    // no depende de una cantidad fija de rutas abiertas.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final suggestAdvance =
        (analysis?.sugerirAvance ?? false) && nivel != GameLevel.avanzado;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.check_circle,
                size: 96,
                color: AppColors.success,
              ),
              const SizedBox(height: 24),
              Text(
                '¡Muy bien!',
                textAlign: TextAlign.center,
                style: AppTextStyles.greeting,
              ),
              const SizedBox(height: 12),
              Text(
                'Completó su ejercicio de $title.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 12),
              if (metrics != null) ...[
                SessionFeedbackCard(
                  feedback: SessionFeedback.fromMetrics(
                    metrics!,
                    gameType: gameType,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                analysis == null
                    ? gameType == 'trazado_guiado' ||
                              metrics is PhonePracticeMetrics
                          ? 'Este ejercicio aún no tiene una puntuación calibrada. El resumen muestra lo que realizó en esta partida.'
                          : 'La puntuación de esta partida aún no está disponible. Puede consultar los datos del ejercicio.'
                    : 'El resultado de esta partida ya fue analizado. La tendencia se calcula por separado con varias sesiones comparables.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 12),
              Text(
                recorded
                    ? 'Puede consultar sus partidas disponibles en Mi progreso. El historial se actualizará al sincronizarse.'
                    : 'Este resumen está disponible aquí. No pudimos confirmar el registro de la partida en su seguimiento.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              if (suggestAdvance) ...[
                const SizedBox(height: 12),
                Text(
                  'Cuando quiera, puede probar el nivel siguiente.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Jugar de nuevo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _goHome(context),
                child: const Text('Volver al inicio'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
