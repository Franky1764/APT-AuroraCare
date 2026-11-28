// domain/usecases/watch_caregiver_invite.dart
import '../entities/invite_status.dart';
import '../repositories/caregiver_invite_repository.dart';
import 'stream_usecase.dart';

/// Observa en tiempo real el estado de una invitación: activa, usada o
/// expirada.
class WatchCaregiverInvite
    implements StreamUseCase<InviteStatus, WatchCaregiverInviteParams> {
  final CaregiverInviteRepository repository;
  const WatchCaregiverInvite(this.repository);

  @override
  Stream<InviteStatus> call(WatchCaregiverInviteParams params) =>
      repository.watchInvite(params.token);
}

class WatchCaregiverInviteParams {
  final String token;
  const WatchCaregiverInviteParams({required this.token});
}
