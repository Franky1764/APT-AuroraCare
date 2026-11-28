import 'package:aurora_care/presentation/games/shared/game_providers.dart';
import 'package:aurora_care/core/auth_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/data/repositories/cognitive_profile_repository_impl.provider.dart';
import 'package:aurora_care/data/repositories/session_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/repositories/cognitive_profile_repository.dart';
import 'package:aurora_care/domain/repositories/session_repository.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/presentation/shared/change_usage_mode_provider.dart';

import '../../helpers/fake_auth_repository.dart';

final _now = DateTime(2026, 10, 30);

class _Profiles implements CognitiveProfileRepository {
  CognitiveProfile? profile;
  bool failRead = false;
  int creations = 0;
  @override
  Future<CognitiveProfile?> getLocalProfile() async {
    if (failRead) throw StateError('offline');
    return profile;
  }

  @override
  Future<CognitiveProfile> createProfile({required int activeMode}) async {
    creations++;
    return profile = CognitiveProfile(
      uuid: 'profile',
      deviceId: 'device',
      createdAt: _now,
      activeMode: activeMode,
    );
  }

  @override
  Future<void> updateActiveMode({
    required String uuid,
    required int activeMode,
  }) async {
    final previous = profile!;
    profile = CognitiveProfile(
      uuid: uuid,
      deviceId: previous.deviceId,
      createdAt: previous.createdAt,
      activeMode: activeMode,
    );
  }
}

class _Sessions extends Fake implements SessionRepository {
  List<Session> sessions = [];
  final requestedUuids = <String>[];
  @override
  Future<List<Session>> getSessionsInWindow(
    String uuid, {
    String? domain,
    int days = 28,
  }) async {
    requestedUuids.add(uuid);
    return sessions;
  }
}

void main() {
  late _Profiles profiles;
  late _Sessions sessions;
  late ProviderContainer container;

  void restore(int mode) => container
      .read(navigationSessionProvider.notifier)
      .restore(
        SessionInfo(
          uid: 'adult',
          email: 'adult@example.test',
          currentMode: mode,
        ),
      );

  setUp(() {
    profiles = _Profiles();
    sessions = _Sessions();
    container = ProviderContainer(
      overrides: [
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        cognitiveProfileRepositoryProvider.overrideWithValue(profiles),
        sessionRepositoryProvider.overrideWithValue(sessions),
        progressClockProvider.overrideWithValue(() => _now),
      ],
    );
  });
  tearDown(() => container.dispose());

  for (final mode in [2, 3]) {
    test(
      'modo $mode prepara seguimiento ausente sin inventar partidas',
      () async {
        restore(mode);
        final result = await container.read(progressProvider.future);
        expect(result.hasProfile, isTrue);
        expect(result.domains.length, 3);
        expect(result.domains.every((domain) => domain.sessions == 0), isTrue);
        expect(profiles.creations, 1);
        expect(profiles.profile!.activeMode, mode);
        expect(sessions.requestedUuids, ['profile']);
      },
    );
  }

  test(
    'cambiar de modo conserva el historial y refresca el progreso',
    () async {
      restore(2);
      profiles.profile = CognitiveProfile(
        uuid: 'existing',
        deviceId: 'device',
        createdAt: DateTime(2025),
        activeMode: 2,
      );
      sessions.sessions = [
        Session(
          sessionId: 'saved-session',
          uuid: 'existing',
          domain: 'memoria',
          gameType: 'memorice_clasico',
          nivel: GameLevel.facil,
          startTime: _now,
          endTime: _now,
          metrics: const MemoriaMetrics(
            errores: 0,
            intentos: 12,
            tiempoSegundos: 60,
            tasaAciertoPct: 100,
          ),
        ),
      ];
      final subscription = container.listen(progressProvider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(progressProvider.future);
      await container.read(changeUsageModeProvider)(3);
      final after = await container.read(progressProvider.future);
      expect(before.domains.first.sessions, 1);
      expect(after.hasProfile, isTrue);
      expect(after.domains.first.sessions, 1);
      expect(after.domains.first.latestSession!.sessionId, 'saved-session');
      expect(sessions.requestedUuids, ['existing', 'existing']);
      expect(profiles.creations, 0);
      expect(profiles.profile!.uuid, 'existing');
      expect(profiles.profile!.createdAt, DateTime(2025));
      expect(profiles.profile!.activeMode, 3);
    },
  );

  test(
    'un fallo de lectura se muestra como error sin crear otro perfil',
    () async {
      restore(3);
      profiles.failRead = true;
      await expectLater(
        container.read(progressProvider.future),
        throwsStateError,
      );
      expect(profiles.creations, 0);
      expect(sessions.requestedUuids, isEmpty);
    },
  );

  test('sin sesión activa no se prepara un perfil nuevo', () async {
    final result = await container.read(progressProvider.future);
    expect(result.hasProfile, isFalse);
    expect(profiles.creations, 0);
    expect(sessions.requestedUuids, isEmpty);
  });
  test(
    'Firebase and navigation account mismatch never selects a profile',
    () async {
      profiles.failRead = true;
      final isolated = ProviderContainer(
        overrides: [
          authenticatedAccountIdProvider.overrideWithValue('adult-b'),
          cognitiveProfileRepositoryProvider.overrideWithValue(profiles),
        ],
      );
      addTearDown(isolated.dispose);
      isolated
          .read(navigationSessionProvider.notifier)
          .restore(
            const SessionInfo(
              uid: 'adult-a',
              email: 'a@example.test',
              currentMode: 2,
            ),
          );
      expect(await isolated.read(activeProfileProvider.future), isNull);
      expect(profiles.creations, 0);
    },
  );
}
