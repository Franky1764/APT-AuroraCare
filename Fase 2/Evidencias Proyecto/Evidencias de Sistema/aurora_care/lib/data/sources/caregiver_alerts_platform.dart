// lib/data/sources/caregiver_alerts_platform.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canal hacia Android para los avisos del cuidador (SCRUM-34).
/// Sigue la misma lógica que PracticeFeedbackPlatform del adulto mayor:
/// las notificaciones se muestran en el teléfono con AlarmManager y
/// NotificationManager, sin servidor.
final caregiverAlertsPlatformProvider = Provider<CaregiverAlertsPlatform>(
  (ref) => const CaregiverAlertsPlatform(),
);

class CaregiverAlertsPlatform {
  const CaregiverAlertsPlatform();

  static const _channel = MethodChannel('auroracare/caregiver_alerts');

  /// Activa o desactiva los avisos para la cuenta del cuidador y programa
  /// (o cancela) la revisión de las 19:00. [lastPractice] (milisegundos) y
  /// [practiceDays] ('aaaa-mm-dd') sirven para «Hace unos días que no
  /// practica» y el resumen semanal con la app cerrada.
  Future<void> configure({
    required String? account,
    required bool enabled,
    required bool dailyReminder,
    int? lastPractice,
    List<String> practiceDays = const [],
  }) => _invoke<void>('configure', {
    'account': account,
    'enabled': enabled,
    'daily': dailyReminder,
    'lastPractice': lastPractice,
    'days': practiceDays,
  });

  /// Muestra un aviso. [kind]: 'progress', 'attention', 'new_area',
  /// 'linked', 'unlinked' o 'streak'.
  Future<bool> notify({
    required String account,
    required String kind,
    required String title,
    required String message,
  }) async =>
      await _invoke<bool>('notify', {
        'account': account,
        'kind': kind,
        'title': title,
        'message': message,
      }) ??
      false;

  /// Aviso para el ADULTO MAYOR sobre su vínculo con el cuidador.
  /// Usa su propio canal («Vínculo familiar»), no depende de los avisos
  /// del cuidador.
  /// [kind]: 'left' (se desvinculó) o 'linked' (se vinculó).
  Future<bool> notifyElder({
    required String title,
    required String message,
    String kind = 'left',
  }) async =>
      await _invoke<bool>('elder_notice', {
        'kind': kind,
        'title': title,
        'message': message,
      }) ??
      false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
