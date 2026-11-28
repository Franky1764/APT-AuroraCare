// domain/repositories/cognitive_profile_repository.dart
import '../entities/cognitive_profile.dart';

abstract class CognitiveProfileRepository {
  /// Retorna solo el perfil de la cuenta autenticada en este dispositivo.
  /// Sin sesión o sin referencia propia retorna null; nunca adopta el historial legado.
  Future<CognitiveProfile?> getLocalProfile();

  /// Genera un UUID y un deviceId nuevos, los persiste localmente
  /// (SharedPreferences) y crea el documento en Firestore.
  Future<CognitiveProfile> createProfile({required int activeMode});

  /// Actualiza el modo activo de un perfil ya existente (Firestore).
  Future<void> updateActiveMode({
    required String uuid,
    required int activeMode,
  });
}
