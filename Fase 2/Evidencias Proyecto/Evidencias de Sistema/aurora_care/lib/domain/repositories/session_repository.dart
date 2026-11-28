// domain/repositories/session_repository.dart
import '../entities/session.dart';

abstract class SessionRepository {
  /// Guarda una sesión de juego recién terminada.
  Future<void> saveSession(Session session);

  /// Guarda el score de una sesión que se había guardado sin analizar.
  Future<void> updateSessionScore(
    String uuid,
    String sessionId,
    double score, {
    required String scoringVersion,
  });

  /// Trae las últimas [limit] sesiones de un usuario, para calcular tendencia.
  Future<List<Session>> getRecentSessions(String uuid, {int limit = 5});

  /// Trae las sesiones de los últimos [days] días, opcionalmente de un solo dominio,
  /// para la ventana de 28 días que usa el scoring.
  Future<List<Session>> getSessionsInWindow(
    String uuid, {
    String? domain,
    int days = 28,
  });
}
