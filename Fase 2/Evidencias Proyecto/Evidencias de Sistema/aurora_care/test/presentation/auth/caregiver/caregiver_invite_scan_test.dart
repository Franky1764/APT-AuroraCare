import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/domain/entities/caregiver_invite.dart';
import 'package:aurora_care/domain/repositories/caregiver_invite_repository.provider.dart';
import 'package:aurora_care/presentation/auth/caregiver/caregiver_invite_scan_controller.dart';

import '../../../helpers/fake_caregiver_invite_repository.dart';

class Invitations extends FakeCaregiverInviteRepository {
  final result = Completer<void>();
  int redemptions = 0;
  String? token;
  @override
  Future<void> redeemInvite(String token) {
    redemptions++;
    this.token = token;
    return result.future;
  }
}

void main() {
  final token = List.filled(43, 'A').join();
  String payload() =>
      CaregiverInvite(token: token, expiresAt: DateTime(2026)).qrPayload;
  late Invitations repository;
  late ProviderContainer container;
  setUp(() {
    repository = Invitations();
    container = ProviderContainer(
      overrides: [
        caregiverInviteRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.listen(caregiverInviteScanProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  test('adult generator payload is consumed by the caregiver reader without alteration', () async {
    final pending = container
        .read(caregiverInviteScanProvider.notifier)
        .scan(payload());
    expect(repository.token, token);
    expect(container.read(caregiverInviteScanProvider).isLoading, true);
    repository.result.complete();
    await pending;
    expect(container.read(caregiverInviteScanProvider).valueOrNull, true);
  });
  test('duplicate camera detections do not consume twice', () async {
    final controller = container.read(caregiverInviteScanProvider.notifier);
    final first = controller.scan(payload());
    await controller.scan(payload());
    expect(repository.redemptions, 1);
    repository.result.complete();
    await first;
    await controller.scan(payload());
    expect(repository.redemptions, 1);
  });
  test('foreign and malformed QR codes never reach Firestore', () async {
    for (final raw in [
      'https://example.test',
      token,
      '${payload()}?uuid=private',
      '${payload()}\n',
    ]) {
      await container.read(caregiverInviteScanProvider.notifier).scan(raw);
      expect(container.read(caregiverInviteScanProvider).hasError, true);
    }
    expect(repository.redemptions, 0);
  });
  test(
    'rejected redemption does not announce success and allows explicit retry',
    () async {
      final pending = container
          .read(caregiverInviteScanProvider.notifier)
          .scan(payload());
      repository.result.completeError(StateError('expired'));
      await pending;
      expect(container.read(caregiverInviteScanProvider).hasError, true);
      expect(
        container.read(caregiverInviteScanProvider).valueOrNull,
        isNot(true),
      );
      container.read(caregiverInviteScanProvider.notifier).retry();
      expect(container.read(caregiverInviteScanProvider).hasError, false);
    },
  );
}
