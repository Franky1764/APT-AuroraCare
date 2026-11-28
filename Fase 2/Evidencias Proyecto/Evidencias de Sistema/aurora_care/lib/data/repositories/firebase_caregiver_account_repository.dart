import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/account_role.dart';
import '../../domain/entities/session_info.dart';
import '../../domain/exceptions/caregiver_auth_exception.dart';
import '../../domain/repositories/caregiver_account_repository.dart';
import '../sources/session_role_store.dart';

class FirebaseCaregiverAccountRepository implements CaregiverAccountRepository {
  const FirebaseCaregiverAccountRepository(
    this.auth,
    this.firestore,
    this.roles,
  );
  final fb.FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SessionRoleStore roles;

  void _check(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const CaregiverAuthException(CaregiverAuthFailure.unknown);
    }
  }

  CaregiverAuthException _mapped(fb.FirebaseAuthException error) =>
      CaregiverAuthException(switch (error.code) {
        'email-already-in-use' => CaregiverAuthFailure.emailInUse,
        'invalid-email' => CaregiverAuthFailure.invalidEmail,
        // Política de contraseñas de Firebase en modo "Notificar
        // aplicación": casi nunca debería llegar, porque la pantalla ya
        // valida con PasswordPolicy antes de registrar — se mapea
        // igual, por si Firebase cambia a modo "Aplicar" más adelante.
        'weak-password' ||
        'password-does-not-meet-requirements' =>
          CaregiverAuthFailure.weakPassword,
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'user-disabled' => CaregiverAuthFailure.invalidCredentials,
        'network-request-failed' => CaregiverAuthFailure.network,
        'too-many-requests' => CaregiverAuthFailure.tooManyRequests,
        _ => CaregiverAuthFailure.unknown,
      });

  @override
  Future<SessionInfo> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final displayName = name.trim();
    if (displayName.isEmpty || displayName.length > 80) {
      throw const CaregiverAuthException(CaregiverAuthFailure.unknown);
    }
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const CaregiverAuthException(CaregiverAuthFailure.unknown);
      }
      _check(user.uid);
      try {
        // Solo identidad. No se crea un perfil cognitivo ni un vínculo.
        await firestore.collection('users').doc(user.uid).set({
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'caregiver',
          'currentMode': 0,
          'consentGiven': false,
          'consentDate': null,
        });
      } catch (_) {
        // Si no se pudo crear el documento, no dejar una cuenta que aparente
        // estar lista. Se elimina exclusivamente el usuario recién creado.
        try {
          await firestore.collection('users').doc(user.uid).delete();
          await user.delete();
        } catch (_) {
          throw const CaregiverAuthException(
            CaregiverAuthFailure.incompleteRegistration,
          );
        }
        throw const CaregiverAuthException(
          CaregiverAuthFailure.incompleteRegistration,
        );
      }
      _check(user.uid);
      // El caché de navegación es auxiliar: no invalida un registro confirmado.
      try {
        await roles.save(user.uid, AccountRole.caregiver);
      } catch (_) {}
      _check(user.uid);
      return SessionInfo(
        uid: user.uid,
        email: user.email ?? email.trim(),
        displayName: displayName,
        role: AccountRole.caregiver,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw _mapped(error);
    }
  }

  @override
  Future<SessionInfo> login({
    required String email,
    required String password,
  }) async {
    fb.User? user;
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      user = credential.user;
      if (user == null) {
        throw const CaregiverAuthException(
          CaregiverAuthFailure.invalidCredentials,
        );
      }
      final doc = await firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      _check(user.uid);
      final data = doc.data();
      if (data == null ||
          readAccountRole(data['role']) != AccountRole.caregiver) {
        throw const CaregiverAuthException(CaregiverAuthFailure.wrongRole);
      }
      try {
        await roles.save(user.uid, AccountRole.caregiver);
      } catch (_) {}
      _check(user.uid);
      return SessionInfo(
        uid: user.uid,
        email: user.email ?? email.trim(),
        displayName: data['displayName'] as String?,
        role: AccountRole.caregiver,
      );
    } catch (error) {
      if (user != null && auth.currentUser?.uid == user.uid) {
        await auth.signOut();
      }
      if (error is fb.FirebaseAuthException) throw _mapped(error);
      rethrow;
    }
  }
}
