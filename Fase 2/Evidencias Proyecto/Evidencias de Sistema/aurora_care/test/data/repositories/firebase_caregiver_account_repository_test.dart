// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/data/repositories/firebase_caregiver_account_repository.dart';
import 'package:aurora_care/data/sources/session_role_store.dart';
import 'package:aurora_care/domain/entities/account_role.dart';
import 'package:aurora_care/domain/exceptions/caregiver_auth_exception.dart';

class Account extends Fake implements fb.User {
  bool deleted = false;
  @override
  String get uid => 'caregiver';
  @override
  String get email => 'caregiver@example.test';
  @override
  Future<void> delete() async {
    deleted = true;
  }
}

class Credential extends Fake implements fb.UserCredential {
  Credential(this.account);
  final Account account;
  @override
  fb.User? get user => account;
}

class Auth extends Fake implements fb.FirebaseAuth {
  final account = Account();
  int signOuts = 0;
  fb.FirebaseAuthException? failure;
  @override
  fb.User? get currentUser => account;
  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    return Credential(account);
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => Credential(account);
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class Document extends Fake implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? value = {
    'role': 'caregiver',
    'displayName': 'Persona cuidadora',
  };
  Object? writeError;
  bool deleted = false;
  Completer<void>? reading;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    if (reading != null) await reading!.future;
    return Snapshot(value);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (writeError != null) throw writeError!;
    value = data;
  }

  @override
  Future<void> delete() async {
    value = null;
    deleted = true;
  }
}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final document = Document();
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'caregiver');
    return document;
  }
}

class Store extends Fake implements FirebaseFirestore {
  final users = Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    // Cualquier acceso a perfiles cognitivos o vínculos hace fallar la prueba.
    expect(path, 'users');
    return users;
  }
}

void main() {
  late Auth auth;
  late Store firestore;
  late SessionRoleStore roles;
  late FirebaseCaregiverAccountRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = Auth();
    firestore = Store();
    roles = SessionRoleStore(await SharedPreferences.getInstance());
    repository = FirebaseCaregiverAccountRepository(auth, firestore, roles);
  });
  test(
    'registration writes only identity and never creates cognitive data',
    () async {
      final result = await repository.register(
        name: ' Persona cuidadora ',
        email: 'caregiver@example.test',
        password: 'secret123',
      );
      expect(result.role, AccountRole.caregiver);
      expect(firestore.users.document.value!.keys.toSet(), {
        'displayName',
        'createdAt',
        'role',
        'currentMode',
        'consentGiven',
        'consentDate',
      });
      expect(roles.read('caregiver'), AccountRole.caregiver);
      expect(roles.read('another'), AccountRole.unknown);
    },
  );
  test('login requires server confirmation of caregiver role', () async {
    final result = await repository.login(
      email: 'caregiver@example.test',
      password: 'secret123',
    );
    expect(result.role, AccountRole.caregiver);
    expect(auth.signOuts, 0);
  });
  test(
    'elder and unknown roles cannot enter through caregiver login',
    () async {
      for (final role in ['elder', null, 'invalid']) {
        firestore.users.document.value = {'role': role};
        await expectLater(
          repository.login(
            email: 'caregiver@example.test',
            password: 'secret123',
          ),
          throwsA(
            isA<CaregiverAuthException>().having(
              (e) => e.failure,
              'failure',
              CaregiverAuthFailure.wrongRole,
            ),
          ),
        );
      }
      expect(auth.signOuts, 3);
    },
  );
  test(
    'registration storage failure rolls back only the newly created identity',
    () async {
      firestore.users.document.writeError = StateError('denied');
      await expectLater(
        repository.register(
          name: 'Cuidador',
          email: 'caregiver@example.test',
          password: 'secret123',
        ),
        throwsA(isA<CaregiverAuthException>()),
      );
      expect(firestore.users.document.deleted, true);
      expect(auth.account.deleted, true);
    },
  );
  test('invalid credentials produce a safe typed error', () async {
    auth.failure = fb.FirebaseAuthException(code: 'invalid-credential');
    await expectLater(
      repository.login(email: 'caregiver@example.test', password: 'secret123'),
      throwsA(
        isA<CaregiverAuthException>().having(
          (e) => e.failure,
          'failure',
          CaregiverAuthFailure.invalidCredentials,
        ),
      ),
    );
  });
}
