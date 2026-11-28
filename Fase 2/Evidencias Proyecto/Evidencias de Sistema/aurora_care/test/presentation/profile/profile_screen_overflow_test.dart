import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/constants/app_palettes.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/presentation/profile/profile_screen.dart';
import 'package:aurora_care/presentation/profile/theme_selection_screen.dart';

/// Confirma que la fila "Tema" del perfil, y la pantalla "Elegir tema" que
/// abre, no rompen el layout en los tamaños y escalas de texto que ya se
/// probaban antes. Ambas pantallas usan SingleChildScrollView, así que más
/// contenido puede significar más scroll — lo que no debe pasar nunca es
/// un RenderFlex/overflow.
Future<ProviderContainer> _buildContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'ProfileScreen en ${tamanio.width.toInt()}x${tamanio.height.toInt()} '
        'con textScale $textScale: sin overflow',
        (WidgetTester tester) async {
          final container = await _buildContainer();
          addTearDown(container.dispose);
          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: const MaterialApp(home: ProfileScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // La fila "Tema" muestra el tema actual (Aurora por defecto).
          expect(find.text('Tema'), findsOneWidget);
          expect(find.text(AppPalettes.aurora.nombre), findsOneWidget);
        },
      );

      testWidgets(
        'ThemeSelectionScreen en ${tamanio.width.toInt()}x'
        '${tamanio.height.toInt()} con textScale $textScale: sin overflow',
        (WidgetTester tester) async {
          final container = await _buildContainer();
          addTearDown(container.dispose);
          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: const MaterialApp(home: ThemeSelectionScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Todos los temas están presentes, con su nombre y descripción.
          for (final opcion in AppPalettes.todas) {
            final nombreFinder = find.text(opcion.nombre);
            await tester.ensureVisible(nombreFinder);
            expect(nombreFinder, findsOneWidget);
            expect(find.text(opcion.descripcion), findsOneWidget);
          }
        },
      );
    }
  }
}
