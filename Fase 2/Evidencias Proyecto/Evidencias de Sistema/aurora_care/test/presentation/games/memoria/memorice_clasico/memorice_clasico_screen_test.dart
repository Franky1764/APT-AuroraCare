import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_colors.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_text_styles.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_card.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_controller.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_demo.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/shared/status_banner.dart';

/// soundsEnabledProvider es un NotifierProvider: no tiene overrideWithValue.
/// Sin esto, necesitaría sharedPreferencesProvider (que lanza si no se
/// sobreescribe) en cada test que toque una carta, aunque no le importe
/// el sonido — este fija el valor sin tocar prefs.
class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

/// Avanza el reloj falso de los tests exactamente la duración de la
/// vista previa de [nivel], para dejar el tablero listo para jugar.
Future<void> _saltarVistaPrevia(WidgetTester tester, GameLevel nivel) {
  return tester.pump(memoricePreviewDuration(nivel));
}

/// Encuentra y voltea todos los pares que falten, de a uno, hasta
/// terminar la partida. Asume que no hay ningún par ya a la vista
/// (revealedIndices vacío) antes de cada vuelta.
Future<void> _encontrarTodosLosPares(
  WidgetTester tester,
  ProviderContainer container,
  GameLevel nivel,
) async {
  final provider = memoriceClasicoControllerProvider(nivel);
  while (!container.read(provider).isFinished) {
    final cards = container.read(provider).cards;
    final i = cards.indexWhere((c) => !c.isMatched);
    final j = _pairIndexOf(cards, i);
    await tester.tap(find.byType(MemoriceCard).at(i));
    await tester.pump();
    await tester.tap(find.byType(MemoriceCard).at(j));
    await tester.pump();
  }
}

int _pairIndexOf(List<MemoriceCardModel> cards, int i) {
  final face = cards[i].faceIndex;
  for (var j = 0; j < cards.length; j++) {
    if (j != i && cards[j].faceIndex == face) return j;
  }
  throw StateError('sin pareja');
}

int _mismatchIndexOf(List<MemoriceCardModel> cards, int i) {
  final face = cards[i].faceIndex;
  for (var j = 0; j < cards.length; j++) {
    if (cards[j].faceIndex != face) return j;
  }
  throw StateError('sin carta distinta');
}

GameRun _fakeRun(
  GameLevel nivel, {
  void Function(CognitiveMetrics)? onFinish,
  VoidCallback? onStartClock,
}) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 240),
    elapsed: () => Duration.zero,
    finish: onFinish ?? (_) {},
    startClock: onStartClock,
  );
}

Future<void> _pumpBoard(WidgetTester tester, GameLevel nivel) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      child: MaterialApp(
        home: Scaffold(body: MemoriceClasicoScreen(run: _fakeRun(nivel))),
      ),
    ),
  );
}

void main() {
  testWidgets('nivel Fácil muestra 12 cartas (6 pares)', (tester) async {
    await _pumpBoard(tester, GameLevel.facil);
    expect(find.byType(MemoriceCard), findsNWidgets(12));
  });

  testWidgets('nivel Intermedio muestra 16 cartas (8 pares)', (tester) async {
    await _pumpBoard(tester, GameLevel.intermedio);
    expect(find.byType(MemoriceCard), findsNWidgets(16));
  });

  testWidgets('nivel Avanzado muestra 20 cartas (10 pares)', (tester) async {
    await _pumpBoard(tester, GameLevel.avanzado);
    expect(find.byType(MemoriceCard), findsNWidgets(20));
  });

  testWidgets(
    'todas las cartas empiezan boca arriba (vista previa) y no responden '
    'al toque',
    (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpBoard(tester, GameLevel.facil);

      expect(find.bySemanticsLabel('Carta 1, boca abajo'), findsNothing);
      final card1 = tester.widget<MemoriceCard>(
        find.byType(MemoriceCard).at(0),
      );
      expect(card1.isFaceUp, isTrue);
      expect(card1.onTap, isNull);

      // Tocarla no hace nada: sigue boca arriba y onTap sigue null.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      expect(
        tester.widget<MemoriceCard>(find.byType(MemoriceCard).at(0)).isFaceUp,
        isTrue,
      );

      handle.dispose();
    },
  );

  testWidgets(
    'tras la vista previa, todas las cartas se tapan y tocar una la voltea',
    (tester) async {
      await _pumpBoard(tester, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      expect(
        tester
            .widgetList<MemoriceCard>(find.byType(MemoriceCard))
            .every((c) => !c.isFaceUp),
        isTrue,
      );

      await tester.tap(find.byType(MemoriceCard).first);
      await tester.pump();

      final card = tester.widget<MemoriceCard>(find.byType(MemoriceCard).first);
      expect(card.isFaceUp, isTrue);
    },
  );

  testWidgets(
    'el indicador de pares encontrados avanza solo al acertar un par y '
    'no cambia al fallar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      expect(find.text('Pares encontrados: 0 de 6'), findsOneWidget);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);
      final pairB = _pairIndexOf(cards, 0);

      // Falla a propósito: el indicador no debe cambiar.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();
      expect(find.text('Pares encontrados: 0 de 6'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50)); // resuelve el error

      // Ahora acierta el par real de la carta 0.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(pairB));
      await tester.pump();
      expect(find.text('Pares encontrados: 1 de 6'), findsOneWidget);
    },
  );

  testWidgets(
    'estado inicial: no hay ningún ícono de acierto ni de error',
    (tester) async {
      await _pumpBoard(tester, GameLevel.facil);
      expect(find.byType(StatusBanner), findsNothing);
    },
  );

  testWidgets(
    'al acertar un par, el banner muestra el check verde con el mensaje '
    'correcto, y se limpia recién al tocar la primera carta del '
    'siguiente intento',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await _saltarVistaPrevia(tester, GameLevel.facil);
      final cards = container.read(provider).cards;
      final pairB = _pairIndexOf(cards, 0);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(pairB));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(StatusBanner), matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.check_circle_outline_rounded);
      expect(icon.color, AppColors.success);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'Encontró la pareja',
      );

      // No desaparece por sí solo: sigue ahí hasta la primera carta del
      // siguiente intento.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StatusBanner), findsOneWidget);

      final cardsRestantes = container
          .read(provider)
          .cards
          .asMap()
          .entries
          .where((e) => !e.value.isMatched)
          .map((e) => e.key)
          .toList();
      await tester.tap(find.byType(MemoriceCard).at(cardsRestantes.first));
      await tester.pump();
      expect(find.byType(StatusBanner), findsNothing);

      handle.dispose();
    },
  );

  testWidgets(
    'al fallar un par, el banner muestra la equis roja y persiste '
    'mientras las cartas se vuelven a tapar, hasta el siguiente intento',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await _saltarVistaPrevia(tester, GameLevel.facil);
      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();

      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(StatusBanner), matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.cancel_outlined);
      expect(icon.color, AppColors.error);
      expect(
        tester.getSemantics(find.byType(StatusBanner)).label,
        'No es la pareja',
      );

      // El temporizador tapa las cartas solas, pero el mensaje se
      // mantiene: todavía no empezó el siguiente intento.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(StatusBanner), findsOneWidget);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      expect(find.byType(StatusBanner), findsNothing);

      handle.dispose();
    },
  );

  const tamanios = [Size(360, 640), Size(360, 800)];

  for (final nivel in GameLevel.values) {
    for (final tamanio in tamanios) {
      testWidgets(
        'nivel ${nivel.label} en ${tamanio.width.toInt()}x'
        '${tamanio.height.toInt()}: tablero completo sin overflow y '
        'cartas >=48dp, en vista previa y después, con el mismo tamaño',
        (tester) async {
          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
              ],
              child: MaterialApp(
                home: Scaffold(
                  appBar: AppBar(),
                  body: MemoriceClasicoScreen(run: _fakeRun(nivel)),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          final sizeVistaPrevia = tester.getSize(
            find.byType(MemoriceCard).first,
          );
          expect(sizeVistaPrevia.width, greaterThanOrEqualTo(48));
          expect(sizeVistaPrevia.height, greaterThanOrEqualTo(48));

          await _saltarVistaPrevia(tester, nivel);

          expect(tester.takeException(), isNull);
          final sizeDespues = tester.getSize(find.byType(MemoriceCard).first);
          expect(
            sizeDespues,
            sizeVistaPrevia,
            reason:
                'el tablero cambió de tamaño entre la vista previa y el '
                'juego normal en ${nivel.label} '
                '${tamanio.width.toInt()}x${tamanio.height.toInt()}',
          );
        },
      );
    }
  }

  testWidgets('con textScale 1,3 no hay overflow (se acepta scroll)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.avanzado)),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await _saltarVistaPrevia(tester, GameLevel.avanzado);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '"Ver cómo se juega" abre el diálogo con la demo, y "Volver al '
    'juego" lo cierra sin cambiar el estado de la partida ni el reloj',
    (tester) async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [memoriceClockProvider.overrideWithValue(() => ahora), soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
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
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      // No aparece durante la vista previa.
      expect(find.text('Ver cómo se juega'), findsNothing);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final estadoAntes = container.read(provider);
      expect(find.text('Ver cómo se juega'), findsOneWidget);

      // No se usa pumpAndSettle: la demo dentro del diálogo anima en
      // bucle (AnimationController.repeat()) y nunca "se asienta".
      await tester.tap(find.text('Ver cómo se juega'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.byType(MemoriceClasicoDemo), findsOneWidget);
      expect(
        find.text('Primero mire dónde está cada imagen.'),
        findsOneWidget,
      );

      // Mientras el diálogo está abierto "pasan" 30 s de reloj: no debe
      // afectar nada, porque _firstFlipTime recién se fija con la
      // primera carta tocada, no en build().
      ahora = ahora.add(const Duration(seconds: 30));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Volver al juego'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cómo jugar'), findsNothing);
      final estadoDespues = container.read(provider);
      expect(estadoDespues, same(estadoAntes));
      expect(find.text('Ver cómo se juega'), findsOneWidget);
    },
  );

  testWidgets(
    '"Ver cómo se juega" ya no aparece después del primer volteo (no '
    'se puede reabrir a mitad de partida)',
    (tester) async {
      await _pumpBoard(tester, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);
      expect(find.text('Ver cómo se juega'), findsOneWidget);

      await tester.tap(find.byType(MemoriceCard).first);
      await tester.pump();

      expect(find.text('Ver cómo se juega'), findsNothing);
    },
  );

  testWidgets(
    '"Ver cómo se juega" desaparece apenas se voltea la primera carta '
    '(antes de resolver el par) y no vuelve a aparecer ni acertando '
    'ni fallando el par',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
          soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
            ),
          ),
        ),
      );

      await _saltarVistaPrevia(tester, GameLevel.facil);
      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);
      final pairB = _pairIndexOf(cards, 0);

      expect(find.text('Ver cómo se juega'), findsOneWidget);

      // Primera carta volteada: el reloj ya arrancó (_firstFlipTime se
      // fija en la misma llamada que incrementa intentos), así que el
      // botón debe desaparecer de inmediato, sin esperar a que se
      // complete el intento.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      expect(find.text('Ver cómo se juega'), findsNothing);

      // Falla el par: sigue sin reaparecer, ni mientras está bloqueado
      // ni después de que el temporizador tape las cartas de nuevo.
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();
      expect(find.text('Ver cómo se juega'), findsNothing);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Ver cómo se juega'), findsNothing);

      // Acierta el par real de la carta 0: tampoco reaparece.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(pairB));
      await tester.pump();
      expect(find.text('Ver cómo se juega'), findsNothing);
    },
  );

  testWidgets(
    'el tamaño de las cartas en Avanzado no cambia antes y después de '
    'resolver el primer par (la franja del botón/banner no cambia de '
    'alto)',
    (tester) async {
      for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
        tester.view.physicalSize = tamanio;
        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer(
          overrides: [
            memoriceMismatchDelayProvider.overrideWithValue(
              const Duration(milliseconds: 5),
            ),
            soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(),
                body: MemoriceClasicoScreen(
                  run: _fakeRun(GameLevel.avanzado),
                ),
              ),
            ),
          ),
        );

        await _saltarVistaPrevia(tester, GameLevel.avanzado);
        final sizeAntes = tester.getSize(find.byType(MemoriceCard).first);

        final provider = memoriceClasicoControllerProvider(
          GameLevel.avanzado,
        );
        final cards = container.read(provider).cards;
        final pairB = _pairIndexOf(cards, 0);

        await tester.tap(find.byType(MemoriceCard).at(0));
        await tester.pump();
        await tester.tap(find.byType(MemoriceCard).at(pairB));
        await tester.pump();

        final sizeDespues = tester.getSize(find.byType(MemoriceCard).first);

        expect(
          sizeDespues,
          sizeAntes,
          reason:
              'el tamaño de carta no debería cambiar al pasar de '
              '"antes del primer volteo" a "par resuelto" en '
              '${tamanio.width.toInt()}x${tamanio.height.toInt()}',
        );
        expect(sizeDespues.width, greaterThanOrEqualTo(48));
        expect(sizeDespues.height, greaterThanOrEqualTo(48));

        tester.view.reset();
        container.dispose();
      }
    },
  );

  // Auditoría (misma clase de bug que ¿Qué cambió?): el banner acá vive
  // en una franja de 48dp SIEMPRE (no 24), así que hay mucho más margen
  // — se verifica con Rects, no solo con ausencia de overflow, que
  // "Encontró la pareja"/"No es la pareja" nunca se solapan con la
  // primera carta del tablero, en los 2 anchos y las 2 escalas de
  // texto.
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'auditoría en ${tamanio.width.toInt()}x${tamanio.height.toInt()} '
        'con textScale $textScale: el banner de acierto no se solapa '
        'con el tablero',
        (tester) async {
          final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
          addTearDown(container.dispose);
          final provider = memoriceClasicoControllerProvider(
            GameLevel.facil,
          );
          container.listen(provider, (_, _) {});

          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
              ),
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: Scaffold(
                    appBar: AppBar(),
                    body: MemoriceClasicoScreen(
                      run: _fakeRun(GameLevel.facil),
                    ),
                  ),
                ),
              ),
            ),
          );

          await _saltarVistaPrevia(tester, GameLevel.facil);
          final cards = container.read(provider).cards;
          final pairB = _pairIndexOf(cards, 0);
          await tester.tap(find.byType(MemoriceCard).at(0));
          await tester.pump();
          await tester.tap(find.byType(MemoriceCard).at(pairB));
          await tester.pump();

          expect(tester.takeException(), isNull);
          final bannerRect = tester.getRect(find.byType(StatusBanner));
          final primeraCartaRect = tester.getRect(
            find.byType(MemoriceCard).first,
          );
          expect(
            bannerRect.bottom,
            lessThanOrEqualTo(primeraCartaRect.top),
            reason:
                'el banner "Encontró la pareja" se solapa con el '
                'tablero en ${tamanio.width.toInt()}x'
                '${tamanio.height.toInt()} con textScale $textScale',
          );
        },
      );
    }
  }

  // Auditoría (mismo bug de ¿Qué cambió?, que_cambio_screen.dart): la
  // franja del banner acá es fija (antes 48dp) y "Encontró la pareja"
  // ya necesita 2 líneas a 360dp de ancho, recortándose. Igual que en
  // ¿Qué cambió?, comparar RenderParagraph.size contra su propio
  // contenedor no detecta esto (el tamaño que reporta queda ajustado
  // al contenedor en vez de mostrar cuánto necesitaba). Por eso se
  // mide el mismo texto/ancho/estilo en un árbol de widgets aparte y
  // sin restricción de alto, y se compara contra el alto real que
  // reserva memorice_clasico_banner_stack.
  for (final tamanio in [const Size(360, 640), const Size(360, 800)]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'en ${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
        'textScale $textScale: el banner de acierto y de error no se '
        'recortan',
        (tester) async {
          final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
          addTearDown(container.dispose);
          final provider = memoriceClasicoControllerProvider(
            GameLevel.facil,
          );
          container.listen(provider, (_, _) {});

          tester.view.physicalSize = tamanio;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  home: Scaffold(
                    appBar: AppBar(),
                    body: MemoriceClasicoScreen(
                      run: _fakeRun(GameLevel.facil),
                    ),
                  ),
                ),
              ),
            ),
          );

          await _saltarVistaPrevia(tester, GameLevel.facil);
          final cards = container.read(provider).cards;
          final pairB = _pairIndexOf(cards, 0);

          // Acierto.
          await tester.tap(find.byType(MemoriceCard).at(0));
          await tester.pump();
          await tester.tap(find.byType(MemoriceCard).at(pairB));
          await tester.pump();
          final richTextAcierto = find
              .descendant(
                of: find.byType(StatusBanner),
                matching: find.byType(RichText),
              )
              .last;
          final anchoAcierto = tester.getSize(richTextAcierto).width;
          final alturaContenedorAcierto = tester
              .getRect(
                find.byKey(const ValueKey('memorice_clasico_banner_stack')),
              )
              .height;

          // Siguiente intento (limpia el banner) y falla a propósito.
          final cardsRestantes = container
              .read(provider)
              .cards
              .asMap()
              .entries
              .where((e) => !e.value.isMatched)
              .map((e) => e.key)
              .toList();
          await tester.tap(find.byType(MemoriceCard).at(cardsRestantes.first));
          await tester.pump();
          final cardsTrasVoltear = container.read(provider).cards;
          final caraElegida = cardsTrasVoltear[cardsRestantes.first].faceIndex;
          final wrongB2 = cardsTrasVoltear.indexWhere(
            (c) => !c.isMatched && c.faceIndex != caraElegida,
          );
          await tester.tap(find.byType(MemoriceCard).at(wrongB2));
          await tester.pump();
          final richTextError = find
              .descendant(
                of: find.byType(StatusBanner),
                matching: find.byType(RichText),
              )
              .last;
          final anchoError = tester.getSize(richTextError).width;
          final alturaContenedorError = tester
              .getRect(
                find.byKey(const ValueKey('memorice_clasico_banner_stack')),
              )
              .height;

          container.dispose();

          Future<double> alturaNatural(String texto, double ancho) async {
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
                        width: ancho,
                        child: Text(texto, style: AppTextStyles.bodySecondary),
                      ),
                    ),
                  ),
                ),
              ),
            );
            return tester.getSize(find.text(texto)).height;
          }

          final naturalAcierto = await alturaNatural(
            'Encontró la pareja',
            anchoAcierto,
          );
          expect(
            naturalAcierto,
            lessThanOrEqualTo(alturaContenedorAcierto),
            reason:
                'el banner de acierto se recorta en '
                '${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
                'textScale $textScale',
          );

          final naturalError = await alturaNatural(
            'No es la pareja',
            anchoError,
          );
          expect(
            naturalError,
            lessThanOrEqualTo(alturaContenedorError),
            reason:
                'el banner de error se recorta en '
                '${tamanio.width.toInt()}x${tamanio.height.toInt()} con '
                'textScale $textScale',
          );
        },
      );
    }
  }

  testWidgets(
    'el tamaño de las cartas no cambia entre "Ver cómo se juega", '
    'acierto y error (misma franja, no una altura fija)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      );
      addTearDown(container.dispose);
      final provider = memoriceClasicoControllerProvider(GameLevel.avanzado);
      container.listen(provider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.avanzado)),
            ),
          ),
        ),
      );

      await _saltarVistaPrevia(tester, GameLevel.avanzado);
      final sizeBoton = tester.getSize(find.byType(MemoriceCard).first);

      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();
      final sizeError = tester.getSize(find.byType(MemoriceCard).first);

      expect(
        sizeError,
        sizeBoton,
        reason: 'el tablero cambió de tamaño al mostrar el banner de error',
      );

      container.dispose();
    },
  );

  testWidgets(
    '"Ver cómo se juega" no aparece durante la vista previa, y aparece '
    'al terminar (antes del primer volteo)',
    (tester) async {
      await _pumpBoard(tester, GameLevel.facil);
      expect(find.text('Ver cómo se juega'), findsNothing);

      await _saltarVistaPrevia(tester, GameLevel.facil);
      expect(find.text('Ver cómo se juega'), findsOneWidget);
    },
  );

  testWidgets(
    'la cuenta regresiva de la vista previa se ve, pero el anuncio de '
    'accesibilidad no cambia cada segundo (solo al empezar y al '
    'terminar)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBoard(tester, GameLevel.facil);

      expect(find.text('Memorice las imágenes: 9'), findsOneWidget);
      expect(find.bySemanticsLabel('Memorice las imágenes'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Memorice las imágenes: 8'), findsOneWidget);
      // Mismo anuncio que al empezar: no repite el número cada segundo.
      expect(find.bySemanticsLabel('Memorice las imágenes'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      // findsWidgets, no findsOneWidget: el mismo texto también existe
      // como referencia invisible (reservando alto) en otro lado del
      // Stack — ver _mensajesVistaPreviaPosibles en la pantalla.
      expect(find.text('Ahora busque las parejas'), findsWidgets);
      expect(
        find.bySemanticsLabel('Ahora busque las parejas'),
        findsOneWidget,
      );

      handle.dispose();
    },
  );

  testWidgets(
    'sin disableAnimations, justo al terminar la vista previa las '
    'cartas todavía están animando el volteo (no es instantáneo)',
    (tester) async {
      await _pumpBoard(tester, GameLevel.facil);
      final primeraCara = tester
          .widgetList<MemoriceCard>(find.byType(MemoriceCard))
          .first
          .face;

      await _saltarVistaPrevia(tester, GameLevel.facil);

      expect(
        find.byKey(ValueKey('face_up_${primeraCara.name}')),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'con disableAnimations activo, las cartas quedan tapadas en el '
    'mismo frame en que termina la vista previa (cambio instantáneo)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProviderScope(
            overrides: [
              soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
              ),
            ),
          ),
        ),
      );

      await _saltarVistaPrevia(tester, GameLevel.facil);

      expect(find.byKey(const ValueKey('face_down')), findsNWidgets(12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'al taparse las cartas se arranca el reloj visible (run.startClock), '
    'aunque no se haya tocado ninguna carta',
    (tester) async {
      var llamadas = 0;
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceClasicoScreen(
                run: _fakeRun(
                  GameLevel.facil,
                  onStartClock: () => llamadas++,
                ),
              ),
            ),
          ),
        ),
      );

      expect(llamadas, 0);
      await _saltarVistaPrevia(tester, GameLevel.facil);
      expect(llamadas, 1);

      // No se llama de nuevo por seguir jugando.
      await tester.tap(find.byType(MemoriceCard).first);
      await tester.pump();
      expect(llamadas, 1);
    },
  );

  final formasDeCerrarElDialogo = <String, Future<void> Function(WidgetTester)>{
    'el botón "Volver al juego"': (tester) => tester.tap(
      find.widgetWithText(ElevatedButton, 'Volver al juego'),
    ),
    'el botón atrás del sistema': (tester) => tester.binding.handlePopRoute(),
    'tocar fuera del diálogo': (tester) =>
        tester.tapAt(const Offset(10, 10)),
  };

  for (final cierre in formasDeCerrarElDialogo.entries) {
    testWidgets(
      'abrir "Ver cómo se juega", esperar 30 s y cerrarlo con '
      '${cierre.key}: no suma esos 30 s a tiempoSegundos ni al reloj '
      'de la métrica',
      (tester) async {
        var ahora = DateTime(2026, 1, 1, 12, 0, 0);
        final container = ProviderContainer(
          overrides: [memoriceClockProvider.overrideWithValue(() => ahora), soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
        );
        addTearDown(container.dispose);
        final provider = memoriceClasicoControllerProvider(GameLevel.facil);
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
                body: MemoriceClasicoScreen(run: _fakeRun(GameLevel.facil)),
              ),
            ),
          ),
        );

        await _saltarVistaPrevia(tester, GameLevel.facil);

        await tester.tap(find.text('Ver cómo se juega'));
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Cómo jugar'), findsOneWidget);

        ahora = ahora.add(const Duration(seconds: 30));

        await cierre.value(tester);
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Cómo jugar'), findsNothing);

        ahora = ahora.add(const Duration(seconds: 4));
        await _encontrarTodosLosPares(tester, container, GameLevel.facil);

        expect(container.read(provider).metrics!.tiempoSegundos, 4);
      },
    );
  }
}
