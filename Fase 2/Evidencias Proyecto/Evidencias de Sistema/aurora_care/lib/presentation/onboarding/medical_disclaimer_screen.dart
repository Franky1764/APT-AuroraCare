// lib/presentation/onboarding/medical_disclaimer_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Aviso sobre el alcance de AuroraCare, independiente del consentimiento
/// de métricas y del permiso para compartir información con un cuidador.
class MedicalDisclaimerScreen extends StatefulWidget {
  const MedicalDisclaimerScreen({
    super.key,
    required this.userName,
    this.onAccept,
  });

  /// Nombre real ingresado en el registro (o el de mejor esfuerzo del login),
  /// que se propaga hacia ModeSelectionScreen y HomeScreen.
  final String userName;
  final Future<void> Function()? onAccept;

  @override
  State<MedicalDisclaimerScreen> createState() =>
      _MedicalDisclaimerScreenState();
}

class _MedicalDisclaimerScreenState extends State<MedicalDisclaimerScreen> {
  // Color específico del mockup, no está en AppColors — confirmar con
  // Daniela si se agrega a la paleta.
  static const Color _disclaimerBackground = Color(0xFFF3EEDF);

  bool _hasAcknowledged = false;
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _accept() async {
    if (!_hasAcknowledged || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final save = widget.onAccept;
      if (save == null) {
        throw StateError('Falta conectar el guardado del aviso');
      }
      await save();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No pudimos guardar su aceptación. '
            'Compruebe su conexión y vuelva a intentarlo.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleAcknowledged([bool? value]) {
    setState(() => _hasAcknowledged = value ?? !_hasAcknowledged);
  }

  @override
  Widget build(BuildContext context) {
    // Según ARCHITECTURE.md sección 5.3: "Sin aceptación explícita no hay acceso a la app".
    // El acceso HACIA ADELANTE está bloqueado por el checkbox (el botón no se habilita
    // sin marcarlo). Se permite volver atrás por si el usuario seleccionó el rol
    // equivocado - esto no viola la regla, ya que no otorga acceso, solo permite salir.
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text('Antes de empezar', style: AppTextStyles.heading),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: _disclaimerBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // AppTextStyles.body (color textPrimary) fue verificado
                          // con buen contraste sobre este fondo beige claro.
                          Text.rich(
                            textAlign: TextAlign.justify,
                            TextSpan(
                              style: AppTextStyles.body,
                              children: const [
                                TextSpan(text: 'AuroraCare '),
                                TextSpan(
                                  text: 'no diagnostica',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' ninguna enfermedad.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Es una herramienta de bienestar para ejercitar la '
                            'mente.',
                            textAlign: TextAlign.justify,
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Ante cualquier duda de salud, hable con su médico.',
                            textAlign: TextAlign.justify,
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _hasAcknowledged,
                          activeColor: AppColors.primary,
                          onChanged: _isSaving ? null : _toggleAcknowledged,
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _isSaving ? null : _toggleAcknowledged,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Entiendo y acepto lo anterior',
                                style: AppTextStyles.body,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(_errorMessage!, style: AppTextStyles.body),
                      ),
                      TextButton(
                        onPressed: _hasAcknowledged && !_isSaving
                            ? _accept
                            : null,
                        child: const Text('Reintentar'),
                      ),
                    ],
                    if (_isSaving) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Guardando su aceptación',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // Deshabilitado sigue legible: colores de la paleta
                        // en vez del gris translúcido por defecto de Material.
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textSecondary,
                      ),
                      onPressed: _hasAcknowledged && !_isSaving
                          ? _accept
                          : null,
                      child: const Text('Entendido, continuar'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
