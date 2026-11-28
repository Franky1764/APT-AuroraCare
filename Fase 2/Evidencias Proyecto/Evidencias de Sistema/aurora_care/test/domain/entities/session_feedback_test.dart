import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/session_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conecta los puntos explica intentos, demostración y tiempo sin score clínico', () {
    final feedback = SessionFeedback.fromMetrics(
      const PraxiasMetrics(
        precisionPct: 90,
        correcciones: 2,
        tiempoSegundos: 12,
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
            precisionPct: 90,
            connectedPoints: 6,
            totalPoints: 6,
            activeTimeMs: 12000,
            tolerancePx: 15,
            outOfOrderTouches: 2,
            lifts: 1,
            demonstrationViews: 0,
          ),
        ],
      ),
    );
    expect(feedback.items['Figuras completadas'], '1');
    expect(feedback.items['Intentos registrados'], '2');
    expect(feedback.items['Tiempo de práctica'], '12 segundos');
    expect(feedback.items['Demostraciones consultadas'], '1');
    expect(feedback.items['Toques en otros puntos'], '2');
    expect(
      feedback.explanations['Tiempo de práctica'],
      contains('excluye las pausas'),
    );
  });

  test(
    'list and zoom summaries distinguish assistance from actual gestures',
    () {
      final list = SessionFeedback.fromMetrics(
        const PhoneListMetrics(
          completedSearches: 3,
          totalSearches: 3,
          selectionAttempts: 5,
          otherSelections: 2,
          scrollGestures: 4,
          revealRequests: 2,
          searchesWithHelp: 1,
          listLength: 8,
        ),
      );
      expect(list.items['Elementos encontrados'], '3 de 3');
      expect(list.items['Búsquedas con apoyo'], '1');
      final zoom = SessionFeedback.fromMetrics(
        const PhoneZoomMetrics(
          completedActions: 2,
          totalActions: 2,
          successfulPinches: 1,
          pinchAttempts: 3,
          assistedActions: 1,
          maxScaleReached: 2.4,
          targetScale: 1.6,
        ),
      );
      expect(zoom.items['Gestos logrados con dos dedos'], '1');
      expect(zoom.items['Acciones con un botón'], '1');
      expect(zoom.items['Tamaño máximo de la imagen'], '2,4 veces');
    },
  );
  test('drag summary describes completion and keeps support distinct', () {
    final result = SessionFeedback.fromMetrics(
      const PhoneDragMetrics(
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
    expect(result.items['Imágenes colocadas'], '4 de 4');
    expect(result.items['Arrastres logrados'], '3');
    expect(result.items['Intentos de arrastre'], '5');
    expect(result.items['Veces que soltó fuera del destino'], '2');
    expect(result.items['Colocaciones con un botón'], '1');
    expect(result.items.containsKey('Tiempo promedio para responder'), isFalse);
  });
  test('button support is distinct from achieved swipes in the summary', () {
    final result = SessionFeedback.fromMetrics(
      const PhoneSwipeMetrics(
        completedActions: 4,
        totalActions: 4,
        successfulSwipes: 3,
        gestureAttempts: 5,
        assistedActions: 1,
        requiredDistanceRatio: .25,
      ),
    );
    expect(result.items['Cambios de imagen completados'], '4 de 4');
    expect(result.items['Deslizamientos logrados'], '3');
    expect(result.items['Gestos intentados'], '5');
    expect(result.items['Cambios con un botón'], '1');
    expect(
      result.explanations['Cambios con un botón'],
      contains('por separado'),
    );
  });
  test(
    'phone actions are described without a reaction time or invented score',
    () {
      final result = SessionFeedback.fromMetrics(
        const PhoneTouchMetrics(
          completedTargets: 6,
          totalTargets: 6,
          touchesOnTarget: 6,
          touchesOutsideTarget: 2,
          buttonWidthDp: 176,
          buttonHeightDp: 72,
          imageSizeDp: 144,
        ),
        gameType: 'toque_preciso',
      );
      expect(result.items['Acciones completadas'], '6 de 6');
      expect(result.items['Toques realizados'], '8');
      expect(result.items['Toques fuera del elemento'], '2');
      expect(
        result.items.containsKey('Tiempo promedio para responder'),
        isFalse,
      );
    },
  );
  test('response averages use seconds and describe the actual task', () {
    const metrics = AtencionMetrics(
      tiempoRespuestaMs: 1628,
      tasaErrorPct: 0,
      alcance: 1,
    );
    const label = 'Tiempo promedio para responder';
    for (final game in [
      'toca_correcto',
      'contador_objetos',
      'secuencias_colores',
    ]) {
      final feedback = SessionFeedback.fromMetrics(metrics, gameType: game);
      expect(feedback.items[label], '1,6 segundos');
      expect(feedback.explanations[label], isNotEmpty);
    }
    expect(
      SessionFeedback.fromMetrics(
        metrics,
        gameType: 'toca_correcto',
      ).explanations[label],
      contains('correctamente'),
    );
    expect(
      SessionFeedback.fromMetrics(
        metrics,
        gameType: 'contador_objetos',
      ).explanations[label],
      contains('opciones de respuesta'),
    );
    expect(
      SessionFeedback.fromMetrics(
        metrics,
        gameType: 'secuencias_colores',
      ).explanations[label],
      contains('primer toque'),
    );
    final tiny = SessionFeedback.fromMetrics(
      const AtencionMetrics(tiempoRespuestaMs: 1, tasaErrorPct: 0, alcance: 1),
    );
    expect(tiny.items[label], 'Menos de 0,1 segundos');
  });
  test(
    'tracing reports observed precision, distinct figures and all attempts',
    () {
      TracingAttemptMetrics attempt(bool completed) => TracingAttemptMetrics(
        figure: 'circle',
        attempt: completed ? 2 : 1,
        completed: completed,
        precisionPct: 92,
        coveragePct: completed ? 100 : 50,
        activeTimeMs: 2000,
        tolerancePx: 15,
      );
      final feedback = SessionFeedback.fromMetrics(
        PraxiasMetrics(
          precisionPct: 92,
          correcciones: 0,
          tiempoSegundos: 10,
          tracingVersion: 'tracing-practice-v2',
          tracingAttempts: [attempt(false), attempt(true), attempt(true)],
        ),
      );
      expect(feedback.items['Precisión del recorrido'], '92 %');
      expect(feedback.items['Figuras completadas'], '1');
      expect(feedback.items['Intentos realizados'], '3');
    },
  );

  test(
    'invalid measurements and unavailable timing are not shown as results',
    () {
      final feedback = SessionFeedback.fromMetrics(
        const AtencionMetrics(
          tiempoRespuestaMs: 0,
          tasaErrorPct: double.nan,
          alcance: 0,
        ),
      );
      expect(feedback.items, isEmpty);
      final legacy = SessionFeedback.fromMetrics(
        const PraxiasMetrics(
          precisionPct: 101,
          correcciones: 0,
          tiempoSegundos: 0,
        ),
      );
      expect(legacy.items, isEmpty);
    },
  );
}
