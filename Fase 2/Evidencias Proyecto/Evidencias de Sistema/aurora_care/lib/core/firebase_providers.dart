// core/firebase_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una sola instancia de Firestore para toda la app.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Una sola instancia de Firebase Auth para toda la app.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Instancia de SharedPreferences. SharedPreferences.getInstance() es
/// asíncrono, así que este provider NO puede resolverlo por sí solo —
/// debe sobreescribirse en main.dart con la instancia real, obtenida
/// con `await` antes de runApp(). Si ves este error en pantalla, significa
/// que faltó el override en ProviderScope.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse en main.dart antes de runApp',
  );
});