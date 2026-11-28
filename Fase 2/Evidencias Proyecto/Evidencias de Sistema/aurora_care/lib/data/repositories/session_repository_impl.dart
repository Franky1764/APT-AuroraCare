import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/session.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';
import '../sources/account_profile_store.dart';
import '../sources/local_session_store.dart';

class SessionRepositoryImpl implements SessionRepository {
  final FirebaseFirestore firestore;

  const SessionRepositoryImpl(this.firestore, this.local);
  final AccountProfileStore local;
  LocalSessionStore get _device => LocalSessionStore(local.preferences);

  void _sync(Future<void> Function() write) {
    unawaited(
      Future.sync(write).catchError((Object error) {
        // La copia del dispositivo sigue disponible si Firestore rechaza la escritura.
        developer.log(
          'Sincronización de partida pendiente: ${error.runtimeType}',
        );
      }),
    );
  }

  // Las sesiones viven dentro del perfil cognitivo: el UUID es la llave de acceso.
  CollectionReference<Map<String, dynamic>> _sessionsOf(String uuid) =>
      firestore
          .collection('cognitive_profiles')
          .doc(uuid)
          .collection('sessions');

  @override
  Future<void> saveSession(Session session) async {
    final account = local.requireMetricsWriteAccess(session.uuid);
    final model = SessionModel.fromEntity(session);
    await _device.save(model);
    local.checkAccount(account);
    _sync(() {
      local.requireMetricsWriteAccess(session.uuid);
      return _sessionsOf(session.uuid).doc(session.sessionId).set(model.toMap());
    });
  }

  @override
  Future<void> updateSessionScore(
    String uuid,
    String sessionId,
    double score, {
    required String scoringVersion,
  }) async {
    final account = local.requireMetricsWriteAccess(uuid);
    final saved = _device.read(uuid, sessionId);
    final updates = {'scoreSesion': score, 'scoringVersion': scoringVersion};
    if (saved != null) {
      await _device.save(
        SessionModel.fromMap(sessionId, {...saved.toMap(), ...updates}),
      );
      local.checkAccount(account);
      _sync(() {
        local.requireMetricsWriteAccess(uuid);
        return _sessionsOf(uuid).doc(sessionId).update(updates);
      });
    } else {
      await _sessionsOf(uuid).doc(sessionId).update(updates);
      local.checkAccount(account);
    }
  }

  @override
  Future<List<Session>> getRecentSessions(String uuid, {int limit = 5}) async {
    final account = local.requireProfileAccess(uuid);
    final results = await _read(
      uuid,
      account,
      () =>
          _sessionsOf(uuid).orderBy('startTime', descending: true).limit(limit),
      (_) => true,
    );
    results.sort((a, b) => b.startTime.compareTo(a.startTime));
    return results.take(limit).toList();
  }

  @override
  Future<List<Session>> getSessionsInWindow(
    String uuid, {
    String? domain,
    int days = 28,
  }) async {
    final account = local.requireProfileAccess(uuid);
    final since = DateTime.now().subtract(Duration(days: days));
    final sessions = await _read(
      uuid,
      account,
      () {
        Query<Map<String, dynamic>> query = _sessionsOf(uuid);
        if (domain != null) query = query.where('domain', isEqualTo: domain);
        return query
            .where(
              'startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since),
            )
            .orderBy('startTime');
      },
      (session) =>
          !session.startTime.toDate().isBefore(since) &&
          (domain == null || session.domain == domain),
    );
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    return sessions;
  }

  Future<List<Session>> _read(
    String uuid,
    String account,
    Query<Map<String, dynamic>> Function() query,
    bool Function(SessionModel) matches,
  ) async {
    QuerySnapshot<Map<String, dynamic>>? snapshot;
    Object? failure;
    try {
      snapshot = await query().get().timeout(const Duration(seconds: 3));
    } on TimeoutException catch (error) {
      failure = error;
    } on FirebaseException catch (error) {
      failure = error;
    }
    local.checkAccount(account);
    final merged = {
      for (final session in _device.all(uuid).where(matches))
        session.sessionId: session,
    };
    if (snapshot != null) {
      for (final doc in snapshot.docs) {
        final remote = SessionModel.fromMap(doc.id, doc.data());
        if (remote.uuid != uuid || !matches(remote)) continue;
        final stored = _device.read(uuid, doc.id);
        if (stored != null &&
            (stored.scoreSesion != null || remote.scoreSesion == null)) {
          merged[doc.id] = stored;
          continue;
        }
        await _device.save(remote);
        local.checkAccount(account);
        merged[doc.id] = _device.read(uuid, doc.id) ?? remote;
      }
      if (snapshot.docs.isEmpty && snapshot.metadata.isFromCache) {
        failure = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      }
    }
    if (merged.isEmpty && failure != null) throw failure;
    return merged.values.map((model) => model.toEntity()).toList();
  }
}
