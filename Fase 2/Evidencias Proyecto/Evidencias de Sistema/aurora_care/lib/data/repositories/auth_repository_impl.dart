import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/account_role.dart';

// data/repositories/auth_repository_impl.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/exceptions/caregiver_revocation_unavailable.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  const AuthRepositoryImpl(this._firebaseAuth, this._firestore, {this.preferences});
  final SharedPreferences? preferences;

  AuthErrorType _mapFirebaseCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return AuthErrorType.emailAlreadyInUse;
      case 'invalid-email':
        return AuthErrorType.invalidEmail;
      case 'weak-password':
      // Política de contraseñas de Firebase (proyecto DuocAuroraCare) en
      // modo "Notificar aplicación": este código casi nunca debería
      // llegar, porque la app ya valida con PasswordPolicy antes de
      // registrar — se mapea igual, por si Firebase cambia a modo
      // "Aplicar" más adelante.
      case 'password-does-not-meet-requirements':
        return AuthErrorType.weakPassword;
      case 'user-not-found':
        return AuthErrorType.userNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return AuthErrorType.wrongPassword;
      case 'network-request-failed':
        return AuthErrorType.networkError;
      case 'too-many-requests':
        return AuthErrorType.tooManyRequests;
      case 'user-disabled':
        return AuthErrorType.userDisabled;
      default:
        return AuthErrorType.unknown;
    }
  }

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException(AuthErrorType.unknown);
      }

      await fbUser.updateDisplayName(displayName);

      final createdAt = DateTime.now();

      // Documento en Firestore: solo identidad básica, sin métricas ni UUID
      // cognitivo (ver ARCHITECTURE.md sección 6 y 7 — separación identidad/comportamiento).
      // currentMode = 0: aún no elige modo. Se actualiza al completar la
      // selección de modo (F1 paso 5). El consentimiento de métricas
      // (consentGiven) se pide antes de la primera sesión (F4 paso 0).
      await _firestore.collection('users').doc(fbUser.uid).set({
        'displayName': displayName,
        'createdAt': createdAt,
        'consentGiven': false,
        'consentDate': null,
        'currentMode': 0,
      });

      return User(
        uid: fbUser.uid,
        displayName: displayName,
        createdAt: createdAt,
        consentGiven: false,
        consentDate: null,
        currentMode: 0,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code));
    }
  }

  @override
  Future<User> loginElder({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const AuthException(AuthErrorType.unknown);
      }

      final doc = await _firestore
          .collection('users')
          .doc(fbUser.uid)
          .get(const GetOptions(source: Source.server));
      final data = doc.data();

      if (data == null) {
        throw const AuthException(AuthErrorType.unknown);
      }

      if (readAccountRole(data['role']) != AccountRole.elder) {
        await _firebaseAuth.signOut();
        throw const AuthException(AuthErrorType.wrongRole);
      }

      return User(
        uid: fbUser.uid,
        displayName: data['displayName'] as String? ?? fbUser.displayName ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        consentGiven: data['consentGiven'] as bool? ?? false,
        consentDate: (data['consentDate'] as Timestamp?)?.toDate(),
        currentMode: data['currentMode'] as int? ?? 0,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code));
    }
  }

  @override
  Future<void> acceptDisclaimer({required String uid}) async {
    if (_firebaseAuth.currentUser?.uid != uid) {
      throw StateError('Se necesita la sesión del titular');
    }
    final userRef = _firestore.collection('users').doc(uid);
    // Requiere confirmación del servidor; sin conexión no se concede acceso.
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw StateError('No existe el usuario');
      if (snapshot.data()?['disclaimerAcceptedAt'] == null) {
        transaction.update(userRef, {
          'disclaimerAcceptedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Future<bool> hasMetricsConsent({required String uid}) async {
    if (preferences?.getBool('privacy_metrics_withdrawn_$uid') == true) return false;
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['consentGiven'] as bool?) ?? false;
  }

  @override
  Future<void> setMetricsConsent({
    required String uid,
    required bool given,
  }) async {
    if (_firebaseAuth.currentUser?.uid != uid) {
      throw StateError('Se necesita la sesión del titular');
    }
    if (!given) {
      await preferences?.setBool('privacy_metrics_withdrawn_$uid', true);
    }
    await _firestore.collection('users').doc(uid).update({
      'consentGiven': given,
      'consentDate': given ? FieldValue.serverTimestamp() : null,
    });
    if (_firebaseAuth.currentUser?.uid == uid && given) {
      await preferences?.remove('privacy_metrics_withdrawn_$uid');
    }
  }

  @override
  Future<void> updateCurrentMode({
    required String uid,
    required int mode,
  }) async {
    if (mode != 2 && mode != 3) {
      throw ArgumentError.value(mode, 'mode', 'Debe ser 2 o 3');
    }
    if (_firebaseAuth.currentUser?.uid != uid) {
      throw StateError('Se necesita la sesión del titular');
    }
    final userRef = _firestore.collection('users').doc(uid);
    // La transacción requiere conexión y comprueba el modo del servidor,
    // incluso si otra pantalla o dispositivo cambió el modo guardado.
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw StateError('No existe el usuario');
      final data = snapshot.data()!;
      // El QR actual es una simulación y no concede acceso real. Si una
      // implementación futura registra acceso real, exige su revocación
      // efectiva antes de habilitar este flujo; nunca fingir que se retiró.
      if (mode == 2 && data['caregiverSharingEnabled'] == true) {
        throw const CaregiverRevocationUnavailable();
      }
      final previousMode = data['currentMode'];
      final epoch = data['caregiverAccessEpoch'];
      if (epoch != null && (epoch is! int || epoch < 0)) {
        throw StateError('No se pudo confirmar el estado de acceso');
      }
      transaction.update(userRef, {
        'currentMode': mode,
        if (mode == 2 || previousMode != 3) 'caregiverSharingEnabled': false,
        if (mode == 2 && previousMode == 3)
          'caregiverAccessEpoch': (epoch as int? ?? 0) + 1,
      });
    });
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }
}
