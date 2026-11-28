enum CaregiverAuthFailure {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  network,
  tooManyRequests,
  wrongRole,
  incompleteRegistration,
  unknown,
}

class CaregiverAuthException implements Exception {
  const CaregiverAuthException(this.failure);
  final CaregiverAuthFailure failure;
}
