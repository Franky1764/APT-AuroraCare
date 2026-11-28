import '../../../domain/entities/account_role.dart';

// lib/presentation/games/shared/game_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase_providers.dart';
import '../../../core/auth_account_provider.dart';
import '../../../core/router/navigation_session.dart';
import '../../../domain/entities/cognitive_profile.dart';
import '../../../domain/entities/game_level.dart';
import '../../../domain/usecases/get_active_profile.provider.dart';
import '../../../domain/usecases/get_or_create_cognitive_profile.dart';
import '../../../domain/usecases/get_or_create_cognitive_profile.provider.dart';
import '../../../domain/usecases/usecase.dart';

/// Perfil compartido por juegos y progreso. Una cuenta con modo elegido
/// puede preparar el seguimiento de este dispositivo si todavía no existe.
final activeProfileProvider = FutureProvider.autoDispose<CognitiveProfile?>((
  ref,
) async {
  final session = ref.watch(navigationSessionProvider).session;
  if (session == null || session.role != AccountRole.elder) return null;
  final account = ref.watch(authenticatedAccountIdProvider);
  if (account != session.uid) return null;
  void checkSession() {
    if (ref.read(authenticatedAccountIdProvider) != account ||
        ref.read(navigationSessionProvider).session?.uid != account) {
      throw StateError('La sesión cambió durante la consulta del perfil');
    }
  }

  final getProfile = ref.watch(getActiveProfileProvider);
  final profile = await getProfile(const NoParams());
  checkSession();
  if (profile != null) return profile;
  final mode = session.currentMode;
  if (mode != 2 && mode != 3) return null;
  // Una lectura fallida lanza error: nunca se sustituye por un UUID nuevo.
  final created = await ref.read(getOrCreateCognitiveProfileProvider)(
    GetOrCreateCognitiveProfileParams(activeMode: mode!),
  );
  checkSession();
  return created;
});

/// Último nivel jugado en cada juego. Es una preferencia de interfaz,
/// guardada solo en el dispositivo.
class LevelPreference {
  const LevelPreference(this._prefs);
  final SharedPreferences _prefs;

  GameLevel read(String gameType) {
    final value = _prefs.getInt('last_level_$gameType');
    return value == null ? GameLevel.facil : GameLevel.fromValue(value);
  }

  Future<void> write(String gameType, GameLevel level) =>
      _prefs.setInt('last_level_$gameType', level.value);
}

final levelPreferenceProvider = Provider<LevelPreference>((ref) {
  return LevelPreference(ref.watch(sharedPreferencesProvider));
});
