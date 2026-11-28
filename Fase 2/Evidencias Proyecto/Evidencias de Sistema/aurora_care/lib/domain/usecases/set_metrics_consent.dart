// lib/domain/usecases/set_metrics_consent.dart
import '../repositories/auth_repository.dart';
import 'usecase.dart';

/// Registra (given = true) o retira (given = false) el consentimiento
/// de métricas de la persona.
class SetMetricsConsent implements UseCase<void, SetMetricsConsentParams> {
  final AuthRepository repository;
  const SetMetricsConsent(this.repository);

  @override
  Future<void> call(SetMetricsConsentParams params) =>
      repository.setMetricsConsent(uid: params.uid, given: params.given);
}

class SetMetricsConsentParams {
  final String uid;
  final bool given;
  const SetMetricsConsentParams({required this.uid, required this.given});
}