// domain/usecases/cancel_caregiver_invite.dart
import '../repositories/caregiver_invite_repository.dart';
import 'usecase.dart';

/// El adulto mayor cancela manualmente una invitación antes de que
/// expire.
class CancelCaregiverInvite
    implements UseCase<void, CancelCaregiverInviteParams> {
  final CaregiverInviteRepository repository;
  const CancelCaregiverInvite(this.repository);

  @override
  Future<void> call(CancelCaregiverInviteParams params) =>
      repository.cancelInvite(params.token);
}

class CancelCaregiverInviteParams {
  final String token;
  const CancelCaregiverInviteParams({required this.token});
}
