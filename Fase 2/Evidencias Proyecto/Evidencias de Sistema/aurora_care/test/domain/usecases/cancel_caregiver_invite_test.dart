import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/caregiver_invite.dart';
import 'package:aurora_care/domain/usecases/cancel_caregiver_invite.dart';

import '../../helpers/fake_caregiver_invite_repository.dart';

void main() {
  test('call() delega en repository.cancelInvite() con el token pedido', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = CancelCaregiverInvite(repo);

    await usecase.call(const CancelCaregiverInviteParams(token: 'xyz'));

    expect(repo.lastCancelledToken, 'xyz');
  });

  test('si el token cancelado era la invitación activa, deja de serlo', () async {
    final repo = FakeCaregiverInviteRepository();
    repo.activeInvite = CaregiverInvite(
      token: 'activa',
      expiresAt: DateTime(2026, 1, 1, 12, 10),
    );
    final usecase = CancelCaregiverInvite(repo);

    await usecase.call(const CancelCaregiverInviteParams(token: 'activa'));

    expect(repo.activeInvite, isNull);
  });
}
