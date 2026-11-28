import '../../data/repositories/firestore_caregiver_invite_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/navigation_session.dart';
import '../../core/auth_account_provider.dart';
import '../../domain/entities/account_role.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';

final caregiverConnectionProvider = StreamProvider.autoDispose<bool>((ref) {
  final session = ref.watch(navigationSessionProvider).session;
  if (session?.role != AccountRole.caregiver ||
      ref.watch(authenticatedAccountIdProvider) != session?.uid) {
    return Stream.value(false);
  }
  final repository = ref.watch(caregiverInviteRepositoryProvider);
  return repository is FirestoreCaregiverInviteRepository
      ? repository.publishCaregiverName()
      : repository.watchConnection();
});

final linkedCaregiverIdentityProvider =
    StreamProvider.autoDispose<({bool linked, String? name})>((ref) {
      final session = ref.watch(navigationSessionProvider).session;
      if (session?.role != AccountRole.elder ||
          ref.watch(authenticatedAccountIdProvider) != session?.uid) {
        return Stream.value((linked: false, name: null));
      }
      final repository = ref.watch(caregiverInviteRepositoryProvider);
      return repository is FirestoreCaregiverInviteRepository
          ? repository.watchCaregiverIdentity()
          : Stream.value((linked: false, name: null));
    });
