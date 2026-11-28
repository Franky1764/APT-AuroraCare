// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.dart';
import 'package:aurora_care/domain/exceptions/caregiver_revocation_unavailable.dart';

class Adult extends Fake implements fb.User {
  @override
  String get uid => 'adult';
}

class Auth extends Fake implements fb.FirebaseAuth {
  @override
  fb.User? get currentUser => Adult();
}

class Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  Snapshot(this.value);
  final Map<String, dynamic> value;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
}

class Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'adult');
    return Document();
  }
}

class Tx extends Fake implements Transaction {
  Tx(this.value);
  final Map<String, dynamic> value;
  Map<Object, Object?>? updateData;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => Snapshot(value) as DocumentSnapshot<T>;
  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    updateData = data;
    return this;
  }
}

class Store extends Fake implements FirebaseFirestore {
  Store(this.tx);
  final Tx tx;
  Object? error;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return Collection();
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (error != null) throw error!;
    return transactionHandler(tx);
  }
}

void main() {
  test(
    'personal mode disables sharing and advances epoch in one transaction',
    () async {
      final tx = Tx({'currentMode': 3, 'caregiverAccessEpoch': 7});
      await AuthRepositoryImpl(
        Auth(),
        Store(tx),
      ).updateCurrentMode(uid: 'adult', mode: 2);
      expect(tx.updateData, {
        'currentMode': 2,
        'caregiverSharingEnabled': false,
        'caregiverAccessEpoch': 8,
      });
    },
  );
  test(
    'retry does not advance epoch again and mode 3 never reenables access',
    () async {
      for (final target in [2, 3]) {
        final tx = Tx({'currentMode': 2, 'caregiverAccessEpoch': 8});
        await AuthRepositoryImpl(
          Auth(),
          Store(tx),
        ).updateCurrentMode(uid: 'adult', mode: target);
        expect(tx.updateData, {
          'currentMode': target,
          'caregiverSharingEnabled': false,
        });
      }
    },
  );
  test(
    'future real access remains blocked until effective revocation exists',
    () async {
      final tx = Tx({'currentMode': 3, 'caregiverSharingEnabled': true});
      await expectLater(
        AuthRepositoryImpl(
          Auth(),
          Store(tx),
        ).updateCurrentMode(uid: 'adult', mode: 2),
        throwsA(isA<CaregiverRevocationUnavailable>()),
      );
      expect(tx.updateData, isNull);
    },
  );
  test('network failure never confirms personal mode', () async {
    final tx = Tx({'currentMode': 3});
    final store = Store(tx)..error = StateError('offline');
    await expectLater(
      AuthRepositoryImpl(
        Auth(),
        store,
      ).updateCurrentMode(uid: 'adult', mode: 2),
      throwsStateError,
    );
    expect(tx.updateData, isNull);
  });
}
