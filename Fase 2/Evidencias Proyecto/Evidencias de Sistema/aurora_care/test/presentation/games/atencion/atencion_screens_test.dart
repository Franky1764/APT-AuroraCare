import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/contador_objetos/contador_objetos_controller.dart';
import 'package:aurora_care/presentation/games/atencion/contador_objetos/contador_objetos_screen.dart';
import 'package:aurora_care/presentation/games/atencion/shared/jugador_nombre_provider.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_controller.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_figuras.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

/// soundsEnabledProvider es un NotifierProvider: no tiene overrideWithValue.
/// Sin esto, necesitaría sharedPreferencesProvider (que lanza si no se
/// sobreescribe) en cada test que toque algo, aunque no le importe el
/// sonido — este fija el valor sin tocar prefs.
class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

GameRun _fakeRun({void Function(CognitiveMetrics)? onFinish}) {
  return GameRun(
    nivel: GameLevel.facil,
    maxDuration: const Duration(seconds: 150),
    elapsed: () => Duration.zero,
    finish: onFinish ?? (_) {},
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget pantalla,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      jugadorNombreProvider.overrideWithValue('Rosa'),
      soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: pantalla)),
    ),
  );
  return container;
}

void main() {
  group('Toca el correcto', () {
    final overrides = [
      tocaAutoPlayProvider.overrideWithValue(false),
      tocaRandomProvider.overrideWithValue(Random(3)),
    ];

    testWidgets('muestra arriba la figura que hay que tocar', (tester) async {
      final c = await _pump(tester, TocaCorrectoScreen(run: _fakeRun()), overrides);
      final objetivo =
          c.read(tocaCorrectoControllerProvider(GameLevel.facil)).objetivo;

      expect(find.text('Toque solo ${objetivo.articulo}'), findsOneWidget);
      expect(find.text(objetivo.nombre), findsOneWidget);
      expect(find.text('Esta vez busque:'), findsOneWidget);
    });

    testWidgets('tocar el objetivo dice "¡Muy bien, Rosa!"', (tester) async {
      final c = await _pump(tester, TocaCorrectoScreen(run: _fakeRun()), overrides);
      final provider = tocaCorrectoControllerProvider(GameLevel.facil);
      final notifier = c.read(provider.notifier);

      notifier.empezar();
      // Avanza hasta el primer objetivo dejando pasar las demás figuras.
      while (!c.read(provider).esObjetivo) {
        notifier.expirar();
        notifier.continuar();
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('toca_figura')));
      await tester.pumpAndSettle();
      expect(find.text('¡Muy bien, Rosa!'), findsOneWidget);
    });
  });

  group('Contador de objetos', () {
    final overrides = [
      contadorAutoPlayProvider.overrideWithValue(false),
      contadorRandomProvider.overrideWithValue(Random(5)),
    ];

    testWidgets('al acertar dice "¡Muy bien, Rosa!" y cuántas eran',
        (tester) async {
      final c = await _pump(
        tester,
        ContadorObjetosScreen(run: _fakeRun()),
        overrides,
      );
      final provider = contadorObjetosControllerProvider(GameLevel.facil);
      final notifier = c.read(provider.notifier);

      notifier.mostrar();
      notifier.ocultar();
      await tester.pumpAndSettle();

      final cantidad = c.read(provider).cantidad;
      await tester.tap(find.byKey(Key('contador_opcion_$cantidad')));
      await tester.pumpAndSettle();

      expect(find.text('¡Muy bien, Rosa!'), findsOneWidget);
      expect(find.text('Eran $cantidad.'), findsOneWidget);
    });

    testWidgets('al equivocarse anima a seguir, sin palabras negativas',
        (tester) async {
      final c = await _pump(
        tester,
        ContadorObjetosScreen(run: _fakeRun()),
        overrides,
      );
      final provider = contadorObjetosControllerProvider(GameLevel.facil);
      final notifier = c.read(provider.notifier);

      notifier.mostrar();
      notifier.ocultar();
      await tester.pumpAndSettle();

      final s = c.read(provider);
      final incorrecta = s.opciones.firstWhere((o) => o != s.cantidad);
      await tester.tap(find.byKey(Key('contador_opcion_$incorrecta')));
      await tester.pumpAndSettle();

      expect(find.text('¡Buen intento, Rosa!'), findsOneWidget);
    });
  });
}
