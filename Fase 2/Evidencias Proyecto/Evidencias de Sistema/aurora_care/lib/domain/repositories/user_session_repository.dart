// domain/repositories/user_session_repository.dart
import '../entities/session_info.dart';

/// Lee la sesión guardada por Firebase Auth al reabrir la app (Sprint 3 —
/// "mantener la sesión iniciada"). Distinto de SessionRepository
/// (domain/repositories/session_repository.dart), que es sobre sesiones
/// de juego/ejercicio, no de autenticación.
///
/// No escribe nada en Firestore. Solo puede hacer signOut() en Firebase
/// Auth si la cuenta ya no es válida (user-not-found/user-disabled).
abstract class UserSessionRepository {
  /// Devuelve null si no hay ningún usuario con sesión activa.
  Future<SessionInfo?> readSession();
}
