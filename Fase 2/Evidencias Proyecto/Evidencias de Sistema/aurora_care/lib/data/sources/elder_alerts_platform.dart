// lib/data/sources/elder_alerts_platform.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canal hacia Android para los avisos extra del adulto mayor
/// (16:00 sugerencia, 20:00 constancia, domingo 18:00 resumen).
/// Es aparte de PracticeFeedbackPlatform para no tocar los avisos de las
/// 09:00 y 20:00 que ya existían.
final elderAlertsPlatformProvider = Provider<ElderAlertsPlatform>(
  (ref) => const ElderAlertsPlatform(),
);

class ElderAlertsPlatform {
  const ElderAlertsPlatform();

  static const _channel = MethodChannel('auroracare/elder_alerts');

  Future<void> configure({
    required String? account,
    required bool enabled,
    List<String> practiceDays = const [],
    String? suggestedArea,
  }) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'account': account,
        'enabled': enabled,
        'days': practiceDays,
        'area': suggestedArea,
      });
    } on MissingPluginException {
      // Sin Android (tests o web): no hay avisos.
    } on PlatformException {
      // Un fallo del aviso nunca bloquea la app.
    }
  }
}
