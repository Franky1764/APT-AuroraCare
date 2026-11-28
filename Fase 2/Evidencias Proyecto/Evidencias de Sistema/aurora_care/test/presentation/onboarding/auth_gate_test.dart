import 'package:aurora_care/presentation/elder_alerts/elder_alerts.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/elder_caregiver_departure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/data/repositories/user_session_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/repositories/user_session_repository.dart';
import 'package:aurora_care/main.dart';
import 'package:aurora_care/presentation/home/home_screen.dart';
import 'package:aurora_care/presentation/challenges/daily_challenge_provider.dart';
import 'package:aurora_care/presentation/onboarding/auth_gate.dart';
import 'package:aurora_care/presentation/onboarding/splash_screen.dart';
import 'package:aurora_care/presentation/onboarding/welcome_screen.dart';
import 'package:aurora_care/presentation/profile/profile_screen.dart';
import 'package:aurora_care/presentation/progress/progress_screen.dart';

/// Repositorio falso: la sesión devuelta (o null) se controla desde el
/// test. [delay] simula una lectura lenta, para poder observar el splash.
class _FakeUserSessionRepository implements UserSessionRepository {
  _FakeUserSessionRepository(this.session, {this.delay = Duration.zero});

  final SessionInfo? session;
  final Duration delay;

  @override
  Future<SessionInfo?> readSession() async {
    if (delay > Duration.zero) await Future.delayed(delay);
    return session;
  }
}

Future<Widget> _wrap({
  SessionInfo? session,
  Duration delay = Duration.zero,
}) async {
  // HomeScreen/ProfileScreen leen textScaleProvider etc., que ahora
  // dependen de sharedPreferencesProvider.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      elderAlertsSyncProvider.overrideWith((ref) {}),
      userSessionRepositoryProvider.overrideWithValue(
        _FakeUserSessionRepository(session, delay: delay),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      elderCaregiverDepartureProvider.overrideWith((ref) {}),
      dailyChallengeProvider.overrideWithValue(null),
    ],
    child: const AuroraCareApp(),
  );
}

/// pumpAndSettle() no avanza Timers que no estén atados a una animación
/// en curso (como el Future.delayed interno de startupSessionProvider),
/// así que primero hay que forzar el reloj hacia adelante con un pump()
/// explícito y luego sí dejar asentar el resto (navegación, imágenes).
Future<void> _settleStartup(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  group('AuthGate', () {
    testWidgets('el splash aparece mientras la sesión se está leyendo', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _wrap(session: null, delay: const Duration(milliseconds: 500)),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);

      await _settleStartup(tester);
    });

    testWidgets('sin sesión, muestra la Bienvenida', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await _wrap(session: null));
      await _settleStartup(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('con sesión, muestra Home con el nombre de displayName', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _wrap(
          session: const SessionInfo(
            uid: 'u1',
            email: 'rosa@correo.cl',
            displayName: 'Rosa',
            consentGiven: true,
            currentMode: 2,
            disclaimerAccepted: true,
          ),
        ),
      );
      await _settleStartup(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Rosa'), findsWidgets);
    });

    testWidgets('sesión sin displayName usa la parte del correo antes de @', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _wrap(
          session: const SessionInfo(uid: 'u1', email: 'carla@correo.cl'),
        ),
      );
      await _settleStartup(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('carla'), findsWidgets);
    });

    testWidgets('con sesión guardada, tocar el avatar abre ProfileScreen y '
        '"Ver mi progreso" abre ProgressScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        await _wrap(
          session: const SessionInfo(
            uid: 'u1',
            email: 'rosa@correo.cl',
            displayName: 'Rosa',
            consentGiven: true,
            currentMode: 2,
            disclaimerAccepted: true,
          ),
        ),
      );
      await _settleStartup(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Avatar: la inicial del nombre ("R") es el único Text con ese
      // contenido dentro del CircleAvatar.
      await tester.tap(find.text('R'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      // AppHeaderBar usa un IconButton propio, no el BackButton estándar
      // que tester.pageBack() espera encontrar.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      final viewProgress = find.text('Ver mi progreso');
      await tester.ensureVisible(viewProgress);
      await tester.pumpAndSettle();
      await tester.tap(viewProgress);
      await tester.pumpAndSettle();
      expect(find.byType(ProgressScreen), findsOneWidget);
    });
  });

  group('persistencia del tamaño de texto', () {
    testWidgets('con textScale=1.3 guardado, la app arranca con ese textScaler '
        '(vía AuroraCareApp, no solo AuthGate)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'pref_text_scale': 1.3});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
      dailyChallengeProvider.overrideWithValue(null),
            userSessionRepositoryProvider.overrideWithValue(
              _FakeUserSessionRepository(null),
            ),
          ],
          child: const AuroraCareApp(),
        ),
      );
      await _settleStartup(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      final mediaQuery = MediaQuery.of(
        tester.element(find.byType(WelcomeScreen)),
      );
      expect(mediaQuery.textScaler.scale(10), 13.0);
    });
  });

  group('resolveStartDestination', () {
    SessionInfo session({bool? disclaimerAccepted, int? currentMode}) =>
        SessionInfo(
          uid: 'u1',
          email: 'rosa@correo.cl',
          disclaimerAccepted: disclaimerAccepted,
          currentMode: currentMode,
        );

    test('sin sesión: Bienvenida', () {
      expect(
        resolveStartDestination(null, enforceOnboarding: false),
        StartDestination.welcome,
      );
      expect(
        resolveStartDestination(null, enforceOnboarding: true),
        StartDestination.welcome,
      );
    });

    test('disclaimer pendiente (disclaimerAccepted false): Disclaimer', () {
      expect(
        resolveStartDestination(
          session(disclaimerAccepted: false, currentMode: 0),
          enforceOnboarding: true,
        ),
        StartDestination.disclaimer,
      );
    });

    test('el disclaimer pendiente tiene prioridad sobre el modo', () {
      expect(
        resolveStartDestination(
          session(disclaimerAccepted: false, currentMode: 2),
          enforceOnboarding: true,
        ),
        StartDestination.disclaimer,
      );
    });

    test('disclaimer aceptado y modo 0 (no elegido): Selección de modo', () {
      expect(
        resolveStartDestination(
          session(disclaimerAccepted: true, currentMode: 0),
          enforceOnboarding: true,
        ),
        StartDestination.modeSelection,
      );
    });

    test('disclaimer aceptado y modo 1 (eliminado): Selección de modo', () {
      expect(
        resolveStartDestination(
          session(disclaimerAccepted: true, currentMode: 1),
          enforceOnboarding: true,
        ),
        StartDestination.modeSelection,
      );
    });

    test('disclaimer aceptado y modo 2 o 3: Home', () {
      for (final mode in [2, 3]) {
        expect(
          resolveStartDestination(
            session(disclaimerAccepted: true, currentMode: mode),
            enforceOnboarding: true,
          ),
          StartDestination.home,
        );
      }
    });

    test('datos desconocidos (sin red): Home, no se vuelve al onboarding', () {
      expect(
        resolveStartDestination(session(), enforceOnboarding: true),
        StartDestination.home,
      );
    });

    test('enforceOnboarding en false: Home aunque falte el onboarding', () {
      expect(
        resolveStartDestination(
          session(disclaimerAccepted: false, currentMode: 0),
          enforceOnboarding: false,
        ),
        StartDestination.home,
      );
    });
  });

  test('kEnforceOnboardingOnReopen está en true', () {
    expect(kEnforceOnboardingOnReopen, isTrue);
  });
}
