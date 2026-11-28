/// Rol de identidad para navegación; no contiene referencias cognitivas.
enum AccountRole { elder, caregiver, unknown }

AccountRole readAccountRole(Object? value) => switch (value) {
  null || 'elder' => AccountRole.elder,
  'caregiver' => AccountRole.caregiver,
  _ => AccountRole.unknown,
};
