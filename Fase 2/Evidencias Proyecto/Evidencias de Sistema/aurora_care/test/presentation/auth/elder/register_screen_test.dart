import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/domain/entities/user.dart';
import 'package:aurora_care/domain/exceptions/auth_exception.dart';
import 'package:aurora_care/domain/repositories/auth_repository.dart';
import 'package:aurora_care/presentation/auth/elder/register_screen.dart';

/// Repositorio falso: permite forzar el [AuthErrorType] que devuelve
/// registerElder(), sin tocar data/ ni domain/ (solo se usa en el test).
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

  _FakeAuthRepository({this.registerError});

  final AuthErrorType? registerError;

  @override
  Future<User> registerElder({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (registerError != null) throw AuthException(registerError!);
    return User(
      uid: 'u1',
      displayName: displayName,
      createdAt: DateTime.now(),
      consentGiven: false,
      currentMode: 1,
    );
  }

  @override
  Future<User> loginElder({required String email, required String password}) {
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

bool _hasFocus(WidgetTester tester, Finder fieldFinder) {
  final editableText = tester.widget<EditableText>(
    find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
  );
  return editableText.focusNode.hasFocus;
}

Color _borderColor(WidgetTester tester, Finder fieldFinder) {
  final textField = tester.widget<TextField>(
    find.descendant(of: fieldFinder, matching: find.byType(TextField)),
  );
  final border = textField.decoration!.enabledBorder as OutlineInputBorder;
  return border.borderSide.color;
}

void main() {
  final nameField = find.widgetWithText(TextFormField, 'Rosa');
  final emailField = find.widgetWithText(TextFormField, 'rosa@correo.cl');
  final passwordField = find.widgetWithText(TextFormField, '••••••');
  final submitButton = find.widgetWithText(ElevatedButton, 'Crear mi cuenta');

  // 12 caracteres, con mayúscula, minúscula y número — cumple la
  // política vigente (ver password_policy.dart).
  const validPassword = 'Rosa12345678';

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(nameField, 'Rosa');
    await tester.enterText(emailField, 'rosa@correo.cl');
    await tester.enterText(passwordField, validPassword);
    // El botón se habilita recién cuando la contraseña es válida (ver
    // build()): hace falta un pump() para que ese setState() se
    // refleje antes de tocar el botón.
    await tester.pump();
  }

  testWidgets('RegisterScreen renderiza los campos y el botón', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pump(); // deja resolver el build() async del notifier

    expect(find.text('¿Cómo quiere que lo llamemos?'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(submitButton, findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Ya tengo cuenta'), findsOneWidget);
  });

  testWidgets('nombre vacío: error bajo Nombre y el foco va a ese campo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));

    await tester.enterText(emailField, 'rosa@correo.cl');
    await tester.enterText(passwordField, validPassword);
    await tester.pump();
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Cuéntanos cómo te llamamos'), findsOneWidget);
    expect(_hasFocus(tester, nameField), isTrue);
  });

  testWidgets(
    'correo vacío o inválido: error bajo Correo con el mensaje pedido',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(nameField, 'Rosa');
      await tester.enterText(passwordField, validPassword);
      await tester.pump();
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(_hasFocus(tester, emailField), isTrue);
    },
  );

  testWidgets(
    'contraseña corta: el botón queda deshabilitado y muestra cuántos '
    'caracteres faltan',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.enterText(nameField, 'Rosa');
      await tester.enterText(emailField, 'rosa@correo.cl');
      await tester.enterText(passwordField, '123');
      await tester.pump();

      expect(find.text('Te faltan 9 caracteres (mínimo 12).'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(submitButton);
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('correo ya registrado: error bajo Correo con el mensaje pedido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const RegisterScreen(),
        authRepository: _FakeAuthRepository(
          registerError: AuthErrorType.emailAlreadyInUse,
        ),
      ),
    );

    await fillValidForm(tester);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Este correo ya tiene una cuenta. ¿Quieres iniciar sesión?'),
      findsOneWidget,
    );
    expect(_borderColor(tester, emailField), AppColors.error);
  });

  testWidgets('sin conexión u otro error: mensaje general sobre el botón', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const RegisterScreen(),
        authRepository: _FakeAuthRepository(
          registerError: AuthErrorType.unknown,
        ),
      ),
    );

    await fillValidForm(tester);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Algo salió mal. Intenta de nuevo.'), findsOneWidget);
    // El banner general va justo sobre el botón de enviar.
    final bannerTop = tester.getTopLeft(
      find.text('Algo salió mal. Intenta de nuevo.'),
    );
    final buttonTop = tester.getTopLeft(submitButton);
    expect(bannerTop.dy, lessThan(buttonTop.dy));
  });

  testWidgets('el error de un campo se borra apenas se vuelve a escribir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));

    await tester.enterText(emailField, 'rosa@correo.cl');
    await tester.enterText(passwordField, validPassword);
    await tester.pump();
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('Cuéntanos cómo te llamamos'), findsOneWidget);

    await tester.enterText(nameField, 'R');
    await tester.pump();

    expect(find.text('Cuéntanos cómo te llamamos'), findsNothing);
  });

  testWidgets(
    'RegisterScreen ejecuta onRegisterSuccess cuando el formulario es válido',
    (WidgetTester tester) async {
      String? registeredUserName;

      await tester.pumpWidget(
        _wrap(
          RegisterScreen(
            onRegisterSuccess: (userName) => registeredUserName = userName,
          ),
          authRepository: _FakeAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await fillValidForm(tester);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(registeredUserName, 'Rosa');
    },
  );
}
