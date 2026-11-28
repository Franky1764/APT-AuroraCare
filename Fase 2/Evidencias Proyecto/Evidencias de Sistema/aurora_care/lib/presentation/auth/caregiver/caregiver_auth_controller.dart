import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation_session.dart';
import '../../../data/repositories/caregiver_account_repository.provider.dart';
import '../../../domain/entities/account_role.dart';
import '../../../domain/entities/session_info.dart';
import '../../../domain/exceptions/caregiver_auth_exception.dart';

enum CaregiverAuthForm { login, register }

class CaregiverAuthController
    extends AutoDisposeFamilyAsyncNotifier<SessionInfo?, CaregiverAuthForm> {
  bool _disposed = false;
  @override
  FutureOr<SessionInfo?> build(CaregiverAuthForm arg) {
    ref.onDispose(() => _disposed = true);
    return null;
  }

  Future<void> submit({
    String? name,
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return;
    final repository = ref.read(caregiverAccountRepositoryProvider);
    state = const AsyncLoading();
    try {
      final session = arg == CaregiverAuthForm.register
          ? await repository.register(
              name: name!,
              email: email,
              password: password,
            )
          : await repository.login(email: email, password: password);
      if (_disposed) return;
      if (session.role != AccountRole.caregiver) {
        throw const CaregiverAuthException(CaregiverAuthFailure.wrongRole);
      }
      ref.read(navigationSessionProvider.notifier).restore(session);
      state = AsyncData(session);
    } catch (error, stack) {
      if (!_disposed) state = AsyncError(error, stack);
    }
  }
}

final caregiverAuthProvider = AsyncNotifierProvider.autoDispose
    .family<CaregiverAuthController, SessionInfo?, CaregiverAuthForm>(
      CaregiverAuthController.new,
    );

String caregiverAuthMessage(Object error) => switch (error) {
  CaregiverAuthException(failure: CaregiverAuthFailure.invalidCredentials) =>
    'Revise su correo y contraseña e intente de nuevo.',
  CaregiverAuthException(failure: CaregiverAuthFailure.emailInUse) => 'Este correo ya tiene una cuenta. Puede iniciar sesión o recuperar su contraseña.',
  CaregiverAuthException(failure: CaregiverAuthFailure.wrongRole) => 'Esta cuenta no está registrada como cuidador. Use el acceso de adulto mayor.',
  CaregiverAuthException(failure: CaregiverAuthFailure.network) =>
    'No pudimos conectarnos. Intente de nuevo cuando tenga conexión.',
  CaregiverAuthException(failure: CaregiverAuthFailure.tooManyRequests) =>
    'Espere un momento antes de volver a intentarlo.',
  CaregiverAuthException(failure: CaregiverAuthFailure.weakPassword) =>
    'La contraseña no cumple los requisitos de seguridad. Revise la lista '
        'de abajo.',
  CaregiverAuthException(failure: CaregiverAuthFailure.invalidEmail) =>
    'Revise que el correo esté escrito correctamente.',
  CaregiverAuthException(
    failure: CaregiverAuthFailure.incompleteRegistration,
  ) =>
    'No pudimos completar el registro. Intente de nuevo; si el correo ya existe, recupere el acceso o solicite ayuda.',
  _ => 'No pudimos completar la solicitud. Intente de nuevo.',
};
