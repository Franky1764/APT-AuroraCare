import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/privacy_data.dart';

/// El progreso del borrado vive en el teléfono, separado de las métricas remotas.
class PrivacyOperationStore {
  const PrivacyOperationStore(this.preferences);

  final SharedPreferences preferences;
  String key(String uid) =>
      'privacy_operation_${base64Url.encode(utf8.encode(uid))}';

  Map<String, dynamic>? read(String uid) {
    final raw = preferences.getString(key(uid));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> begin(String uid, PrivacyDeletion kind, String? uuid) async {
    if (!await preferences.setString(
      key(uid),
      jsonEncode({'kind': kind.name, 'uuid': uuid}),
    )) {
      throw StateError('No se pudo guardar el estado del borrado');
    }
  }

  Future<void> complete(String uid) async {
    if (!await preferences.remove(key(uid))) {
      throw StateError('No se pudo completar el borrado en el dispositivo');
    }
  }

  bool retired(String uuid) =>
      preferences.getBool('privacy_retired_$uuid') ?? false;
  Future<void> retire(String uuid) async {
    if (!await preferences.setBool('privacy_retired_$uuid', true)) {
      throw StateError('No se pudo proteger el historial durante el borrado');
    }
  }
}
