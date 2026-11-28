// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/data/repositories/user_session_repository_impl.dart';
import 'package:aurora_care/data/sources/session_role_store.dart';
import 'package:aurora_care/domain/entities/account_role.dart';

class User extends Fake implements fb.User {
  @override
  String get uid => 'account-a';
  @override
  String get email => 'a@example.test';
  @override
  Future<void> reload() async {}
}

class Auth extends Fake implements fb.FirebaseAuth {
  @override
  fb.User? get currentUser => User();
}

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class Document extends Fake implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? value;
  bool offline = false;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (offline) throw StateError('offline');
    return Snapshot(value);
  }
}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final document = Document();
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'account-a');
    return document;
  }
}

class Store extends Fake implements FirebaseFirestore {
  final users = Collection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return users;
  }
}

void main() {
  late Store firestore;
  late SessionRoleStore roles;
  late UserSessionRepositoryImpl repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    roles = SessionRoleStore(await SharedPreferences.getInstance());
    firestore = Store();
    repository = UserSessionRepositoryImpl(Auth(), firestore, roles);
  });
  test(
    'caregiver role is restored without creating an elder profile',
    () async {
      firestore.users.document.value = {
        'role': 'caregiver',
        'displayName': 'Cuidador',
        'currentMode': 0,
      };
      final session = await repository.readSession();
      expect(session!.role, AccountRole.caregiver);
      expect(roles.read('account-a'), AccountRole.caregiver);
    },
  );
  test(
    'legacy identity document without role remains an elder account',
    () async {
      firestore.users.document.value = {
        'displayName': 'Persona',
        'currentMode': 2,
      };
      expect((await repository.readSession())!.role, AccountRole.elder);
    },
  );
  test('offline startup uses only the current account cached role', () async {
    await roles.save('account-a', AccountRole.caregiver);
    firestore.users.document.offline = true;
    expect((await repository.readSession())!.role, AccountRole.caregiver);
  });
  test(
    'another accounts cached role never grants caregiver navigation',
    () async {
      await roles.save('account-b', AccountRole.caregiver);
      firestore.users.document.offline = true;
      expect((await repository.readSession())!.role, AccountRole.unknown);
    },
  );
  test(
    'server-confirmed missing identity does not use stale cached role',
    () async {
      await roles.save('account-a', AccountRole.caregiver);
      expect((await repository.readSession())!.role, AccountRole.unknown);
    },
  );
}
