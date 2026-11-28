import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/auth/caregiver/caregiver_register_screen.dart';

Widget _wrap() {
  return const ProviderScope(
    child: MaterialApp(home: CaregiverRegisterScreen()),
  );
}

Finder get _passwordField => find.byType(TextFormField).at(2);
Finder get _submitButton =>
    find.widgetWithText(ElevatedButton, 'Crear cuenta');

Future<void> _enterPassword(WidgetTester tester, String password) async {
  await tester.enterText(_passwordField, password);
  await tester.pump();
}

bool _buttonEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_submitButton).onPressed != null;

void main() {
  testWidgets(
    'contraseña corta: el botón queda deshabilitado y muestra cuántos '
    'caracteres faltan',
    (tester) async {
      await tester.pumpWidget(_wrap());

      await _enterPassword(tester, 'Abc123');

      expect(_buttonEnabled(tester), isFalse);
      expect(find.text('Te faltan 6 caracteres (mínimo 12).'), findsOneWidget);
    },
  );

  testWidgets(
    'sin mayúscula: el botón queda deshabilitado y muestra el mensaje '
    'correspondiente',
    (tester) async {
      await tester.pumpWidget(_wrap());

      await _enterPassword(tester, 'cuidadora1234');

      expect(_buttonEnabled(tester), isFalse);
      expect(
        find.text('Falta al menos una letra mayúscula.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('contraseña válida: el botón queda habilitado', (tester) async {
    await tester.pumpWidget(_wrap());

    // 16 caracteres (9 letras + 7 números): cumple los 4 obligatorios y
    // llega a "Muy fuerte" por longitud, sin necesitar un carácter
    // especial.
    await _enterPassword(tester, 'Cuidadora1234567');

    expect(_buttonEnabled(tester), isTrue);
    expect(find.text('Seguridad: Muy fuerte'), findsOneWidget);
  });

  testWidgets(
    'más de 20 caracteres: el botón queda bloqueado y muestra cuántos '
    'caracteres sobran',
    (tester) async {
      await tester.pumpWidget(_wrap());

      // 'Cuidadora' (9) + 14 dígitos = 23 caracteres: 3 de sobra sobre
      // el máximo de 20.
      await _enterPassword(tester, 'Cuidadora${'1' * 14}');

      expect(_buttonEnabled(tester), isFalse);
      expect(find.text('Te sobran 3 caracteres (máximo 20).'), findsOneWidget);
    },
  );
}
