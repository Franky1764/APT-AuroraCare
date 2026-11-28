import '../../core/firebase_providers.dart';
import '../../core/auth_account_provider.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';
import 'firestore_caregiver_invite_repository.dart';

/// Invitaciones reales. El servidor valida vencimiento y canje único.
final caregiverInviteRepositoryOverride = caregiverInviteRepositoryProvider
    .overrideWith((ref) {
      ref.watch(authAccountChangesProvider);
      return FirestoreCaregiverInviteRepository(
        ref.watch(firestoreProvider),
        ref.watch(firebaseAuthProvider),
      );
    });
