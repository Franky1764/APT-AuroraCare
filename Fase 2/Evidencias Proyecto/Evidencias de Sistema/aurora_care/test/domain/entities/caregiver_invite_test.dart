import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/caregiver_invite.dart';
import 'package:aurora_care/domain/entities/invite_status.dart';

void main() {
  test('CaregiverInvite guarda token y expiresAt tal cual se construye', () {
    const token = 'abc123';
    final expiresAt = DateTime(2026, 1, 1, 12, 10);

    final invite = CaregiverInvite(token: token, expiresAt: expiresAt);

    expect(invite.token, token);
    expect(invite.expiresAt, expiresAt);
  });

  test('InviteStatus tiene exactamente active, redeemed y expired', () {
    expect(InviteStatus.values, [
      InviteStatus.active,
      InviteStatus.redeemed,
      InviteStatus.expired,
    ]);
  });
}
