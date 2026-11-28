// lib/presentation/games/shared/metrics_consent_view.dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

/// Pantalla de consentimiento de métricas (F4 paso 0, Ley 21.719).
/// Se muestra antes del primer juego, hasta que la persona acepta.
///
/// Texto sujeto a revisión legal final.
class MetricsConsentView extends StatefulWidget {
  const MetricsConsentView({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  /// Guarda el consentimiento. Si lanza, se muestra un error y se puede
  /// reintentar.
  final Future<void> Function() onAccept;
  final VoidCallback onDecline;

  @override
  State<MetricsConsentView> createState() => _MetricsConsentViewState();
}

class _MetricsConsentViewState extends State<MetricsConsentView> {
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar su respuesta. Intente de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text('Antes de jugar', style: AppTextStyles.heading),
                    const SizedBox(height: 16),
                    Text(
                      'Para mostrarle cómo va mejorando, AuroraCare guarda '
                      'cómo le va en cada juego: sus aciertos, el tiempo que '
                      'toma y el nivel que elige.',
                      textAlign: TextAlign.justify,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No guarda su nombre, su correo ni datos de salud junto '
                      'a esos resultados: se guardan bajo un código anónimo.',
                      textAlign: TextAlign.justify,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Si más adelante conecta a un cuidador, él verá solo un '
                      'resumen con colores, nunca los números.',
                      textAlign: TextAlign.justify,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Puede dejar de guardar su progreso o borrarlo cuando '
                      'quiera, desde Configuración.',
                      textAlign: TextAlign.justify,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AuroraCare no hace diagnósticos ni reemplaza a un '
                      'profesional de la salud.',
                      textAlign: TextAlign.justify,
                      style: AppTextStyles.bodySecondary,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        key: const ValueKey('consent_error'),
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    key: const ValueKey('consent_accept'),
                    onPressed: _saving ? null : _accept,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Acepto, continuar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('consent_decline'),
                    onPressed: _saving ? null : widget.onDecline,
                    child: const Text('Ahora no'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}