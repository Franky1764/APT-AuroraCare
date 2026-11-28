import '../../domain/entities/account_role.dart';
import '../../domain/entities/session_info.dart';
import 'app_routes.dart';
import 'navigation_session.dart';

/// Si es true, al reabrir la app quien no terminó el onboarding (disclaimer
/// o elección de modo) lo retoma donde quedó. Ya existe la persistencia de
/// disclaimerAcceptedAt y currentMode, por eso queda activo.
const bool kEnforceOnboardingOnReopen = true;

enum StartDestination { welcome, disclaimer, modeSelection, home }

/// Función pura (sin providers ni navegación) para poder testearla sola.
///
/// Reglas (con enforceOnboarding):
/// - sin sesión → bienvenida
/// - disclaimerAccepted == false → disclaimer
/// - currentMode conocido y < 2 (0 = no elegido; 1 = modo eliminado) →
///   selección de modo
/// - cualquier dato desconocido (null, por falta de red) → Inicio, para no
///   devolver al onboarding a quien ya lo completó.
StartDestination resolveStartDestination(
  SessionInfo? session, {
  required bool enforceOnboarding,
}) {
  if (session == null) return StartDestination.welcome;
  if (!enforceOnboarding) return StartDestination.home;
  if (session.disclaimerAccepted == false) return StartDestination.disclaimer;
  final mode = session.currentMode;
  if (mode != null && mode < 2) return StartDestination.modeSelection;
  return StartDestination.home;
}

String resolveUserName(SessionInfo session) {
  final displayName = session.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final emailPrefix = session.email.split('@').first.trim();
  if (emailPrefix.isNotEmpty) return emailPrefix;
  return 'Usuario';
}

String destinationForSession(NavigationSession access) {
  if (access.session?.role == AccountRole.caregiver) {
    return AppRoutes.caregiverHome;
  }
  if (access.session?.role == AccountRole.unknown) {
    return AppRoutes.roleSelection;
  }
  return switch (resolveStartDestination(
    access.session,
    enforceOnboarding: kEnforceOnboardingOnReopen,
  )) {
    StartDestination.welcome => AppRoutes.welcome,
    StartDestination.disclaimer => AppRoutes.disclaimer,
    StartDestination.modeSelection => AppRoutes.modeSelection,
    StartDestination.home => AppRoutes.home,
  };
}

/// El control de rutas no sustituye las reglas de acceso de Firebase.
/// El cuidador autenticado no puede entrar en rutas privadas del adulto mayor.
String? navigationRedirect(
  String path,
  NavigationSession access, {
  String? pendingPath,
}) {
  if (!access.initialized) {
    return path == AppRoutes.startup
        ? null
        : Uri(
            path: AppRoutes.startup,
            queryParameters: {'next': path},
          ).toString();
  }
  final destination = destinationForSession(access);
  if (path == AppRoutes.startup) {
    // Solo se recuperan destinos conocidos y permitidos, nunca URLs externas.
    const resumable = {
      AppRoutes.privacy,
      AppRoutes.welcome,
      AppRoutes.roleSelection,
      AppRoutes.elderLogin,
      AppRoutes.elderRegister,
      AppRoutes.forgotPassword,
      AppRoutes.caregiverLogin,
      AppRoutes.caregiverRegister,
      AppRoutes.caregiverForgotPassword,
      AppRoutes.home,
      AppRoutes.progressReport,
      AppRoutes.caregiverLink,
      AppRoutes.disclaimer,
      AppRoutes.modeSelection,
      AppRoutes.caregiverHome,
    };
    if (pendingPath != null &&
        resumable.contains(pendingPath) &&
        navigationRedirect(pendingPath, access) == null) {
      return pendingPath;
    }
    return destination;
  }
  final elderPrivate =
      path == AppRoutes.home ||
      path.startsWith('${AppRoutes.home}/') ||
      path.startsWith('/onboarding/');
  if (access.session == null) {
    if (elderPrivate || path == AppRoutes.privacy) return destination;
    if (path.startsWith('/caregiver/')) {
      return AppRoutes.welcome;
    }
    return null;
  }
  if (path == AppRoutes.privacy) return null;
  if (access.session?.role == AccountRole.caregiver) {
    return path.startsWith('/caregiver/') ? null : AppRoutes.caregiverHome;
  }
  if (access.session?.role == AccountRole.unknown) {
    return path == AppRoutes.roleSelection || path.startsWith('/auth/')
        ? null
        : AppRoutes.roleSelection;
  }
  if (path.startsWith('/caregiver/')) return destination;
  if (destination != AppRoutes.home) {
    return path == destination ? null : destination;
  }
  if (path == AppRoutes.caregiverLink && access.session?.currentMode != 3) {
    return AppRoutes.home;
  }
  if (path == AppRoutes.disclaimer ||
      path == AppRoutes.modeSelection ||
      path == AppRoutes.welcome ||
      path == AppRoutes.roleSelection ||
      path.startsWith('/auth/')) {
    return AppRoutes.home;
  }
  return null;
}
