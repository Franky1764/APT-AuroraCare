import 'package:aurora_care/presentation/caregiver_dashboard/elder_caregiver_departure.dart';
import 'package:aurora_care/presentation/challenges/daily_challenge_provider.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_connection_provider.dart';
import 'package:aurora_care/domain/entities/account_role.dart';
import 'package:aurora_care/domain/repositories/caregiver_account_repository.dart';
import 'package:aurora_care/data/repositories/caregiver_account_repository.provider.dart';
import 'package:aurora_care/core/auth_account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora_care/main.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/presentation/auth/caregiver/caregiver_login_screen.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_dashboard_screen.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_navigation.dart';
import 'package:aurora_care/core/router/app_router.dart';
import 'package:aurora_care/core/router/app_routes.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/data/repositories/cognitive_profile_repository_impl.provider.dart';
import 'package:aurora_care/data/repositories/user_session_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/entities/user.dart';
import 'package:aurora_care/domain/repositories/cognitive_profile_repository.dart';
import 'package:aurora_care/domain/repositories/user_session_repository.dart';
import 'package:aurora_care/presentation/onboarding/auth_gate.dart';
import 'package:aurora_care/presentation/onboarding/medical_disclaimer_screen.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/presentation/onboarding/mode_selection_screen.dart';
import 'package:aurora_care/presentation/onboarding/role_selection_screen.dart';
import 'package:aurora_care/presentation/onboarding/welcome_screen.dart';
import 'package:aurora_care/presentation/auth/elder/register_screen.dart';
import 'package:aurora_care/presentation/auth/elder/login_screen.dart';
import 'package:aurora_care/presentation/auth/elder/forgot_password_screen.dart';
import 'package:aurora_care/presentation/home/home_screen.dart';

import '../../helpers/fake_auth_repository.dart';

class SessionRepository implements UserSessionRepository {
  SessionInfo? session;
  @override
  Future<SessionInfo?> readSession() async => session;
}

class AuthRepository extends FakeAuthRepository {
  AuthRepository(this.sessions);
  final SessionRepository sessions;
  bool failDisclaimer = false;

  @override
  Future<void> acceptDisclaimer({required String uid}) async {
    if (failDisclaimer) throw StateError('sin conexión');
  }

  @override
  Future<User> loginElder({
    required String email,
    required String password,
  }) async {
    sessions.session = const SessionInfo(
      uid: 'u1',
      email: 'rosa@example.test',
      displayName: 'Rosa',
      currentMode: 2,
      disclaimerAccepted: true,
    );
    return super.loginElder(email: email, password: password);
  }

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) async {
    sessions.session = SessionInfo(
      uid: 'u1',
      email: email,
      displayName: displayName,
      currentMode: 0,
      disclaimerAccepted: false,
    );
    return super.registerElder(
      displayName: displayName,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> logout() async {
    sessions.session = null;
  }
}

class ProfileRepository implements CognitiveProfileRepository {
  @override
  Future<CognitiveProfile?> getLocalProfile() async => null;
  @override
  Future<CognitiveProfile> createProfile({required int activeMode}) async =>
      CognitiveProfile(
        uuid: 'local-only',
        deviceId: 'test-device',
        createdAt: DateTime(2026),
        activeMode: activeMode,
      );
  @override
  Future<void> updateActiveMode({
    required String uuid,
    required int activeMode,
  }) async {}
}

class CaregiverAccounts extends Fake implements CaregiverAccountRepository {
  @override
  Future<SessionInfo> login({
    required String email,
    required String password,
  }) async => SessionInfo(
    uid: 'caregiver',
    email: email,
    displayName: 'Cuidador',
    role: AccountRole.caregiver,
  );
}

Future<ProviderContainer> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final sessions = SessionRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        elderCaregiverDepartureProvider.overrideWith((ref) {}),
        dailyChallengeProvider.overrideWithValue(null),
        caregiverConnectionProvider.overrideWith((ref) => Stream.value(false)),
        caregiverAccountRepositoryProvider.overrideWithValue(
          CaregiverAccounts(),
        ),
        authenticatedAccountIdProvider.overrideWith(
          (ref) => ref.watch(navigationSessionProvider).session?.uid,
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        startupSessionProvider.overrideWith((ref) async => null),
        userSessionRepositoryProvider.overrideWithValue(sessions),
        authRepositoryProvider.overrideWithValue(AuthRepository(sessions)),
        cognitiveProfileRepositoryProvider.overrideWithValue(
          ProfileRepository(),
        ),
      ],
      child: const AuroraCareApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AuroraCareApp)));
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> openRegister(WidgetTester tester) async {
  await tap(tester, 'Comenzar');
  expect(find.byType(RoleSelectionScreen), findsOneWidget);
  await tap(tester, 'Soy adulto mayor');
  expect(find.byType(RegisterScreen), findsOneWidget);
}

void main() {
  testWidgets(
    'default links navigate welcome, role, login and password recovery',
    (tester) async {
      final container = await start(tester);
      await openRegister(tester);
      await tap(tester, 'Ya tengo cuenta');
      expect(find.byType(LoginScreen), findsOneWidget);
      final router = container.read(appRouterProvider);
      await container.read(textScaleProvider.notifier).set(1.3);
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider), same(router));
      expect(find.byType(LoginScreen), findsOneWidget);
      await container.read(textScaleProvider.notifier).set(1);
      await tester.pumpAndSettle();
      await tap(tester, 'Olvidé mi contraseña');
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'rosa@example.test');
      await tap(tester, 'Enviar instrucciones');
      await tap(tester, 'Volver a iniciar sesión');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        AppRoutes.elderLogin,
      );
    },
  );
  testWidgets(
    'login and logout reset the stack and prevent anonymous access to home',
    (tester) async {
      final container = await start(tester);
      await openRegister(tester);
      await tap(tester, 'Ya tengo cuenta');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'rosa@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tap(tester, 'Entrar');
      final router = container.read(appRouterProvider);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Rosa'), findsWidgets);
      expect(router.canPop(), isFalse);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        isNot(contains('Rosa')),
      );
      await tap(tester, 'R');
      await tap(tester, 'Cerrar sesión');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(router.canPop(), isFalse);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );
  testWidgets(
    'registration requires disclaimer and mode before entering home',
    (tester) async {
      final container = await start(tester);
      await openRegister(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Rosa');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'rosa@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Rosa12345678',
      );
      // El botón "Crear mi cuenta" se habilita recién cuando la
      // contraseña es válida (ver password_policy.dart): hace falta un
      // pump() para que ese setState() se refleje antes de tocarlo.
      await tester.pump();
      await tap(tester, 'Crear mi cuenta');
      expect(find.byType(MedicalDisclaimerScreen), findsOneWidget);
      await tap(tester, 'Entiendo y acepto lo anterior');
      final auth = container.read(authRepositoryProvider) as AuthRepository;
      auth.failDisclaimer = true;
      await tap(tester, 'Entendido, continuar');
      expect(find.byType(MedicalDisclaimerScreen), findsOneWidget);
      expect(
        container.read(navigationSessionProvider).session!.disclaimerAccepted,
        isFalse,
      );
      container.read(appRouterProvider).go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(MedicalDisclaimerScreen), findsOneWidget);
      auth.failDisclaimer = false;
      await tap(tester, 'Reintentar');
      expect(
        container.read(navigationSessionProvider).session!.disclaimerAccepted,
        isTrue,
      );
      expect(find.byType(ModeSelectionScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode_card_2')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(appRouterProvider).canPop(), isFalse);
    },
  );
  testWidgets('unknown route offers a safe return to the start', (
    tester,
  ) async {
    final container = await start(tester);
    container.read(appRouterProvider).go('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('No encontramos esta pantalla.'), findsOneWidget);
    await tap(tester, 'Volver al inicio');
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
  testWidgets(
    'authenticated caregiver has its own start and real logout route',
    (tester) async {
      final container = await start(tester);
      final router = container.read(appRouterProvider);
      router.go(AppRoutes.caregiverLogin);
      await tester.pumpAndSettle();
      expect(find.byType(CaregiverLoginScreen), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'caregiver@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      // El dashboard tiene animaciones continuas: no se espera a que se detengan.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CaregiverDashboardScreen), findsOneWidget);
      router.go(AppRoutes.home);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(CaregiverDashboardScreen), findsOneWidget);
      CaregiverNavigation.logout(
        tester.element(find.byType(CaregiverDashboardScreen)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(router.canPop(), isFalse);
    },
  );
}
