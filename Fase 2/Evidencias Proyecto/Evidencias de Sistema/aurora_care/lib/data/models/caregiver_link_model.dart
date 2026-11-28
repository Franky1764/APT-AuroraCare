// data/models/caregiver_link_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/caregiver_link.dart';

class CaregiverLinkModel {
  final String linkId;
  final String adultUid;
  final String caregiverUid;
  final int epoch;
  final Timestamp linkedAt;
  final String
  status; // se guarda como texto en Firestore: 'active' o 'revoked'

  const CaregiverLinkModel({
    required this.linkId,
    required this.adultUid,
    required this.caregiverUid,
    required this.epoch,
    required this.linkedAt,
    required this.status,
  });

  factory CaregiverLinkModel.fromMap(String linkId, Map<String, dynamic> map) {
    return CaregiverLinkModel(
      linkId: linkId,
      adultUid: map['adultUID'] as String,
      caregiverUid: map['caregiverUID'] as String,
      epoch: map['epoch'] as int,
      linkedAt: map['linkedAt'] as Timestamp,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adultUID': adultUid,
      'caregiverUID': caregiverUid,
      'epoch': epoch,
      'linkedAt': linkedAt,
      'status': status,
    };
  }

  CaregiverLink toEntity() {
    return CaregiverLink(
      linkId: linkId,
      adultUid: adultUid,
      caregiverUid: caregiverUid,
      epoch: epoch,
      linkedAt: linkedAt.toDate(),
      status: status == 'active' ? LinkStatus.active : LinkStatus.revoked,
    );
  }

  factory CaregiverLinkModel.fromEntity(CaregiverLink entity) {
    return CaregiverLinkModel(
      linkId: entity.linkId,
      adultUid: entity.adultUid,
      caregiverUid: entity.caregiverUid,
      epoch: entity.epoch,
      linkedAt: Timestamp.fromDate(entity.linkedAt),
      status: entity.status == LinkStatus.active ? 'active' : 'revoked',
    );
  }
}
