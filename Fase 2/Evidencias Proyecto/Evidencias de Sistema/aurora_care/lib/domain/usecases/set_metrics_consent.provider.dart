// lib/domain/usecases/set_metrics_consent.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import 'set_metrics_consent.dart';

final setMetricsConsentProvider = Provider<SetMetricsConsent>((ref) {
  return SetMetricsConsent(ref.watch(authRepositoryProvider));
});