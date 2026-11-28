// domain/usecases/create_caregiver_invite.dart
import '../entities/caregiver_invite.dart';
import '../repositories/caregiver_invite_repository.dart';
import 'usecase.dart';

/// Crea una invitación nueva para vincular un cuidador (F8). Descarta
/// la anterior si había una activa.
class CreateCaregiverInvite implements UseCase<CaregiverInvite, NoParams> {
  final CaregiverInviteRepository repository;
  const CreateCaregiverInvite(this.repository);

  @override
  Future<CaregiverInvite> call(NoParams params) => repository.createInvite();
}
