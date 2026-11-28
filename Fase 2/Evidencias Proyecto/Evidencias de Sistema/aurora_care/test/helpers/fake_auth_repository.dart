import 'package:aurora_care/domain/entities/user.dart';
import 'package:aurora_care/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  User _fakeUser(String displayName) => User(
        uid: 'test-uid',
        displayName: displayName,
        createdAt: DateTime(2026, 1, 1),
        consentGiven: false,
        currentMode: 1,
      );

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) async =>
      _fakeUser(displayName);

  @override
  Future<User> loginElder({
    required String email,
    required String password,
  }) async =>
      _fakeUser(email.split('@').first);

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> acceptDisclaimer({required String uid}) async {}

  @override
  Future<bool> hasMetricsConsent({required String uid}) async => true;

  @override
  Future<void> setMetricsConsent({
    required String uid,
    required bool given,
  }) async {}

  @override
  Future<void> updateCurrentMode({
    required String uid,
    required int mode,
  }) async {}
}