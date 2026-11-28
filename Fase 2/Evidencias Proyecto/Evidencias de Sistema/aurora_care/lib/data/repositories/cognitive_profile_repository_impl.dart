import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/cognitive_profile.dart';
import '../../domain/repositories/cognitive_profile_repository.dart';
import '../sources/account_profile_store.dart';

class CognitiveProfileRepositoryImpl implements CognitiveProfileRepository {
  CognitiveProfileRepositoryImpl(this._firestore, this._local);
  final FirebaseFirestore _firestore;
  final AccountProfileStore _local;
  final _creations = <String, Future<CognitiveProfile>>{};

  @override
  Future<CognitiveProfile?> getLocalProfile() async {
    if (_local.currentAccount() == null) return null;
    final account = _local.requireAccount();
    final local = _local.read(account);
    if (local == null) return null;
    int? mode;
    try {
      final doc = await _firestore
          .collection('cognitive_profiles')
          .doc(local.uuid)
          .get()
          .timeout(const Duration(seconds: 3));
      _local.checkAccount(account);
      if (doc.data()?['privacyDeleted'] == true) {
        await _local.discardDeletedProfile(local.uuid);
        return null;
      }
      mode = doc.data()?['activeMode'] as int?;
    } on TimeoutException {
      // El perfil local permite consultar partidas sin conexión.
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' && error.code != 'deadline-exceeded') {
        rethrow;
      }
    }
    _local.checkAccount(account);
    return CognitiveProfile(
      uuid: local.uuid,
      deviceId: local.deviceId,
      createdAt: local.createdAt,
      activeMode: mode ?? local.activeMode,
      hasUnassignedHistory: local.hasUnassignedHistory,
    );
  }

  @override
  Future<CognitiveProfile> createProfile({required int activeMode}) async {
    final account = _local.requireAccount();
    final pending = _creations[account];
    if (pending != null) return pending;
    final operation = _create(account, activeMode);
    _creations[account] = operation;
    try {
      return await operation;
    } finally {
      _creations.remove(account);
    }
  }

  Future<CognitiveProfile> _create(String account, int activeMode) async {
    if (activeMode != 2 && activeMode != 3) {
      throw ArgumentError.value(activeMode);
    }
    const generator = Uuid();
    final profile = CognitiveProfile(
      uuid: generator.v4(),
      deviceId: generator.v4(),
      createdAt: DateTime.now(),
      activeMode: activeMode,
      hasUnassignedHistory: _local.hasUnassignedHistory,
    );
    // Se conserva primero una referencia completa y atómica. Si falla la red,
    // un reintento no genera otro UUID ni desconecta las partidas de esta cuenta.
    await _local.saveNew(account, profile);
    await _writeMode(profile, account, activeMode);
    return profile;
  }

  Future<void> _writeMode(
    CognitiveProfile profile,
    String account,
    int mode,
  ) async {
    _local.checkAccount(account);
    await _firestore.collection('cognitive_profiles').doc(profile.uuid).set({
      'deviceId': profile.deviceId,
      'createdAt': Timestamp.fromDate(profile.createdAt),
      'activeMode': mode,
    }, SetOptions(merge: true));
    _local.checkAccount(account);
  }

  @override
  Future<void> updateActiveMode({
    required String uuid,
    required int activeMode,
  }) async {
    if (activeMode != 2 && activeMode != 3) {
      throw ArgumentError.value(activeMode);
    }
    final account = _local.requireProfileAccess(uuid);
    await _writeMode(_local.read(account)!, account, activeMode);
  }
}
