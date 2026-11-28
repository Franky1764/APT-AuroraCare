// lib/domain/entities/session_analysis.dart
import 'game_level.dart';

enum TrendSignal { insuficiente, mejora, estable, atencion, revisar }

/// Resultado del análisis de una sesión (SCORING.md §5.2).
class SessionAnalysis {
  final double scoreSesion;
  final GameLevel nivelJugado;
  final bool sugerirAvance;
  final int sesionesEnVentana;
  final TrendSignal senal;
  final double? variacionPct;
  final GameLevel? nivelSenal;
  final String? scoringVersion;

  const SessionAnalysis({
    required this.scoreSesion,
    required this.nivelJugado,
    required this.sugerirAvance,
    required this.sesionesEnVentana,
    required this.senal,
    this.variacionPct,
    this.nivelSenal,
    this.scoringVersion,
  });
}

/// Lo que devuelve FinishSession. [analysis] es null si la sesión
/// quedó guardada pero sin analizar (sin conexión o servicio caído).
class SessionResult {
  final SessionAnalysis? analysis;
  const SessionResult(this.analysis);
}
