import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/account_role.dart';

/// Solo identidad local para recuperar la pantalla correcta al estar sin red.
class SessionRoleStore {
  const SessionRoleStore(this.preferences);
  final SharedPreferences preferences;
  String _key(String uid) =>
      'identity_role_v1_${base64Url.encode(utf8.encode(uid))}';
  AccountRole read(String uid) => switch (preferences.getString(_key(uid))) {
    'elder' => AccountRole.elder,
    'caregiver' => AccountRole.caregiver,
    _ => AccountRole.unknown,
  };
  Future<void> save(String uid, AccountRole role) async {
    if (role == AccountRole.unknown) return;
    if (!await preferences.setString(_key(uid), role.name)) {
      throw StateError('No se pudo guardar el rol local');
    }
  }
}
