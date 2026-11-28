import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/domain/entities/memory_category.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_demo.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_controller.dart';
import 'package:aurora_care/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_screen.dart';
import 'package:aurora_care/presentation/games/shared/status_banner.dart';

const _familia = MemoryCategory(
  id: 'familia',
  name: 'Familia y amistades',
  isPredefined: true,
  iconKey: 'familia',
);

/// 5 respuestas distintas: ya jugable (>=5 respondidas, >=4 distintas).
const _datosJugables = {
  'mis_recuerdos_v1_uid1':
      '{"version": 1, "avisoPrivacidadVisto": true, '
      '"respuestasSugeridas": {'
      '"familia_padre": {"answer": "Juan", "status": "respondida"}, '
      '"familia_madre": {"answer": "Rosa", "status": "respondida"}, '
      '"familia_pareja": {"answer": "Ana", "status": "respondida"}, '
      '"familia_hijo_mayor": {"answer": "Pedro", "status": "respondida"}, '
      '"familia_hermano": {"answer": "Luis", "status": "respondida"}'
      '}, "preguntasPropias": []}',
};

Future<SharedPreferences> _mockPrefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs,
  Size tamanio,
) async {
  tester.view.physicalSize = tamanio;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          body: const MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1'),
        ),
      ),
    ),
  );
}

void main() {
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    testWidgets(
      'en ${tamanio.width.toInt()}x${tamanio.height.toInt()}: se '
      'construye sin overflow',
      (tester) async {
        final prefs = await _mockPrefs(_datosJugables);
        await _pump(tester, prefs, tamanio);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('con textScale 1.3 no hay overflow', (tester) async {
    final prefs = await _mockPrefs(_datosJugables);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: Scaffold(
              body: MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'muestra 4 opciones, marca correcta/incorrecta al responder y avanza '
    'con Siguiente',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 800));
      await tester.pump();

      expect(find.text('Pregunta 1 de 5'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(4));

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();

      expect(find.text('Pregunta 2 de 5'), findsOneWidget);
    },
  );

  testWidgets(
    'al responder las 5 preguntas muestra el resultado final sin puntaje '
    'numérico, con "Jugar otra vez" y "Volver"',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 800));
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(OutlinedButton).first);
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
        await tester.pump();
      }

      expect(find.widgetWithText(ElevatedButton, 'Jugar otra vez'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Volver'), findsOneWidget);
      // Sin ningún dígito visible de puntaje (ej. "3 de 5" o similar).
      expect(find.textContaining(RegExp(r'\d de \d')), findsNothing);
    },
  );

  testWidgets(
    'antes de responder no aparece ningún ícono de acierto ni de error',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 800));
      await tester.pump();

      expect(find.byType(StatusBanner), findsNothing);
    },
  );

  testWidgets(
    'al elegir la respuesta correcta, el banner muestra el check verde '
    'con el mensaje de acierto',
    (tester) async {
      final handle = tester.ensureSemantics();
      final prefs = await _mockPrefs(_datosJugables);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1'),
            ),
          ),
        ),
      );
      await tester.pump();

      final indiceCorrecto = container.read(provider).value!.actual.indiceCorrecto;
      await tester.tap(find.byType(OutlinedButton).at(indiceCorrecto));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(StatusBanner),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.check_circle_outline_rounded);
      expect(icon.color, AppColors.success);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        '¡Muy bien! Esa es la respuesta correcta.',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'al elegir una respuesta incorrecta, el banner muestra la equis '
    'roja con el mensaje completo (la respuesta correcta incluida)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final prefs = await _mockPrefs(_datosJugables);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1'),
            ),
          ),
        ),
      );
      await tester.pump();

      final actual = container.read(provider).value!.actual;
      final indiceIncorrecto = (actual.indiceCorrecto + 1) % 4;
      await tester.tap(find.byType(OutlinedButton).at(indiceIncorrecto));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(StatusBanner),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.cancel_outlined);
      expect(icon.color, AppColors.error);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'No es esa. La respuesta correcta es '
        '"${actual.pregunta.answer}".',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'elegir cualquier opción no corre las opciones de lugar (quedan en '
    'el mismo orden, el banner y "Siguiente" aparecen debajo)',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 640));
      await tester.pump();

      final cantidadAntes = find.byType(OutlinedButton).evaluate().length;
      final posicionAntes = tester.getTopLeft(
        find.byType(OutlinedButton).first,
      );

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      final posicionDespues = tester.getTopLeft(
        find.byType(OutlinedButton).first,
      );
      expect(
        posicionDespues,
        posicionAntes,
        reason: 'la primera opción cambió de posición al responder',
      );
      expect(cantidadAntes, 4);
    },
  );

  testWidgets(
    'la pantalla funciona sin ningún provider de Firebase/Firestore '
    'sobrescrito: solo depende de SharedPreferences (almacenamiento '
    'local), nunca de data/ remoto',
    (tester) async {
      // _pump() solo sobrescribe sharedPreferencesProvider. Si esta
      // pantalla alguna vez llegara a necesitar Firestore, este test
      // fallaría aquí (no hay Firebase inicializado en el entorno de
      // prueba) en vez de descubrirse recién en producción.
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 800));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Pregunta 1 de 5'), findsOneWidget);
    },
  );

  testWidgets(
    '"Ver cómo se juega" se muestra solo en la pregunta 1 sin '
    'responder, abre el diálogo con la demo, y "Volver al juego" lo '
    'cierra sin cambiar aciertos ni la pregunta actual',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final provider = misRecuerdosQuizControllerProvider(('uid1', 'familia'));
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MisRecuerdosQuizScreen(categoria: _familia, uid: 'uid1'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ver cómo se juega'), findsOneWidget);
      final estadoAntes = container.read(provider).value!;

      // No se usa pumpAndSettle: la demo dentro del diálogo anima en
      // bucle.
      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.byType(MisRecuerdosDemo), findsOneWidget);
      expect(find.text('Lea la pregunta y las 4 opciones.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al juego'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsNothing);
      final estadoDespues = container.read(provider).value!;
      // Este juego no mide tiempo (sin clockProvider ni metrics con
      // tiempoSegundos): lo que importa es que aciertos e indiceActual
      // no cambiaron, algo que solo ocurre con un toque real en una
      // opción (elegirOpcion), imposible mientras el diálogo modal
      // está abierto.
      expect(estadoDespues.indiceActual, estadoAntes.indiceActual);
      expect(estadoDespues.aciertos, estadoAntes.aciertos);
      expect(estadoDespues.opcionElegida, isNull);
      expect(find.text('Ver cómo se juega'), findsOneWidget);
    },
  );

  testWidgets(
    '"Ver cómo se juega" desaparece al responder la pregunta 1 y no '
    'vuelve a aparecer en preguntas posteriores',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 800));
      await tester.pump();

      expect(find.text('Ver cómo se juega'), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      expect(find.text('Ver cómo se juega'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pump();
      expect(find.text('Pregunta 2 de 5'), findsOneWidget);
      expect(find.text('Ver cómo se juega'), findsNothing);
    },
  );

  testWidgets(
    'la posición de las opciones es la misma antes y después de que '
    '"Ver cómo se juega" desaparece al responder',
    (tester) async {
      final prefs = await _mockPrefs(_datosJugables);
      await _pump(tester, prefs, const Size(360, 640));
      await tester.pump();

      final posicionAntes = tester.getTopLeft(
        find.byType(OutlinedButton).first,
      );

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();

      final posicionDespues = tester.getTopLeft(
        find.byType(OutlinedButton).first,
      );
      expect(
        posicionDespues,
        posicionAntes,
        reason:
            'la primera opción cambió de posición cuando "Ver cómo se '
            'juega" desapareció',
      );
    },
  );

  // Auditoría: el StatusBanner acá vive directo en la Column (sin
  // altura fija) dentro de un SingleChildScrollView, así que no debería
  // poder recortarse ni solaparse con "Siguiente". Se confirma con
  // Rects, en los 2 anchos y las 2 escalas de texto, con el mensaje de
  // error (incluye el texto libre de la respuesta correcta).
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'auditoría en ${tamanio.width.toInt()}x${tamanio.height.toInt()} '
        'con textScale $textScale: el banner de error no se solapa '
        'con "Siguiente"',
        (tester) async {
          final prefs = await _mockPrefs(_datosJugables);
          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: ProviderScope(
                overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
                child: MaterialApp(
                  home: Scaffold(
                    body: MisRecuerdosQuizScreen(
                      categoria: _familia,
                      uid: 'uid1',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.byType(OutlinedButton).last);
          await tester.pump();

          expect(tester.takeException(), isNull);
          final bannerRect = tester.getRect(find.byType(StatusBanner));
          final siguienteRect = tester.getRect(
            find.widgetWithText(ElevatedButton, 'Siguiente'),
          );
          expect(
            bannerRect.bottom,
            lessThanOrEqualTo(siguienteRect.top),
            reason:
                'el banner de error se solapa con "Siguiente" en '
                '${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
                'textScale $textScale',
          );
        },
      );
    }
  }
}
