class PrivacyData {
  const PrivacyData({
    required this.name,
    required this.email,
    required this.consent,
    required this.json,
    required this.hasUnassignedHistory,
  });

  final String name;
  final String email;
  final bool consent;
  final String json;
  final bool hasUnassignedHistory;
}

enum PrivacyDeletion { history, account }
