// domain/usecases/get_or_create_cognitive_profile.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/cognitive_profile_repository_impl.provider.dart';
import 'get_or_create_cognitive_profile.dart';

final getOrCreateCognitiveProfileProvider =
    Provider<GetOrCreateCognitiveProfile>((ref) {
  return GetOrCreateCognitiveProfile(
    ref.watch(cognitiveProfileRepositoryProvider),
  );
});