import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Invalida los repositorios cuando Firebase cambia de cuenta o cierra sesión.
final authAccountChangesProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);
  yield auth.currentUser?.uid;
  yield* auth.authStateChanges().map((user) => user?.uid).distinct();
});

/// Cuenta efectiva de Firebase; la navegación puede actualizarse después.
final authenticatedAccountIdProvider = Provider<String?>((ref) {
  ref.watch(authAccountChangesProvider);
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
});
