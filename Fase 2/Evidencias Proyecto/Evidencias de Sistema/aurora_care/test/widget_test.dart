import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/main.dart';
import 'package:aurora_care/presentation/onboarding/auth_gate.dart';

void main() {
  testWidgets(
    'AuroraCareApp smoke test: sin sesión guardada arranca en la bienvenida',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // Sin sesión guardada: evita tocar Firebase y el splash de 800 ms.
            startupSessionProvider.overrideWith((ref) async => null),
          ],
          child: const AuroraCareApp(),
        ),
      );

      // 1er frame: splash (el FutureProvider aún está cargando).
      // 2do frame: ya resolvió la sesión y muestra la bienvenida.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Comenzar'), findsOneWidget);
    },
  );
}
