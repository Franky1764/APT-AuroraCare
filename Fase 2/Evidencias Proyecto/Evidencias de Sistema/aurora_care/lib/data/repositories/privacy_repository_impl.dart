import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/privacy_data.dart';
import '../../domain/repositories/privacy_repository.dart';
import '../../domain/repositories/caregiver_invite_repository.dart';
import '../sources/account_profile_store.dart';
import '../sources/local_session_store.dart';
import '../sources/privacy_operation_store.dart';
import '../sources/practice_feedback_platform.dart';
import '../sources/caregiver_alerts_platform.dart';
import '../sources/privacy_actions_platform.dart';

class PrivacyRepositoryImpl implements PrivacyRepository {
  PrivacyRepositoryImpl(
    this.auth,
    this.firestore,
    this.preferences,
    this.invites, {
    this.account,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SharedPreferences preferences;
  final CaregiverInviteRepository invites;
  final String? account;
  bool _busy = false;

  User _user() {
    final user = auth.currentUser;
    if (user == null || (account != null && user.uid != account)) {
      throw StateError('Inicie sesión para gestionar sus datos');
    }
    return user;
  }

  void _check(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('La sesión cambió');
  }

  DocumentReference<Map<String, dynamic>> _identity(String uid) =>
      firestore.collection('users').doc(uid);

  AccountProfileStore get _profiles =>
      AccountProfileStore(preferences, () => auth.currentUser?.uid);
  PrivacyOperationStore get _operations => PrivacyOperationStore(preferences);

  @override
  Future<PrivacyData> readData() async {
    final user = _user();
    final identity = await _identity(user.uid)
        .get(const GetOptions(source: Source.server));
    _check(user.uid);
    final profile = _profiles.read(user.uid);
    final sessions = <String, dynamic>{
      if (profile != null)
        for (final session in LocalSessionStore(preferences).all(profile.uuid))
          session.sessionId: session.toMap(),
    };
    if (profile != null) {
      final remote = await firestore
          .collection('cognitive_profiles')
          .doc(profile.uuid)
          .collection('sessions')
          .get(const GetOptions(source: Source.server));
      _check(user.uid);
      for (final doc in remote.docs) {
        sessions[doc.id] = {
          ...?sessions[doc.id] as Map<String, dynamic>?,
          ...doc.data(),
        };
      }
    }
    final local = <String, Object?>{};
    for (final key in preferences.getKeys()) {
      if (_belongsToAccount(key, user.uid)) local[key] = preferences.get(key);
    }
    final caregiver = identity.data()?['role'] == 'caregiver';
    final links = await firestore
        .collection('caregiver_links')
        .where(caregiver ? 'caregiverUID' : 'adultUID', isEqualTo: user.uid)
        .get(const GetOptions(source: Source.server));
    final invites = await firestore
        .collection('caregiver_invites')
        .where(caregiver ? 'usedBy' : 'adultUID', isEqualTo: user.uid)
        .get(const GetOptions(source: Source.server));
    _check(user.uid);
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {'email': user.email, ...?identity.data()},
      'availableProfile': profile == null
          ? null
          : {
              'uuid': profile.uuid,
              'deviceId': profile.deviceId,
              'activeMode': profile.activeMode,
              'createdAt': profile.createdAt.toIso8601String(),
              'sessions': sessions,
            },
      'links': {for (final doc in links.docs) doc.id: doc.data()},
      'invitations': {for (final doc in invites.docs) doc.id: doc.data()},
      'localAccountData': local,
      'scope':
          'Datos de esta cuenta y del perfil disponible en este dispositivo. '
          'Para datos de otros dispositivos, contacte a auroracareprivacidad@gmail.com.',
    };
    return PrivacyData(
      name:
          identity.data()?['displayName'] as String? ?? user.displayName ?? '',
      email: user.email ?? '',
      consent: identity.data()?['consentGiven'] == true,
      hasUnassignedHistory: _profiles.hasUnassignedHistory,
      json: JsonEncoder.withIndent('  ', (value) {
        if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
        if (value is GeoPoint) {
          return {'latitude': value.latitude, 'longitude': value.longitude};
        }
        throw const FormatException('Formato de datos desconocido');
      }).convert(data),
    );
  }

  Future<void> _serverWrite(
    String uid,
    void Function(Transaction) write,
  ) async {
    // Las transacciones fallan sin conexión; el borrado no deja escrituras
    // diferidas que puedan ejecutarse después de un reintento.
    await firestore.runTransaction((transaction) async {
      _check(uid);
      write(transaction);
    }, timeout: const Duration(seconds: 12));
    _check(uid);
  }

  @override
  Future<void> correctName(String name) async {
    final user = _user();
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 80) {
      throw ArgumentError('Nombre inválido');
    }
    await _serverWrite(
      user.uid,
      (transaction) =>
          transaction.update(_identity(user.uid), {'displayName': cleaned}),
    );
    _check(user.uid);
    await user.updateDisplayName(cleaned);
    // El nombre publicado en un vínculo de cuidador se mantiene actualizado.
    final links = await firestore
        .collection('caregiver_links')
        .where('caregiverUID', isEqualTo: user.uid)
        .get(const GetOptions(source: Source.server));
    for (final link in links.docs.where(
      (doc) => doc.data()['status'] == 'active',
    )) {
      _check(user.uid);
      await _serverWrite(
        user.uid,
        (transaction) =>
            transaction.update(link.reference, {'caregiverName': cleaned}),
      );
    }
  }

  @override
  Future<void> withdrawConsent() async {
    final user = _user();
    // Se revoca primero el acceso del cuidador antes de retirar el consentimiento.
    if (!await preferences.setBool(
      'privacy_metrics_withdrawn_${user.uid}',
      true,
    )) {
      throw StateError('No se pudo guardar su decisión');
    }
    await invites.cancelAllInvites();
    _check(user.uid);
    await _serverWrite(
      user.uid,
      (transaction) => transaction.update(_identity(user.uid), {
        'consentGiven': false,
        'consentDate': null,
      }),
    );
  }

  Future<void> _deleteQuery(
    Query<Map<String, dynamic>> query,
    String uid,
  ) async {
    while (true) {
      _check(uid);
      final page = await query
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) return;
      await _serverWrite(uid, (transaction) {
        for (final doc in page.docs) {
          transaction.delete(doc.reference);
        }
      });
    }
  }

  Future<void> _stopAlerts(String uid) async {
    await const PrivacyActionsPlatform().clearReminders(uid);
    await const PracticeFeedbackPlatform().configure(
      account: null,
      enabled: false,
    );
    await const CaregiverAlertsPlatform().configure(
      account: null,
      enabled: false,
      dailyReminder: false,
    );
  }

  bool _belongsToAccount(String key, String uid) =>
      key == 'identity_role_v1_${base64Url.encode(utf8.encode(uid))}' ||
      key == 'privacy_metrics_withdrawn_$uid' ||
      key == 'profile_portrait_v1_$uid' ||
      key == 'mis_recuerdos_v1_$uid' ||
      key == 'caregiver_alerts_enabled_$uid' ||
      key == 'caregiver_daily_reminder_$uid' ||
      key == 'caregiver_permission_asked_$uid' ||
      key == 'caregiver_alerts_link_$uid' ||
      key == 'elder_caregiver_left_$uid' ||
      key.startsWith('caregiver_alerts_state_${uid}_') ||
      key.startsWith('caregiver_alerts_streak_${uid}_') ||
      key.startsWith('caregiver_day_history_${uid}_');

  @override
  Future<void> delete(PrivacyDeletion deletion, String password) async {
    if (_busy) throw StateError('Ya hay una operación en curso');
    _busy = true;
    try {
      final user = _user();
      final email = user.email;
      if (email == null || password.isEmpty) {
        throw ArgumentError('Se necesita su contraseña');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      _check(user.uid);
      final previous = _operations.read(user.uid);
      if (previous != null && previous['kind'] != deletion.name) {
        throw StateError('Complete primero la eliminación pendiente');
      }
      final uuid =
          previous?['uuid'] as String? ?? _profiles.read(user.uid)?.uuid;
      final identity = await _identity(user.uid)
          .get(const GetOptions(source: Source.server));
      if (!identity.exists && previous == null) {
        throw StateError(
          'No se pudo confirmar la cuenta. Contacte al equipo de privacidad.',
        );
      }
      await _operations.begin(user.uid, deletion, uuid);
      if (!identity.exists && deletion == PrivacyDeletion.account) {
        await _stopAlerts(user.uid);
        await user.delete();
        await _operations.complete(user.uid);
        return;
      }
      final caregiver = identity.data()?['role'] == 'caregiver';
      if (identity.exists) {
        await _serverWrite(
          user.uid,
          (transaction) => transaction.update(_identity(user.uid), {
            'deletionPending': true,
            'consentGiven': false,
            'consentDate': null,
          }),
        );
      }
      _check(user.uid);
      if (uuid != null) {
        await _operations.retire(uuid);
        // Se conserva solo una marca aleatoria para impedir escrituras atrasadas.
        final profile = firestore.collection('cognitive_profiles').doc(uuid);
        await _serverWrite(
          user.uid,
          (transaction) => transaction.set(profile, {
            'privacyDeleted': true,
          }, SetOptions(merge: true)),
        );
        await _deleteQuery(profile.collection('sessions'), user.uid);
        await _serverWrite(
          user.uid,
          (transaction) => transaction.set(profile, {'privacyDeleted': true}),
        );
      }

      final links = await firestore
          .collection('caregiver_links')
          .where(caregiver ? 'caregiverUID' : 'adultUID', isEqualTo: user.uid)
          .get(const GetOptions(source: Source.server));
      for (final link in links.docs) {
        _check(user.uid);
        await _serverWrite(user.uid, (transaction) {
          transaction.delete(
            firestore.collection('caregiver_summaries').doc(link.id),
          );
          transaction.delete(link.reference);
        });
      }
      if (!caregiver) {
        await _deleteQuery(
          firestore
              .collection('caregiver_invites')
              .where('adultUID', isEqualTo: user.uid),
          user.uid,
        );
        await _serverWrite(
          user.uid,
          (transaction) => transaction.delete(
            firestore.collection('caregiver_invite_state').doc(user.uid),
          ),
        );
      } else if (deletion == PrivacyDeletion.account) {
        await _deleteQuery(
          firestore
              .collection('caregiver_invites')
              .where('usedBy', isEqualTo: user.uid),
          user.uid,
        );
        await _serverWrite(
          user.uid,
          (transaction) => transaction.delete(
            firestore.collection('caregiver_link_state').doc(user.uid),
          ),
        );
        await _deleteQuery(
          firestore
              .collection('alerts')
              .where('caregiverUID', isEqualTo: user.uid),
          user.uid,
        );
      }
      _check(user.uid);
      final keys = preferences
          .getKeys()
          .where(
            (key) =>
                (uuid != null &&
                    key.startsWith('practice_session_v1_${uuid}_')) ||
                key == 'mis_recuerdos_v1_${user.uid}' ||
                key == AccountProfileStore.keyFor(user.uid) ||
                (deletion == PrivacyDeletion.account &&
                    _belongsToAccount(key, user.uid)),
          )
          .toList();
      for (final key in keys) {
        if (!await preferences.remove(key)) {
          throw StateError('No se pudo borrar el dato local');
        }
      }

      if (deletion == PrivacyDeletion.account) {
        // El documento de identidad se elimina antes que Authentication.
        // El registro local permite repetir la operación si el último paso falla.
        await _stopAlerts(user.uid);
        await _serverWrite(
          user.uid,
          (transaction) => transaction.delete(_identity(user.uid)),
        );
        await user.delete();
      } else {
        await _stopAlerts(user.uid);
        await _serverWrite(
          user.uid,
          (transaction) => transaction.update(_identity(user.uid), {
            'deletionPending': false,
          }),
        );
      }
      await _operations.complete(user.uid);
    } finally {
      _busy = false;
    }
  }
}
