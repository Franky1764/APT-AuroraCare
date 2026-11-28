import 'dart:async';

import 'package:aurora_care/data/repositories/auth_repository_impl.provider.dart';
import 'package:aurora_care/domain/exceptions/auth_exception.dart';
import 'package:aurora_care/presentation/auth/elder/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';

/// Repositorio que registra los envíos y permite simular errores o una
/// respuesta lenta.
class _ResetRepository extends FakeAuthRepository {
  final List<String> sent = [];
  AuthErrorType? failWith;
  Completer<void>? gate;

  @override
  Future<void> sendPasswordReset({required String email}) async {
    sent.add(email);
    if (gate != null) await gate!.future;
    if (failWith != null) throw AuthException(failWith!);
  }
}

Widget _wrap(_ResetRepository repo) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: ForgotPasswordScreen()),
);

final _emailField = find.widgetWithText(TextFormField, 'rosa@correo.cl');
final _sendButton = find.widgetWithText(ElevatedButton, 'Enviar instrucciones');

Future<void> _submit(WidgetTester tester, String email) async {
  await tester.enterText(_emailField.first, email);
  await tester.tap(_sendButton);
}

void main() {
  testWidgets('renderiza el formulario inicial', (tester) async {
    await tester.pumpWidget(_wrap(_ResetRepository()));

    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(_sendButton, findsOneWidget);
  });

  testWidgets('con correo inválido muestra error y no envía nada', (
    tester,
  ) async {
    final repo = _ResetRepository();
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'correo-invalido');
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
    expect(repo.sent, isEmpty);
  });

  testWidgets('con correo válido envía el correo y muestra la confirmación', (
    tester,
  ) async {
    final repo = _ResetRepository();
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, '  rosa@correo.cl ');
    await tester.pumpAndSettle();

    expect(repo.sent, ['rosa@correo.cl']);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('rosa@correo.cl'), findsOneWidget);
    expect(find.textContaining('spam'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Volver a iniciar sesión'),
      findsOneWidget,
    );
  });

  testWidgets('si la cuenta no existe, la confirmación es la misma', (
    tester,
  ) async {
    final repo = _ResetRepository()..failWith = AuthErrorType.userNotFound;
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'nadie@correo.cl');
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu correo'), findsOneWidget);
  });

  testWidgets('sin conexión muestra el error y deja reintentar', (
    tester,
  ) async {
    final repo = _ResetRepository()..failWith = AuthErrorType.networkError;
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'rosa@correo.cl');
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay conexión a internet'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);

    repo.failWith = null;
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(repo.sent, hasLength(2));
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });

  testWidgets('demasiados intentos y errores desconocidos tienen mensaje', (
    tester,
  ) async {
    final repo = _ResetRepository()..failWith = AuthErrorType.tooManyRequests;
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'rosa@correo.cl');
    await tester.pumpAndSettle();
    expect(find.textContaining('Demasiados intentos'), findsOneWidget);

    repo.failWith = AuthErrorType.unknown;
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos enviar el correo'), findsOneWidget);
    expect(find.textContaining('Demasiados intentos'), findsNothing);
  });

  testWidgets('correo rechazado por el servidor marca el campo', (
    tester,
  ) async {
    final repo = _ResetRepository()..failWith = AuthErrorType.invalidEmail;
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'rosa@correo.cl');
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('mientras envía, el botón se desactiva y no duplica el envío', (
    tester,
  ) async {
    final repo = _ResetRepository()..gate = Completer<void>();
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'rosa@correo.cl');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_sendButton, findsNothing);
    expect(repo.sent, hasLength(1));

    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(repo.sent, hasLength(1));
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });

  testWidgets('el reenvío se habilita tras la espera y envía de nuevo', (
    tester,
  ) async {
    final repo = _ResetRepository();
    await tester.pumpWidget(_wrap(repo));

    await _submit(tester, 'rosa@correo.cl');
    await tester.pumpAndSettle();

    final waiting = find.widgetWithText(
      OutlinedButton,
      'Podrás reenviar el correo en un minuto',
    );
    expect(waiting, findsOneWidget);
    expect(tester.widget<OutlinedButton>(waiting).onPressed, isNull);

    await tester.pump(forgotPasswordResendDelay);
    final resend = find.widgetWithText(OutlinedButton, 'Reenviar correo');
    expect(resend, findsOneWidget);

    await tester.tap(resend);
    await tester.pumpAndSettle();

    expect(repo.sent, ['rosa@correo.cl', 'rosa@correo.cl']);
    expect(find.text('Enviamos el correo de nuevo.'), findsOneWidget);
    expect(waiting, findsOneWidget);
    expect(tester.widget<OutlinedButton>(waiting).onPressed, isNull);
  });
}
