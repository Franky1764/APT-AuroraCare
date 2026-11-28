// data/sources/preferences_local_source.dart
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_palettes.dart';

/// Preferencias de accesibilidad guardadas en el dispositivo (no en
/// Firebase). Se mantienen al cerrar sesión: son del teléfono, no de la
/// cuenta — por eso también se ven en Bienvenida y Login.
class PreferencesLocalSource {
  const PreferencesLocalSource(this._prefs);

  final SharedPreferences _prefs;

  static const _textScaleKey = 'pref_text_scale';
  static const _soundsKey = 'pref_sounds';
  static const _musicKey = 'pref_music';
  static const _notificationsKey = 'pref_notifications_opt_in_v2';
  static const _breathingMinutesKey = 'pref_breathing_minutes';
  static const _themeIdKey = 'pref_theme_id';

  static const List<double> _validTextScales = [1.0, 1.3];
  static const List<int> _validBreathingMinutes = [2, 5, 10];

  /// Solo 1.0 o 1.3 son válidos; cualquier otro valor guardado (o
  /// ausente) se trata como 1.0.
  double getTextScale() {
    final value = _prefs.getDouble(_textScaleKey);
    return _validTextScales.contains(value) ? value! : 1.0;
  }

  Future<void> setTextScale(double value) {
    return _prefs.setDouble(_textScaleKey, value);
  }

  int getSoundLevel() => (_prefs.getInt('pref_sound_level') ?? 3).clamp(1, 3);

  Future<void> setSoundLevel(int value) =>
      _prefs.setInt('pref_sound_level', value);

  int getVibrationLevel() =>
      (_prefs.getInt('pref_vibration_level') ?? 1).clamp(0, 2);

  Future<void> setVibrationLevel(int value) =>
      _prefs.setInt('pref_vibration_level', value);

  bool getSoundsEnabled() => _prefs.getBool(_soundsKey) ?? true;

  Future<void> setSoundsEnabled(bool value) {
    return _prefs.setBool(_soundsKey, value);
  }

  /// Música de fondo, independiente de "Sonidos" (que solo controla los
  /// efectos). Por defecto apagada, a diferencia de los efectos.
  bool getMusicEnabled() => _prefs.getBool(_musicKey) ?? false;

  Future<void> setMusicEnabled(bool value) {
    return _prefs.setBool(_musicKey, value);
  }

  bool getNotificationsEnabled() => _prefs.getBool(_notificationsKey) ?? false;

  Future<void> setNotificationsEnabled(bool value) {
    return _prefs.setBool(_notificationsKey, value);
  }

  /// Última duración elegida para la respiración guiada (F5). Solo 2, 5 o
  /// 10 son válidos; cualquier otro valor guardado (o ausente) cae a 5.
  /// No es una métrica cognitiva: es una preferencia de uso, igual que las
  /// de accesibilidad.
  int getBreathingMinutes() {
    final value = _prefs.getInt(_breathingMinutesKey);
    return _validBreathingMinutes.contains(value) ? value! : 5;
  }

  Future<void> setBreathingMinutes(int value) {
    return _prefs.setInt(_breathingMinutesKey, value);
  }

  /// Tema de color elegido. Cualquier id guardado que ya no exista en
  /// AppPalettes.todas (o si no hay nada guardado) cae en Aurora.
  String getThemeId() {
    final value = _prefs.getString(_themeIdKey);
    final esValido = AppPalettes.todas.any((tema) => tema.id == value);
    return esValido ? value! : AppPalettes.aurora.id;
  }

  Future<void> setThemeId(String value) {
    return _prefs.setString(_themeIdKey, value);
  }
}
