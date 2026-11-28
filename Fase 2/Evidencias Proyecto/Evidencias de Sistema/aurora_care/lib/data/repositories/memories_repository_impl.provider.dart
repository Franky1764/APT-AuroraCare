// data/repositories/memories_repository_impl.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/repositories/memories_repository.dart';
import 'memories_repository_impl.dart';

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MemoriesRepositoryImpl(prefs);
});
