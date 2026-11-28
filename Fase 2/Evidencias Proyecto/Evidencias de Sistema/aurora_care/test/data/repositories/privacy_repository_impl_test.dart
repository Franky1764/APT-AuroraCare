// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'package:aurora_care/data/repositories/privacy_repository_impl.dart';
import 'package:aurora_care/data/sources/account_profile_store.dart';
import 'package:aurora_care/data/sources/privacy_operation_store.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/privacy_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_caregiver_invite_repository.dart';

class _Auth extends Fake implements auth.FirebaseAuth {
  final person = _User();
  @override
  auth.User? get currentUser => person.deleted ? null : person;
}

class _User extends Fake implements auth.User {
  bool acceptedPassword = true;
  bool failDelete = false;
  bool deleted = false;
  @override
  String get uid => 'owner';
  @override
  String get email => 'owner@example.test';
  @override
  Future<auth.UserCredential> reauthenticateWithCredential(
    auth.AuthCredential credential,
  ) async {
    if (!acceptedPassword) {
      throw auth.FirebaseAuthException(code: 'invalid-credential');
    }
    return _Credential();
  }

  @override
  Future<void> delete() async {
    if (failDelete) {
      throw auth.FirebaseAuthException(code: 'network-request-failed');
    }
    deleted = true;
  }
}

class _Credential extends Fake implements auth.UserCredential {}

class _Store extends Fake implements FirebaseFirestore {
  final data = <String, Map<String, dynamic>>{
    'users/owner': {
      'role': 'elder',
      'displayName': 'Ana',
      'consentGiven': true,
    },
    'caregiver_links/token': {
      'adultUID': 'owner',
      'caregiverUID': 'caregiver',
      'status': 'active',
    },
    'caregiver_summaries/token': {'sessions': 1},
    'caregiver_invites/token': {'adultUID': 'owner'},
    'caregiver_invite_state/owner': {'token': 'token'},
    'users/other': {'displayName': 'Otra persona'},
    'cognitive_profiles/other/sessions/keep': {'uuid': 'other'},
  };
  bool failBatch = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final value = await handler(transaction);
    if (failBatch && transaction.deleting) throw StateError('Sin conexión');
    for (final write in transaction.writes) {
      write();
    }
    return value;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
  String? filter;
  Object? expected;
  int pageSize = 100000;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(store, '${this.path}/$path');
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    filter = field as String;
    expected = isEqualTo;
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    pageSize = limit;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Page(
    [
      for (final entry in store.data.entries)
        if (entry.key.startsWith('$path/') &&
            entry.key.substring(path.length + 1).contains('/') == false &&
            (filter == null || entry.value[filter] == expected))
          _QueryDoc(store, entry.key),
    ].take(pageSize).toList(),
  );
}

class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(store.data[path]);
  @override
  Future<void> update(Map<Object, Object?> data) async {
    store.data[path] = {...?store.data[path], ...data.cast<String, dynamic>()};
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.data[path] = {
      if (options?.merge == true) ...?store.data[path],
      ...data,
    };
  }

  @override
  Future<void> delete() async {
    store.data.remove(path);
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class _QueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(this.store, this.path);
  final _Store store;
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  DocumentReference<Map<String, dynamic>> get reference => _Doc(store, path);
  @override
  Map<String, dynamic> data() => store.data[path]!;
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Page(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.store);
  final _Store store;
  bool deleting = false;
  final writes = <void Function()>[];
  @override
  Transaction delete(DocumentReference reference) {
    deleting = true;
    writes.add(() {
      store.data.remove(reference.path);
    });
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes.add(() {
      store.data[reference.path] = {
        ...?store.data[reference.path],
        ...data.cast<String, dynamic>(),
      };
    });
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes.add(() {
      store.data[reference.path] = {
        if (options?.merge == true) ...?store.data[reference.path],
        ...data as Map<String, dynamic>,
      };
    });
    return this;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth authentication;
  late _Store firestore;
  late SharedPreferences preferences;
  late PrivacyRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'mis_recuerdos_v1_owner': '{}',
      'mis_recuerdos_v1_other': '{"keep":true}',
      'profile_portrait_v1_owner': 'avatar:leaf',
      'practice_session_v1_profile_old': 'local-data',
    });
    preferences = await SharedPreferences.getInstance();
    authentication = _Auth();
    firestore = _Store();
    for (var index = 0; index < 220; index++) {
      firestore.data['cognitive_profiles/profile/sessions/$index'] = {
        'uuid': 'profile',
      };
    }
    await AccountProfileStore(preferences, () => 'owner').saveNew(
      'owner',
      CognitiveProfile(
        uuid: 'profile',
        deviceId: 'device',
        createdAt: DateTime(2026),
        activeMode: 3,
      ),
    );
    repository = PrivacyRepositoryImpl(
      authentication,
      firestore,
      preferences,
      FakeCaregiverInviteRepository(),
    );
  });

  test('retirar consentimiento impide escribir pero permite consultar el historial', () async {
    await preferences.remove('practice_session_v1_profile_old');
    await repository.withdrawConsent();
    final store = AccountProfileStore(preferences, () => 'owner');
    expect(store.requireProfileAccess('profile'), 'owner');
    expect(() => store.requireMetricsWriteAccess('profile'), throwsStateError);
    expect(firestore.data['users/owner']!['consentGiven'], false);
  });

  test('una contraseña incorrecta impide cualquier borrado', () async {
    authentication.person.acceptedPassword = false;
    await expectLater(
      repository.delete(PrivacyDeletion.account, 'bad'),
      throwsA(isA<auth.FirebaseAuthException>()),
    );
    expect(firestore.data['users/owner']!['consentGiven'], true);
    expect(PrivacyOperationStore(preferences).read('owner'), isNull);
    expect(
      firestore.data.keys
          .where(
            (path) => path.startsWith('cognitive_profiles/profile/sessions/'),
          )
          .length,
      220,
    );
  });

  test(
    'borra más de un lote de historial y conserva la cuenta y los datos ajenos',
    () async {
      await repository.delete(PrivacyDeletion.history, 'password');
      expect(authentication.person.deleted, false);
      expect(firestore.data['users/owner']!['deletionPending'], false);
      expect(firestore.data['users/owner']!['consentGiven'], false);
      expect(firestore.data['cognitive_profiles/profile'], {
        'privacyDeleted': true,
      });
      expect(
        firestore.data.keys.where(
          (path) => path.startsWith('cognitive_profiles/profile/sessions/'),
        ),
        isEmpty,
      );
      expect(firestore.data.containsKey('caregiver_links/token'), false);
      expect(
        firestore.data.containsKey('cognitive_profiles/other/sessions/keep'),
        true,
      );
      expect(preferences.getString('mis_recuerdos_v1_other'), '{"keep":true}');
      expect(preferences.containsKey('mis_recuerdos_v1_owner'), false);
      expect(
        preferences.containsKey(AccountProfileStore.keyFor('owner')),
        false,
      );
      expect(PrivacyOperationStore(preferences).read('owner'), isNull);
    },
  );

  test('un borrado interrumpido bloquea escrituras y se reanuda sin perder el perfil', () async {
    firestore.failBatch = true;
    await expectLater(
      repository.delete(PrivacyDeletion.history, 'password'),
      throwsStateError,
    );
    expect(
      PrivacyOperationStore(preferences).read('owner')?['uuid'],
      'profile',
    );
    expect(
      () => AccountProfileStore(
        preferences,
        () => 'owner',
      ).requireProfileAccess('profile'),
      throwsStateError,
    );
    firestore.failBatch = false;
    await repository.delete(PrivacyDeletion.history, 'password');
    expect(PrivacyOperationStore(preferences).read('owner'), isNull);
  });

  test('si falla Authentication se puede reintentar después de borrar la identidad', () async {
    authentication.person.failDelete = true;
    await expectLater(
      repository.delete(PrivacyDeletion.account, 'password'),
      throwsA(isA<auth.FirebaseAuthException>()),
    );
    expect(firestore.data.containsKey('users/owner'), false);
    expect(PrivacyOperationStore(preferences).read('owner'), isNotNull);
    authentication.person.failDelete = false;
    await repository.delete(PrivacyDeletion.account, 'password');
    expect(authentication.person.deleted, true);
    expect(PrivacyOperationStore(preferences).read('owner'), isNull);
    expect(firestore.data.containsKey('users/other'), true);
  });
}
