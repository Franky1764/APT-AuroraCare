import '../shared/email_validation.dart';
// lib/presentation/auth/elder/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../onboarding/welcome_flow.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/exceptions/auth_exception.dart';
import '../../shared/auth_error_widgets.dart';
import 'login_notifier.dart';

/// Pantalla de login del adulto mayor (F2 — auth/elder, SCRUM-94).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onForgotPassword,
    this.onGoToRegister,
  });

  final void Function(String userName)? onLoginSuccess;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onGoToRegister;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  /// true cuando Firebase devolvió credenciales incorrectas: por
  /// protección contra enumeración de correos no se sabe cuál de los dos
  /// campos falló, así que ambos se marcan en rojo pero el mensaje se
  /// muestra una sola vez, bajo Contraseña.
  bool _credentialsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _computeEmailError(String value) {
    final email = value.trim();
    if (email.isEmpty || !EmailValidation.isValid(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _computePasswordError(String value) {
    if (value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    return null;
  }

  void _focusFirstError() {
    if (_emailError != null || _credentialsError) {
      _emailFocusNode.requestFocus();
    } else if (_passwordError != null) {
      _passwordFocusNode.requestFocus();
    }
  }

  Future<void> _handleLogin() async {
    final emailError = _computeEmailError(_emailController.text);
    final passwordError = _computePasswordError(_passwordController.text);

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _credentialsError = false;
      _generalError = null;
    });

    if (emailError != null || passwordError != null) {
      _focusFirstError();
      return;
    }

    await ref
        .read(loginNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _handleForgotPassword() {
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
    } else {
      context.push(AppRoutes.forgotPassword);
    }
  }

  void _handleGoToRegister() {
    if (widget.onGoToRegister != null) {
      widget.onGoToRegister!();
    } else {
      context.push(AppRoutes.elderRegister);
    }
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
    ref.listen(loginNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (success) {
          if (success) {
            // El flujo de acceso recupera el nombre real de la sesión;
            // este valor solo sirve como respaldo para el callback.
            final fallbackName = _emailController.text.split('@').first;
            if (widget.onLoginSuccess != null) {
              widget.onLoginSuccess!(fallbackName);
            } else {
              continueAfterAuth(context, fallbackName);
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
            _credentialsError = false;
            _generalError = null;
            switch (type) {
              case AuthErrorType.userNotFound:
              case AuthErrorType.wrongPassword:
                _credentialsError = true;
                break;
              case AuthErrorType.invalidEmail:
                _emailError = 'Ingresa un correo válido';
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
              case AuthErrorType.wrongRole:
                _generalError = 'Esta cuenta es de cuidador. Ingrese por el acceso de cuidador.';
                break;
              case AuthErrorType.emailAlreadyInUse:
              case AuthErrorType.weakPassword:
              case AuthErrorType.unknown:
                _generalError = 'Algo salió mal. Intenta de nuevo.';
                break;
            }
          });
          _focusFirstError();
        },
      );
    });

    final isLoading = ref.watch(loginNotifierProvider).isLoading;
    final emailHasError = _emailError != null || _credentialsError;
    final passwordHasError = _passwordError != null || _credentialsError;
    final passwordErrorText = _credentialsError
        ? 'Correo o contraseña incorrectos. Inténtelo de nuevo.'
        : _passwordError;

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
              Text('Hola de nuevo', style: AppTextStyles.heading),
              const SizedBox(height: 32),
              Text('Correo electrónico', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                style: AppTextStyles.body,
                decoration: _decoration(
                  'carla@email.com',
                  hasError: emailHasError,
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) {
                  if (_emailError != null || _credentialsError) {
                    setState(() {
                      _emailError = null;
                      _credentialsError = false;
                    });
                  }
                },
              ),
              if (_emailError != null) FieldErrorText(_emailError!),
              const SizedBox(height: 20),
              Text('Contraseña', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                style: AppTextStyles.body,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                decoration: _decoration('••••••', hasError: passwordHasError)
                    .copyWith(
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                onChanged: (_) {
                  if (_passwordError != null || _credentialsError) {
                    setState(() {
                      _passwordError = null;
                      _credentialsError = false;
                    });
                  }
                },
              ),
              if (passwordErrorText != null) FieldErrorText(passwordErrorText),
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
              if (_generalError != null) ...[
                GeneralErrorBanner(_generalError!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _handleGoToRegister,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Crear cuenta',
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
