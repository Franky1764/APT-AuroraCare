// domain/entities/caregiver_invite.dart

/// Invitación para vincular un cuidador vía código QR (F8). Entidad
/// pura: no sabe que existe Firebase ni Flutter.
class CaregiverInvite {
  /// Código que se codifica en el QR y que el cuidador escanea.
  final String token;

  /// Momento en que la invitación deja de ser válida. La implementación
  /// real (Firestore) lo calcula como createdAt (fijado por el
  /// servidor) + 10 minutos — el cliente NUNCA decide ni fija cuánto
  /// dura una invitación, solo recibe este valor ya calculado.
  final DateTime expiresAt;

  String get qrPayload => 'auroracare://caregiver-invite/v1/$token';

  static String? parseQr(String raw) {
    final match = RegExp(
      r'^auroracare://caregiver-invite/v1/([A-Za-z0-9_-]{43})$',
    ).firstMatch(raw);
    return match?.group(0) == raw ? match?.group(1) : null;
  }

  const CaregiverInvite({required this.token, required this.expiresAt});
}
