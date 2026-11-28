import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/breathing/breathing_complete_screen.dart';

void main() {
  testWidgets('muestra el texto de cierre y el botón "Volver al inicio"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BreathingCompleteScreen(userName: 'Rosa')),
    );

    expect(find.text('¡Muy bien, Rosa!'), findsOneWidget);
    expect(find.text('Terminó su momento de calma.'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Volver al inicio'),
      findsOneWidget,
    );
  });

  testWidgets('"Volver al inicio" hace pop hacia la pantalla anterior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const BreathingCompleteScreen(userName: 'Rosa'),
                  ),
                ),
                child: const Text('Abrir cierre'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir cierre'));
    await tester.pumpAndSettle();
    expect(find.byType(BreathingCompleteScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(BreathingCompleteScreen), findsNothing);
    expect(find.text('Abrir cierre'), findsOneWidget);
  });

  testWidgets('el botón "Volver al inicio" tiene una etiqueta de semántica clara', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(home: BreathingCompleteScreen(userName: 'Rosa')),
    );

    expect(find.bySemanticsLabel('Volver al inicio'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('se construye sin overflow con textScaler 1.3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(
          home: BreathingCompleteScreen(userName: 'Rosa'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
