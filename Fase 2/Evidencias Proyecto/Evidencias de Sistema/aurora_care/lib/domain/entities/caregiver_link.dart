// domain/entities/caregiver_link.dart
enum LinkStatus { active, revoked }

class CaregiverLink {
  final String linkId;
  final String adultUid;
  final String caregiverUid;
  final int epoch;
  final DateTime linkedAt;
  final LinkStatus status;

  const CaregiverLink({
    required this.linkId,
    required this.adultUid,
    required this.caregiverUid,
    required this.epoch,
    required this.linkedAt,
    required this.status,
  });
}
