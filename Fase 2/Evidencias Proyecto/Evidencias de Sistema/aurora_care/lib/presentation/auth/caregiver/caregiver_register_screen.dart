import '../shared/email_validation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_auth_controller.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../shared/password_policy.dart';
import '../shared/password_requirements_list.dart';
import '../shared/password_strength_meter.dart';

class CaregiverRegisterScreen extends ConsumerStatefulWidget {
  const CaregiverRegisterScreen({
    super.key,
    this.onRegisterSuccess,
    this.onGoToLogin,
  });

  final VoidCallback? onRegisterSuccess;
  final VoidCallback? onGoToLogin;

  @override
  ConsumerState<CaregiverRegisterScreen> createState() =>
      _CaregiverRegisterScreenState();
}

class _CaregiverRegisterScreenState
    extends ConsumerState<CaregiverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  PasswordEvaluation _passwordEvaluation = PasswordPolicy.evaluate('');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty || value.trim().length > 80) {
      return 'Ingresa tu nombre completo';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !EmailValidation.isValid(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    // Resguardo defensivo: el botón ya queda deshabilitado mientras
    // _passwordEvaluation no sea válida (ver build()).
    final evaluation = PasswordPolicy.evaluate(value ?? '');
    if (evaluation.isValid) return null;
    return evaluation.issues.isEmpty
        ? 'Escriba una contraseña.'
        : evaluation.issues.first;
  }

  void _onPasswordChanged(String value) {
    setState(() => _passwordEvaluation = PasswordPolicy.evaluate(value));
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(caregiverAuthProvider(CaregiverAuthForm.register).notifier)
        .submit(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ref
            .read(caregiverAuthProvider(CaregiverAuthForm.register))
            .valueOrNull !=
        null) {
      widget.onRegisterSuccess?.call();
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySecondary,
      errorStyle: AppTextStyles.fieldError,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(caregiverAuthProvider(CaregiverAuthForm.register));
    final loading = auth.isLoading;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registro de cuidador', style: AppTextStyles.heading),
                const SizedBox(height: 24),
                Text('Nombre completo', style: AppTextStyles.cardTitle),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: loading,
                  controller: _nameController,
                  style: AppTextStyles.body,
                  decoration: _decoration('Ej. Carla García'),
                  textCapitalization: TextCapitalization.words,
                  validator: _validateName,
                ),
                const SizedBox(height: 20),
                Text('Correo electrónico', style: AppTextStyles.cardTitle),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: loading,
                  controller: _emailController,
                  style: AppTextStyles.body,
                  decoration: _decoration('carla@correo.cl'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                Text('Contraseña', style: AppTextStyles.cardTitle),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: loading,
                  controller: _passwordController,
                  style: AppTextStyles.body,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  // A diferencia de Nombre/Correo (que solo validan al
                  // enviar), la contraseña muestra el mensaje detallado
                  // en vivo mientras se escribe — mismo criterio que la
                  // pantalla del adulto mayor.
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: _decoration('••••••').copyWith(
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: _validatePassword,
                  onChanged: _onPasswordChanged,
                ),
                PasswordStrengthMeter(strength: _passwordEvaluation.strength),
                PasswordRequirementsList(
                  requirements: _passwordEvaluation.requirements,
                ),
                const SizedBox(height: 32),
                if (auth.hasError) ...[
                  Text(
                    caregiverAuthMessage(auth.error!),
                    key: const ValueKey('caregiver-auth-error'),
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: (loading || !_passwordEvaluation.isValid)
                      ? null
                      : _handleRegister,
                  child: Text(loading ? 'Un momento…' : 'Crear cuenta'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: loading ? null : widget.onGoToLogin,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      'Ya tengo cuenta',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
