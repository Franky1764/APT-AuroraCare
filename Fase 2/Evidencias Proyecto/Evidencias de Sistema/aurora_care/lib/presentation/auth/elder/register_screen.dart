import '../shared/email_validation.dart';
// lib/presentation/auth/elder/register_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../onboarding/welcome_flow.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/exceptions/auth_exception.dart';
import '../../shared/auth_error_widgets.dart';
import '../shared/password_policy.dart';
import '../shared/password_requirements_list.dart';
import '../shared/password_strength_meter.dart';
import 'register_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onRegisterSuccess, this.onGoToLogin});

  final void Function(String userName)? onRegisterSuccess;
  final VoidCallback? onGoToLogin;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  PasswordEvaluation _passwordEvaluation = PasswordPolicy.evaluate('');

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_validateEmailOnBlur);
  }

  void _validateEmailOnBlur() {
    if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
      setState(() => _emailError = _computeEmailError(_emailController.text));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.removeListener(_validateEmailOnBlur);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _computeNameError(String value) {
    if (value.trim().isEmpty) {
      return 'Cuéntanos cómo te llamamos';
    }
    return null;
  }

  String? _computeEmailError(String value) {
    final email = value.trim();
    if (email.isEmpty || !EmailValidation.isValid(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordEvaluation = PasswordPolicy.evaluate(value);
      // Mensaje detallado en vivo: el primero de la lista (longitud,
      // luego mayúscula, minúscula, número). El botón ya queda
      // deshabilitado mientras no sea válida — este mensaje es la
      // guía de qué falta, no lo único que lo impide.
      _passwordError = _passwordEvaluation.issues.isEmpty
          ? null
          : _passwordEvaluation.issues.first;
    });
  }

  void _focusFirstError() {
    if (_nameError != null) {
      _nameFocusNode.requestFocus();
    } else if (_emailError != null) {
      _emailFocusNode.requestFocus();
    } else if (_passwordError != null) {
      _passwordFocusNode.requestFocus();
    }
  }

  Future<void> _handleRegister() async {
    final nameError = _computeNameError(_nameController.text);
    final emailError = _computeEmailError(_emailController.text);
    // El botón ya queda deshabilitado mientras la contraseña no sea
    // válida (ver build()); esto es solo un resguardo defensivo.
    final passwordError = _passwordEvaluation.isValid
        ? null
        : (_passwordEvaluation.issues.isEmpty
              ? 'Escriba una contraseña.'
              : _passwordEvaluation.issues.first);

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _generalError = null;
    });

    if (nameError != null || emailError != null || passwordError != null) {
      _focusFirstError();
      return;
    }

    await ref
        .read(registerNotifierProvider.notifier)
        .register(
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  InputDecoration _decoration(String hint, {bool hasError = false}) {
    final borderColor = hasError ? AppColors.error : AppColors.border;
    final borderWidth = hasError ? 2.0 : 1.0;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.primary,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (success) {
          if (success) {
            if (widget.onRegisterSuccess != null) {
              widget.onRegisterSuccess!(_nameController.text.trim());
            } else {
              continueAfterAuth(context, _nameController.text.trim());
            }
          }
        },
        error: (error, _) {
          final type = error is AuthException
              ? error.type
              : AuthErrorType.unknown;
          setState(() {
            _emailError = null;
            _passwordError = null;
            _generalError = null;
            switch (type) {
              case AuthErrorType.emailAlreadyInUse:
                _emailError =
                    'Este correo ya tiene una cuenta. ¿Quieres iniciar '
                    'sesión?';
                break;
              case AuthErrorType.invalidEmail:
                _emailError = 'Ingresa un correo válido';
                break;
              case AuthErrorType.weakPassword:
                _passwordError =
                    'La contraseña no cumple los requisitos de seguridad. '
                    'Revise la lista de abajo.';
                break;
              case AuthErrorType.networkError:
                _generalError =
                    'No hay conexión a internet. Revise su conexión e '
                    'inténtelo de nuevo.';
                break;
              case AuthErrorType.tooManyRequests:
                _generalError =
                    'Demasiados intentos. Espere unos minutos e inténtelo '
                    'de nuevo.';
                break;
              case AuthErrorType.userDisabled:
                _generalError = 'Esta cuenta está deshabilitada.';
                break;
              case AuthErrorType.userNotFound:
              case AuthErrorType.wrongPassword:
              case AuthErrorType.wrongRole:
              case AuthErrorType.unknown:
                _generalError = 'Algo salió mal. Intenta de nuevo.';
                break;
            }
          });
          _focusFirstError();
        },
      );
    });

    final isLoading = ref.watch(registerNotifierProvider).isLoading;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crear mi cuenta', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Un espacio para usted, a su ritmo.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 24),
              Text(
                '¿Cómo quiere que lo llamemos?',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                readOnly: isLoading,
                maxLength: 80,
                autofillHints: const [AutofillHints.nickname],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                focusNode: _nameFocusNode,
                style: AppTextStyles.body,
                decoration: _decoration('Rosa', hasError: _nameError != null),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              if (_nameError != null) FieldErrorText(_nameError!),
              const SizedBox(height: 20),
              Text('Correo', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                readOnly: isLoading,
                focusNode: _emailFocusNode,
                style: AppTextStyles.body,
                decoration: _decoration(
                  'rosa@correo.cl',
                  hasError: _emailError != null,
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) {
                  setState(() => _emailError = null);
                },
              ),
              if (_emailError != null) FieldErrorText(_emailError!),
              if (EmailValidation.suggestion(_emailController.text)
                  case final suggestion?)
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => setState(() {
                          _emailController.text = suggestion;
                          _emailError = null;
                        }),
                  child: Text('¿Quiso decir $suggestion?'),
                ),
              const SizedBox(height: 20),
              Text('Contraseña', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                readOnly: isLoading,
                focusNode: _passwordFocusNode,
                style: AppTextStyles.body,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                    _decoration(
                      '••••••',
                      hasError: _passwordError != null,
                    ).copyWith(
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
                onChanged: _onPasswordChanged,
              ),
              if (_passwordError != null) FieldErrorText(_passwordError!),
              PasswordStrengthMeter(strength: _passwordEvaluation.strength),
              PasswordRequirementsList(
                requirements: _passwordEvaluation.requirements,
              ),
              const SizedBox(height: 32),
              if (_generalError != null) ...[
                GeneralErrorBanner(_generalError!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: (isLoading || !_passwordEvaluation.isValid)
                    ? null
                    : _handleRegister,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear mi cuenta'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed:
                      widget.onGoToLogin ??
                      () => context.push(AppRoutes.elderLogin),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Ya tengo cuenta',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
