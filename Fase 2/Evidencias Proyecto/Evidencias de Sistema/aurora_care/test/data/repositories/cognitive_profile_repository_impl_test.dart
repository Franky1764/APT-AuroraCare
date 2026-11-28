import 'package:aurora_care/domain/entities/cognitive_profile.dart';

// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/data/repositories/cognitive_profile_repository_impl.dart';
import 'package:aurora_care/data/sources/account_profile_store.dart';
import 'package:aurora_care/domain/usecases/get_or_create_cognitive_profile.dart';

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class Document extends Fake implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? value;
  Object? readError, writeError;
  Completer<void>? reading;
  int writes = 0;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (reading != null) await reading!.future;
    if (readError != null) throw readError!;
    return Snapshot(value);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (writeError != null) throw writeError!;
    expect(options?.merge, true);
    expect(data.keys, isNot(contains('uid')));
    expect(data.keys, isNot(contains('email')));
    writes++;
    value = {...?value, ...data};
  }
}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final documents = <String, Document>{};
  Object? writeError;
  @override
  Document doc([String? path]) =>
      documents.putIfAbsent(path!, () => Document()..writeError = writeError);
}

class Store extends Fake implements FirebaseFirestore {
  final profiles = Collection();
  @override
  Collection collection(String path) {
    expect(path, 'cognitive_profiles');
    return profiles;
  }
}

void main() {
  late SharedPreferences prefs;
  late AccountProfileStore local;
  late CognitiveProfileRepositoryImpl repository;
  late Store firestore;
  String? account;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    account = 'adult-a';
    local = AccountProfileStore(prefs, () => account);
    firestore = Store();
    repository = CognitiveProfileRepositoryImpl(firestore, local);
  });
  Future<CognitiveProfile> prepare(int mode) => GetOrCreateCognitiveProfile(
    repository,
  )(GetOrCreateCognitiveProfileParams(activeMode: mode));

  test('accounts retain distinct profiles through sign out and repeated mode changes', () async {
    final a = await prepare(2);
    account = null;
    expect(await repository.getLocalProfile(), isNull);
    account = 'adult-b';
    final b = await prepare(3);
    expect(b.uuid, isNot(a.uuid));
    for (final owner in ['adult-a', 'adult-b']) {
      account = owner;
      final original = owner == 'adult-a' ? a : b;
      for (final mode in [3, 2, 3, 2]) {
        final profile = await prepare(mode);
        expect(profile.uuid, original.uuid);
        expect(profile.createdAt, original.createdAt);
        expect(profile.deviceId, original.deviceId);
      }
    }
    expect(firestore.profiles.documents.length, 2);
  });
  test(
    'legacy reference is retained but never assigned to the signing-in account',
    () async {
      await prefs.setString('cognitive_profile_uuid', 'legacy-private-profile');
      await prefs.setString('cognitive_profile_device_id', 'legacy-device');
      await prefs.setString(
        'cognitive_profile_created_at',
        DateTime(2026).toIso8601String(),
      );
      expect(await repository.getLocalProfile(), isNull);
      final profile = await prepare(2);
      expect(profile.uuid, isNot('legacy-private-profile'));
      expect(profile.hasUnassignedHistory, true);
      expect(
        prefs.getString('cognitive_profile_uuid'),
        'legacy-private-profile',
      );
      expect(
        firestore.profiles.documents,
        isNot(contains('legacy-private-profile')),
      );
    },
  );
  test('corrupt account record never rotates its reference', () async {
    await prefs.setString(
      AccountProfileStore.keyFor(account!),
      '{"uuid":"keep-this-uuid"}',
    );
    await expectLater(prepare(3), throwsStateError);
    expect(
      prefs.getString(AccountProfileStore.keyFor(account!)),
      contains('keep-this-uuid'),
    );
    expect(firestore.profiles.documents, isEmpty);
  });
  test('missing parent retains the same account UUID', () async {
    final original = await prepare(2);
    firestore.profiles.doc(original.uuid).value = null;
    final repaired = await prepare(3);
    expect(repaired.uuid, original.uuid);
    expect(firestore.profiles.doc(original.uuid).value!['activeMode'], 3);
  });
  test('read failure never generates another profile', () async {
    final original = await prepare(2);
    firestore.profiles.doc(original.uuid).readError = StateError('offline');
    await expectLater(prepare(3), throwsStateError);
    expect(local.read(account!)!.uuid, original.uuid);
    expect(firestore.profiles.documents.length, 1);
  });
  test(
    'account change during read never returns previous account history',
    () async {
      final original = await prepare(2);
      final gate = Completer<void>();
      firestore.profiles.doc(original.uuid).reading = gate;
      final pending = repository.getLocalProfile();
      final checked = expectLater(pending, throwsStateError);
      account = 'adult-b';
      gate.complete();
      await checked;
      expect(await repository.getLocalProfile(), isNull);
    },
  );
  test('another account cannot update the first account profile', () async {
    final original = await prepare(2);
    account = 'adult-b';
    await expectLater(
      repository.updateActiveMode(uuid: original.uuid, activeMode: 3),
      throwsStateError,
    );
    expect(firestore.profiles.doc(original.uuid).value!['activeMode'], 2);
  });
  test('simultaneous creation shares one stable reference', () async {
    final results = await Future.wait([
      repository.createProfile(activeMode: 2),
      repository.createProfile(activeMode: 2),
    ]);
    expect(results.first.uuid, results.last.uuid);
    expect(firestore.profiles.documents.length, 1);
  });
  test('a second explicit creation cannot replace an existing UUID', () async {
    final original = await prepare(2);
    await expectLater(
      repository.createProfile(activeMode: 3),
      throwsStateError,
    );
    expect(local.read(account!)!.uuid, original.uuid);
  });
  test(
    'signed-out creation is denied before storage or network writes',
    () async {
      account = null;
      await expectLater(
        repository.createProfile(activeMode: 2),
        throwsStateError,
      );
      expect(prefs.getKeys(), isEmpty);
      expect(firestore.profiles.documents, isEmpty);
    },
  );
  test(
    'failed remote creation retains one recoverable local reference',
    () async {
      firestore.profiles.writeError = StateError('offline');
      await expectLater(
        repository.createProfile(activeMode: 2),
        throwsStateError,
      );
      final original = local.read(account!)!;
      firestore.profiles.doc(original.uuid).writeError = null;
      final retried = await prepare(3);
      expect(retried.uuid, original.uuid);
      expect(firestore.profiles.documents.length, 1);
    },
  );
  test('account change during creation cannot attach the reference to the new account', () async {
    final pending = repository.createProfile(activeMode: 2);
    final checked = expectLater(pending, throwsStateError);
    account = 'adult-b';
    await checked;
    expect(local.read('adult-b'), isNull);
    account = 'adult-a';
    expect(local.read('adult-a'), isNotNull);
    expect(firestore.profiles.documents, isEmpty);
  });
}
