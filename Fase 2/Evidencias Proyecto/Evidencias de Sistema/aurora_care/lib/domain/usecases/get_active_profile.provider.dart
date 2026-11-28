// lib/domain/usecases/get_active_profile.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/cognitive_profile_repository_impl.provider.dart';
import 'get_active_profile.dart';

final getActiveProfileProvider = Provider<GetActiveProfile>((ref) {
  return GetActiveProfile(ref.watch(cognitiveProfileRepositoryProvider));
});