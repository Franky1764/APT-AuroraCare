import '../../presentation/privacy/privacy_screen.dart';
import '../../presentation/privacy/privacy_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/caregiver/caregiver_login_screen.dart';
import '../../presentation/auth/caregiver/caregiver_register_screen.dart';
import '../../presentation/auth/elder/forgot_password_screen.dart';
import '../../presentation/auth/elder/login_screen.dart';
import '../../presentation/auth/elder/register_screen.dart';
import '../../presentation/caregiver_dashboard/caregiver_dashboard_screen.dart';
import '../../presentation/caregiver_dashboard/caregiver_navigation.dart';
import '../../presentation/home/home_flow.dart';
import '../../presentation/onboarding/auth_gate.dart';
import '../../presentation/onboarding/role_selection_screen.dart';
import '../../presentation/onboarding/welcome_flow.dart';
import '../../presentation/onboarding/welcome_screen.dart';
import 'app_routes.dart';
import '../../presentation/profile/caregiver_link_screen.dart';
import '../../presentation/reports/progress_report_screen.dart';
import '../audio/music_route_scope.dart';
import 'navigation_session.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.startup,
    // Registra musicRouteObserver sobre el Navigator que administra
    // GoRouter: Home, Perfil y el resto de pantallas abiertas con
    // Navigator.push desde Home comparten ese mismo Navigator, así que
    // un solo observador alcanza para ambos estilos de navegación (ver
    // core/audio/music_route_scope.dart).
    observers: [musicRouteObserver],
    redirect: (_, state) {
      final access = ref.read(navigationSessionProvider);
      if (access.initialized &&
          access.session != null &&
          ref.read(pendingPrivacyDeletionProvider) != null) {
        return state.uri.path == AppRoutes.privacy ? null : AppRoutes.privacy;
      }
      return navigationRedirect(
        state.uri.path,
        access,
        pendingPath: state.uri.queryParameters['next'],
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, _) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.caregiverLink,
        builder: (_, _) => const CaregiverLinkScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressReport,
        builder: (_, _) => const ProgressReportScreen(),
      ),
      GoRoute(path: AppRoutes.startup, builder: (_, _) => const AuthGate()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (_, _) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.elderRegister,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.elderLogin,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.disclaimer,
        builder: (_, _) =>
            buildDisclaimerStep(ref.read(navigationSessionProvider).userName),
      ),
      GoRoute(
        path: AppRoutes.modeSelection,
        builder: (_, _) => buildModeSelectionStep(
          ref.read(navigationSessionProvider).userName,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) =>
            buildHomeScreen(ref.read(navigationSessionProvider).userName),
      ),
      GoRoute(
        path: AppRoutes.caregiverRegister,
        builder: (context, _) => CaregiverRegisterScreen(
          onRegisterSuccess: () => CaregiverNavigation.startSession(context),
          onGoToLogin: () => context.push(AppRoutes.caregiverLogin),
        ),
      ),
      GoRoute(
        path: AppRoutes.caregiverLogin,
        builder: (context, _) => CaregiverLoginScreen(
          onLoginSuccess: () => CaregiverNavigation.startSession(context),
          onGoToRegister: () => context.push(AppRoutes.caregiverRegister),
          onForgotPassword: () =>
              context.push(AppRoutes.caregiverForgotPassword),
        ),
      ),
      GoRoute(
        path: AppRoutes.caregiverForgotPassword,
        builder: (context, _) => ForgotPasswordScreen(
          onBackToLogin: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.caregiverLogin);
            }
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.caregiverHome,
        builder: (_, _) => CaregiverDashboardScreen(
          caregiverName: ref.read(navigationSessionProvider).userName,
        ),
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('AuroraCare')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No encontramos esta pantalla.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.startup),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // Escuchar evita recrear el router y perder su pila cuando cambia la sesión.
  ref.listen(navigationSessionProvider, (_, _) => router.refresh());
  ref.listen(pendingPrivacyDeletionProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
