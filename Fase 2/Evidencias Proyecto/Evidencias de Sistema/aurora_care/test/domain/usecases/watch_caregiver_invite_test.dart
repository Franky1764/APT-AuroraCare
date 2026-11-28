import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/invite_status.dart';
import 'package:aurora_care/domain/usecases/watch_caregiver_invite.dart';

import '../../helpers/fake_caregiver_invite_repository.dart';

void main() {
  test('call() emite los estados que reporta el repositorio', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = WatchCaregiverInvite(repo);

    final emitidos = <InviteStatus>[];
    final sub = usecase
        .call(const WatchCaregiverInviteParams(token: 'abc'))
        .listen(emitidos.add);

    repo.emitStatus('abc', InviteStatus.active);
    repo.emitStatus('abc', InviteStatus.redeemed);
    await Future<void>.delayed(Duration.zero);

    expect(emitidos, [InviteStatus.active, InviteStatus.redeemed]);
    await sub.cancel();
  });

  test('solo escucha el token pedido, no otros', () async {
    final repo = FakeCaregiverInviteRepository();
    final usecase = WatchCaregiverInvite(repo);

    final emitidos = <InviteStatus>[];
    final sub = usecase
        .call(const WatchCaregiverInviteParams(token: 'mio'))
        .listen(emitidos.add);

    repo.emitStatus('otro-token', InviteStatus.expired);
    await Future<void>.delayed(Duration.zero);

    expect(emitidos, isEmpty);
    await sub.cancel();
  });
}
