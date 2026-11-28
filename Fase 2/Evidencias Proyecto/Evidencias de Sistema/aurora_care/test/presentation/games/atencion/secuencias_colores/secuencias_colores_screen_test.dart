import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/secuencias_colores/secuencias_colores_controller.dart';
import 'package:aurora_care/presentation/games/atencion/secuencias_colores/secuencias_colores_screen.dart';
import 'package:aurora_care/presentation/games/atencion/shared/jugador_nombre_provider.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

GameRun _fakeRun({void Function(CognitiveMetrics)? onFinish}) {
  return GameRun(
    nivel: GameLevel.facil,
    maxDuration: const Duration(seconds: 180),
    elapsed: () => Duration.zero,
    finish: onFinish ?? (_) {},
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String? nombre = 'Rosa',
  void Function(CognitiveMetrics)? onFinish,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      secuenciasAutoPlayProvider.overrideWithValue(false),
      secuenciasRandomProvider.overrideWithValue(Random(7)),
      jugadorNombreProvider.overrideWithValue(nombre),
      soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: SecuenciasColoresScreen(run: _fakeRun(onFinish: onFinish))),
      ),
    ),
  );
  return container;
}

SecuenciasColoresController _notifier(ProviderContainer c) =>
    c.read(secuenciasColoresControllerProvider(GameLevel.facil).notifier);

SecuenciasColoresState _state(ProviderContainer c) =>
    c.read(secuenciasColoresControllerProvider(GameLevel.facil));

/// Muestra la secuencia completa y la repite bien tocando los botones.
Future<void> _jugarRondaBien(WidgetTester tester, ProviderContainer c) async {
  for (var i = 0; i < 100; i++) {
    _notifier(c).avanzarEstimulo();
  }
  await tester.pumpAndSettle();
  for (final color in _state(c).secuencia) {
    await tester.tap(find.byKey(Key('secuencias_color_$color')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los 4 colores con su nombre', (tester) async {
    await _pump(tester);
    for (final nombre in ['Rojo', 'Azul', 'Verde', 'Amarillo']) {
      expect(find.text(nombre), findsOneWidget);
    }
    expect(find.text('Mire con atención…'), findsOneWidget);
  });

  testWidgets('al acertar dice "¡Muy bien, Rosa!"', (tester) async {
    final c = await _pump(tester);
    await _jugarRondaBien(tester, c);
    expect(find.text('¡Muy bien, Rosa!'), findsOneWidget);
  });

  testWidgets('sin nombre dice solo "¡Muy bien!"', (tester) async {
    final c = await _pump(tester, nombre: null);
    await _jugarRondaBien(tester, c);
    expect(find.text('¡Muy bien!'), findsOneWidget);
  });

  testWidgets('al equivocarse anima a seguir, sin palabras negativas',
      (tester) async {
    final c = await _pump(tester);
    for (var i = 0; i < 100; i++) {
      _notifier(c).avanzarEstimulo();
    }
    await tester.pumpAndSettle();
    final incorrecto =
        (_state(c).secuencia.first + 1) % secuenciasCantidadColores;
    await tester.tap(find.byKey(Key('secuencias_color_$incorrecto')));
    await tester.pumpAndSettle();
    expect(find.text('¡Buen intento, Rosa!'), findsOneWidget);
  });

  testWidgets('al terminar celebra y después entrega las métricas',
      (tester) async {
    CognitiveMetrics? recibido;
    final c = await _pump(tester, onFinish: (m) => recibido = m);

    for (var ronda = 1; ronda <= secuenciasRondasPorPartida; ronda++) {
      await _jugarRondaBien(tester, c);
      _notifier(c).continuar();
      await tester.pumpAndSettle();
    }

    expect(find.text('¡Excelente trabajo, Rosa!'), findsOneWidget);
    expect(recibido, isNull);

    await tester.pump(secuenciasPausaCelebracion);
    expect(recibido, isA<AtencionMetrics>());
  });
}
