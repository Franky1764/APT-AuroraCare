import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/constants/app_palettes.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/presentation/profile/theme_selection_screen.dart';

Future<ProviderContainer> _buildContainer({
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ThemeSelectionScreen()),
  );
}

void main() {
  testWidgets('muestra todos los temas y marca el actual como seleccionado', (
    WidgetTester tester,
  ) async {
    final container = await _buildContainer(
      initialPrefs: {'pref_theme_id': AppPalettes.bosque.id},
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    for (final opcion in AppPalettes.todas) {
      expect(find.text(opcion.nombre), findsOneWidget);
      expect(find.text(opcion.descripcion), findsOneWidget);
    }
    // Solo Bosque está marcado.
    expect(find.text('Seleccionado'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(AppPalettes.bosque.nombre),
          matching: find.byType(Card),
        ),
        matching: find.text('Seleccionado'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tocar un tema lo aplica, lo persiste y la pantalla sigue abierta',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).id, AppPalettes.aurora.id);

      final oceano = find.text(AppPalettes.oceano.nombre);
      await tester.ensureVisible(oceano);
      await tester.tap(oceano);
      await tester.pump();

      expect(container.read(themeProvider).id, AppPalettes.oceano.id);
      // Persistido de inmediato, no solo en memoria.
      expect(
        container.read(preferencesLocalSourceProvider).getThemeId(),
        AppPalettes.oceano.id,
      );
      // La pantalla no se cerró: sigue siendo ThemeSelectionScreen.
      expect(find.byType(ThemeSelectionScreen), findsOneWidget);
      // Solo un tema queda marcado (se movió, no se duplicó).
      expect(find.text('Seleccionado'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(AppPalettes.oceano.nombre),
            matching: find.byType(Card),
          ),
          matching: find.text('Seleccionado'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un id de tema inválido guardado cae a Aurora al construir',
    (WidgetTester tester) async {
      final container = await _buildContainer(
        initialPrefs: {'pref_theme_id': 'no_existe'},
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(container.read(themeProvider).id, AppPalettes.aurora.id);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(AppPalettes.aurora.nombre),
            matching: find.byType(Card),
          ),
          matching: find.text('Seleccionado'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'las frases descriptivas no quedan recortadas con textScale 1,3',
    (WidgetTester tester) async {
      final container = await _buildContainer();
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(home: ThemeSelectionScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final opcion in AppPalettes.todas) {
        final descripcionFinder = find.text(opcion.descripcion);
        await tester.ensureVisible(descripcionFinder);
        await tester.pumpAndSettle();
        final parrafo = tester.renderObject<RenderParagraph>(
          descripcionFinder,
        );
        expect(
          parrafo.didExceedMaxLines,
          isFalse,
          reason:
              'La descripción de "${opcion.nombre}" quedó recortada con '
              'textScale 1,3.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
