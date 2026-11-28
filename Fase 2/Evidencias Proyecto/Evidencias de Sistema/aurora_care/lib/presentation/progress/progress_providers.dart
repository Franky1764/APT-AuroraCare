import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/session_repository_impl.provider.dart';
import '../../domain/entities/game_level.dart';
import '../../domain/entities/cognitive_metrics.dart';
import '../../domain/entities/session.dart';
import '../games/shared/game_providers.dart';

const progressScoringVersion = 'scoring-v1.1-memorice-1';
final progressClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final progressProvider = FutureProvider.autoDispose<ProgressSummary>((
  ref,
) async {
  final clock = ref.watch(progressClockProvider);
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile == null) return const ProgressSummary(hasProfile: false);
  final sessions = await ref
      .watch(sessionRepositoryProvider)
      .getSessionsInWindow(profile.uuid, days: 28);
  final summary = summarizeProgress(sessions, uuid: profile.uuid, now: clock());
  return ProgressSummary(
    hasProfile: true,
    domains: summary.domains,
    hasUnassignedHistory: profile.hasUnassignedHistory,
  );
});

enum ProgressTrend { insufficient, improving, stable, attention, review }

class DomainSummary {
  const DomainSummary({
    required this.domain,
    required this.sessions,
    required this.scoredSessions,
    this.level,
    this.trend = ProgressTrend.insufficient,
    this.variation,
    this.comparableSessions = 0,
    this.latestSession,
    this.recordedSessions = const [],
    this.averageScore,
    this.comparisonGame,
    this.practiceDays = 0,
    this.firstComparable,
    this.lastComparable,
  });
  final String domain;
  final int sessions;
  final int scoredSessions;
  final GameLevel? level;
  final ProgressTrend trend;
  final double? variation;
  final int comparableSessions;
  final Session? latestSession;
  final List<Session> recordedSessions;
  final double? averageScore;
  final String? comparisonGame;
  final int practiceDays;
  final Session? firstComparable;
  final Session? lastComparable;
  int get missingSessions => (5 - comparableSessions).clamp(0, 5);

  String get contextText {
    if (sessions == 0) {
      return 'Al practicar, podrá ver aquí los datos de sus partidas.';
    }
    if (scoredSessions == 0) {
      return 'Puede consultar sus partidas registradas. Aún no hay puntuaciones calibradas disponibles para calcular una tendencia.';
    }
    if (trend == ProgressTrend.insufficient) {
      return 'Hay $comparableSessions de 5 sesiones analizadas en el nivel seleccionado. '
          'Faltan $missingSessions para el mínimo de comparación dentro de los últimos 28 días. '
          'Este seguimiento es inicial; no describe por sí solo cambios en sus habilidades.';
    }
    return 'Comparación de sesiones analizadas del mismo juego, nivel y versión dentro de los últimos 28 días. '
        'Describe su desempeño en los juegos; no es una evaluación clínica.';
  }

  String get statusText {
    if (sessions == 0) return 'Sin sesiones recientes';
    if (scoredSessions == 0) return 'Seguimiento inicial';
    return switch (trend) {
      ProgressTrend.insufficient =>
        'Aún faltan sesiones para mostrar una tendencia',
      ProgressTrend.improving => 'Tendencia de mejora',
      ProgressTrend.stable => 'Rendimiento estable',
      ProgressTrend.attention => 'Leve tendencia descendente',
      ProgressTrend.review => 'Tendencia descendente sostenida',
    };
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.hasProfile,
    this.domains = const [],
    this.hasUnassignedHistory = false,
  });
  final bool hasUnassignedHistory;
  final bool hasProfile;
  final List<DomainSummary> domains;
}

ProgressTrend classifyProgressTrend(double variation) {
  if (variation > 5) return ProgressTrend.improving;
  if (variation >= -5) return ProgressTrend.stable;
  if (variation >= -15) return ProgressTrend.attention;
  return ProgressTrend.review;
}

ProgressSummary summarizeProgress(
  List<Session> sessions, {
  required String uuid,
  required DateTime now,
}) {
  final since = now.subtract(const Duration(days: 28));
  final window = sessions.where(
    (s) =>
        s.uuid == uuid &&
        !s.startTime.isBefore(since) &&
        !s.startTime.isAfter(now),
  );
  return ProgressSummary(
    hasProfile: true,
    domains: [
      for (final domain in ['memoria', 'atencion', 'praxias'])
        _summarizeDomain(
          window.where((s) => s.domain == domain).toList(),
          domain,
        ),
    ],
  );
}

DomainSummary _summarizeDomain(List<Session> sessions, String domain) {
  final recent = sessions.toList()
    ..sort((a, b) {
      final time = b.startTime.compareTo(a.startTime);
      return time != 0 ? time : a.sessionId.compareTo(b.sessionId);
    });
  final scored =
      sessions
          .where(
            (s) =>
                s.scoringVersion == progressScoringVersion &&
                s.scoreSesion != null &&
                s.scoreSesion!.isFinite &&
                s.scoreSesion! >= 0 &&
                s.scoreSesion! <= 100,
          )
          .toList()
        ..sort((a, b) {
          final time = a.startTime.compareTo(b.startTime);
          return time != 0 ? time : a.sessionId.compareTo(b.sessionId);
        });
  final groups = <(String, GameLevel, String?), List<Session>>{};
  for (final session in scored) {
    final version = switch (session.metrics) {
      PraxiasMetrics(:final tracingVersion, :final connectionVersion) =>
        tracingVersion ?? connectionVersion,
      _ => null,
    };
    groups
        .putIfAbsent((session.gameType, session.nivel, version), () => [])
        .add(session);
  }
  final levels = groups.keys.toList()
    ..sort((a, b) {
      final count = groups[b]!.length.compareTo(groups[a]!.length);
      if (count != 0) return count;
      final recent = groups[b]!.last.startTime.compareTo(
        groups[a]!.last.startTime,
      );
      return recent != 0 ? recent : a.$2.value.compareTo(b.$2.value);
    });
  final group = levels.firstOrNull;
  final selected = groups[group] ?? <Session>[];
  final practiceDays = selected
      .map((session) {
        final date = session.startTime.toLocal();
        return (date.year, date.month, date.day);
      })
      .toSet()
      .length;
  double? variation;
  var trend = ProgressTrend.insufficient;
  if (selected.length >= 5) {
    final n = selected.length;
    final mean = selected.fold(0.0, (sum, s) => sum + s.scoreSesion!) / n;
    final center = (n - 1) / 2;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (i - center) * (selected[i].scoreSesion! - mean);
      denominator += (i - center) * (i - center);
    }
    final raw =
        numerator / denominator * (n - 1) / (mean < 1e-9 ? 1e-9 : mean) * 100;
    // Se clasifica antes de redondear, según SCORING sección 4.
    trend = classifyProgressTrend(raw);
    variation = (raw * 10).round() / 10;
  }
  return DomainSummary(
    domain: domain,
    sessions: sessions.length,
    scoredSessions: scored.length,
    level: group?.$2,
    comparisonGame: group?.$1,
    practiceDays: practiceDays,
    firstComparable: selected.firstOrNull,
    lastComparable: selected.lastOrNull,
    trend: trend,
    variation: variation,
    comparableSessions: selected.length,
    averageScore: selected.isEmpty
        ? null
        : selected.fold(0.0, (sum, s) => sum + s.scoreSesion!) /
              selected.length,
    recordedSessions: List.unmodifiable(recent),
    latestSession: recent.isEmpty ? null : recent.first,
  );
}
