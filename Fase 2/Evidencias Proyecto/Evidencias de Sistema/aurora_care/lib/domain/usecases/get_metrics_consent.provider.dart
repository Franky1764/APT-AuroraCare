// lib/domain/usecases/get_metrics_consent.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import 'get_metrics_consent.dart';

final getMetricsConsentProvider = Provider<GetMetricsConsent>((ref) {
  return GetMetricsConsent(ref.watch(authRepositoryProvider));
});