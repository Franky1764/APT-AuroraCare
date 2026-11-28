// domain/repositories/caregiver_invite_repository.dart
import '../entities/caregiver_invite.dart';
import '../entities/invite_status.dart';

/// Contrato de invitación para vincular un cuidador vía código QR (F8).
/// Iniciada exclusivamente por el adulto mayor; el cuidador nunca puede
/// solicitar acceso.
///
/// Ningún método recibe adultUuid ni uid: la implementación real
/// obtiene la identidad por su cuenta (Firebase Auth). El UUID cognitivo
/// nunca interviene aquí.
abstract class CaregiverInviteRepository {
  /// Crea una invitación nueva y descarta la anterior (si había una
  /// activa). El servidor fija el vencimiento, nunca el cliente.
  Future<CaregiverInvite> createInvite();

  /// La invitación activa del adulto mayor, si existe. Pensado para
  /// reabrir la app sin generar una invitación nueva innecesariamente
  /// mientras la anterior siga vigente.
  Future<CaregiverInvite?> getActiveInvite();

  /// Observa en tiempo real el estado de la invitación [token]: activa,
  /// usada (un cuidador la escaneó y se vinculó) o expirada.
  Stream<InviteStatus> watchInvite(String token);

  /// El adulto mayor cancela manualmente la invitación [token] antes de
  /// que expire.
  Future<void> cancelInvite(String token);

  /// Retira las invitaciones y el vínculo de cuentas de su titular.
  /// No borra perfiles ni sesiones ni comparte datos cognitivos.
  Future<void> cancelAllInvites();

  /// Canje atómico: registra el vínculo de cuentas, sin acceso a métricas.
  Future<void> redeemInvite(String token);

  /// Estado del vínculo de cuentas. No consulta perfiles cognitivos.
  Stream<bool> watchConnection();
}
