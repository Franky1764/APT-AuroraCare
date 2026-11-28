// domain/entities/session.dart
import 'cognitive_metrics.dart';
import 'game_level.dart';

class Session {
  final String sessionId;
  final String uuid;
  final String
  domain; // 'memoria', 'atencion' o 'praxias' (en la UI: Motricidad)
  final String
  gameType; // ej: 'memorice_clasico' (los 9 valores están en SCORING §2.1)
  final GameLevel nivel;
  final DateTime startTime;
  final DateTime endTime;
  final CognitiveMetrics metrics;
  final double? scoreSesion; // null = aún sin analizar (sin conexión)
  final String? scoringVersion;

  const Session({
    required this.sessionId,
    required this.uuid,
    required this.domain,
    required this.gameType,
    required this.nivel,
    required this.startTime,
    required this.endTime,
    required this.metrics,
    this.scoreSesion,
    this.scoringVersion,
  });

  Session withScore(double score) => Session(
    sessionId: sessionId,
    uuid: uuid,
    domain: domain,
    gameType: gameType,
    nivel: nivel,
    startTime: startTime,
    endTime: endTime,
    metrics: metrics,
    scoreSesion: score,
    scoringVersion: scoringVersion,
  );
}
