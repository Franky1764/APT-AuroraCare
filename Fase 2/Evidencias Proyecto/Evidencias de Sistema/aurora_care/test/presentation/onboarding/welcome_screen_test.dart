import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/onboarding/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen muestra el logo, el subtítulo y el botón Comenzar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.text('Ejercicios simples para mantener la mente activa.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Comenzar'), findsOneWidget);
  });

  testWidgets('WelcomeScreen ejecuta onContinue al tocar Comenzar',
      (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(onContinue: () => pressed = true),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Comenzar'));
    await tester.pump();

    expect(pressed, isTrue);
  });
}
