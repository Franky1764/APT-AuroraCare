// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/data/repositories/session_repository_impl.dart';
import 'package:aurora_care/data/sources/account_profile_store.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';

class ServerMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
}

class Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  SnapshotMetadata get metadata => ServerMetadata();
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

class QueryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final response = Completer<QuerySnapshot<Map<String, dynamic>>>();
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
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
  }) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      response.future;
}

class Profile extends Fake implements DocumentReference<Map<String, dynamic>> {
  Profile(this.query);
  final QueryCollection query;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'sessions');
    return query;
  }
}

class Profiles extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  Profiles(this.query);
  final QueryCollection query;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => Profile(query);
}

class Store extends Fake implements FirebaseFirestore {
  final query = QueryCollection();
  int calls = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    calls++;
    expect(path, 'cognitive_profiles');
    return Profiles(query);
  }
}

void main() {
  late AccountProfileStore local;
  late SessionRepositoryImpl repository;
  late Store firestore;
  String? account;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    account = 'adult-a';
    local = AccountProfileStore(prefs, () => account);
    await local.saveNew(
      account!,
      CognitiveProfile(
        uuid: 'profile-a',
        deviceId: 'device-a',
        createdAt: DateTime(2026),
        activeMode: 2,
      ),
    );
    firestore = Store();
    repository = SessionRepositoryImpl(firestore, local);
  });
  test('another account cannot read or score the previous profile', () async {
    account = 'adult-b';
    await expectLater(
      repository.getRecentSessions('profile-a'),
      throwsStateError,
    );
    await expectLater(
      repository.getSessionsInWindow('profile-a'),
      throwsStateError,
    );
    await expectLater(
      repository.updateSessionScore(
        'profile-a',
        'old-session',
        50,
        scoringVersion: 'v1',
      ),
      throwsStateError,
    );
    expect(firestore.calls, 0);
  });
  test('unfinished game from another account cannot save its result', () async {
    account = 'adult-b';
    final session = Session(
      sessionId: 'old-session',
      uuid: 'profile-a',
      domain: 'memoria',
      gameType: 'memorice_clasico',
      nivel: GameLevel.facil,
      startTime: DateTime(2026),
      endTime: DateTime(2026),
      metrics: const MemoriaMetrics(
        errores: 0,
        intentos: 1,
        tiempoSegundos: 1,
        tasaAciertoPct: 100,
      ),
    );
    await expectLater(repository.saveSession(session), throwsStateError);
    expect(firestore.calls, 0);
  });
  test('sign out blocks access before any network request', () async {
    account = null;
    await expectLater(
      repository.getSessionsInWindow('profile-a'),
      throwsStateError,
    );
    expect(firestore.calls, 0);
  });
  test('late history response is discarded after account switch', () async {
    final pending = repository.getSessionsInWindow('profile-a');
    final checked = expectLater(pending, throwsStateError);
    account = 'adult-b';
    firestore.query.response.complete(Snapshot());
    await checked;
  });
  test(
    'completed practice and score survive reopening with Firestore offline',
    () async {
      final now = DateTime.now();
      final session = Session(
        sessionId: 'saved-session',
        uuid: 'profile-a',
        domain: 'memoria',
        gameType: 'memorice_clasico',
        nivel: GameLevel.facil,
        startTime: now.subtract(const Duration(minutes: 1)),
        endTime: now,
        metrics: const MemoriaMetrics(
          errores: 9,
          intentos: 20,
          tiempoSegundos: 60,
          tasaAciertoPct: 55,
        ),
      );
      await repository.saveSession(session);
      await repository.updateSessionScore(
        'profile-a',
        session.sessionId,
        60,
        scoringVersion: 'scoring-v1.1-memorice-1',
      );
      await local.preferences.reload();
      final offline = Store();
      final reopened = SessionRepositoryImpl(offline, local);
      final reading = reopened.getSessionsInWindow('profile-a');
      offline.query.response.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      final restored = (await reading).single;
      expect(restored.sessionId, session.sessionId);
      expect((restored.metrics as MemoriaMetrics).tasaAciertoPct, 55);
      expect(restored.scoreSesion, 60);
      account = 'adult-b';
      await expectLater(
        reopened.getSessionsInWindow('profile-a'),
        throwsStateError,
      );
    },
  );

  test('the original account can access its history again', () async {
    account = 'adult-b';
    account = 'adult-a';
    firestore.query.response.complete(Snapshot());
    expect(await repository.getSessionsInWindow('profile-a'), isEmpty);
    expect(firestore.calls, 1);
  });
}
