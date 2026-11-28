// data/models/session_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cognitive_metrics.dart';
import '../../domain/entities/game_level.dart';
import '../../domain/entities/session.dart';

class SessionModel {
  final String sessionId;
  final String uuid;
  final String domain;
  final String gameType;
  final int nivel; // 1, 2 o 3
  final Timestamp startTime;
  final Timestamp endTime;
  final Map<String, dynamic>
  metrics; // en Firestore, las métricas SÍ se guardan como mapa
  final double? scoreSesion; // null = sesión aún sin analizar
  final String? scoringVersion;

  const SessionModel({
    required this.sessionId,
    required this.uuid,
    required this.domain,
    required this.gameType,
    required this.nivel,
    required this.startTime,
    required this.endTime,
    required this.metrics,
    this.scoreSesion,
    this.scoringVersion,
  });

  factory SessionModel.fromMap(String sessionId, Map<String, dynamic> map) {
    return SessionModel(
      sessionId: sessionId,
      uuid: map['uuid'] as String,
      domain: map['domain'] as String,
      gameType: map['gameType'] as String,
      nivel: map['nivel'] as int,
      startTime: map['startTime'] as Timestamp,
      endTime: map['endTime'] as Timestamp,
      metrics: Map<String, dynamic>.from(map['metrics'] as Map),
      // Los scores anteriores sin versión provienen del analizador ficticio.
      scoreSesion: map['scoringVersion'] == 'scoring-v1.1-memorice-1'
          ? (map['scoreSesion'] as num?)?.toDouble()
          : null,
      scoringVersion: map['scoringVersion'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'domain': domain,
      'gameType': gameType,
      'nivel': nivel,
      'startTime': startTime,
      'endTime': endTime,
      'metrics': metrics,
      if (scoreSesion != null) 'scoreSesion': scoreSesion,
      if (scoringVersion != null) 'scoringVersion': scoringVersion,
    };
  }

  // Aquí ocurre la traducción clave: de mapa genérico a ficha específica según el dominio
  Session toEntity() {
    return Session(
      sessionId: sessionId,
      uuid: uuid,
      domain: domain,
      gameType: gameType,
      nivel: GameLevel.fromValue(nivel),
      startTime: startTime.toDate(),
      endTime: endTime.toDate(),
      metrics: _parseMetrics(domain, metrics),
      scoreSesion: scoreSesion,
      scoringVersion: scoringVersion,
    );
  }

  static CognitiveMetrics _parseMetrics(
    String domain,
    Map<String, dynamic> map,
  ) {
    switch (domain) {
      case 'memoria':
        return MemoriaMetrics(
          errores: map['errores'] as int,
          intentos: map['intentos'] as int,
          tiempoSegundos: map['tiempoSegundos'] as int,
          tasaAciertoPct: (map['tasaAciertoPct'] as num).toDouble(),
        );
      case 'atencion':
        return AtencionMetrics(
          tiempoRespuestaMs: map['tiempoRespuestaMs'] as int,
          tasaErrorPct: (map['tasaErrorPct'] as num).toDouble(),
          alcance: map['alcance'] as int,
        );
      case 'praxias':
        if (map['practiceVersion'] == 'phone-list-v1') {
          return PhoneListMetrics(
            completedSearches: map['completedSearches'] as int,
            totalSearches: map['totalSearches'] as int,
            selectionAttempts: map['selectionAttempts'] as int,
            otherSelections: map['otherSelections'] as int,
            scrollGestures: map['scrollGestures'] as int,
            revealRequests: map['revealRequests'] as int,
            searchesWithHelp: map['searchesWithHelp'] as int,
            listLength: map['listLength'] as int,
          );
        }
        if (map['practiceVersion'] == 'phone-zoom-v1') {
          return PhoneZoomMetrics(
            completedActions: map['completedActions'] as int,
            totalActions: map['totalActions'] as int,
            successfulPinches: map['successfulPinches'] as int,
            pinchAttempts: map['pinchAttempts'] as int,
            assistedActions: map['assistedActions'] as int,
            maxScaleReached: (map['maxScaleReached'] as num).toDouble(),
            targetScale: (map['targetScale'] as num).toDouble(),
          );
        }
        if (map['practiceVersion'] == 'phone-drag-v1') {
          return PhoneDragMetrics(
            completedActions: map['completedActions'] as int,
            totalActions: map['totalActions'] as int,
            successfulDrags: map['successfulDrags'] as int,
            dragAttempts: map['dragAttempts'] as int,
            dropsOutsideTarget: map['dropsOutsideTarget'] as int,
            assistedActions: map['assistedActions'] as int,
            itemSizeDp: (map['itemSizeDp'] as num).toDouble(),
            targetSizeDp: (map['targetSizeDp'] as num).toDouble(),
            minimumOverlapRatio: (map['minimumOverlapRatio'] as num).toDouble(),
          );
        }
        if (map['practiceVersion'] == 'phone-swipe-v1') {
          return PhoneSwipeMetrics(
            completedActions: map['completedActions'] as int,
            totalActions: map['totalActions'] as int,
            successfulSwipes: map['successfulSwipes'] as int,
            gestureAttempts: map['gestureAttempts'] as int,
            assistedActions: map['assistedActions'] as int,
            requiredDistanceRatio: (map['requiredDistanceRatio'] as num)
                .toDouble(),
          );
        }
        if (map['practiceVersion'] == 'phone-touch-v1') {
          return PhoneTouchMetrics(
            completedTargets: map['completedTargets'] as int,
            totalTargets: map['totalTargets'] as int,
            touchesOnTarget: map['touchesOnTarget'] as int,
            touchesOutsideTarget: map['touchesOutsideTarget'] as int,
            buttonWidthDp: (map['buttonWidthDp'] as num).toDouble(),
            buttonHeightDp: (map['buttonHeightDp'] as num).toDouble(),
            imageSizeDp: (map['imageSizeDp'] as num).toDouble(),
          );
        }
        return PraxiasMetrics(
          precisionPct: (map['precisionPct'] as num).toDouble(),
          correcciones: map['correcciones'] as int,
          tiempoSegundos: map['tiempoSegundos'] as int,
          tracingVersion: map['tracingVersion'] as String?,
          connectionVersion: map['connectionVersion'] as String?,
          connectionAttempts: [
            for (final raw in (map['connectionAttempts'] as List? ?? const []))
              _parseConnectionAttempt(Map<String, dynamic>.from(raw as Map)),
          ],
          tracingAttempts: [
            for (final raw in (map['tracingAttempts'] as List? ?? const []))
              _parseTracingAttempt(Map<String, dynamic>.from(raw as Map)),
          ],
        );
      default:
        throw ArgumentError('Dominio desconocido: $domain');
    }
  }

  factory SessionModel.fromEntity(Session entity) {
    return SessionModel(
      sessionId: entity.sessionId,
      uuid: entity.uuid,
      domain: entity.domain,
      gameType: entity.gameType,
      nivel: entity.nivel.value,
      startTime: Timestamp.fromDate(entity.startTime),
      endTime: Timestamp.fromDate(entity.endTime),
      metrics: _metricsToMap(entity.metrics),
      scoreSesion: entity.scoreSesion,
      scoringVersion: entity.scoringVersion,
    );
  }

  static Map<String, dynamic> _metricsToMap(CognitiveMetrics metrics) {
    if (metrics is PhoneListMetrics) {
      return {
        'practiceVersion': 'phone-list-v1',
        'completedSearches': metrics.completedSearches,
        'totalSearches': metrics.totalSearches,
        'selectionAttempts': metrics.selectionAttempts,
        'otherSelections': metrics.otherSelections,
        'scrollGestures': metrics.scrollGestures,
        'revealRequests': metrics.revealRequests,
        'searchesWithHelp': metrics.searchesWithHelp,
        'listLength': metrics.listLength,
      };
    }
    if (metrics is PhoneZoomMetrics) {
      return {
        'practiceVersion': 'phone-zoom-v1',
        'completedActions': metrics.completedActions,
        'totalActions': metrics.totalActions,
        'successfulPinches': metrics.successfulPinches,
        'pinchAttempts': metrics.pinchAttempts,
        'assistedActions': metrics.assistedActions,
        'maxScaleReached': metrics.maxScaleReached,
        'targetScale': metrics.targetScale,
      };
    }
    if (metrics is PhoneDragMetrics) {
      return {
        'practiceVersion': 'phone-drag-v1',
        'completedActions': metrics.completedActions,
        'totalActions': metrics.totalActions,
        'successfulDrags': metrics.successfulDrags,
        'dragAttempts': metrics.dragAttempts,
        'dropsOutsideTarget': metrics.dropsOutsideTarget,
        'assistedActions': metrics.assistedActions,
        'itemSizeDp': metrics.itemSizeDp,
        'targetSizeDp': metrics.targetSizeDp,
        'minimumOverlapRatio': metrics.minimumOverlapRatio,
      };
    }
    if (metrics is PhoneSwipeMetrics) {
      return {
        'practiceVersion': 'phone-swipe-v1',
        'completedActions': metrics.completedActions,
        'totalActions': metrics.totalActions,
        'successfulSwipes': metrics.successfulSwipes,
        'gestureAttempts': metrics.gestureAttempts,
        'assistedActions': metrics.assistedActions,
        'requiredDistanceRatio': metrics.requiredDistanceRatio,
      };
    }
    if (metrics is PhoneTouchMetrics) {
      return {
        'practiceVersion': 'phone-touch-v1',
        'completedTargets': metrics.completedTargets,
        'totalTargets': metrics.totalTargets,
        'touchesOnTarget': metrics.touchesOnTarget,
        'touchesOutsideTarget': metrics.touchesOutsideTarget,
        'buttonWidthDp': metrics.buttonWidthDp,
        'buttonHeightDp': metrics.buttonHeightDp,
        'imageSizeDp': metrics.imageSizeDp,
      };
    } else if (metrics is MemoriaMetrics) {
      return {
        'errores': metrics.errores,
        'intentos': metrics.intentos,
        'tiempoSegundos': metrics.tiempoSegundos,
        'tasaAciertoPct': metrics.tasaAciertoPct,
      };
    } else if (metrics is AtencionMetrics) {
      return {
        'tiempoRespuestaMs': metrics.tiempoRespuestaMs,
        'tasaErrorPct': metrics.tasaErrorPct,
        'alcance': metrics.alcance,
      };
    } else if (metrics is PraxiasMetrics) {
      return {
        'precisionPct': metrics.precisionPct,
        'correcciones': metrics.correcciones,
        'tiempoSegundos': metrics.tiempoSegundos,
        if (metrics.tracingVersion != null)
          'tracingVersion': metrics.tracingVersion,
        if (metrics.tracingAttempts.isNotEmpty)
          'tracingAttempts': [
            for (final a in metrics.tracingAttempts)
              {
                'figure': a.figure,
                'attempt': a.attempt,
                'completed': a.completed,
                'precisionPct': a.precisionPct,
                'coveragePct': a.coveragePct,
                'activeTimeMs': a.activeTimeMs,
                'tolerancePx': a.tolerancePx,
                'helpRequests': a.helpRequests,
                'demonstrationViews': a.demonstrationViews,
                'undoCount': a.undoCount,
                'lifts': a.lifts,
                if (a.practicePrecisionPct != null)
                  'practicePrecisionPct': a.practicePrecisionPct,
              },
          ],
        if (metrics.connectionVersion != null)
          'connectionVersion': metrics.connectionVersion,
        if (metrics.connectionAttempts.isNotEmpty)
          'connectionAttempts': [
            for (final attempt in metrics.connectionAttempts)
              {
                'figure': attempt.figure,
                'attempt': attempt.attempt,
                'completed': attempt.completed,
                'precisionPct': attempt.precisionPct,
                'connectedPoints': attempt.connectedPoints,
                'totalPoints': attempt.totalPoints,
                'activeTimeMs': attempt.activeTimeMs,
                'tolerancePx': attempt.tolerancePx,
                'outOfOrderTouches': attempt.outOfOrderTouches,
                'lifts': attempt.lifts,
                'demonstrationViews': attempt.demonstrationViews,
              },
          ],
      };
    }
    throw ArgumentError('Tipo de métrica desconocido');
  }

  static ConnectionAttemptMetrics _parseConnectionAttempt(
    Map<String, dynamic> map,
  ) => ConnectionAttemptMetrics(
    figure: map['figure'] as String,
    attempt: map['attempt'] as int,
    completed: map['completed'] as bool,
    precisionPct: (map['precisionPct'] as num?)?.toDouble(),
    connectedPoints: map['connectedPoints'] as int,
    totalPoints: map['totalPoints'] as int,
    activeTimeMs: map['activeTimeMs'] as int,
    tolerancePx: (map['tolerancePx'] as num).toDouble(),
    outOfOrderTouches: map['outOfOrderTouches'] as int,
    lifts: map['lifts'] as int,
    demonstrationViews: map['demonstrationViews'] as int,
  );

  static TracingAttemptMetrics _parseTracingAttempt(Map<String, dynamic> m) =>
      TracingAttemptMetrics(
        figure: m['figure'] as String,
        attempt: m['attempt'] as int,
        completed: m['completed'] as bool,
        precisionPct: (m['precisionPct'] as num).toDouble(),
        coveragePct: (m['coveragePct'] as num).toDouble(),
        activeTimeMs: m['activeTimeMs'] as int,
        tolerancePx: (m['tolerancePx'] as num).toDouble(),
        helpRequests: m['helpRequests'] as int? ?? 0,
        demonstrationViews: m['demonstrationViews'] as int? ?? 0,
        undoCount: m['undoCount'] as int? ?? 0,
        lifts: m['lifts'] as int? ?? 0,
        practicePrecisionPct: (m['practicePrecisionPct'] as num?)?.toDouble(),
      );
}
