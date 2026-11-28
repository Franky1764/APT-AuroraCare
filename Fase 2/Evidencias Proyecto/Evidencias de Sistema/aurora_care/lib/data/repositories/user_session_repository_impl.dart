import '../../domain/entities/account_role.dart';
import '../sources/session_role_store.dart';

// data/repositories/user_session_repository_impl.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/session_info.dart';
import '../../domain/repositories/user_session_repository.dart';

class UserSessionRepositoryImpl implements UserSessionRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final SessionRoleStore _roles;

  const UserSessionRepositoryImpl(
    this._firebaseAuth,
    this._firestore,
    this._roles,
  );

  static const _timeout = Duration(seconds: 4);

  @override
  Future<SessionInfo?> readSession() async {
    var fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;

    try {
      await fbUser.reload().timeout(_timeout);
      // reload() actualiza el usuario cacheado; se vuelve a leer para
      // tener los datos frescos (o null si en el camino se cerró sesión).
      fbUser = _firebaseAuth.currentUser;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled') {
        await _firebaseAuth.signOut();
        return null;
      }
      // Cualquier otro código (ej. problemas de red): conserva la sesión.
    } catch (_) {
      // Timeout u otro error no de Firebase: conserva la sesión.
    }

    if (fbUser == null) return null;

    final email = fbUser.email ?? '';

    try {
      final doc = await _firestore
          .collection('users')
          .doc(fbUser.uid)
          .get()
          .timeout(_timeout);
      if (_firebaseAuth.currentUser?.uid != fbUser.uid) return null;
      final data = doc.data();
      if (data == null) {
        return SessionInfo(
          uid: fbUser.uid,
          email: email,
          role: AccountRole.unknown,
        );
      }
      final role = readAccountRole(data['role']);
      try {
        await _roles.save(fbUser.uid, role);
      } catch (_) {}
      if (_firebaseAuth.currentUser?.uid != fbUser.uid) return null;
      return SessionInfo(
        role: role,
        uid: fbUser.uid,
        email: email,
        displayName: data['displayName'] as String?,
        consentGiven: data['consentGiven'] as bool?,
        currentMode: data['currentMode'] as int?,
        // Documento leído: presente = aceptado, ausente = pendiente.
        disclaimerAccepted: data['disclaimerAcceptedAt'] != null,
      );
    } catch (_) {
      // Sin red o timeout se conserva solo el rol conocido de esta cuenta.
      if (_firebaseAuth.currentUser?.uid != fbUser.uid) return null;
      return SessionInfo(
        uid: fbUser.uid,
        email: email,
        role: _roles.read(fbUser.uid),
      );
    }
  }
}
