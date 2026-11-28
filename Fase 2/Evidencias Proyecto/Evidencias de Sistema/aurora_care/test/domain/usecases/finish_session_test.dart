import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/session_analysis.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/repositories/session_repository.dart';
import 'package:aurora_care/domain/repositories/session_analyzer.dart';
import 'package:aurora_care/domain/usecases/finish_session.dart';

import '../../data/repositories/api_session_analyzer_test.dart' show sample;

const version = 'scoring-v1.1-memorice-1';

class Repository implements SessionRepository {
  final sessions = <Session>[];
  double? persistedScore;
  String? persistedVersion;
  @override
  Future<void> saveSession(Session session) async {
    sessions.add(session);
  }

  @override
  Future<List<Session>> getSessionsInWindow(
    String uuid, {
    String? domain,
    int days = 28,
  }) async => sessions;
  @override
  Future<List<Session>> getRecentSessions(String uuid, {int limit = 5}) async =>
      sessions;
  @override
  Future<void> updateSessionScore(
    String uuid,
    String sessionId,
    double score, {
    required String scoringVersion,
  }) async {
    persistedScore = score;
    persistedVersion = scoringVersion;
  }
}

class Analyzer implements SessionAnalyzer {
  Analyzer({this.fail = false});
  final bool fail;
  bool called = false;
  List<Session> received = [];
  @override
  Future<SessionAnalysis> analyze(
    Session session,
    List<Session> history,
  ) async {
    called = true;
    received = history;
    if (fail) throw StateError('service unavailable');
    return const SessionAnalysis(
      scoreSesion: 55.8,
      nivelJugado: GameLevel.facil,
      sugerirAvance: false,
      sesionesEnVentana: 2,
      senal: TrendSignal.insuficiente,
      scoringVersion: version,
    );
  }
}

void main() {
  test(
    'list and zoom sessions are saved without entering cognitive scoring',
    () async {
      const observations = <PhonePracticeMetrics>[
        PhoneListMetrics(
          completedSearches: 3,
          totalSearches: 3,
          selectionAttempts: 3,
          otherSelections: 0,
          scrollGestures: 4,
          revealRequests: 0,
          searchesWithHelp: 0,
          listLength: 8,
        ),
        PhoneZoomMetrics(
          completedActions: 2,
          totalActions: 2,
          successfulPinches: 2,
          pinchAttempts: 2,
          assistedActions: 0,
          maxScaleReached: 2,
          targetScale: 1.6,
        ),
      ];
      for (final observation in observations) {
        final repository = Repository();
        final analyzer = Analyzer();
        final result = await FinishSession(repository, analyzer)(
          FinishSessionParams(sample(domain: 'praxias', metrics: observation)),
        );
        expect(repository.sessions.single.metrics, same(observation));
        expect(analyzer.called, isFalse);
        expect(result.analysis, isNull);
      }
    },
  );
  test('drag practice is saved without requesting a cognitive score', () async {
    final repository = Repository();
    final analyzer = Analyzer();
    final result = await FinishSession(repository, analyzer)(
      FinishSessionParams(
        sample(
          domain: 'praxias',
          metrics: const PhoneDragMetrics(
            completedActions: 4,
            totalActions: 4,
            successfulDrags: 4,
            dragAttempts: 5,
            dropsOutsideTarget: 1,
            assistedActions: 0,
            itemSizeDp: 88,
            targetSizeDp: 136,
            minimumOverlapRatio: .65,
          ),
        ),
      ),
    );
    expect(repository.sessions.single.metrics, isA<PhoneDragMetrics>());
    expect(analyzer.called, isFalse);
    expect(result.analysis, isNull);
  });
  test(
    'swipe sessions are saved without scoring or reaction-time substitution',
    () async {
      final repository = Repository();
      final analyzer = Analyzer();
      final result = await FinishSession(repository, analyzer)(
        FinishSessionParams(
          sample(
            domain: 'praxias',
            metrics: const PhoneSwipeMetrics(
              completedActions: 4,
              totalActions: 4,
              successfulSwipes: 4,
              gestureAttempts: 5,
              assistedActions: 0,
              requiredDistanceRatio: .25,
            ),
          ),
        ),
      );
      expect(repository.sessions.single.metrics, isA<PhoneSwipeMetrics>());
      expect(analyzer.called, isFalse);
      expect(result.analysis, isNull);
    },
  );
  test(
    'phone practice is saved without requesting an unrelated cognitive score',
    () async {
      final repository = Repository();
      final analyzer = Analyzer();
      final result = await FinishSession(repository, analyzer)(
        FinishSessionParams(
          sample(
            domain: 'praxias',
            metrics: const PhoneTouchMetrics(
              completedTargets: 6,
              totalTargets: 6,
              touchesOnTarget: 6,
              touchesOutsideTarget: 1,
              buttonWidthDp: 176,
              buttonHeightDp: 72,
              imageSizeDp: 144,
            ),
          ),
        ),
      );
      expect(repository.sessions, hasLength(1));
      expect(analyzer.called, isFalse);
      expect(result.analysis, isNull);
      expect(repository.persistedScore, isNull);
    },
  );
  test(
    'persists real score with provenance and excludes old fake scores',
    () async {
      final repository = Repository()
        ..sessions.addAll([
          sample(id: 'legacy', score: 70),
          sample(id: 'real', score: 61, version: version),
        ]);
      final analyzer = Analyzer();
      final result = await FinishSession(repository, analyzer)(
        FinishSessionParams(sample()),
      );
      expect(result.analysis?.scoreSesion, 55.8);
      expect(repository.persistedScore, 55.8);
      expect(repository.persistedVersion, version);
      expect(analyzer.received.map((s) => s.sessionId), ['real']);
    },
  );
  test(
    'keeps raw metrics when analysis fails without inventing a score',
    () async {
      final repository = Repository();
      final result = await FinishSession(repository, Analyzer(fail: true))(
        FinishSessionParams(sample()),
      );
      expect(repository.sessions, hasLength(1));
      expect(repository.persistedScore, isNull);
      expect(result.analysis, isNull);
    },
  );
}
