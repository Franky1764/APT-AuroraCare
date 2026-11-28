import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/account_role.dart';

import '../../core/auth_account_provider.dart';
import '../../core/router/navigation_session.dart';
import '../../data/repositories/firestore_caregiver_invite_repository.dart';
import '../../domain/entities/cognitive_metrics.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';
import '../progress/progress_providers.dart';

final sharedPracticeRepositoryProvider =
    Provider<FirestoreCaregiverInviteRepository?>((ref) {
      final session = ref.watch(navigationSessionProvider).session;
      if (session == null ||
          ref.watch(authenticatedAccountIdProvider) != session.uid) {
        return null;
      }
      final repository = ref.watch(caregiverInviteRepositoryProvider);
      return repository is FirestoreCaregiverInviteRepository
          ? repository
          : null;
    });

final sharedPracticeLinkProvider = StreamProvider.autoDispose<String?>(
  (ref) =>
      ref.watch(sharedPracticeRepositoryProvider)?.watchActiveLinkToken() ??
      Stream.value(null),
);

final sharedPracticeSummaryProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, token) =>
          ref.watch(sharedPracticeRepositoryProvider)?.watchSummary(token) ??
          Stream.value(null),
    );

Map<String, dynamic> sharedPracticeData(ProgressSummary progress) {
  DateTime? latest;
  final areas = <String, dynamic>{};
  for (final domain in ['memoria', 'atencion', 'praxias']) {
    final area = progress.domains
        .where((area) => area.domain == domain)
        .firstOrNull;
    final session = area?.latestSession;
    final date = session?.endTime;
    if (date != null && (latest == null || date.isAfter(latest))) latest = date;
    final (metric, value, total) = switch (session?.metrics) {
      MemoriaMetrics(:final tasaAciertoPct) => (
        'accuracy',
        _percent(tasaAciertoPct),
        0,
      ),
      AtencionMetrics(:final tiempoRespuestaMs) => (
        'response',
        tiempoRespuestaMs.round(),
        0,
      ),
      PraxiasMetrics(:final precisionPct) => (
        'precision',
        _percent(precisionPct),
        0,
      ),
      PhoneListMetrics(:final completedSearches, :final totalSearches) => (
        'completed',
        completedSearches,
        totalSearches,
      ),
      PhoneTouchMetrics(:final completedTargets, :final totalTargets) => (
        'completed',
        completedTargets,
        totalTargets,
      ),
      PhoneDragMetrics(:final completedActions, :final totalActions) => (
        'completed',
        completedActions,
        totalActions,
      ),
      PhoneSwipeMetrics(:final completedActions, :final totalActions) => (
        'completed',
        completedActions,
        totalActions,
      ),
      PhoneZoomMetrics(:final completedActions, :final totalActions) => (
        'completed',
        completedActions,
        totalActions,
      ),
      _ => ('none', 0, 0),
    };
    areas[domain] = {
      'count': area?.sessions ?? 0,
      'metric': metric,
      'value': value < 0 ? 0 : value,
      'total': total,
      'trend': (area?.trend ?? ProgressTrend.insufficient).name,
      'comparable': area?.comparableSessions ?? 0,
      'level': area?.level?.value,
      'average': area?.averageScore,
      'latestGame': _knownGame(session?.gameType),
      'latestLevel': session?.nivel.value,
      'latestAt': date == null ? null : Timestamp.fromDate(date),
      'attempts': switch (session?.metrics) {
        MemoriaMetrics(:final intentos) => intentos,
        _ => null,
      },
      'errorsPct': switch (session?.metrics) {
        AtencionMetrics(:final tasaErrorPct) => _percent(tasaErrorPct),
        _ => null,
      },
      'figures': switch (session?.metrics) {
        PraxiasMetrics(:final tracingAttempts)
            when tracingAttempts.isNotEmpty =>
          tracingAttempts
              .where((attempt) => attempt.completed)
              .map((attempt) => attempt.figure)
              .toSet()
              .length,
        _ => null,
      },
      'supports': switch (session?.metrics) {
        PraxiasMetrics(:final tracingAttempts)
            when tracingAttempts.isNotEmpty =>
          tracingAttempts.fold<int>(
            0,
            (totalSupports, attempt) =>
                totalSupports +
                attempt.helpRequests +
                attempt.demonstrationViews,
          ),
        _ => null,
      },
      'comparisonGame': _knownGame(area?.comparisonGame),
      'practiceDays': area?.practiceDays ?? 0,
      'firstScore': area?.firstComparable?.scoreSesion,
      'lastScore': area?.lastComparable?.scoreSesion,
    };
  }
  return {
    ...areas,
    'lastPracticeAt': latest == null ? null : Timestamp.fromDate(latest),
  };
}

const _sharedGameTypes = {
  'memorice_clasico',
  'memorice_secuencias',
  'que_cambio',
  'recuerde_numero',
  'toca_correcto',
  'contador_objetos',
  'secuencias_colores',
  'trazado_guiado',
  'conecta_puntos',
  'colorear_contorno',
  'buscar_en_lista',
  'ampliar_imagen',
  'arrastrar_elementos',
  'deslizar_imagenes',
  'toque_preciso',
};

String? _knownGame(String? game) =>
    _sharedGameTypes.contains(game) ? game : null;

int _percent(double value) => value.isFinite ? value.clamp(0, 100).round() : 0;

final syncSharedPracticeProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final session = ref.watch(navigationSessionProvider).session;
  if (session?.role != AccountRole.elder || session?.currentMode != 3) return;
  final token = ref.watch(sharedPracticeLinkProvider).valueOrNull;
  final repository = ref.watch(sharedPracticeRepositoryProvider);
  if (token == null || repository == null) return;
  final progress = await ref.watch(progressProvider.future);
  if (!progress.hasProfile) return;
  await repository.refreshSharedSummary(
    () async => sharedPracticeData(progress),
  );
});
