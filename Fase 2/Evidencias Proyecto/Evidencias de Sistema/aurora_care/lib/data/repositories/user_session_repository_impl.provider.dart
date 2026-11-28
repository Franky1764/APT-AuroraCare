import '../sources/session_role_store.dart';

// data/repositories/user_session_repository_impl.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/repositories/user_session_repository.dart';
import 'user_session_repository_impl.dart';

final userSessionRepositoryProvider = Provider<UserSessionRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return UserSessionRepositoryImpl(
    firebaseAuth,
    firestore,
    SessionRoleStore(ref.watch(sharedPreferencesProvider)),
  );
});
