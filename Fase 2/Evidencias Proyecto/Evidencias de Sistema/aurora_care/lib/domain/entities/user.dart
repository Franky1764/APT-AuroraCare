// domain/entities/user.dart
class User {
  final String uid;
  final String displayName;
  final DateTime createdAt;
  final bool consentGiven;
  final DateTime? consentDate; // null si nunca dio el consentimiento de métricas o lo retiró
  final int currentMode; // 1, 2 o 3

  const User({
    required this.uid,
    required this.displayName,
    required this.createdAt,
    required this.consentGiven,
    this.consentDate,
    required this.currentMode,
  });
}