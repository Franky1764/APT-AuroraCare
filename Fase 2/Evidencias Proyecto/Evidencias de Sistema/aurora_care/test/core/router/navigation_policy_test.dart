import 'package:aurora_care/domain/entities/account_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/core/router/app_routes.dart';
import 'package:aurora_care/core/router/navigation_policy.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';

void main() {
  const anonymous = NavigationSession(initialized: true);
  const ready = NavigationSession(
    initialized: true,
    session: SessionInfo(
      uid: 'u1',
      email: 'rosa@example.test',
      disclaimerAccepted: true,
      currentMode: 2,
    ),
  );
  test('initial loading preserves only the requested path, not personal query data', () {
    final target = navigationRedirect(
      AppRoutes.elderLogin,
      const NavigationSession(),
    );
    final uri = Uri.parse(target!);
    expect(uri.path, AppRoutes.startup);
    expect(uri.queryParameters['next'], AppRoutes.elderLogin);
    expect(
      navigationRedirect(AppRoutes.startup, const NavigationSession()),
      isNull,
    );
  });
  test('anonymous users cannot open private destinations', () {
    for (final path in [
      AppRoutes.home,
      AppRoutes.disclaimer,
      AppRoutes.modeSelection,
      AppRoutes.caregiverHome,
      AppRoutes.caregiverLink,
      '/home/profile',
    ]) {
      expect(navigationRedirect(path, anonymous), AppRoutes.welcome);
    }
    expect(navigationRedirect(AppRoutes.elderLogin, anonymous), isNull);
  });
  test('deep links are restored only when permitted and internal', () {
    expect(
      navigationRedirect('/', anonymous, pendingPath: AppRoutes.elderLogin),
      AppRoutes.elderLogin,
    );
    expect(
      navigationRedirect('/', anonymous, pendingPath: AppRoutes.home),
      AppRoutes.welcome,
    );
    expect(
      navigationRedirect('/', ready, pendingPath: 'https://outside.test'),
      AppRoutes.home,
    );
    expect(
      navigationRedirect('/', ready, pendingPath: '//outside.test'),
      AppRoutes.home,
    );
  });
  test('disclaimer precedes mode selection and home', () {
    const pending = NavigationSession(
      initialized: true,
      session: SessionInfo(
        uid: 'u1',
        email: '',
        disclaimerAccepted: false,
        currentMode: 0,
      ),
    );
    expect(navigationRedirect(AppRoutes.home, pending), AppRoutes.disclaimer);
    expect(
      navigationRedirect(AppRoutes.modeSelection, pending),
      AppRoutes.disclaimer,
    );
    expect(navigationRedirect(AppRoutes.disclaimer, pending), isNull);
    const mode = NavigationSession(
      initialized: true,
      session: SessionInfo(
        uid: 'u1',
        email: '',
        disclaimerAccepted: true,
        currentMode: 0,
      ),
    );
    expect(navigationRedirect(AppRoutes.home, mode), AppRoutes.modeSelection);
  });
  test('the caregiver link route requires elder mode 3', () {
    const linkedMode = NavigationSession(
      initialized: true,
      session: SessionInfo(uid: 'u1', email: '', currentMode: 3),
    );
    expect(navigationRedirect(AppRoutes.caregiverLink, ready), AppRoutes.home);
    expect(navigationRedirect(AppRoutes.caregiverLink, linkedMode), isNull);
    expect(
      navigationRedirect('/', linkedMode, pendingPath: AppRoutes.caregiverLink),
      AppRoutes.caregiverLink,
    );
  });
  test('unknown offline fields do not restart onboarding', () {
    const offline = NavigationSession(
      initialized: true,
      session: SessionInfo(uid: 'u1', email: ''),
    );
    expect(navigationRedirect('/', offline), AppRoutes.home);
    expect(navigationRedirect(AppRoutes.home, offline), isNull);
  });
  test('authenticated caregiver cannot enter elder routes', () {
    const demo = NavigationSession(
      initialized: true,
      session: SessionInfo(
        uid: 'caregiver',
        email: '',
        role: AccountRole.caregiver,
      ),
    );
    expect(navigationRedirect(AppRoutes.caregiverHome, demo), isNull);
    expect(navigationRedirect(AppRoutes.home, demo), AppRoutes.caregiverHome);
    expect(navigationRedirect(AppRoutes.caregiverHome, ready), AppRoutes.home);
  });
  test('anonymous users cannot access caregiver routes', () {
    expect(
      navigationRedirect(
        AppRoutes.caregiverHome,
        const NavigationSession(initialized: true),
      ),
      AppRoutes.welcome,
    );
  });
  test('unknown account role requires choosing an access route', () {
    const unknown = NavigationSession(
      initialized: true,
      session: SessionInfo(uid: 'u', email: '', role: AccountRole.unknown),
    );
    expect(
      navigationRedirect(AppRoutes.home, unknown),
      AppRoutes.roleSelection,
    );
    expect(
      navigationRedirect(AppRoutes.caregiverHome, unknown),
      AppRoutes.roleSelection,
    );
    expect(navigationRedirect(AppRoutes.caregiverLogin, unknown), isNull);
  });
}
