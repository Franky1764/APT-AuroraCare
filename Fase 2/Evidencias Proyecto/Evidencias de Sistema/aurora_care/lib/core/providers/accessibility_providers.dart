// core/providers/accessibility_providers.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/preferences_local_source.dart';
import '../../data/sources/practice_feedback_platform.dart';
import '../../domain/entities/account_role.dart';
import '../constants/app_colors.dart';
import '../constants/app_palettes.dart';
import '../router/navigation_session.dart';
import '../firebase_providers.dart';

/// sharedPreferencesProvider ya existe en core/firebase_providers.dart
/// (se sobreescribe en main.dart antes de runApp).
final preferencesLocalSourceProvider = Provider<PreferencesLocalSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesLocalSource(prefs);
});

/// Notifier en vez de StateProvider: necesita un método set() que, además
/// de actualizar el estado, lo persista de inmediato en el dispositivo.
class TextScaleNotifier extends Notifier<double> {
  @override
  double build() => ref.watch(preferencesLocalSourceProvider).getTextScale();

  Future<void> set(double value) async {
    state = value;
    await ref.read(preferencesLocalSourceProvider).setTextScale(value);
  }
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, double>(
  TextScaleNotifier.new,
);

/// Tema de color activo. Igual que TextScaleNotifier: build() lee lo
/// guardado y set() actualiza el estado y persiste. Además, ambos activan
/// la paleta en AppColors de inmediato — quien de verdad reconstruye las
/// pantallas ya montadas para que se vea el cambio es main.dart (AppColors
/// es estado global leído con getters sueltos, no vía InheritedWidget, así
/// que ref.watch solo no alcanza para refrescar toda la UI).
class ThemeNotifier extends Notifier<AppThemeOption> {
  @override
  AppThemeOption build() {
    final id = ref.watch(preferencesLocalSourceProvider).getThemeId();
    final tema = AppPalettes.porId(id) ?? AppPalettes.aurora;
    AppColors.usarPaleta(tema.paleta);
    return tema;
  }

  Future<void> set(AppThemeOption tema) async {
    state = tema;
    AppColors.usarPaleta(tema.paleta);
    await ref.read(preferencesLocalSourceProvider).setThemeId(tema.id);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeOption>(
  ThemeNotifier.new,
);

final soundLevelProvider = NotifierProvider<SoundLevelNotifier, int>(
  SoundLevelNotifier.new,
);

class SoundLevelNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(preferencesLocalSourceProvider).getSoundLevel();

  Future<void> set(int level) async {
    state = level;
    await ref.read(preferencesLocalSourceProvider).setSoundLevel(level);
  }
}

/// Main conecta los ejercicios con la preferencia guardada en el dispositivo.
final exerciseVibrationProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

final vibrationLevelProvider = NotifierProvider<VibrationLevelNotifier, int>(
  VibrationLevelNotifier.new,
);

class VibrationLevelNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(preferencesLocalSourceProvider).getVibrationLevel();

  Future<void> set(int level) async {
    state = level;
    await ref.read(preferencesLocalSourceProvider).setVibrationLevel(level);
  }

  Future<void> pulse() async {
    try {
      switch (state) {
        case 1:
          await HapticFeedback.lightImpact();
        case 2:
          await HapticFeedback.heavyImpact();
      }
    } on PlatformException {
      // La respuesta táctil es opcional durante el ejercicio.
    } on MissingPluginException {
      // El dispositivo no ofrece el canal de respuesta táctil.
    }
  }
}

class SoundsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesLocalSourceProvider).getSoundsEnabled();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesLocalSourceProvider).setSoundsEnabled(value);
  }
}

final soundsEnabledProvider = NotifierProvider<SoundsEnabledNotifier, bool>(
  SoundsEnabledNotifier.new,
);

/// Independiente de [soundsEnabledProvider]: este controla SOLO la música
/// de fondo, aquel controla SOLO los efectos cortos.
class MusicEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesLocalSourceProvider).getMusicEnabled();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesLocalSourceProvider).setMusicEnabled(value);
  }
}

final musicEnabledProvider = NotifierProvider<MusicEnabledNotifier, bool>(
  MusicEnabledNotifier.new,
);

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(preferencesLocalSourceProvider).getNotificationsEnabled();

  Future<bool> set(bool value) async {
    final feedback = ref.read(practiceFeedbackPlatformProvider);
    final session = ref.read(navigationSessionProvider).session;
    final allowed = !value || await feedback.requestNotifications();
    if (ref.read(navigationSessionProvider).session?.uid != session?.uid) {
      return false;
    }
    final enabled = value && allowed;
    await ref
        .read(preferencesLocalSourceProvider)
        .setNotificationsEnabled(enabled);
    state = enabled;
    await feedback.configure(
      account: session?.role == AccountRole.elder ? session?.uid : null,
      enabled: enabled,
    );
    return allowed;
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
      NotificationsEnabledNotifier.new,
    );
