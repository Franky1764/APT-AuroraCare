import 'package:flutter/services.dart';

import '../../domain/entities/privacy_request.dart';

/// Abre un borrador. El envío lo confirma la persona en su aplicación de correo.
class PrivacyActionsPlatform {
  const PrivacyActionsPlatform();
  static const _channel = MethodChannel('auroracare/privacy');

  Future<bool> compose(PrivacyRequest request) async =>
      await _channel.invokeMethod<bool>('email', {
        'subject': request.subject,
        'body': request.body,
      }) ??
      false;

  Future<void> clearReminders(String uid) async {
    try {
      await _channel.invokeMethod<void>('clearReminders', {'account': uid});
    } on MissingPluginException {
      // Algunos entornos no tienen almacenamiento nativo de avisos.
    }
  }

  Future<bool> saveData(String json) async =>
      await _channel.invokeMethod<bool>('save', {'text': json}) ?? false;
}
