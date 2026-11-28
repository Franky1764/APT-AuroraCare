import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/usecases/create_caregiver_invite.dart';
import 'package:aurora_care/domain/usecases/usecase.dart';

import '../../helpers/fake_caregiver_invite_repository.dart';

void main() {
  test('call() delega en repository.createInvite()', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = CreateCaregiverInvite(repo);

    final invite = await usecase.call(const NoParams());

    expect(invite.token, 'fake-token-1');
    expect(repo.createCallCount, 1);
    expect(repo.activeInvite, same(invite));
  });

  test('cada llamada crea una invitación nueva', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = CreateCaregiverInvite(repo);

    final primera = await usecase.call(const NoParams());
    final segunda = await usecase.call(const NoParams());

    expect(primera.token, isNot(segunda.token));
    expect(repo.createCallCount, 2);
  });
}
