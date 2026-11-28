import '../shared/email_validation.dart';
// lib/presentation/auth/elder/forgot_password_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/repositories/auth_repository_impl.provider.dart';
import '../../../domain/exceptions/auth_exception.dart';
import '../../shared/auth_error_widgets.dart';

/// Espera antes de permitir reenviar el correo: evita ráfagas de envíos y
/// los límites de Firebase ("too-many-requests").
const forgotPasswordResendDelay = Duration(seconds: 60);

/// Pantalla de recuperación de contraseña del adulto mayor
/// (F2 — auth/elder, SCRUM-95).
/// Envía el correo de recuperación con
/// FirebaseAuth.sendPasswordResetEmail (vía AuthRepository). Por protección
/// contra enumeración de correos, la confirmación no revela si existe una
/// cuenta con ese correo: "no existe" se trata igual que un envío correcto.
/// Sirve para adulto mayor y cuidador.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.onBackToLogin});

  final VoidCallback? onBackToLogin;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _instructionsSent = false;
  bool _sending = false;
  bool _canResend = false;
  bool _resent = false;
  String? _emailError;
  String? _generalError;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !EmailValidation.isValid(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  Future<void> _handleSendInstructions({bool resend = false}) async {
    if (_sending) return;
    if (!resend && !_formKey.currentState!.validate()) {
      return;
    }
    final email = _emailController.text.trim();
    setState(() {
      _sending = true;
      _emailError = null;
      _generalError = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
    } on AuthException catch (e) {
      if (!mounted) return;
      // "No existe la cuenta" se muestra como envío correcto (no revelar
      // qué correos están registrados).
      if (e.type != AuthErrorType.userNotFound) {
        setState(() {
          _sending = false;
          switch (e.type) {
            case AuthErrorType.invalidEmail:
              _emailError = 'Ingresa un correo válido';
            case AuthErrorType.networkError:
              _generalError =
                  'No hay conexión a internet. Revisa tu conexión e '
                  'inténtalo de nuevo.';
            case AuthErrorType.tooManyRequests:
              _generalError =
                  'Demasiados intentos. Espera unos minutos e inténtalo '
                  'de nuevo.';
            default:
              _generalError =
                  'No pudimos enviar el correo. Inténtalo de nuevo en un '
                  'momento.';
          }
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _generalError =
            'No pudimos enviar el correo. Inténtalo de nuevo en un momento.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _instructionsSent = true;
      _resent = resend;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer(forgotPasswordResendDelay, () {
      if (mounted) setState(() => _canResend = true);
    });
  }

  void _handleBackToLogin() {
    if (widget.onBackToLogin != null) {
      widget.onBackToLogin!();
    } else {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutes.elderLogin);
      }
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySecondary,
      errorStyle: AppTextStyles.fieldError,
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Olvidé mi contraseña', style: AppTextStyles.heading),
          const SizedBox(height: 12),
          Text(
            'Te enviaremos instrucciones a tu correo para recuperar el '
            'acceso.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 32),
          Text('Correo', style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            style: AppTextStyles.body,
            decoration: _decoration('rosa@correo.cl'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            validator: _validateEmail,
            enabled: !_sending,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          if (_emailError != null) FieldErrorText(_emailError!),
          const SizedBox(height: 32),
          if (_generalError != null) ...[
            Semantics(
              liveRegion: true,
              child: GeneralErrorBanner(_generalError!),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _sending ? null : () => _handleSendInstructions(),
            child: _sending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Text('Enviar instrucciones'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read, color: AppColors.primary, size: 80),
        const SizedBox(height: 24),
        Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading,
        ),
        const SizedBox(height: 12),
        Text(
          'Si hay una cuenta con ${_emailController.text.trim()}, te '
          'enviamos instrucciones para recuperar tu contraseña.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 12),
        Text(
          'Si no lo ves en unos minutos, revisa la carpeta de spam o '
          'correo no deseado.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
        if (_resent) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              'Enviamos el correo de nuevo.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
          ),
        ],
        if (_generalError != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: GeneralErrorBanner(_generalError!),
          ),
        ],
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _canResend && !_sending
              ? () => _handleSendInstructions(resend: true)
              : null,
          child: _sending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Text(
                  _canResend
                      ? 'Reenviar correo'
                      : 'Podrás reenviar el correo en un minuto',
                ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _handleBackToLogin,
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: _instructionsSent ? _buildConfirmation() : _buildForm(),
        ),
      ),
    );
  }
}
