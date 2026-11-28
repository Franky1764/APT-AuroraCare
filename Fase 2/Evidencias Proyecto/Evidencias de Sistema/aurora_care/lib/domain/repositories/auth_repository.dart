// domain/repositories/auth_repository.dart
import '../entities/user.dart';

abstract class AuthRepository {
  /// Crea la cuenta del adulto mayor y su perfil inicial. Lanza [AuthException] si falla.
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  });

  Future<User> loginElder({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> logout();

  /// Registra que la persona aceptó el aviso de que AuroraCare no es un
  /// dispositivo médico (F1 paso 4). No es el consentimiento de métricas.
  Future<void> acceptDisclaimer({required String uid});

  /// Registra o retira el consentimiento para guardar métricas de juego
  /// (F4 paso 0, Ley 21.719). Al retirarlo, consentDate queda en null.
  Future<void> setMetricsConsent({required String uid, required bool given});

  /// ¿La persona dio su consentimiento de métricas? (users/{uid}.consentGiven)
  Future<bool> hasMetricsConsent({required String uid});

  /// Guarda el modo elegido. Solo 2 (seguimiento personal) o 3 (con cuidador).
  Future<void> updateCurrentMode({required String uid, required int mode});
}