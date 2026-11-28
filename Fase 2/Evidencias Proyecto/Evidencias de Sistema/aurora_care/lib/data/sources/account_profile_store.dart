import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cognitive_profile.dart';
import 'privacy_operation_store.dart';

/// Asociación solo local. La identidad nunca se añade al documento cognitivo.
/// Las claves antiguas se conservan sin atribuirlas a la cuenta que inicia sesión.
class AccountProfileStore {
  const AccountProfileStore(this.preferences, this.currentAccount);
  final SharedPreferences preferences;
  final String? Function() currentAccount;
  static const prefix = 'cognitive_profile_v2_';

  static String keyFor(String account) =>
      '$prefix${base64Url.encode(utf8.encode(account))}';

  String requireAccount() {
    final account = currentAccount();
    if (account == null || account.isEmpty) {
      throw StateError('Se necesita una sesión activa');
    }
    return account;
  }

  void checkAccount(String account) {
    if (currentAccount() != account) {
      throw StateError('La sesión cambió durante la operación');
    }
  }

  bool get hasUnassignedHistory =>
      preferences.containsKey('cognitive_profile_uuid');

  CognitiveProfile? read(String account) {
    checkAccount(account);
    final raw = preferences.getString(keyFor(account));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final uuid = data['uuid'] as String;
      final device = data['deviceId'] as String;
      final date = DateTime.parse(data['createdAt'] as String);
      if (uuid.isEmpty || device.isEmpty) throw const FormatException();
      return CognitiveProfile(
        uuid: uuid,
        deviceId: device,
        createdAt: date,
        activeMode: data['activeMode'] as int? ?? 2,
        hasUnassignedHistory: hasUnassignedHistory,
      );
    } catch (_) {
      // Un registro inválido puede contener la única referencia al historial.
      throw StateError(
        'No se pudo leer el perfil de esta cuenta; se conserva su referencia',
      );
    }
  }

  Future<void> saveNew(String account, CognitiveProfile profile) async {
    checkAccount(account);
    if (PrivacyOperationStore(preferences).read(account) != null) {
      throw StateError('Hay una eliminación de datos pendiente');
    }
    if (preferences.containsKey(keyFor(account))) {
      throw StateError('Esta cuenta ya tiene una referencia de perfil');
    }
    final saved = await preferences.setString(
      keyFor(account),
      jsonEncode({
        'uuid': profile.uuid,
        'deviceId': profile.deviceId,
        'createdAt': profile.createdAt.toIso8601String(),
        'activeMode': profile.activeMode,
      }),
    );
    if (!saved) {
      throw StateError('No se pudo guardar la referencia del historial');
    }
    checkAccount(account);
  }

  String requireProfileAccess(String uuid) {
    final account = requireAccount();
    final privacy = PrivacyOperationStore(preferences);
    if (privacy.read(account) != null || privacy.retired(uuid)) {
      throw StateError('El historial está en proceso de eliminación');
    }
    if (read(account)?.uuid != uuid) {
      throw StateError('El perfil no corresponde a la cuenta activa');
    }
    return account;
  }
  String requireMetricsWriteAccess(String uuid) {
    final account = requireProfileAccess(uuid);
    if (preferences.getBool('privacy_metrics_withdrawn_$account') ?? false) {
      throw StateError('El consentimiento para guardar métricas fue retirado');
    }
    return account;
  }

  Future<void> discardDeletedProfile(String uuid) async {
    final account = requireAccount();
    if (read(account)?.uuid != uuid) throw StateError('El perfil cambió');
    await PrivacyOperationStore(preferences).retire(uuid);
    final keys = preferences.getKeys().where(
      (key) => key.startsWith('practice_session_v1_${uuid}_'),
    ).toList();
    for (final key in [...keys, keyFor(account)]) {
      checkAccount(account);
      if (!await preferences.remove(key)) {
        throw StateError('No se pudo borrar el historial local eliminado');
      }
    }
  }

}
