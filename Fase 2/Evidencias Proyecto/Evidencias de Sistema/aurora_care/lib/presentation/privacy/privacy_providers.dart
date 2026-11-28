import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../data/repositories/privacy_repository_impl.dart';
import '../../data/sources/privacy_actions_platform.dart';
import '../../data/sources/privacy_operation_store.dart';
import '../../domain/entities/privacy_data.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';
import '../../domain/repositories/privacy_repository.dart';

final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => PrivacyRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(caregiverInviteRepositoryProvider),
    account: ref.watch(navigationSessionProvider).session?.uid,
  ),
);

final privacyActionsProvider = Provider<PrivacyActionsPlatform>(
  (ref) => const PrivacyActionsPlatform(),
);

final privacyDataProvider = FutureProvider.autoDispose<PrivacyData>(
  (ref) => ref.watch(privacyRepositoryProvider).readData(),
);

final pendingPrivacyDeletionProvider = Provider<PrivacyDeletion?>((ref) {
  final uid = ref.watch(navigationSessionProvider).session?.uid;
  if (uid == null) return null;
  final saved = PrivacyOperationStore(ref.watch(sharedPreferencesProvider))
      .read(uid);
  if (saved == null) return null;
  return PrivacyDeletion.values.byName(saved['kind'] as String);
});

final privacyActionProvider = AsyncNotifierProvider<PrivacyAction, void>(
  PrivacyAction.new,
);

class PrivacyAction extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> run(Future<void> Function(PrivacyRepository) operation) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => operation(ref.read(privacyRepositoryProvider)),
    );
    ref.invalidate(privacyDataProvider);
    ref.invalidate(pendingPrivacyDeletionProvider);
    return !state.hasError;
  }
}
