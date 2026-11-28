import '../shared/email_validation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_auth_controller.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CaregiverLoginScreen extends ConsumerStatefulWidget {
  const CaregiverLoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onForgotPassword,
    this.onGoToRegister,
  });

  final VoidCallback? onLoginSuccess;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onGoToRegister;

  @override
  ConsumerState<CaregiverLoginScreen> createState() =>
      _CaregiverLoginScreenState();
}

class _CaregiverLoginScreenState extends ConsumerState<CaregiverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !EmailValidation.isValid(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(caregiverAuthProvider(CaregiverAuthForm.login).notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ref.read(caregiverAuthProvider(CaregiverAuthForm.login)).valueOrNull !=
        null) {
      widget.onLoginSuccess?.call();
    }
  }

  void _handleForgotPassword() {
    widget.onForgotPassword?.call();
  }

  void _handleGoToRegister() {
    widget.onGoToRegister?.call();
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
    final auth = ref.watch(caregiverAuthProvider(CaregiverAuthForm.login));
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
                Text('Hola de nuevo', style: AppTextStyles.heading),
                const SizedBox(height: 8),
                Text(
                  'Ingresa para ver el progreso de tu ser querido.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 32),
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
                  autofillHints: const [AutofillHints.password],
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
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Olvidé mi contraseña',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (auth.hasError) ...[
                  Text(
                    caregiverAuthMessage(auth.error!),
                    key: const ValueKey('caregiver-auth-error'),
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: loading ? null : _handleLogin,
                  child: Text(loading ? 'Un momento…' : 'Entrar'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: loading ? null : _handleGoToRegister,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      'Crear cuenta',
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
