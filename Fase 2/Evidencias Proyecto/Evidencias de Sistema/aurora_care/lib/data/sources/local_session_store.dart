import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_model.dart';

/// El repositorio verifica la cuenta y el UUID antes de acceder al historial.
class LocalSessionStore {
  const LocalSessionStore(this._preferences);

  final SharedPreferences _preferences;

  String _prefix(String uuid) => 'practice_session_v1_${uuid}_';

  SessionModel? read(String uuid, String id) {
    final raw = _preferences.getString('${_prefix(uuid)}$id');
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map['startTime'] = Timestamp.fromMicrosecondsSinceEpoch(
      map['startTime'] as int,
    );
    map['endTime'] = Timestamp.fromMicrosecondsSinceEpoch(
      map['endTime'] as int,
    );
    final session = SessionModel.fromMap(id, map);
    if (session.uuid != uuid) {
      throw const FormatException('Perfil de partida inválido');
    }
    return session;
  }

  Iterable<SessionModel> all(String uuid) sync* {
    final prefix = _prefix(uuid);
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final session = read(uuid, key.substring(prefix.length));
      if (session != null) yield session;
    }
  }

  Future<void> save(SessionModel session) async {
    final saved = await _preferences.setString(
      '${_prefix(session.uuid)}${session.sessionId}',
      jsonEncode({
        ...session.toMap(),
        'startTime': session.startTime.toDate().microsecondsSinceEpoch,
        'endTime': session.endTime.toDate().microsecondsSinceEpoch,
      }),
    );
    if (!saved) {
      throw StateError('No se pudo guardar la partida en el dispositivo');
    }
  }
}
