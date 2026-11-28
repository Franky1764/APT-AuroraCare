import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/caregiver_invite.dart';
import '../../domain/entities/invite_status.dart';
import '../../domain/repositories/caregiver_invite_repository.dart';

/// Invitación y vínculo de identidad. Nunca consulta ni comparte UUID cognitivos.
class FirestoreCaregiverInviteRepository implements CaregiverInviteRepository {
  FirestoreCaregiverInviteRepository(this.firestore, this.auth);
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  static const lifetime = Duration(minutes: 10);
  String _uid() {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Se necesita iniciar sesión');
    return uid;
  }

  void _check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('La sesión cambió');
  }

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _pointer(String uid) =>
      firestore.collection('caregiver_invite_state').doc(uid);
  DocumentReference<Map<String, dynamic>> _invite(String token) =>
      firestore.collection('caregiver_invites').doc(token);
  DocumentReference<Map<String, dynamic>> _link(String token) =>
      firestore.collection('caregiver_links').doc(token);
  DocumentReference<Map<String, dynamic>> _caregiverPointer(String uid) =>
      firestore.collection('caregiver_link_state').doc(uid);
  int _epoch(Map<String, dynamic> data) =>
      data['caregiverAccessEpoch'] as int? ?? 0;
  bool _isElder(Map<String, dynamic> data) =>
      data['role'] == null || data['role'] == 'elder';
  CaregiverInvite _entity(String token, Map<String, dynamic> data) =>
      CaregiverInvite(
        token: token,
        expiresAt: (data['createdAt'] as Timestamp).toDate().add(lifetime),
      );
  Future<Map<String, dynamic>> _identity(String uid) async {
    final snapshot = await _user(uid)
        .get(const GetOptions(source: Source.server));
    _check(uid);
    final data = snapshot.data();
    if (data == null) throw StateError('No se pudo confirmar la cuenta');
    return data;
  }

  @override
  Future<CaregiverInvite> createInvite() async {
    final uid = _uid();
    final random = Random.secure();
    final token = base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await firestore.runTransaction((transaction) async {
      _check(uid);
      final identity = (await transaction.get(_user(uid))).data();
      if (identity == null ||
          !_isElder(identity) ||
          identity['currentMode'] != 3) {
        throw StateError('Elija el modo con cuidador para generar un código');
      }
      final previous =
          (await transaction.get(_pointer(uid))).data()?['token'] as String?;
      Map<String, dynamic>? oldInvite, oldLink;
      if (previous != null) {
        oldInvite = (await transaction.get(_invite(previous))).data();
        oldLink = (await transaction.get(_link(previous))).data();
      }
      _check(uid);
      // Todas las lecturas preceden a las escrituras de la transacción.
      if (previous != null &&
          oldInvite != null &&
          oldInvite['status'] != 'cancelled') {
        transaction.update(_invite(previous), {'status': 'cancelled'});
      }
      if (previous != null && oldLink?['status'] == 'active') {
        transaction.update(_link(previous), {'status': 'revoked'});
        transaction.delete(_summary(previous));
      }
      transaction.set(_invite(token), {
        'adultUID': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'validForSeconds': 600,
        'epoch': _epoch(identity),
        'status': 'active',
        'consentVersion': 'caregiver-link-v2',
      });
      transaction.set(_pointer(uid), {'token': token});
    });
    _check(uid);
    final data = (await _invite(
      token,
    ).get(const GetOptions(source: Source.server))).data();
    _check(uid);
    if (data == null) throw StateError('No se pudo confirmar la invitación');
    return _entity(token, data);
  }

  @override
  Future<CaregiverInvite?> getActiveInvite() async {
    final uid = _uid();
    final identity = await _identity(uid);
    if (!_isElder(identity) || identity['currentMode'] != 3) return null;
    final token =
        (await _pointer(uid).get(const GetOptions(source: Source.server)))
                .data()?['token']
            as String?;
    if (token == null) return null;
    final data = (await _invite(
      token,
    ).get(const GetOptions(source: Source.server))).data();
    _check(uid);
    if (data == null ||
        data['status'] != 'active' ||
        data['epoch'] != _epoch(identity)) {
      return null;
    }
    final invite = _entity(token, data);
    // Esto solo ajusta la presentación. El canje se autoriza con request.time.
    return invite.expiresAt.isAfter(DateTime.now()) ? invite : null;
  }

  @override
  Future<void> redeemInvite(String token) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw StateError('El código no es de AuroraCare');
    }
    final uid = _uid();
    await firestore.runTransaction((transaction) async {
      _check(uid);
      final identity = (await transaction.get(_user(uid))).data();
      if (identity?['role'] != 'caregiver') {
        throw StateError('Se necesita una cuenta de cuidador');
      }
      final data = (await transaction.get(_invite(token))).data();
      if (data == null ||
          data['status'] != 'active' ||
          data['adultUID'] == uid) {
        throw StateError('El código ya no está disponible');
      }
      _check(uid);
      // Las reglas comprueban vigencia, generación, modo y uso único con
      // datos del servidor. El cliente no decide si el plazo sigue vigente.
      transaction.update(_invite(token), {
        'status': 'used',
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_link(token), {
        'adultUID': data['adultUID'],
        'caregiverUID': uid,
        if (identity?['displayName'] case final String name)
          'caregiverName': name,
        'epoch': data['epoch'],
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      transaction.set(_caregiverPointer(uid), {'token': token});
    });
    _check(uid);
  }

  @override
  Future<void> cancelInvite(String token) => _cancel(token);
  @override
  Future<void> cancelAllInvites() => _cancel(null);
  Future<void> _cancel(String? expectedToken) async {
    final uid = _uid();
    await firestore.runTransaction((transaction) async {
      _check(uid);
      final identity = (await transaction.get(_user(uid))).data();
      if (identity == null || !_isElder(identity)) {
        throw StateError('Se necesita la cuenta titular');
      }
      final token =
          (await transaction.get(_pointer(uid))).data()?['token'] as String?;
      if (token == null || (expectedToken != null && token != expectedToken)) {
        return;
      }
      final invite = (await transaction.get(_invite(token))).data();
      final link = (await transaction.get(_link(token))).data();
      _check(uid);
      if (invite != null && invite['status'] != 'cancelled') {
        transaction.update(_invite(token), {'status': 'cancelled'});
      }
      if (link?['status'] == 'active') {
        transaction.update(_link(token), {'status': 'revoked'});
        transaction.delete(_summary(token));
      }
      transaction.set(_pointer(uid), {'token': null});
    });
    _check(uid);
  }

  @override
  Stream<InviteStatus> watchInvite(String token) {
    final uid = _uid();
    late StreamController<InviteStatus> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];
    Timer? expiry;
    Map<String, dynamic>? invite, identity, pointer;
    var received = <String>{};
    var closed = false;
    void emit() {
      if (closed || received.length != 3) return;
      if (auth.currentUser?.uid != uid) {
        controller.addError(StateError('La sesión cambió'));
        return;
      }
      expiry?.cancel();
      final data = invite;
      if (data == null ||
          pointer?['token'] != token ||
          identity?['currentMode'] != 3 ||
          data['epoch'] != _epoch(identity!)) {
        controller.add(InviteStatus.expired);
      } else if (data['status'] == 'used') {
        controller.add(InviteStatus.redeemed);
      } else if (data['status'] != 'active') {
        controller.add(InviteStatus.expired);
      } else {
        final remaining = _entity(
          token,
          data,
        ).expiresAt.difference(DateTime.now());
        controller.add(
          remaining <= Duration.zero
              ? InviteStatus.expired
              : InviteStatus.active,
        );
        if (remaining > Duration.zero) {
          expiry = Timer(remaining, () {
            if (!closed) controller.add(InviteStatus.expired);
          });
        }
      }
    }

    controller = StreamController<InviteStatus>(
      onListen: () {
        subscriptions.add(
          _user(uid).snapshots().listen((s) {
            identity = s.data();
            received.add('user');
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _pointer(uid).snapshots().listen((s) {
            pointer = s.data();
            received.add('pointer');
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          _invite(token).snapshots().listen((s) {
            invite = s.data();
            received.add('invite');
            emit();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        closed = true;
        expiry?.cancel();
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream.distinct();
  }

  @override
  Stream<bool> watchConnection() =>
      _watchActiveLink().map((link) => link != null).distinct();

  Stream<String?> watchActiveLinkToken() =>
      _watchActiveLink().map((link) => link?.id).distinct();

  DocumentReference<Map<String, dynamic>> _summary(String token) =>
      firestore.collection('caregiver_summaries').doc(token);

  Stream<Map<String, dynamic>?> watchSummary(String token) => _summary(token)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.metadata.isFromCache ? null : snapshot.data(),
      );

  Future<void> refreshSharedSummary(
    Future<Map<String, dynamic>> Function() loadSummary,
  ) async {
    final uid = _uid();
    final token =
        (await _pointer(uid).get(const GetOptions(source: Source.server)))
                .data()?['token']
            as String?;
    _check(uid);
    if (token == null) return;
    final link = (await _link(
      token,
    ).get(const GetOptions(source: Source.server))).data();
    _check(uid);
    if (link?['status'] != 'active') return;
    final invitation = (await _invite(
      token,
    ).get(const GetOptions(source: Source.server))).data();
    _check(uid);
    if (invitation?['consentVersion'] != 'caregiver-link-v2') return;
    final summary = await loadSummary();
    _check(uid);
    await firestore.runTransaction((transaction) async {
      _check(uid);
      final existing = (await transaction.get(_summary(token))).data();
      _check(uid);
      final previous = existing?['lastPracticeAt'] as Timestamp?;
      final next = summary['lastPracticeAt'] as Timestamp?;
      if (previous != null && (next == null || previous.compareTo(next) > 0)) {
        return;
      }
      transaction.set(_summary(token), {
        ...summary,
        'publishedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<({bool linked, String? name})> watchCaregiverIdentity() =>
      _watchActiveLink()
          .map(
            (link) => (
              linked: link != null,
              name: link?.data()?['caregiverName'] as String?,
            ),
          )
          .distinct();

  Stream<bool> publishCaregiverName() async* {
    final uid = _uid();
    final identity = await _identity(uid);
    final name = identity['displayName'];
    await for (final link in _watchActiveLink()) {
      _check(uid);
      if (link != null &&
          name is String &&
          link.data()?['caregiverName'] != name) {
        try {
          await link.reference
              .update({'caregiverName': name})
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // Un fallo del nombre no bloquea el acceso a las prácticas.
        }
      }
      yield link != null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _watchActiveLink() {
    final uid = _uid();
    late StreamController<DocumentSnapshot<Map<String, dynamic>>?> controller;
    StreamSubscription<dynamic>? pointerSubscription, linkSubscription;
    Timer? initialTimeout;
    void emit(DocumentSnapshot<Map<String, dynamic>>? link) {
      initialTimeout?.cancel();
      controller.add(link);
    }

    var closed = false;
    var generation = 0;
    controller = StreamController<DocumentSnapshot<Map<String, dynamic>>?>(
      onListen: () async {
        initialTimeout = Timer(const Duration(seconds: 10), () {
          controller.addError(
            TimeoutException('No se pudo confirmar el vínculo'),
          );
        });
        try {
          final identity = await _identity(uid);
          if (closed) return;
          final pointer = identity['role'] == 'caregiver'
              ? _caregiverPointer(uid)
              : _pointer(uid);
          pointerSubscription = pointer
              .snapshots(includeMetadataChanges: true)
              .listen((snapshot) async {
                if (snapshot.metadata.isFromCache) return;
                final current = ++generation;
                await linkSubscription?.cancel();
                if (closed || current != generation) return;
                final token = snapshot.data()?['token'] as String?;
                if (token == null) {
                  emit(null);
                  return;
                }
                linkSubscription = _link(token)
                    .snapshots(includeMetadataChanges: true)
                    .listen(
                      (link) {
                        if (closed || current != generation) return;
                        if (auth.currentUser?.uid != uid) {
                          emit(null);
                          return;
                        }
                        if (link.metadata.isFromCache) return;
                        emit(link.data()?['status'] == 'active' ? link : null);
                      },
                      onError: (Object error, StackTrace stack) {
                        if (!closed) controller.addError(error, stack);
                      },
                    );
              }, onError: controller.addError);
        } catch (error, stack) {
          initialTimeout?.cancel();
          if (!closed) controller.addError(error, stack);
        }
      },
      onCancel: () async {
        closed = true;
        initialTimeout?.cancel();
        generation++;
        await pointerSubscription?.cancel();
        await linkSubscription?.cancel();
      },
    );
    return controller.stream.distinct();
  }
}
