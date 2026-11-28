// lib/domain/usecases/get_metrics_consent.dart
import '../repositories/auth_repository.dart';
import 'usecase.dart';

/// ¿La persona dio su consentimiento para guardar métricas de juego?
class GetMetricsConsent implements UseCase<bool, MetricsConsentParams> {
  final AuthRepository repository;
  const GetMetricsConsent(this.repository);

  @override
  Future<bool> call(MetricsConsentParams params) =>
      repository.hasMetricsConsent(uid: params.uid);
}

class MetricsConsentParams {
  final String uid;
  const MetricsConsentParams({required this.uid});
}