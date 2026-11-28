import 'package:aurora_care/core/auth_account_provider.dart';
import 'package:aurora_care/presentation/profile/caregiver_link_notifier.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/repositories/cognitive_profile_repository.dart';
import 'package:aurora_care/data/repositories/cognitive_profile_repository_impl.provider.dart';
import 'package:aurora_care/data/repositories/fake_caregiver_invite_repository.dart';
import 'package:aurora_care/domain/repositories/caregiver_invite_repository.provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/presentation/shared/change_usage_mode_provider.dart';
import 'package:aurora_care/presentation/shared/current_mode_provider.dart';
import 'package:aurora_care/presentation/shared/usage_mode_exceptions.dart';

import '../helpers/fake_auth_repository.dart';

class _Repository extends FakeAuthRepository {
  final saved = Completer<void>();
  int calls = 0;
  String? uid;
  int? mode;

  @override
  Future<void> updateCurrentMode({required String uid, required int mode}) {
    calls++;
    this.uid = uid;
    this.mode = mode;
    return saved.future;
  }
}

class _Profiles implements CognitiveProfileRepository {
  CognitiveProfile? profile = CognitiveProfile(
    uuid: 'existing-profile',
    deviceId: 'device',
    createdAt: DateTime(2026),
    activeMode: 2,
  );
  bool failRead = false;
  int creations = 0;
  int updates = 0;
  @override
  Future<CognitiveProfile?> getLocalProfile() async {
    if (failRead) throw StateError('profile unavailable');
    return profile;
  }

  @override
  Future<CognitiveProfile> createProfile({required int activeMode}) async {
    creations++;
    return profile = CognitiveProfile(
      uuid: 'new-profile',
      deviceId: 'device',
      createdAt: DateTime(2026),
      activeMode: activeMode,
    );
  }

  @override
  Future<void> updateActiveMode({
    required String uuid,
    required int activeMode,
  }) async {
    updates++;
    final previous = profile!;
    profile = CognitiveProfile(
      uuid: uuid,
      deviceId: previous.deviceId,
      createdAt: previous.createdAt,
      activeMode: activeMode,
    );
  }
}

class _FailingInvitations extends FakeCaregiverInviteRepository {
  _FailingInvitations(super.prefs);
  @override
  Future<void> cancelAllInvites() async => throw StateError('cancel failed');
}

void main() {
  late _Repository repository;
  late _Profiles profiles;
  late ProviderContainer container;
  late FakeCaregiverInviteRepository invitations;

  void restore(String uid, int mode) {
    container
        .read(navigationSessionProvider.notifier)
        .restore(
          SessionInfo(uid: uid, email: '$uid@example.com', currentMode: mode),
        );
    container.read(currentModeProvider.notifier).state = mode;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    invitations = FakeCaregiverInviteRepository(
      await SharedPreferences.getInstance(),
    );
    repository = _Repository();
    profiles = _Profiles();
    container = ProviderContainer(
      overrides: [
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        authRepositoryProvider.overrideWithValue(repository),
        caregiverInviteRepositoryProvider.overrideWithValue(invitations),
        cognitiveProfileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    restore('adult', 2);
  });
  tearDown(() {
    container.dispose();
    invitations.dispose();
  });

  test('actualiza la sesión solo después de confirmar el guardado', () async {
    final pending = container.read(changeUsageModeProvider)(3);
    expect(container.read(currentModeProvider), 2);
    expect(repository.uid, 'adult');
    expect(repository.mode, 3);
    repository.saved.complete();
    await pending;
    expect(container.read(currentModeProvider), 3);
    expect(container.read(navigationSessionProvider).session!.currentMode, 3);
    expect(profiles.profile!.uuid, 'existing-profile');
    expect(profiles.profile!.activeMode, 3);
    expect(profiles.creations, 0);
    expect(profiles.updates, 1);
  });

  test('prepara el perfil si faltaba al cambiar de modo', () async {
    profiles.profile = null;
    repository.saved.complete();
    await container.read(changeUsageModeProvider)(3);
    expect(profiles.creations, 1);
    expect(profiles.profile!.activeMode, 3);
    expect(container.read(currentModeProvider), 3);
  });

  test('un error de red conserva el modo anterior', () async {
    final pending = container.read(changeUsageModeProvider)(3);
    final checked = expectLater(pending, throwsStateError);
    repository.saved.completeError(StateError('offline'));
    await checked;
    expect(container.read(currentModeProvider), 2);
    expect(container.read(navigationSessionProvider).session!.currentMode, 2);
  });

  for (final withInvite in [false, true]) {
    test('modo personal conserva perfil con invitación=$withInvite', () async {
      restore('adult', 3);
      if (withInvite) await invitations.createInvite();
      final uuid = profiles.profile!.uuid;
      repository.saved.complete();
      await container.read(changeUsageModeProvider)(2);
      expect(repository.calls, 1);
      expect(await invitations.getActiveInvite(), isNull);
      expect(profiles.profile!.uuid, uuid);
      expect(profiles.creations, 0);
      expect(container.read(currentModeProvider), 2);
      expect(container.read(navigationSessionProvider).session!.currentMode, 2);
    });
  }

  test(
    'cancellation failure preserves mode and profile without confirming save',
    () async {
      restore('adult', 3);
      final failing = _FailingInvitations(
        await SharedPreferences.getInstance(),
      );
      container.updateOverrides([
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        authRepositoryProvider.overrideWithValue(repository),
        caregiverInviteRepositoryProvider.overrideWithValue(failing),
        cognitiveProfileRepositoryProvider.overrideWithValue(profiles),
      ]);
      await expectLater(
        container.read(changeUsageModeProvider)(2),
        throwsStateError,
      );
      expect(repository.calls, 0);
      expect(container.read(currentModeProvider), 3);
      expect(profiles.profile!.uuid, 'existing-profile');
      expect(profiles.creations, 0);
      failing.dispose();
    },
  );

  test(
    'full mode cycle preserves profile reference and creation date',
    () async {
      repository.saved.complete();
      final original = profiles.profile!;
      for (final mode in [3, 2, 3, 2]) {
        await container.read(changeUsageModeProvider)(mode);
        expect(profiles.profile!.uuid, original.uuid);
        expect(profiles.profile!.deviceId, original.deviceId);
        expect(profiles.profile!.createdAt, original.createdAt);
        expect(profiles.creations, 0);
        expect(container.read(currentModeProvider), mode);
      }
    },
  );

  test(
    'perfil pendiente conserva el modo confirmado y reintenta sin guardarlo',
    () async {
      repository.saved.complete();
      profiles.failRead = true;
      await expectLater(
        container.read(changeUsageModeProvider)(3),
        throwsA(isA<UsageModeProfilePending>()),
      );
      expect(container.read(currentModeProvider), 3);
      expect(container.read(navigationSessionProvider).session!.currentMode, 3);
      expect(repository.calls, 1);
      profiles.failRead = false;
      await container.read(changeUsageModeProvider)(3);
      expect(repository.calls, 1);
      expect(profiles.profile!.uuid, 'existing-profile');
      expect(profiles.profile!.activeMode, 3);
      expect(profiles.creations, 0);
    },
  );

  test('revocación permanece efectiva si falla el guardado del modo', () async {
    restore('adult', 3);
    await invitations.createInvite();
    final subscription = container.listen(caregiverLinkProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(
      (await container.read(caregiverLinkProvider.future)).status,
      CaregiverLinkViewStatus.active,
    );
    final pending = container.read(changeUsageModeProvider)(2);
    final checked = expectLater(
      pending,
      throwsA(isA<UsageModeSaveAfterRevocationFailed>()),
    );
    // La cancelación es asíncrona y precede al guardado.
    await Future<void>.delayed(Duration.zero);
    repository.saved.completeError(StateError('offline'));
    await checked;
    expect(await invitations.getActiveInvite(), isNull);
    expect(
      (await container.read(caregiverLinkProvider.future)).status,
      CaregiverLinkViewStatus.none,
    );
    expect(container.read(currentModeProvider), 3);
    expect(container.read(navigationSessionProvider).session!.currentMode, 3);
    expect(profiles.creations, 0);
    expect(profiles.updates, 0);
  });

  test('sin sesión no intenta guardar', () async {
    container.read(navigationSessionProvider.notifier).clear();
    await expectLater(
      container.read(changeUsageModeProvider)(3),
      throwsStateError,
    );
    expect(repository.calls, 0);
    expect(profiles.creations, 0);
    expect(profiles.updates, 0);
  });

  test('una respuesta tardía no cambia el modo de otra cuenta', () async {
    final pending = container.read(changeUsageModeProvider)(3);
    restore('another-adult', 2);
    final checked = expectLater(pending, throwsStateError);
    repository.saved.complete();
    await checked;
    expect(container.read(currentModeProvider), 2);
    expect(
      container.read(navigationSessionProvider).session!.uid,
      'another-adult',
    );
  });
}
