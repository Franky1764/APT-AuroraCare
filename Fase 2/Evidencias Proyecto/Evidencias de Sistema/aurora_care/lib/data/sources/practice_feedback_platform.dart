import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final practiceFeedbackPlatformProvider = Provider<PracticeFeedbackPlatform>(
  (ref) => const PracticeFeedbackPlatform(),
);

class PracticeFeedbackPlatform {
  const PracticeFeedbackPlatform();

  static const _channel = MethodChannel('auroracare/practice_feedback');

  Future<bool> requestNotifications() async =>
      await _invoke<bool>('requestPermission') ?? false;

  Future<bool> notificationsAllowed() async =>
      await _invoke<bool>('permission') ?? false;

  Future<void> configure({required String? account, required bool enabled}) =>
      _invoke<void>('configure', {'account': account, 'enabled': enabled});

  Future<void> recordPractice(String account, DateTime at) => _invoke<void>(
    'practice',
    {'account': account, 'at': at.millisecondsSinceEpoch},
  );

  Future<void> reportReady(String account, DateTime at) => _invoke<void>(
    'report',
    {'account': account, 'at': at.millisecondsSinceEpoch},
  );

  Future<bool?> touchFeedbackEnabled() => _invoke<bool>('touchFeedbackEnabled');

  Future<void> openSoundSettings() => _invoke<void>('soundSettings');

  Future<void> openSettings() => _invoke<void>('settings');

  Future<void> playPracticeSound() => _invoke<void>('sound');

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
