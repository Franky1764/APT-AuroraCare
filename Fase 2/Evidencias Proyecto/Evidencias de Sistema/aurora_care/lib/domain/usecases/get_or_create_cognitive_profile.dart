// domain/usecases/get_or_create_cognitive_profile.dart
import '../entities/cognitive_profile.dart';
import '../repositories/cognitive_profile_repository.dart';
import 'usecase.dart';

class GetOrCreateCognitiveProfile
    implements UseCase<CognitiveProfile, GetOrCreateCognitiveProfileParams> {
  final CognitiveProfileRepository repository;

  const GetOrCreateCognitiveProfile(this.repository);

  @override
  Future<CognitiveProfile> call(
    GetOrCreateCognitiveProfileParams params,
  ) async {
    final existing = await repository.getLocalProfile();

    if (existing != null) {
      if (existing.activeMode == params.activeMode) return existing;
      await repository.updateActiveMode(
        uuid: existing.uuid,
        activeMode: params.activeMode,
      );
      return CognitiveProfile(
        hasUnassignedHistory: existing.hasUnassignedHistory,
        uuid: existing.uuid,
        deviceId: existing.deviceId,
        createdAt: existing.createdAt,
        activeMode: params.activeMode,
      );
    }

    return repository.createProfile(activeMode: params.activeMode);
  }
}

class GetOrCreateCognitiveProfileParams {
  final int activeMode;
  const GetOrCreateCognitiveProfileParams({required this.activeMode});
}
