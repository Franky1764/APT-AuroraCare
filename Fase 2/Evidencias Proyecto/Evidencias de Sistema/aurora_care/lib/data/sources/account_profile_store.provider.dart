import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'account_profile_store.dart';

final accountProfileStoreProvider = Provider<AccountProfileStore>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AccountProfileStore(
    ref.watch(sharedPreferencesProvider),
    () => auth.currentUser?.uid,
  );
});
