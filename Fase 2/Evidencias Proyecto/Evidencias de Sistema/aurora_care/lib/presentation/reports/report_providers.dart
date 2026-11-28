import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/repositories/api_report_repository.dart';
import '../../core/router/navigation_session.dart';
import '../../data/sources/practice_feedback_platform.dart';
import '../../data/repositories/session_analyzer.provider.dart';
import '../../domain/entities/progress_report.dart';
import '../../domain/repositories/report_repository.dart';
import '../progress/progress_providers.dart';

final reportRepositoryProvider = Provider.autoDispose<ReportRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiReportRepository(client, ref.watch(sessionApiBaseUrlProvider));
});

List<ReportDomain> reportDomains(ProgressSummary summary) => [
  for (final domain in summary.domains)
    ReportDomain(
      domain: domain.domain,
      // El endpoint compara un nivel: no se atribuyen todas las partidas a ese nivel.
      sessions: domain.averageScore == null
          ? domain.sessions
          : domain.comparableSessions,
      level: domain.level?.value,
      averageScore: domain.averageScore,
      signal: domain.scoredSessions == 0 && domain.sessions > 0
          ? 'calibracion_pendiente'
          : switch (domain.trend) {
              ProgressTrend.insufficient => 'insuficiente',
              ProgressTrend.improving => 'mejora',
              ProgressTrend.stable => 'estable',
              ProgressTrend.attention => 'atencion',
              ProgressTrend.review => 'revisar',
            },
    ),
];

final progressReportProvider = FutureProvider.autoDispose<ProgressReport>((
  ref,
) async {
  final account = ref.watch(navigationSessionProvider).session?.uid;
  final repository = ref.watch(reportRepositoryProvider);
  final feedback = ref.watch(practiceFeedbackPlatformProvider);
  final summary = await ref.watch(progressProvider.future);
  if (!summary.hasProfile) throw StateError('No active profile');
  final report = await repository.generate(reportDomains(summary));
  DateTime? latest;
  for (final area in summary.domains) {
    final practice = area.latestSession?.endTime;
    if (practice != null && (latest == null || practice.isAfter(latest))) {
      latest = practice;
    }
  }
  if (account != null && latest != null) {
    unawaited(feedback.reportReady(account, latest));
  }
  return report;
});
