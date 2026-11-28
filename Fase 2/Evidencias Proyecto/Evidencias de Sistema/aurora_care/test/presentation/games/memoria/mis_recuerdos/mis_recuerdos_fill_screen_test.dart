import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/domain/entities/memory_category.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_fill_screen.dart';

const _familia = MemoryCategory(
  id: 'familia',
  name: 'Familia y amistades',
  isPredefined: true,
  iconKey: 'familia',
);

Future<SharedPreferences> _mockPrefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(
      home: MisRecuerdosFillScreen(categoria: _familia, uid: 'uid1'),
    ),
  );
}

void main() {
  testWidgets('muestra las 8 preguntas sugeridas de la categoría', (
    tester,
  ) async {
    final prefs = await _mockPrefs();
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Nombre de su padre'), findsOneWidget);
    expect(find.text('Respondidas: 0 (se necesitan 5 para jugar)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nombre de su nieto o nieta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nombre de su nieto o nieta'), findsOneWidget);
  });

  testWidgets(
    'escribir una respuesta y guardar actualiza el avance de respondidas',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      final campoPadre = find.descendant(
        of: find.ancestor(
          of: find.text('Nombre de su padre'),
          matching: find.byType(Card),
        ),
        matching: find.byType(TextField),
      );
      await tester.enterText(campoPadre, 'Juan');
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Guardar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Sus respuestas se guardaron.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Respondidas: 1 (se necesitan 5 para jugar)'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Respondidas: 1 (se necesitan 5 para jugar)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'escribir en 5 campos y tocar Guardar una sola vez persiste las 5',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      const respuestas = {
        'Nombre de su padre': 'Juan',
        'Nombre de su madre': 'Rosa',
        'Nombre de su pareja': 'Ana',
        'Nombre de su hijo o hija mayor': 'Pedro',
        'Nombre de su hermano o hermana': 'Luis',
      };

      for (final entry in respuestas.entries) {
        final campo = find.descendant(
          of: find.ancestor(
            of: find.text(entry.key),
            matching: find.byType(Card),
          ),
          matching: find.byType(TextField),
        );
        await tester.scrollUntilVisible(
          campo,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(campo, entry.value);
      }

      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Guardar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Sus respuestas se guardaron.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Respondidas: 5 (se necesitan 5 para jugar)'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Respondidas: 5 (se necesitan 5 para jugar)'),
        findsOneWidget,
      );

      // Vuelve a abrir la pantalla (nueva instancia, mismo repositorio) y
      // confirma que las 5 respuestas siguen ahí.
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();
      for (final entry in respuestas.entries) {
        final campo = find.descendant(
          of: find.ancestor(
            of: find.text(entry.key),
            matching: find.byType(Card),
          ),
          matching: find.byType(TextField),
        );
        await tester.scrollUntilVisible(
          campo,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        final widget = tester.widget<TextField>(campo);
        expect(widget.controller!.text, entry.value, reason: entry.key);
      }
    },
  );

  testWidgets(
    'escribir en un campo y luego omitir OTRA pregunta NO borra lo ya '
    'escrito (regresión: _cargar() pisaba texto sin guardar)',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      final campoPadre = find.descendant(
        of: find.ancestor(
          of: find.text('Nombre de su padre'),
          matching: find.byType(Card),
        ),
        matching: find.byType(TextField),
      );
      await tester.enterText(campoPadre, 'Juan');

      // Acción no relacionada contra OTRA pregunta: dispara _cargar().
      final omitirMadre = find.descendant(
        of: find.ancestor(
          of: find.text('Nombre de su madre'),
          matching: find.byType(Card),
        ),
        matching: find.widgetWithText(TextButton, 'Prefiero no responder'),
      );
      await tester.scrollUntilVisible(
        omitirMadre,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(omitirMadre);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        campoPadre,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      final widget = tester.widget<TextField>(campoPadre);
      expect(widget.controller!.text, 'Juan');
    },
  );

  testWidgets(
    '"Prefiero no responder" omite la pregunta y "Deshacer" la revierte',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Prefiero no responder').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Prefiere no responder esta pregunta.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Deshacer'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Deshacer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Prefiere no responder esta pregunta.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'agregar una pregunta propia la muestra en "Mis propias preguntas"',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Agregar mi propia pregunta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Agregar mi propia pregunta'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Pregunta'),
        '¿Mi comida favorita?',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Respuesta'),
        'Cazuela',
      );
      // Acotado al diálogo: el botón "Guardar" de la pantalla también
      // está presente (debajo), con el mismo texto.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Guardar'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('¿Mi comida favorita?'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('¿Mi comida favorita?'), findsOneWidget);
      expect(find.text('Cazuela'), findsOneWidget);
    },
  );
}
