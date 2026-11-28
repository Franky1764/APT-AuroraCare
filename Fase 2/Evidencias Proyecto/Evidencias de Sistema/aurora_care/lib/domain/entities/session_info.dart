import 'account_role.dart';

// domain/entities/session_info.dart

/// Resultado de leer la sesión guardada por Firebase Auth al reabrir la
/// app. Los campos que no son uid/email pueden venir nulos si el
/// documento de Firestore no existe o no se pudo leer a tiempo.
///
/// `disclaimerAccepted`: true/false si se pudo leer el documento
/// (disclaimerAcceptedAt presente o ausente); null = se desconoce
/// (offline o timeout). Un valor desconocido NUNCA debe mandar al usuario
/// de vuelta al onboarding.
class SessionInfo {
  final AccountRole role;
  final String uid;
  final String email;
  final String? displayName;
  final bool? consentGiven;
  final int? currentMode;
  final bool? disclaimerAccepted;

  const SessionInfo({
    this.role = AccountRole.elder,
    required this.uid,
    required this.email,
    this.displayName,
    this.consentGiven,
    this.currentMode,
    this.disclaimerAccepted,
  });
}
