import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_controller.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_screen.dart';

class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

Future<ProviderContainer> show(
  WidgetTester tester, {
  bool reduced = false,
  double textScale = 1,
  Size size = const Size(400, 1000),
  void Function(CognitiveMetrics)? finish,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectDotsRandomProvider.overrideWithValue(Random(3)),
        soundsEnabledProvider.overrideWith(_SoundsDisabled.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ConectaPuntosScreen(
            run: GameRun(
              nivel: GameLevel.facil,
              maxDuration: const Duration(minutes: 2),
              elapsed: () => Duration.zero,
              finish: finish ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ConectaPuntosScreen)),
  );
}

void complete(ProviderContainer container) {
  final state = container.read(connectDotsProvider(GameLevel.facil));
  final controller = container.read(
    connectDotsProvider(GameLevel.facil).notifier,
  );
  controller.down(1, state.evaluator!.points.first);
  for (final point in state.evaluator!.points.skip(1)) {
    controller.move(1, point);
  }
}

void main() {
  testWidgets('texto grande y pantalla pequeña permiten pausa y demostración', (
    tester,
  ) async {
    final container = await show(
      tester,
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Pausar práctica'));
    await tester.tap(find.text('Pausar práctica'));
    await tester.pumpAndSettle();
    expect(container.read(connectDotsProvider(GameLevel.facil)).paused, isTrue);
    await tester.ensureVisible(find.text('Ver cómo hacerlo'));
    await tester.tap(find.text('Ver cómo hacerlo'));
    await tester.pumpAndSettle();
    expect(find.text('Cómo unir los puntos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Volver a practicar'));
    await tester.tap(find.text('Volver a practicar'));
    await tester.pumpAndSettle();
    expect(container.read(connectDotsProvider(GameLevel.facil)).paused, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'completa tres figuras y solicita la elección, animaciones reducidas: $reduced',
      (tester) async {
        CognitiveMetrics? result;
        final container = await show(
          tester,
          reduced: reduced,
          finish: (metrics) => result = metrics,
        );
        for (var index = 0; index < 3; index++) {
          complete(container);
          await tester.pumpAndSettle();
          expect(find.text('Figura completada'), findsOneWidget);
          expect(result, isNull);
          await tester.tap(
            find.text(index == 2 ? 'Ver mi resumen' : 'Siguiente figura'),
          );
          await tester.pumpAndSettle();
        }
        final metrics = result as PraxiasMetrics;
        expect(metrics.connectionVersion, 'connect-dots-v2');
        expect(metrics.connectionAttempts.length, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'puede repetir la figura completada sin perder el intento anterior',
    (tester) async {
      final container = await show(tester);
      complete(container);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar otra vez'));
      await tester.pumpAndSettle();
      final state = container.read(connectDotsProvider(GameLevel.facil));
      expect(state.index, 0);
      expect(state.completed, isFalse);
      expect(
        container
            .read(connectDotsProvider(GameLevel.facil).notifier)
            .attempts
            .length,
        1,
      );
    },
  );

  testWidgets('arrastrar dentro del tablero no desplaza la página', (
    tester,
  ) async {
    final container = await show(tester, size: const Size(360, 640));
    final state = container.read(connectDotsProvider(GameLevel.facil));
    final board = tester.getTopLeft(
      find.byKey(const ValueKey('connect_dots_board')),
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = scroll.pixels;
    final gesture = await tester.startGesture(
      board + state.evaluator!.points.first,
    );
    await gesture.moveBy(const Offset(0, 65));
    await gesture.up();
    await tester.pump();
    expect(scroll.pixels, offset);
    expect(
      container.read(connectDotsProvider(GameLevel.facil)).evaluator!.strokes,
      isNotEmpty,
    );
  });
}
