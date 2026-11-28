import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/sources/privacy_actions_platform.dart';
import '../../domain/entities/privacy_request.dart';

class PrivacyRequestScreen extends StatefulWidget {
  const PrivacyRequestScreen({super.key, required this.right});

  final PrivacyRight right;

  @override
  State<PrivacyRequestScreen> createState() => _PrivacyRequestScreenState();
}

class _PrivacyRequestScreenState extends State<PrivacyRequestScreen> {
  final _details = TextEditingController();
  bool _busy = false;
  String? _message;

  PrivacyRequest get _request =>
      PrivacyRequest(right: widget.right, details: _details.text);

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final opened = await const PrivacyActionsPlatform().compose(_request);
      if (mounted) {
        setState(
          () => _message = opened
              ? 'Se abrió el borrador. Revíselo y envíelo desde su aplicación de correo.'
              : 'Puede copiar la solicitud y enviarla desde su correo.',
        );
      }
    } on PlatformException {
      if (mounted) {
        setState(
          () => _message =
              'Puede copiar la solicitud y enviarla desde su correo.',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _message =
              'Puede copiar la solicitud y enviarla desde su correo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Para ${PrivacyRequest.contact}\nAsunto ${_request.subject}\n\n${_request.body}',
      ),
    );
    if (mounted) {
      setState(
        () => _message =
            'Solicitud copiada. Péguela en un correo a ${PrivacyRequest.contact} y envíela.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Solicitud de privacidad')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.right.label, style: AppTextStyles.heading),
          const SizedBox(height: 12),
          const Text(
            'El equipo de AuroraCare recibirá su solicitud por correo y '
            'podrá pedirle verificar que es titular de la cuenta.',
          ),
          const SizedBox(height: 12),
          const SelectableText(PrivacyRequest.contact),
          const SizedBox(height: 20),
          TextField(
            controller: _details,
            enabled: !_busy,
            maxLength: 2000,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '¿Qué necesita? (opcional)',
              alignLabelWithHint: true,
              helperText: 'Evite incluir contraseñas o códigos QR.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _compose,
            icon: const Icon(Icons.mail_outline),
            label: Text(_busy ? 'Preparando…' : 'Preparar correo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _copy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar solicitud'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: AppTextStyles.body.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
