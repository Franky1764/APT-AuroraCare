// domain/entities/cognitive_metrics.dart

abstract class CognitiveMetrics {
  const CognitiveMetrics();
}

/// Observaciones de uso del teléfono, separadas de reacción y del trazado.
/// El tamaño del objetivo contextualiza los toques; no se calcula un score.
abstract class PhonePracticeMetrics extends CognitiveMetrics {
  const PhonePracticeMetrics();
}

class PhoneTouchMetrics extends PhonePracticeMetrics {
  const PhoneTouchMetrics({
    required this.completedTargets,
    required this.totalTargets,
    required this.touchesOnTarget,
    required this.touchesOutsideTarget,
    required this.buttonWidthDp,
    required this.buttonHeightDp,
    required this.imageSizeDp,
  });
  final int completedTargets;
  final int totalTargets;
  final int touchesOnTarget;
  final int touchesOutsideTarget;
  final double buttonWidthDp;
  final double buttonHeightDp;
  final double imageSizeDp;
}

/// Se distinguen los gestos logrados de los cambios realizados con un botón.
/// No se registran fotos personales, velocidad ni posiciones del dedo.
class PhoneSwipeMetrics extends PhonePracticeMetrics {
  const PhoneSwipeMetrics({
    required this.completedActions,
    required this.totalActions,
    required this.successfulSwipes,
    required this.gestureAttempts,
    required this.assistedActions,
    required this.requiredDistanceRatio,
  });
  final int completedActions;
  final int totalActions;
  final int successfulSwipes;
  final int gestureAttempts;
  final int assistedActions;
  final double requiredDistanceRatio;
}

/// Observaciones de arrastre, sin fotos, coordenadas ni tiempos personales.
class PhoneDragMetrics extends PhonePracticeMetrics {
  const PhoneDragMetrics({
    required this.completedActions,
    required this.totalActions,
    required this.successfulDrags,
    required this.dragAttempts,
    required this.dropsOutsideTarget,
    required this.assistedActions,
    required this.itemSizeDp,
    required this.targetSizeDp,
    required this.minimumOverlapRatio,
  });
  final int completedActions;
  final int totalActions;
  final int successfulDrags;
  final int dragAttempts;
  final int dropsOutsideTarget;
  final int assistedActions;
  final double itemSizeDp;
  final double targetSizeDp;
  final double minimumOverlapRatio;
}

/// Datos de navegación y selección en una lista de práctica, sin búsquedas
/// personales ni tiempos que se puedan confundir con reacción.
class PhoneListMetrics extends PhonePracticeMetrics {
  const PhoneListMetrics({
    required this.completedSearches,
    required this.totalSearches,
    required this.selectionAttempts,
    required this.otherSelections,
    required this.scrollGestures,
    required this.revealRequests,
    required this.searchesWithHelp,
    required this.listLength,
  });
  final int completedSearches,
      totalSearches,
      selectionAttempts,
      otherSelections;
  final int scrollGestures, revealRequests, searchesWithHelp, listLength;
}

/// El uso de botones de apoyo se distingue del gesto real con dos dedos.
class PhoneZoomMetrics extends PhonePracticeMetrics {
  const PhoneZoomMetrics({
    required this.completedActions,
    required this.totalActions,
    required this.successfulPinches,
    required this.pinchAttempts,
    required this.assistedActions,
    required this.maxScaleReached,
    required this.targetScale,
  });
  final int completedActions,
      totalActions,
      successfulPinches,
      pinchAttempts,
      assistedActions;
  final double maxScaleReached, targetScale;
}

class MemoriaMetrics extends CognitiveMetrics {
  final int errores;
  final int intentos;
  final int tiempoSegundos;
  final double tasaAciertoPct; // nuevo

  const MemoriaMetrics({
    required this.errores,
    required this.intentos,
    required this.tiempoSegundos,
    required this.tasaAciertoPct,
  });
}

class AtencionMetrics extends CognitiveMetrics {
  final int tiempoRespuestaMs;
  final double tasaErrorPct;
  final int alcance; // antes longitudAlcanzada

  const AtencionMetrics({
    required this.tiempoRespuestaMs,
    required this.tasaErrorPct,
    required this.alcance,
  });
}

class PraxiasMetrics extends CognitiveMetrics {
  final double precisionPct;
  final int correcciones;
  final int tiempoSegundos;
  final String? tracingVersion;
  final List<TracingAttemptMetrics> tracingAttempts;
  final String? connectionVersion;
  final List<ConnectionAttemptMetrics> connectionAttempts;

  const PraxiasMetrics({
    required this.precisionPct,
    required this.correcciones,
    required this.tiempoSegundos,
    this.tracingVersion,
    this.tracingAttempts = const [],
    this.connectionVersion,
    this.connectionAttempts = const [],
  });
}

/// Intentos de conexión: se conserva la práctica, sin coordenadas del dedo.
class ConnectionAttemptMetrics {
  const ConnectionAttemptMetrics({
    required this.figure,
    required this.attempt,
    required this.completed,
    required this.precisionPct,
    required this.connectedPoints,
    required this.totalPoints,
    required this.activeTimeMs,
    required this.tolerancePx,
    required this.outOfOrderTouches,
    required this.lifts,
    required this.demonstrationViews,
  });
  final String figure;
  final int attempt;
  final bool completed;
  // Sin desplazamiento no hay precisión que medir (por ejemplo, solo ver la demostración).
  final double? precisionPct;
  // Los objetivos incluyen el punto inicial y el regreso al 1 para cerrar.
  final int connectedPoints, totalPoints, activeTimeMs;
  final double tolerancePx;
  final int outOfOrderTouches, lifts, demonstrationViews;
}

/// Contexto de cada intento de trazado: no se usa como penalización ni score.
/// Conserva los reinicios para que el resultado final no oculte la práctica.
class TracingAttemptMetrics {
  const TracingAttemptMetrics({
    required this.figure,
    required this.attempt,
    required this.completed,
    required this.precisionPct,
    required this.coveragePct,
    required this.activeTimeMs,
    required this.tolerancePx,
    this.helpRequests = 0,
    this.demonstrationViews = 0,
    this.undoCount = 0,
    this.lifts = 0,
    this.practicePrecisionPct,
  });

  final String figure;
  final int attempt;
  final bool completed;
  final double precisionPct;
  final double coveragePct;
  final int activeTimeMs;
  final double tolerancePx;
  final int helpRequests;
  final int demonstrationViews;
  final int undoCount;
  final int lifts;
  final double? practicePrecisionPct;
}
