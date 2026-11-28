// lib/domain/usecases/get_active_profile.dart
import '../entities/cognitive_profile.dart';
import '../repositories/cognitive_profile_repository.dart';
import 'usecase.dart';

class GetActiveProfile implements UseCase<CognitiveProfile?, NoParams> {
  final CognitiveProfileRepository repository;
  const GetActiveProfile(this.repository);

  @override
  Future<CognitiveProfile?> call(NoParams params) =>
      repository.getLocalProfile();
}