// domain/entities/invite_status.dart

/// Estado de una invitación de vínculo con cuidador (F8).
enum InviteStatus {
  /// Vigente: el servidor todavía no reporta que expiró ni que se usó.
  active,

  /// Un cuidador la escaneó y se completó el vínculo.
  redeemed,

  /// Pasó expiresAt sin que nadie la usara.
  expired,
}
