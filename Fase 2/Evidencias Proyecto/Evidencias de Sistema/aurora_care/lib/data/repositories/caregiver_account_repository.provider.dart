import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/repositories/caregiver_account_repository.dart';
import '../sources/session_role_store.dart';
import 'firebase_caregiver_account_repository.dart';

final caregiverAccountRepositoryProvider = Provider<CaregiverAccountRepository>(
  (ref) {
    return FirebaseCaregiverAccountRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
      SessionRoleStore(ref.watch(sharedPreferencesProvider)),
    );
  },
);
