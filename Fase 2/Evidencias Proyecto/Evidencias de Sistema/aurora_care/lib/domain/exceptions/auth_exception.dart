// domain/exceptions/auth_exception.dart

enum AuthErrorType {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  userNotFound,
  wrongPassword,
  networkError,
  tooManyRequests,
  userDisabled,
  wrongRole,
  unknown,
}

class AuthException implements Exception {
  final AuthErrorType type;

  const AuthException(this.type);
}
