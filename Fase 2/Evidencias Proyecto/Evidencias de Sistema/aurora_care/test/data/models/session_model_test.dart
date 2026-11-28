import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/data/models/session_model.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';

import '../repositories/api_session_analyzer_test.dart' show sample;

void main() {
  test(
    'conexión de puntos conserva intentos, ayuda y tiempo real sin coordenadas',
    () {
      const metrics = PraxiasMetrics(
        precisionPct: 92.5,
        correcciones: 1,
        tiempoSegundos: 18,
        connectionVersion: 'connect-dots-v2',
        connectionAttempts: [
          ConnectionAttemptMetrics(
            figure: 'pentagono',
            attempt: 1,
            completed: false,
            precisionPct: null,
            connectedPoints: 0,
            totalPoints: 6,
            activeTimeMs: 0,
            tolerancePx: 15,
            outOfOrderTouches: 0,
            lifts: 0,
            demonstrationViews: 1,
          ),
          ConnectionAttemptMetrics(
            figure: 'pentagono',
            attempt: 2,
            completed: true,
            precisionPct: 92.5,
            connectedPoints: 6,
            totalPoints: 6,
            activeTimeMs: 18000,
            tolerancePx: 15,
            outOfOrderTouches: 1,
            lifts: 2,
            demonstrationViews: 0,
          ),
        ],
      );
      final session = sample(domain: 'praxias', metrics: metrics);
      final serialized = SessionModel.fromEntity(session).toMap();
      final restored = SessionModel.fromMap(
        'connection',
        serialized,
      ).toEntity();
      expect(
        SessionModel.fromEntity(restored).metrics,
        SessionModel.fromEntity(session).metrics,
      );
      final observations = restored.metrics as PraxiasMetrics;
      expect(observations.connectionAttempts.first.precisionPct, isNull);
      expect(observations.connectionAttempts.last.activeTimeMs, 18000);
      expect(observations.connectionVersion, 'connect-dots-v2');
      expect(restored.scoreSesion, isNull);
      expect(serialized['metrics'].toString(), isNot(contains('strokes')));
    },
  );

  test(
    'list and zoom practice round trip without losing assistance or context',
    () {
      const observations = <PhonePracticeMetrics>[
        PhoneListMetrics(
          completedSearches: 3,
          totalSearches: 3,
          selectionAttempts: 4,
          otherSelections: 1,
          scrollGestures: 6,
          revealRequests: 2,
          searchesWithHelp: 1,
          listLength: 12,
        ),
        PhoneZoomMetrics(
          completedActions: 2,
          totalActions: 2,
          successfulPinches: 1,
          pinchAttempts: 3,
          assistedActions: 1,
          maxScaleReached: 2.4,
          targetScale: 1.9,
        ),
      ];
      for (final observation in observations) {
        final session = sample(domain: 'praxias', metrics: observation);
        final restored = SessionModel.fromMap(
          'phone',
          SessionModel.fromEntity(session).toMap(),
        ).toEntity();
        expect(restored.metrics.runtimeType, observation.runtimeType);
        expect(
          SessionModel.fromEntity(restored).metrics,
          SessionModel.fromEntity(session).metrics,
        );
        expect(restored.scoreSesion, isNull);
      }
    },
  );
  test('drag observations retain attempts, target size and button support', () {
    final session = sample(
      domain: 'praxias',
      metrics: const PhoneDragMetrics(
        completedActions: 4,
        totalActions: 4,
        successfulDrags: 3,
        dragAttempts: 5,
        dropsOutsideTarget: 2,
        assistedActions: 1,
        itemSizeDp: 88,
        targetSizeDp: 136,
        minimumOverlapRatio: .65,
      ),
    );
    final map = SessionModel.fromEntity(session).toMap();
    final restored = SessionModel.fromMap('drag', map).toEntity();
    final metrics = restored.metrics as PhoneDragMetrics;
    expect(metrics.completedActions, 4);
    expect(metrics.successfulDrags, 3);
    expect(metrics.dragAttempts, 5);
    expect(metrics.dropsOutsideTarget, 2);
    expect(metrics.assistedActions, 1);
    expect(metrics.itemSizeDp, 88);
    expect(metrics.targetSizeDp, 136);
    expect(metrics.minimumOverlapRatio, .65);
    expect(restored.scoreSesion, isNull);
  });
  test(
    'swipe practice retains attempts, button support and gesture distance',
    () {
      final session = sample(
        domain: 'praxias',
        metrics: const PhoneSwipeMetrics(
          completedActions: 4,
          totalActions: 4,
          successfulSwipes: 3,
          gestureAttempts: 5,
          assistedActions: 1,
          requiredDistanceRatio: .25,
        ),
      );
      final restored = SessionModel.fromMap(
        'swipe',
        SessionModel.fromEntity(session).toMap(),
      ).toEntity();
      final metrics = restored.metrics as PhoneSwipeMetrics;
      expect(metrics.successfulSwipes, 3);
      expect(metrics.assistedActions, 1);
      expect(metrics.gestureAttempts, 5);
      expect(metrics.completedActions, 4);
      expect(metrics.requiredDistanceRatio, .25);
      expect(restored.scoreSesion, isNull);
    },
  );
  test('phone touch observations round trip separately from tracing', () {
    final original = sample(
      domain: 'praxias',
      metrics: const PhoneTouchMetrics(
        completedTargets: 6,
        totalTargets: 6,
        touchesOnTarget: 6,
        touchesOutsideTarget: 2,
        buttonWidthDp: 176,
        buttonHeightDp: 72,
        imageSizeDp: 144,
      ),
    );
    final map = SessionModel.fromEntity(original).toMap();
    final restored = SessionModel.fromMap('phone', map).toEntity();
    final metrics = restored.metrics as PhoneTouchMetrics;
    expect(metrics.completedTargets, 6);
    expect(metrics.touchesOutsideTarget, 2);
    expect(metrics.imageSizeDp, 144);
    expect(metrics.buttonWidthDp, 176);
    expect(metrics.buttonHeightDp, 72);
    expect(restored.scoreSesion, isNull);
  });
  test('preserves tracing attempts, supports, pauses context and version', () {
    final session = sample(
      domain: 'praxias',
      metrics: const PraxiasMetrics(
        precisionPct: 90,
        correcciones: 1,
        tiempoSegundos: 12,
        tracingVersion: 'tracing-practice-v2',
        tracingAttempts: [
          TracingAttemptMetrics(
            figure: 'recta',
            attempt: 1,
            completed: false,
            precisionPct: 70,
            coveragePct: 40,
            activeTimeMs: 8000,
            tolerancePx: 15,
            helpRequests: 1,
            demonstrationViews: 1,
            undoCount: 1,
            lifts: 3,
            practicePrecisionPct: 60,
          ),
          TracingAttemptMetrics(
            figure: 'recta',
            attempt: 2,
            completed: true,
            precisionPct: 90,
            coveragePct: 99,
            activeTimeMs: 4000,
            tolerancePx: 15,
          ),
        ],
      ),
    );
    final map = SessionModel.fromEntity(session).toMap();
    final metrics =
        SessionModel.fromMap('trace', map).toEntity().metrics as PraxiasMetrics;
    expect(metrics.tracingVersion, 'tracing-practice-v2');
    expect(metrics.tracingAttempts, hasLength(2));
    expect(metrics.tracingAttempts.first.completed, isFalse);
    expect(metrics.tracingAttempts.first.helpRequests, 1);
    expect(metrics.tracingAttempts.first.demonstrationViews, 1);
    expect(metrics.tracingAttempts.first.lifts, 3);
    expect(metrics.tracingAttempts.first.practicePrecisionPct, 60);
    expect(metrics.tracingAttempts.last.completed, isTrue);
  });

  test('old motor sessions remain readable without practice details', () {
    final map = SessionModel.fromEntity(
      sample(
        domain: 'praxias',
        metrics: const PraxiasMetrics(
          precisionPct: 80,
          correcciones: 4,
          tiempoSegundos: 40,
        ),
      ),
    ).toMap();
    final metrics =
        SessionModel.fromMap('old', map).toEntity().metrics as PraxiasMetrics;
    expect(metrics.tracingAttempts, isEmpty);
    expect(metrics.tracingVersion, isNull);
  });
  test('unversioned fixed scores are not treated as real results', () {
    final raw = SessionModel.fromEntity(sample(score: 70)).toMap();
    final restored = SessionModel.fromMap('legacy', raw).toEntity();
    expect(restored.scoreSesion, isNull);
    expect(restored.metrics, isNotNull);
  });
  test('round trips real score and calculation version', () {
    final raw = SessionModel.fromEntity(
      sample(score: 55.8, version: 'scoring-v1.1-memorice-1'),
    ).toMap();
    final restored = SessionModel.fromMap('real', raw).toEntity();
    expect(restored.scoreSesion, 55.8);
    expect(restored.scoringVersion, 'scoring-v1.1-memorice-1');
  });
}
