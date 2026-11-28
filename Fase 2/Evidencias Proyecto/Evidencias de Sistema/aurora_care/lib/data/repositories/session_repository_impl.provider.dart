// data/repositories/session_repository_impl.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../domain/repositories/session_repository.dart';
import 'session_repository_impl.dart';
import '../../core/auth_account_provider.dart';
import '../sources/account_profile_store.provider.dart';

/// El repositorio de sesiones, ya armado con su Firestore inyectado.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  ref.watch(authAccountChangesProvider);
  return SessionRepositoryImpl(
    firestore,
    ref.watch(accountProfileStoreProvider),
  );
});
