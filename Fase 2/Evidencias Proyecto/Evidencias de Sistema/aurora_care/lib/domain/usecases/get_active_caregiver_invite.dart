// domain/usecases/get_active_caregiver_invite.dart
import '../entities/caregiver_invite.dart';
import '../repositories/caregiver_invite_repository.dart';
import 'usecase.dart';

/// La invitación activa del adulto mayor, si existe. Se usa al reabrir
/// la app para no generar una invitación nueva mientras la anterior
/// siga vigente.
class GetActiveCaregiverInvite
    implements UseCase<CaregiverInvite?, NoParams> {
  final CaregiverInviteRepository repository;
  const GetActiveCaregiverInvite(this.repository);

  @override
  Future<CaregiverInvite?> call(NoParams params) =>
      repository.getActiveInvite();
}
