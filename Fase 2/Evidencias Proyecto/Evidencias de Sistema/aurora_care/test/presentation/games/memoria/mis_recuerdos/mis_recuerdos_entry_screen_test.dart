import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/data/repositories/memories_repository_impl.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_entry_screen.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_fill_screen.dart';

Future<SharedPreferences> _mockPrefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

/// Blob de "uid1" con el aviso de privacidad ya visto (para no estorbar
/// en los tests de categorías) y, opcionalmente, categorías y preguntas
/// propias ya guardadas.
String _blob({
  List<Map<String, Object?>> categoriasPropias = const [],
  List<Map<String, Object?>> preguntasPropias = const [],
}) {
  return jsonEncode({
    'version': 1,
    'avisoPrivacidadVisto': true,
    'respuestasSugeridas': <String, Object?>{},
    'preguntasPropias': preguntasPropias,
    'categoriasPropias': categoriasPropias,
  });
}

Widget _app(SharedPreferences prefs, {String? uid = 'uid1'}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: MisRecuerdosEntryScreen(uid: uid)),
  );
}

void main() {
  testWidgets('sin sesión iniciada, no muestra la función', (tester) async {
    final prefs = await _mockPrefs();
    await tester.pumpWidget(_app(prefs, uid: null));
    await tester.pump();

    expect(find.text('Inicie sesión para usar esta función.'), findsOneWidget);
    expect(find.text('Familia y amistades'), findsNothing);
  });

  testWidgets(
    'la primera vez muestra el aviso de privacidad; luego de aceptarlo, '
    'no vuelve a aparecer',
    (tester) async {
      final prefs = await _mockPrefs();
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lo que escriba se guarda solo en este teléfono'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('privacidad_entendido')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Lo que escriba se guarda solo en este teléfono'),
        findsNothing,
      );

      // Si se reconstruye la pantalla (ej. se vuelve a entrar), el aviso
      // ya no aparece de nuevo.
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Lo que escriba se guarda solo en este teléfono'),
        findsNothing,
      );
    },
  );

  testWidgets('muestra las 3 categorías predeterminadas', (tester) async {
    final prefs = await _mockPrefs({'mis_recuerdos_v1_uid1': '{"version": 1, "avisoPrivacidadVisto": true, "respuestasSugeridas": {}, "preguntasPropias": []}'});
    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Familia y amistades'), findsOneWidget);
    expect(find.text('Música'), findsOneWidget);
    expect(find.text('Fechas importantes'), findsOneWidget);
    expect(find.textContaining('Faltan 5 respuestas para jugar'), findsNWidgets(3));
  });

  testWidgets(
    'los botones "Jugar" y "Completar mis recuerdos" no desbordan con '
    'textScale 1,3 en 360x640',
    (tester) async {
      final prefs = await _mockPrefs({
        'mis_recuerdos_v1_uid1':
            '{"version": 1, "avisoPrivacidadVisto": true, '
            '"respuestasSugeridas": {}, "preguntasPropias": []}',
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const MaterialApp(home: MisRecuerdosEntryScreen(uid: 'uid1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(ElevatedButton, 'Jugar'), findsWidgets);
      expect(
        find.widgetWithText(OutlinedButton, 'Completar mis recuerdos'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    '"Crear mi propia categoría" y el aviso de límite no desbordan con '
    'textScale 1,3 en 360x640, aunque haya 10 categorías propias',
    (tester) async {
      final diez = List.generate(
        10,
        (i) => {'id': 'custom_cat_$i', 'name': 'Categoría $i'},
      );
      final prefs = await _mockPrefs({
        'mis_recuerdos_v1_uid1': _blob(categoriasPropias: diez),
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _app(prefs),
        ),
      );
      await tester.pumpAndSettle();

      final botonFinder = find.widgetWithText(
        OutlinedButton,
        'Crear mi propia categoría',
      );
      await tester.scrollUntilVisible(
        botonFinder,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);

      final mensajeFinder = find.textContaining('Llegó al máximo de 10');
      await tester.scrollUntilVisible(
        mensajeFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(mensajeFinder, findsOneWidget);
    },
  );

  testWidgets(
    'tras completar las respuestas de una categoría y volver, "Jugar" se '
    'habilita de inmediato, sin salir de Mis recuerdos',
    (tester) async {
      final prefs = await _mockPrefs({
        'mis_recuerdos_v1_uid1':
            '{"version": 1, "avisoPrivacidadVisto": true, '
            '"respuestasSugeridas": {}, "preguntasPropias": []}',
      });
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      // Antes de completar: "Jugar" está deshabilitado para "Familia y
      // amistades" (la primera tarjeta).
      final tarjetaFamilia = find.ancestor(
        of: find.text('Familia y amistades'),
        matching: find.byType(Card),
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: tarjetaFamilia,
                matching: find.widgetWithText(ElevatedButton, 'Jugar'),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.descendant(
          of: tarjetaFamilia,
          matching: find.widgetWithText(OutlinedButton, 'Completar mis recuerdos'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MisRecuerdosFillScreen), findsOneWidget);

      // 5 respuestas distintas: alcanza el mínimo (5 respondidas, 4
      // distintas) para que la categoría quede jugable.
      const respuestas = {
        'Nombre de su padre': 'Juan',
        'Nombre de su madre': 'Rosa',
        'Nombre de su pareja': 'Carlos',
        'Nombre de su hijo o hija mayor': 'Ana',
        'Nombre de su hermano o hermana': 'Pedro',
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

      // Vuelve a la lista (pop), sin reconstruir MisRecuerdosEntryScreen.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MisRecuerdosFillScreen), findsNothing);
      expect(find.byType(MisRecuerdosEntryScreen), findsOneWidget);

      expect(
        find.descendant(
          of: tarjetaFamilia,
          matching: find.text('Listo para jugar'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: tarjetaFamilia,
                matching: find.widgetWithText(ElevatedButton, 'Jugar'),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  group('Crear mi propia categoría', () {
    testWidgets(
      'el botón está al final de la lista; rechaza nombre vacío y '
      'nombre repetido antes de aceptar uno válido, y lleva directo a '
      'llenar sus preguntas',
      (tester) async {
        final prefs = await _mockPrefs({'mis_recuerdos_v1_uid1': _blob()});
        await tester.pumpWidget(_app(prefs));
        await tester.pumpAndSettle();

        final botonCrear = find.widgetWithText(
          OutlinedButton,
          'Crear mi propia categoría',
        );
        await tester.scrollUntilVisible(
          botonCrear,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(botonCrear);
        await tester.pumpAndSettle();

        // Nombre vacío: no se cierra el diálogo, muestra el error.
        await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
        await tester.pump();
        expect(
          find.text('Escriba un nombre para la categoría.'),
          findsOneWidget,
        );

        // Nombre repetido con una predeterminada (sin distinguir
        // mayúsculas): tampoco se acepta.
        await tester.enterText(find.byType(TextField), 'música');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
        await tester.pump();
        expect(
          find.text('Ya tiene una categoría con ese nombre.'),
          findsOneWidget,
        );

        // Nombre válido: crea la categoría y abre su llenado de inmediato.
        await tester.enterText(find.byType(TextField), 'Arte');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
        await tester.pumpAndSettle();

        expect(find.byType(MisRecuerdosFillScreen), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Arte'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Arte'), findsOneWidget);
        expect(find.textContaining('Faltan 5 respuestas para jugar'), findsWidgets);
      },
    );

    testWidgets(
      'al llegar a 10 categorías propias, el botón se deshabilita y '
      'explica el motivo (sin depender solo del color)',
      (tester) async {
        final diez = List.generate(
          10,
          (i) => {'id': 'custom_cat_$i', 'name': 'Categoría $i'},
        );
        final prefs = await _mockPrefs({
          'mis_recuerdos_v1_uid1': _blob(categoriasPropias: diez),
        });
        await tester.pumpWidget(_app(prefs));
        await tester.pumpAndSettle();

        final botonFinder = find.widgetWithText(
          OutlinedButton,
          'Crear mi propia categoría',
        );
        await tester.scrollUntilVisible(
          botonFinder,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        final boton = tester.widget<OutlinedButton>(botonFinder);
        expect(boton.onPressed, isNull);
        expect(
          find.textContaining('Llegó al máximo de 10 categorías propias'),
          findsOneWidget,
        );
      },
    );
  });

  group('Renombrar y borrar una categoría propia', () {
    testWidgets('Renombrar cambia el nombre en la lista', (tester) async {
      final prefs = await _mockPrefs({
        'mis_recuerdos_v1_uid1': _blob(
          categoriasPropias: [
            {'id': 'custom_cat_1', 'name': 'Arte'},
          ],
        ),
      });
      await tester.pumpWidget(_app(prefs));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Arte'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Arte'),
            matching: find.byType(Card),
          ),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Nombre de la categoría'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Pintura');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Pintura'), findsOneWidget);
      expect(find.text('Arte'), findsNothing);
    });

    testWidgets(
      'predeterminadas no tienen menú de opciones (no se pueden borrar '
      'ni renombrar)',
      (tester) async {
        final prefs = await _mockPrefs({'mis_recuerdos_v1_uid1': _blob()});
        await tester.pumpWidget(_app(prefs));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Familia y amistades'),
              matching: find.byType(Card),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Borrar categoría pide confirmación y, al confirmar, la quita de '
      'la lista sin dejar sus preguntas propias huérfanas',
      (tester) async {
        final prefs = await _mockPrefs({
          'mis_recuerdos_v1_uid1': _blob(
            categoriasPropias: [
              {'id': 'custom_cat_1', 'name': 'Arte'},
            ],
            preguntasPropias: [
              {
                'id': 'custom_q1',
                'categoryId': 'custom_cat_1',
                'quizPrompt': '¿Mi pintor favorito?',
                'answer': 'Matisse',
                'status': 'respondida',
              },
            ],
          ),
        });
        await tester.pumpWidget(_app(prefs));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Arte'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Arte'),
              matching: find.byType(Card),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Borrar categoría'));
        await tester.pumpAndSettle();

        // Cancelar: no borra nada.
        await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('Arte'), findsOneWidget);

        // Confirmar: sí borra.
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Arte'),
              matching: find.byType(Card),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Borrar categoría'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
        await tester.pumpAndSettle();

        expect(find.text('Arte'), findsNothing);

        final repo = MemoriesRepositoryImpl(prefs);
        final preguntas = await repo.loadQuestions(
          uid: 'uid1',
          categoryId: 'custom_cat_1',
        );
        expect(preguntas, isEmpty); // Sin preguntas huérfanas.
      },
    );
  });
}
