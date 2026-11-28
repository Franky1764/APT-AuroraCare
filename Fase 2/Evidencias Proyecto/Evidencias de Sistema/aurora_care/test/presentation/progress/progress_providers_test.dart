import 'package:aurora_care/core/auth_account_provider.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/data/repositories/session_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/domain/repositories/cognitive_profile_repository.dart';
import 'package:aurora_care/domain/repositories/session_repository.dart';
import 'package:aurora_care/domain/usecases/get_active_profile.dart';
import 'package:aurora_care/domain/usecases/get_active_profile.provider.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 10, 28);
Session session(
  int day, {
  double? score = 70,
  String? version = progressScoringVersion,
  String uuid = 'profile',
  String domain = 'memoria',
  String game = 'memorice_clasico',
  GameLevel level = GameLevel.facil,
}) => Session(
  sessionId: '$day-$domain-${level.value}',
  uuid: uuid,
  domain: domain,
  gameType: game,
  nivel: level,
  startTime: now.subtract(Duration(days: day)),
  endTime: now.subtract(Duration(days: day)),
  metrics: const MemoriaMetrics(
    errores: 0,
    intentos: 12,
    tiempoSegundos: 60,
    tasaAciertoPct: 100,
  ),
  scoreSesion: score,
  scoringVersion: version,
);

class Profiles implements CognitiveProfileRepository {
  Profiles(this.profile);
  final CognitiveProfile? profile;
  @override
  Future<CognitiveProfile?> getLocalProfile() async => profile;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Sessions implements SessionRepository {
  Sessions(this.sessions);
  final List<Session> sessions;
  String? requestedUuid;
  int? requestedDays;
  @override
  Future<List<Session>> getSessionsInWindow(
    String uuid, {
    String? domain,
    int days = 28,
  }) async {
    requestedUuid = uuid;
    requestedDays = days;
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('separa juegos del mismo nivel y cuenta días de práctica', () {
    final summary = summarizeProgress(
      [
        session(0),
        session(0),
        session(1),
        session(2, game: 'que_cambio'),
        session(3, game: 'que_cambio'),
      ],
      uuid: 'profile',
      now: now,
    ).domains.first;
    expect(summary.sessions, 5);
    expect(summary.comparisonGame, 'memorice_clasico');
    expect(summary.comparableSessions, 3);
    expect(summary.practiceDays, 2);
    expect(summary.trend, ProgressTrend.insufficient);
  });

  DomainSummary summarize(List<Session> sessions) =>
      summarizeProgress(sessions, uuid: 'profile', now: now).domains.first;

  test(
    'initial follow-up counts comparable sessions and retains raw latest data',
    () {
      final result = summarize([
        session(4),
        session(3),
        session(2),
        session(0, score: null, version: null),
        session(1, level: GameLevel.avanzado),
      ]);
      expect(result.comparableSessions, 3);
      expect(result.missingSessions, 2);
      expect(result.latestSession!.startTime, now);
      expect(result.latestSession!.scoreSesion, isNull);
      expect(result.contextText, contains('Faltan 2'));
      final expired = summarize([session(30)]);
      expect(expired.trend, ProgressTrend.insufficient);
      expect(expired.latestSession, isNull);
      expect(expired.statusText, 'Sin sesiones recientes');
    },
  );

  test('SCORING §4 regression, stable, zeros and calibration', () {
    final scores = [85, 82, 79, 76, 73, 70, 67, 64];
    final result = summarize([
      for (var i = 0; i < scores.length; i++)
        session(8 - i, score: scores[i].toDouble()),
    ]);
    expect(result.trend, ProgressTrend.review);
    expect(result.variation, -28.2);
    expect(
      summarize([for (var i = 0; i < 5; i++) session(i)]).trend,
      ProgressTrend.stable,
    );
    expect(
      summarize([for (var i = 0; i < 5; i++) session(i, score: 0)]).variation,
      0,
    );
    expect(
      summarize([for (var i = 0; i < 4; i++) session(i)]).trend,
      ProgressTrend.insufficient,
    );
    expect(
      summarize([for (var i = 0; i < 5; i++) session(5 - i, score: 50 + i * 5)])
          .trend,
      ProgressTrend.improving,
    );
  });
  test('thresholds are classified before rounding', () {
    expect(classifyProgressTrend(5), ProgressTrend.stable);
    expect(classifyProgressTrend(5.001), ProgressTrend.improving);
    expect(classifyProgressTrend(-5), ProgressTrend.stable);
    expect(classifyProgressTrend(-5.001), ProgressTrend.attention);
    expect(classifyProgressTrend(-15), ProgressTrend.attention);
    expect(classifyProgressTrend(-15.001), ProgressTrend.review);
  });
  test('window, uuid, domain and scoring version filters', () {
    final result = summarize([
      session(28),
      session(29),
      session(-1),
      session(0, uuid: 'other'),
      session(0, domain: 'atencion'),
      session(1, version: null),
      session(2, version: 'old'),
      session(3, score: null),
      session(4, score: double.nan),
      session(5, score: 101),
    ]);
    expect(result.sessions, 6);
    expect(result.scoredSessions, 1);
    expect(result.trend, ProgressTrend.insufficient);
    expect(
      summarize([session(0, version: null)]).statusText,
      'Seguimiento inicial',
    );
  });
  test('dominant level uses count then recency, never mixes levels', () {
    final sessions = [
      for (var i = 1; i <= 5; i++) session(i),
      for (var i = 0; i < 5; i++)
        session(i, level: GameLevel.avanzado, score: 20),
    ];
    expect(summarize(sessions).level, GameLevel.avanzado);
    expect(summarize(sessions.reversed.toList()).variation, 0);
    expect(summarize([...sessions, session(6)]).level, GameLevel.facil);
    expect(
      summarize(sessions.take(4).toList()).trend,
      ProgressTrend.insufficient,
    );
  });
  test('provider reads use case and repository with overrides only', () async {
    final repository = Sessions([session(0)]);
    final container = ProviderContainer(
      overrides: [
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        getActiveProfileProvider.overrideWithValue(
          GetActiveProfile(
            Profiles(
              CognitiveProfile(
                uuid: 'profile',
                deviceId: 'device',
                createdAt: now,
                activeMode: 2,
              ),
            ),
          ),
        ),
        sessionRepositoryProvider.overrideWithValue(repository),
        progressClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(navigationSessionProvider.notifier)
        .restore(
          const SessionInfo(
            uid: 'adult',
            email: 'adult@example.test',
            currentMode: 2,
          ),
        );
    final result = await container.read(progressProvider.future);
    expect(result.domains.first.sessions, 1);
    expect(repository.requestedUuid, 'profile');
    expect(repository.requestedDays, 28);
  });
  test('missing profile never accesses Firebase repository', () async {
    final container = ProviderContainer(
      overrides: [
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        getActiveProfileProvider.overrideWithValue(
          GetActiveProfile(Profiles(null)),
        ),
        sessionRepositoryProvider.overrideWith(
          (ref) => throw StateError('Must not read'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect((await container.read(progressProvider.future)).hasProfile, false);
  });
}
