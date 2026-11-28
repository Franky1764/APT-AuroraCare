// data/repositories/cognitive_profile_repository_impl.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/repositories/cognitive_profile_repository.dart';
import 'cognitive_profile_repository_impl.dart';
import '../sources/account_profile_store.provider.dart';
import '../../core/auth_account_provider.dart';

final cognitiveProfileRepositoryProvider = Provider<CognitiveProfileRepository>(
  (ref) {
    final firestore = ref.watch(firestoreProvider);
    ref.watch(authAccountChangesProvider);
    return CognitiveProfileRepositoryImpl(
      firestore,
      ref.watch(accountProfileStoreProvider),
    );
  },
);
