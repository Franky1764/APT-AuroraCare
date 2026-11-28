import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/caregiver_invite.dart';
import 'package:aurora_care/domain/usecases/get_active_caregiver_invite.dart';
import 'package:aurora_care/domain/usecases/usecase.dart';

import '../../helpers/fake_caregiver_invite_repository.dart';

void main() {
  test('devuelve null si no hay invitación activa', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = GetActiveCaregiverInvite(repo);

    final resultado = await usecase.call(const NoParams());

    expect(resultado, isNull);
  });

  test(
    'devuelve la invitación activa existente, sin crear una nueva',
    () async {
      final repo = FakeCaregiverInviteRepository();
      repo.activeInvite = CaregiverInvite(
        token: 'ya-existente',
        expiresAt: DateTime(2026, 1, 1, 12, 10),
      );
      final usecase = GetActiveCaregiverInvite(repo);

      final resultado = await usecase.call(const NoParams());

      expect(resultado?.token, 'ya-existente');
      expect(repo.createCallCount, 0);
    },
  );
}
