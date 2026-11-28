import 'dart:async';

import 'package:aurora_care/domain/entities/caregiver_invite.dart';
import 'package:aurora_care/domain/entities/invite_status.dart';
import 'package:aurora_care/domain/repositories/caregiver_invite_repository.dart';

/// Fake manual de CaregiverInviteRepository para tests, sin paquete de
/// mocking (mismo patrón que FakeAuthRepository).
class FakeCaregiverInviteRepository implements CaregiverInviteRepository {
  @override
  Future<void> redeemInvite(String token) async {
    emitStatus(token, InviteStatus.redeemed);
  }

  @override
  Stream<bool> watchConnection() => Stream.value(false);

  @override
  Future<void> cancelAllInvites() async {
    final invite = await getActiveInvite();
    if (invite != null) await cancelInvite(invite.token);
  }

  CaregiverInvite? activeInvite;
  int createCallCount = 0;
  String? lastCancelledToken;

  final _controllers = <String, StreamController<InviteStatus>>{};

  @override
  Future<CaregiverInvite> createInvite() async {
    createCallCount++;
    final invite = CaregiverInvite(
      token: 'fake-token-$createCallCount',
      expiresAt: DateTime(2026, 1, 1, 12, 10),
    );
    activeInvite = invite;
    return invite;
  }

  @override
  Future<CaregiverInvite?> getActiveInvite() async => activeInvite;

  @override
  Stream<InviteStatus> watchInvite(String token) {
    final controller = _controllers.putIfAbsent(
      token,
      () => StreamController<InviteStatus>.broadcast(),
    );
    return controller.stream;
  }

  /// Simula que el servidor reporta un cambio de estado para [token].
  void emitStatus(String token, InviteStatus status) {
    _controllers[token]?.add(status);
  }

  @override
  Future<void> cancelInvite(String token) async {
    lastCancelledToken = token;
    if (activeInvite?.token == token) activeInvite = null;
  }
}
