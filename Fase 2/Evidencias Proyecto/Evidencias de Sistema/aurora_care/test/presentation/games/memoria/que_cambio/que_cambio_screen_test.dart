import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_text_styles.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_cell.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_controller.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_screen.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_demo.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/shared/status_banner.dart';

/// soundsEnabledProvider es un NotifierProvider: no tiene overrideWithValue.
/// Sin esto, necesitaría sharedPreferencesProvider (que lanza si no se
/// sobreescribe) en cada test que toque una celda, aunque no le importe
/// el sonido — este fija el valor sin tocar prefs.
class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

GameRun _fakeRun(GameLevel nivel, {void Function(CognitiveMetrics)? onFinish}) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 240),
    elapsed: () => Duration.zero,
    finish: onFinish ?? (_) {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  GameLevel nivel, {
  ProviderContainer? container,
  Size tamanio = const Size(360, 640),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = tamanio;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final widget = MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          // AppBar vacío: simula el alto (56dp) del AppBar real de
          // GameShell, que en la app envuelve a esta pantalla.
          appBar: AppBar(),
          body: QueCambioScreen(run: _fakeRun(nivel)),
        ),
      ),
    ),
  );

  await tester.pumpWidget(
    container == null
        ? ProviderScope(
            overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
            child: widget,
          )
        : UncontrolledProviderScope(container: container, child: widget),
  );
}

void main() {
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final nivel in GameLevel.values) {
      testWidgets(
        'nivel ${nivel.label}: se construye sin overflow en '
        '${tamanio.width.toInt()}x${tamanio.height.toInt()}',
        (tester) async {
          await _pump(tester, nivel, tamanio: tamanio);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'con textScale 1,3 en 360x640 se construye sin overflow',
    (tester) async {
      await _pump(
        tester,
        GameLevel.facil,
        tamanio: const Size(360, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('muestra las dos grillas con la cantidad de celdas correcta', (
    tester,
  ) async {
    await _pump(tester, GameLevel.intermedio);
    // 4 columnas x 3 filas x 2 grillas = 24 celdas.
    expect(find.byType(QueCambioCell), findsNWidgets(24));
  });

  testWidgets(
    'tocar una diferencia la marca como encontrada en ambas grillas y '
    'avanza el indicador',
    (tester) async {
      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pump(tester, GameLevel.facil, container: container);

      final state0 = container.read(provider);
      final diferencia = state0.diferenciaIndices.first;
      final fila = diferencia ~/ state0.columnas + 1;
      final columna = diferencia % state0.columnas + 1;

      final target = find.byWidgetPredicate(
        (w) =>
            w is QueCambioCell &&
            w.esArriba &&
            w.fila == fila &&
            w.columna == columna,
      );
      await tester.tap(target);
      await tester.pump();

      expect(find.text('Diferencias encontradas: 1 de 3'), findsOneWidget);

      final updatedCells = tester.widgetList<QueCambioCell>(
        find.byType(QueCambioCell),
      );
      for (final cell in updatedCells) {
        if (cell.fila == fila && cell.columna == columna) {
          expect(cell.estado, QueCambioCellEstado.encontrada);
        }
      }
    },
  );

  testWidgets(
    'el banner de estado inicial muestra el ícono neutro y el mensaje '
    'de invitación',
    (tester) async {
      final handle = tester.ensureSemantics();

      await _pump(tester, GameLevel.facil);

      final icon = tester.widget<Icon>(find.descendant(of: find.byType(StatusBanner), matching: find.byType(Icon)));
      expect(icon.icon, Icons.touch_app_outlined);
      expect(icon.color, AppColors.primary);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'Toque la imagen donde note un cambio',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'tocar una diferencia muestra el banner de acierto (check verde)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pump(tester, GameLevel.facil, container: container);

      final state0 = container.read(provider);
      final diferencia = state0.diferenciaIndices.first;
      final fila = diferencia ~/ state0.columnas + 1;
      final columna = diferencia % state0.columnas + 1;

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is QueCambioCell &&
              w.esArriba &&
              w.fila == fila &&
              w.columna == columna,
        ),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.descendant(of: find.byType(StatusBanner), matching: find.byType(Icon)));
      expect(icon.icon, Icons.check_circle_outline_rounded);
      expect(icon.color, AppColors.success);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'Diferencia encontrada, 1 de 3',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'tocar una celda sin diferencia muestra el banner de error (equis '
    'roja)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pump(tester, GameLevel.facil, container: container);

      final state0 = container.read(provider);
      final totalCeldas = state0.columnas * 3;
      final indiceSinDiferencia = [
        for (var i = 0; i < totalCeldas; i++) i,
      ].firstWhere((i) => !state0.diferenciaIndices.contains(i));
      final fila = indiceSinDiferencia ~/ state0.columnas + 1;
      final columna = indiceSinDiferencia % state0.columnas + 1;

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is QueCambioCell &&
              w.esArriba &&
              w.fila == fila &&
              w.columna == columna,
        ),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.descendant(of: find.byType(StatusBanner), matching: find.byType(Icon)));
      expect(icon.icon, Icons.cancel_outlined);
      expect(icon.color, AppColors.error);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'No es una diferencia',
      );

      handle.dispose();
    },
  );

  testWidgets('el botón "Ya no encuentro más" termina la partida', (
    tester,
  ) async {
    var finished = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(),
            body: QueCambioScreen(
              run: _fakeRun(
                GameLevel.facil,
                onFinish: (_) => finished = true,
              ),
            ),
          ),
        ),
      ),
    );

    // "Ya no encuentro más" reemplaza a "Ver cómo se juega" recién
    // después del primer toque (intentos > 0).
    await tester.tap(find.byType(QueCambioCell).first);
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Ya no encuentro más'),
    );
    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets(
    '"Ver cómo se juega" abre el diálogo con la demo, y "Volver al '
    'juego" lo cierra sin cambiar el estado de la partida ni el reloj',
    (tester) async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          queCambioClockProvider.overrideWithValue(() => ahora),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: QueCambioScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      final estadoAntes = container.read(provider);
      expect(find.text('Ver cómo se juega'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Ya no encuentro más'), findsNothing);

      // No se usa pumpAndSettle: la demo dentro del diálogo anima en
      // bucle (AnimationController.repeat()) y nunca "se asienta".
      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.byType(QueCambioDemo), findsOneWidget);
      expect(
        find.text('Mire las dos imágenes con atención.'),
        findsOneWidget,
      );

      // Mientras el diálogo está abierto "pasan" 30 s de reloj: la
      // pantalla llama a pausar() al abrirlo y reanudar() al cerrarlo,
      // así que ese tiempo no debe contar en tiempoSegundos (se verifica
      // más abajo, terminando la partida).
      ahora = ahora.add(const Duration(seconds: 30));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al juego'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cómo jugar'), findsNothing);
      final estadoDespues = container.read(provider);
      expect(estadoDespues, same(estadoAntes));
      expect(find.text('Ver cómo se juega'), findsOneWidget);

      // Termina la partida jugando 10 s "reales": tiempoSegundos debe
      // reflejar solo esos 10 s, sin los 30 s pausados.
      final diferencias = container.read(provider).diferenciaIndices.toList();
      ahora = ahora.add(const Duration(seconds: 10));
      for (final i in diferencias) {
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is QueCambioCell &&
                w.esArriba &&
                w.fila == (i ~/ container.read(provider).columnas) + 1 &&
                w.columna == (i % container.read(provider).columnas) + 1,
          ),
        );
        await tester.pump();
      }
      expect(container.read(provider).metrics!.tiempoSegundos, 10);
    },
  );

  testWidgets(
    '"Ver cómo se juega" ya no aparece después del primer toque (no se '
    'puede reabrir a mitad de partida)',
    (tester) async {
      await _pump(tester, GameLevel.facil);
      expect(find.text('Ver cómo se juega'), findsOneWidget);

      await tester.tap(find.byType(QueCambioCell).first);
      await tester.pump();

      expect(find.text('Ver cómo se juega'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Ya no encuentro más'), findsOneWidget);
    },
  );

  testWidgets(
    'cerrar el diálogo con el botón atrás también reanuda (no queda '
    'pausado para siempre)',
    (tester) async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          queCambioClockProvider.overrideWithValue(() => ahora),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: QueCambioScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Cómo jugar'), findsOneWidget);

      ahora = ahora.add(const Duration(seconds: 30));

      // Botón atrás del sistema (equivalente a tocar fuera: ambos
      // completan el Future de showDialog, que es lo que dispara el
      // finally con reanudar()).
      await tester.binding.handlePopRoute();
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Cómo jugar'), findsNothing);

      final diferencias = container.read(provider).diferenciaIndices.toList();
      ahora = ahora.add(const Duration(seconds: 4));
      for (final i in diferencias) {
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is QueCambioCell &&
                w.esArriba &&
                w.fila == (i ~/ container.read(provider).columnas) + 1 &&
                w.columna == (i % container.read(provider).columnas) + 1,
          ),
        );
        await tester.pump();
      }
      expect(container.read(provider).metrics!.tiempoSegundos, 4);
    },
  );

  // Regresión: el banner inicial ("Toque la imagen donde note un
  // cambio") se cortaba porque su franja tenía 24dp fijos, buenos para
  // 1 línea pero no para las 2 que ese texto necesita. La franja ahora
  // se calcula con el alto real de 2 líneas (TextPainter), así que se
  // verifica que el banner, la etiqueta "Imagen original" y la primera
  // fila de la cuadrícula de arriba NUNCA se solapen — en vez de solo
  // comprobar que no hay una excepción de overflow, que no detectaría
  // este tipo de recorte (el Text no tiene maxLines: se "pinta" fuera
  // de su caja en vez de lanzar un error).
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      for (final nivel in GameLevel.values) {
        testWidgets(
          'nivel ${nivel.label} en ${tamanio.width.toInt()}x'
          '${tamanio.height.toInt()} con textScale $textScale: el '
          'banner, la etiqueta y la primera fila del tablero no se '
          'solapan',
          (tester) async {
            await _pump(tester, nivel, tamanio: tamanio, textScale: textScale);
            await tester.pump();
            expect(tester.takeException(), isNull);

            final bannerRect = tester.getRect(find.byType(StatusBanner));
            final etiquetaRect = tester.getRect(
              find.text('Imagen original'),
            );
            final primeraFilaRect = tester.getRect(
              find.byWidgetPredicate(
                (w) =>
                    w is QueCambioCell &&
                    w.esArriba &&
                    w.fila == 1 &&
                    w.columna == 1,
              ),
            );

            expect(
              bannerRect.bottom,
              lessThanOrEqualTo(etiquetaRect.top),
              reason:
                  'el banner se solapa con la etiqueta "Imagen original" '
                  'en ${tamanio.width.toInt()}x${tamanio.height.toInt()} '
                  'con textScale $textScale',
            );
            expect(
              etiquetaRect.bottom,
              lessThanOrEqualTo(primeraFilaRect.top),
              reason:
                  'la etiqueta "Imagen original" se solapa con la '
                  'primera fila del tablero en '
                  '${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
                  'textScale $textScale',
            );
          },
        );
      }
    }
  }

  testWidgets(
    'el banner de 2 líneas más largo ("¡Felicitaciones!...") no excede '
    'el alto reservado (no queda nada pintado fuera de su caja)',
    (tester) async {
      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pump(
        tester,
        GameLevel.facil,
        container: container,
        tamanio: const Size(360, 640),
        textScale: 1.3,
      );

      final diferencias = container.read(provider).diferenciaIndices.toList();
      for (final i in diferencias) {
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is QueCambioCell &&
                w.esArriba &&
                w.fila == (i ~/ container.read(provider).columnas) + 1 &&
                w.columna == (i % container.read(provider).columnas) + 1,
          ),
        );
        await tester.pump();
      }
      expect(
        find.text('¡Felicitaciones! Encontró todas las diferencias.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final bannerRect = tester.getRect(find.byType(StatusBanner));
      final etiquetaRect = tester.getRect(find.text('Imagen original'));
      expect(
        bannerRect.bottom,
        lessThanOrEqualTo(etiquetaRect.top),
        reason: 'el mensaje de felicitaciones (2 líneas) se sale de su caja',
      );
    },
  );

  // Regresión: el texto del banner pasó a 2-3 líneas y la segunda/
  // tercera quedaba recortada por abajo. No basta con comprobar que no
  // hay overflow ni que no se solapa con otros widgets (lo anterior ya
  // se probaba y no detectó este recorte): dentro de una fila cuyo
  // alto es más chico de lo que el texto necesita, Flutter no lanza
  // ningún error, solo recorta el dibujo en silencio, y el tamaño que
  // reporta el propio RenderParagraph queda ajustado (recortado) al
  // contenedor en vez de mostrar cuánto necesitaba de verdad — así que
  // comparar RenderParagraph.size contra su propio contenedor tampoco
  // detecta el recorte. Por eso, para cada estado, esta prueba primero
  // anota el mensaje, el ancho real del texto y el alto del contenedor
  // que lo reserva, y DESPUÉS mide ese mismo texto/ancho/estilo en un
  // árbol de widgets aparte y sin restricción de alto (ahí nada lo
  // puede recortar): si esa altura natural no entra en el alto que el
  // contenedor reservó, la prueba falla.
  for (final nivel in GameLevel.values) {
    for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          'nivel ${nivel.label} en ${tamanio.width.toInt()}x'
          '${tamanio.height.toInt()} con textScale $textScale: el '
          'texto del banner (inicial, acierto y error) no se recorta',
          (tester) async {
            final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
            addTearDown(container.dispose);
            final provider = queCambioControllerProvider(nivel);
            container.listen(provider, (_, _) {});

            tester.view.physicalSize = tamanio;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            Future<void> pumpPantalla() => tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    home: Scaffold(
                      appBar: AppBar(),
                      body: QueCambioScreen(run: _fakeRun(nivel)),
                    ),
                  ),
                ),
              ),
            );

            await pumpPantalla();

            // Anota (mensaje, ancho real del texto, alto del
            // contenedor) de cada estado, sin medir todavía — medir
            // "sin recorte" requiere montar otro árbol de widgets, que
            // destruiría esta pantalla antes de terminar de tocar las
            // 3 celdas.
            final snapshots = <(String, String, double, double)>[];

            void anotar(String etiqueta) {
              final banner = tester.widget<StatusBanner>(
                find.byType(StatusBanner),
              );
              final richText = find
                  .descendant(
                    of: find.byType(StatusBanner),
                    matching: find.byType(RichText),
                  )
                  .last;
              final anchoTexto = tester.getSize(richText).width;
              final contenedorRect = tester.getRect(
                find.byKey(const ValueKey('que_cambio_banner_stack')),
              );
              snapshots.add((
                etiqueta,
                banner.text,
                anchoTexto,
                contenedorRect.height,
              ));
            }

            anotar('inicial');

            final state0 = container.read(provider);
            final noDiferencia = List.generate(
              state0.original.length,
              (i) => i,
            ).firstWhere((i) => !state0.diferenciaIndices.contains(i));
            await tester.tap(
              find.byWidgetPredicate(
                (w) =>
                    w is QueCambioCell &&
                    w.esArriba &&
                    w.fila == noDiferencia ~/ state0.columnas + 1 &&
                    w.columna == noDiferencia % state0.columnas + 1,
              ),
            );
            await tester.pump();
            anotar('error');

            final diferencia = state0.diferenciaIndices.first;
            await tester.tap(
              find.byWidgetPredicate(
                (w) =>
                    w is QueCambioCell &&
                    w.esArriba &&
                    w.fila == diferencia ~/ state0.columnas + 1 &&
                    w.columna == diferencia % state0.columnas + 1,
              ),
            );
            await tester.pump();
            anotar('acierto');

            // Ahora sí: mide cada mensaje anotado, al mismo ancho y
            // estilo, sin nada que lo pueda recortar.
            for (final (etiqueta, mensaje, anchoTexto, alturaContenedor)
                in snapshots) {
              await tester.pumpWidget(
                MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: MaterialApp(
                    home: Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: anchoTexto,
                          child: Text(
                            mensaje,
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final alturaNatural = tester.getSize(find.text(mensaje)).height;
              expect(
                alturaNatural,
                lessThanOrEqualTo(alturaContenedor),
                reason:
                    'el banner de "$etiqueta" ("$mensaje") se recorta en '
                    '${tamanio.width.toInt()}x${tamanio.height.toInt()} '
                    'con textScale $textScale (nivel ${nivel.label}): '
                    'necesita $alturaNatural de alto pero el contenedor '
                    'solo reserva $alturaContenedor',
              );
            }
          },
        );
      }
    }
  }
}
