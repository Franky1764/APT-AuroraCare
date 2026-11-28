import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SaveReportPdfButton extends StatefulWidget {
  const SaveReportPdfButton({
    super.key,
    required this.text,
    this.activity = const {},
    this.sections = const [],
  });

  final String text;
  final Map<String, int> activity;
  final List<Map<String, Object>> sections;

  @override
  State<SaveReportPdfButton> createState() => _SaveReportPdfButtonState();
}

class _SaveReportPdfButtonState extends State<SaveReportPdfButton> {
  static const _channel = MethodChannel('auroracare/report_pdf');
  bool _saving = false;

  Future<void> _export(String action) async {
    setState(() => _saving = true);
    try {
      final saved = await _channel.invokeMethod<bool>(action, {
        'text': widget.text,
        'activity': widget.activity,
        'sections': widget.sections,
      });
      if (mounted && saved == true && action == 'save') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Su informe se guardó como PDF.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos preparar el PDF. Inténtelo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: _saving ? null : () => _export('save'),
        icon: const Icon(Icons.download_outlined),
        label: Text(_saving ? 'Preparando…' : 'Guardar PDF'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _saving ? null : () => _export('share'),
        icon: const Icon(Icons.share_outlined),
        label: const Text('Compartir PDF'),
      ),
    ],
  );
}
