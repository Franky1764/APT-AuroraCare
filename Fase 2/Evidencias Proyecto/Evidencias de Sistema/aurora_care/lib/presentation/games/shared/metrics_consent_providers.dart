// lib/presentation/games/shared/metrics_consent_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/get_metrics_consent.dart';
import '../../../domain/usecases/get_metrics_consent.provider.dart';

/// ¿La persona [uid] dio su consentimiento de métricas?
///
/// Si no se puede comprobar (sin conexión, error), el provider falla y los
/// juegos quedan cerrados: nunca se asume que el consentimiento existe.
/// Quien cambie el consentimiento (aceptar, o retirarlo desde ARCO) debe
/// llamar a `ref.invalidate(metricsConsentProvider(uid))`.
final metricsConsentProvider = FutureProvider.family<bool, String>((ref, uid) {
  return ref
      .read(getMetricsConsentProvider)
      .call(MetricsConsentParams(uid: uid))
      .timeout(const Duration(seconds: 8));
});