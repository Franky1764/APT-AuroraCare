// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/data/repositories/firestore_caregiver_invite_repository.dart';
import 'package:aurora_care/domain/entities/caregiver_invite.dart';

class Account extends Fake implements User {
  Account(this.id);
  final String id;
  @override
  String get uid => id;
}

class Auth extends Fake implements FirebaseAuth {
  String? actor = 'adult';
  @override
  User? get currentUser => actor == null ? null : Account(actor!);
}

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class Document extends Fake implements DocumentReference<Map<String, dynamic>> {
  Document(this.store, this.location);
  final Store store;
  final String location;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    return Snapshot(store.data[location]);
  }
}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  Collection(this.store, this.location);
  final Store store;
  final String location;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      Document(store, '$location/$path');
}

class Tx extends Fake implements Transaction {
  Tx(this.store);
  final Store store;
  bool wrote = false;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    expect(wrote, false, reason: 'Transaction reads must precede all writes');
    return Snapshot(store.data[(reference as Document).location])
        as DocumentSnapshot<T>;
  }

  Map<String, dynamic> resolved(Map<Object, Object?> data) => {
    for (final entry in data.entries)
      entry.key as String: entry.value is FieldValue
          ? Timestamp.fromDate(store.serverTime)
          : entry.value,
  };
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    wrote = true;
    store.data[(reference as Document).location] = resolved(
      data as Map<Object, Object?>,
    );
    return this;
  }

  @override
  Transaction delete(DocumentReference reference) {
    wrote = true;
    store.data.remove((reference as Document).location);
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    wrote = true;
    final path = (reference as Document).location;
    store.data[path] = {...?store.data[path], ...resolved(data)};
    return this;
  }
}

class Store extends Fake implements FirebaseFirestore {
  final serverTime = DateTime.utc(2030, 1, 1);
  final data = <String, Map<String, dynamic>>{
    'users/adult': {'currentMode': 3, 'role': 'elder'},
    'users/caregiver': {'currentMode': 0, 'role': 'caregiver'},
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect([
      'users',
      'caregiver_invites',
      'caregiver_links',
      'caregiver_invite_state',
      'caregiver_link_state',
      'caregiver_summaries',
    ], contains(path));
    return Collection(this, path);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => handler(Tx(this));
}

void main() {
  late Store firestore;
  late Auth auth;
  late FirestoreCaregiverInviteRepository repository;
  setUp(() {
    firestore = Store();
    auth = Auth();
    repository = FirestoreCaregiverInviteRepository(firestore, auth);
  });
  test('real repository generates opaque QR with server-derived expiration and restores it', () async {
    final invite = await repository.createInvite();
    expect(invite.token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(CaregiverInvite.parseQr(invite.qrPayload), invite.token);
    expect(
      invite.expiresAt.toUtc(),
      firestore.serverTime.add(const Duration(minutes: 10)),
    );
    expect((await repository.getActiveInvite())!.token, invite.token);
    expect(firestore.data['caregiver_invites/${invite.token}']!.keys.toSet(), {
      'adultUID',
      'createdAt',
      'validForSeconds',
      'epoch',
      'status',
      'consentVersion',
    });
  });
  test(
    'generation, real consumption and adult cancellation use the same token',
    () async {
      final invite = await repository.createInvite();
      auth.actor = 'caregiver';
      await repository.redeemInvite(CaregiverInvite.parseQr(invite.qrPayload)!);
      expect(
        firestore.data['caregiver_invites/${invite.token}']!['status'],
        'used',
      );
      expect(
        firestore.data['caregiver_link_state/caregiver']!['token'],
        invite.token,
      );
      auth.actor = 'adult';
      await repository.cancelAllInvites();
      expect(
        firestore.data['caregiver_invites/${invite.token}']!['status'],
        'cancelled',
      );
      expect(
        firestore.data['caregiver_links/${invite.token}']!['status'],
        'revoked',
      );
      expect(await repository.getActiveInvite(), isNull);
    },
  );
  test('replacing a code retires the prior invitation', () async {
    final first = await repository.createInvite();
    final second = await repository.createInvite();
    expect(second.token, isNot(first.token));
    expect(
      firestore.data['caregiver_invites/${first.token}']!['status'],
      'cancelled',
    );
  });
  test('caregiver cannot generate and adult cannot redeem', () async {
    auth.actor = 'caregiver';
    await expectLater(repository.createInvite(), throwsStateError);
    auth.actor = 'adult';
    final invite = await repository.createInvite();
    await expectLater(repository.redeemInvite(invite.token), throwsStateError);
  });
  test('signed-out operations fail before any invitation is created', () async {
    auth.actor = null;
    await expectLater(repository.createInvite(), throwsStateError);
    expect(firestore.data.length, 2);
  });
}
