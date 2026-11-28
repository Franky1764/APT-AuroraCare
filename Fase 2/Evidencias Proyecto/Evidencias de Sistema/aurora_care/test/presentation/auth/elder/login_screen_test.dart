import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/user.dart';
import 'package:aurora_care/domain/exceptions/auth_exception.dart';
import 'package:aurora_care/domain/repositories/auth_repository.dart';
import 'package:aurora_care/presentation/auth/elder/login_screen.dart';

/// Repositorio falso: permite forzar el [AuthErrorType] que devuelve
/// loginElder(), sin tocar data/ ni domain/ (solo se usa en el test).
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> acceptDisclaimer({required String uid}) async {}

  @override
  Future<bool> hasMetricsConsent({required String uid}) async => true;

  @override
  Future<void> setMetricsConsent({
    required String uid,
    required bool given,
  }) async {}

  @override
  Future<void> updateCurrentMode({
    required String uid,
    required int mode,
  }) async {}

  _FakeAuthRepository({this.loginError});

  final AuthErrorType? loginError;

  @override
  Future<User> loginElder({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw AuthException(loginError!);
    return User(
      uid: 'u1',
      displayName: 'Rosa',
      createdAt: DateTime.now(),
      consentGiven: false,
      currentMode: 1,
    );
  }

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordReset({required String email}) {
    throw UnimplementedError();
  }
}

Widget _wrap(Widget child, {AuthRepository? authRepository}) {
  return ProviderScope(
    overrides: [
      if (authRepository != null)
        authRepositoryProvider.overrideWithValue(authRepository),
    ],
    child: MaterialApp(home: child),
  );
}

Color _borderColor(WidgetTester tester, Finder fieldFinder) {
  final textField = tester.widget<TextField>(
    find.descendant(of: fieldFinder, matching: find.byType(TextField)),
  );
  final border = textField.decoration!.enabledBorder as OutlineInputBorder;
  return border.borderSide.color;
}

bool _hasFocus(WidgetTester tester, Finder fieldFinder) {
  final editableText = tester.widget<EditableText>(
    find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
  );
  return editableText.focusNode.hasFocus;
}

void main() {
  final emailField = find.widgetWithText(TextFormField, 'carla@email.com');
  final passwordField = find.widgetWithText(TextFormField, '••••••');
  final submitButton = find.widgetWithText(ElevatedButton, 'Entrar');

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(emailField, 'carla@email.com');
    await tester.enterText(passwordField, 'secreta123');
  }

  testWidgets('LoginScreen renderiza los campos y los elementos interactivos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump(); // deja resolver el build() async del notifier

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(submitButton, findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Olvidé mi contraseña'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Crear cuenta'), findsOneWidget);
  });

  testWidgets('correo vacío o inválido: error bajo Correo (validación local)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.enterText(passwordField, 'secreta123');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(_hasFocus(tester, emailField), isTrue);
  });

  testWidgets('contraseña vacía: error bajo Contraseña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.enterText(emailField, 'carla@email.com');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(_hasFocus(tester, passwordField), isTrue);
  });

  testWidgets(
    'credenciales incorrectas: un solo mensaje bajo Contraseña y AMBOS '
    'campos quedan en rojo',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const LoginScreen(),
          authRepository: _FakeAuthRepository(
            loginError: AuthErrorType.wrongPassword,
          ),
        ),
      );

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Correo o contraseña incorrectos. Inténtelo de nuevo.'),
        findsOneWidget,
      );
      expect(_borderColor(tester, emailField), AppColors.error);
      expect(_borderColor(tester, passwordField), AppColors.error);
    },
  );

  testWidgets(
    'el error de credenciales se limpia apenas se vuelve a escribir en '
    'cualquiera de los dos campos',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const LoginScreen(),
          authRepository: _FakeAuthRepository(
            loginError: AuthErrorType.wrongPassword,
          ),
        ),
      );

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Correo o contraseña incorrectos. Inténtelo de nuevo.'),
        findsOneWidget,
      );

      await tester.enterText(emailField, 'otra@correo.cl');
      await tester.pump();

      expect(
        find.text('Correo o contraseña incorrectos. Inténtelo de nuevo.'),
        findsNothing,
      );
      expect(_borderColor(tester, emailField), AppColors.border);
      expect(_borderColor(tester, passwordField), AppColors.border);
    },
  );

  testWidgets(
    'demasiados intentos u otro error no distinguible: mensaje general '
    'sobre el botón',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const LoginScreen(),
          authRepository: _FakeAuthRepository(
            loginError: AuthErrorType.unknown,
          ),
        ),
      );

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Algo salió mal. Intenta de nuevo.'), findsOneWidget);
      final bannerTop = tester.getTopLeft(
        find.text('Algo salió mal. Intenta de nuevo.'),
      );
      final buttonTop = tester.getTopLeft(submitButton);
      expect(bannerTop.dy, lessThan(buttonTop.dy));
    },
  );

  testWidgets(
    'LoginScreen ejecuta onLoginSuccess cuando el formulario es válido',
    (WidgetTester tester) async {
      String? loggedInUserName;

      await tester.pumpWidget(
        _wrap(
          LoginScreen(
            onLoginSuccess: (userName) => loggedInUserName = userName,
          ),
          authRepository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await fillValidForm(tester);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(loggedInUserName, 'carla');
    },
  );
}
