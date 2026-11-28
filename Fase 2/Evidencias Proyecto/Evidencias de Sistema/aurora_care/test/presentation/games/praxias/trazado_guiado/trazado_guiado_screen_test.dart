import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_controller.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_screen.dart';

class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

Future<void> pumpPractice(
  WidgetTester tester, {
  Size size = const Size(320, 640),
  bool disableAnimations = false,
  VoidCallback? onFinish,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            body: TrazadoGuiadoScreen(
              run: GameRun(
                nivel: GameLevel.facil,
                maxDuration: const Duration(minutes: 2),
                elapsed: () => Duration.zero,
                finish: (_) {
                  if (onFinish == null) fail('Must finish manually');
                  onFinish();
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reduced motion offers next, then finish on the final figure', (
    tester,
  ) async {
    var finishes = 0;
    await pumpPractice(
      tester,
      disableAnimations: true,
      onFinish: () => finishes++,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrazadoGuiadoScreen)),
    );
    final controller = container.read(
      trazadoGuiadoProvider(GameLevel.facil).notifier,
    );
    for (var index = 0; index < 3; index++) {
      final e = controller.state.evaluator!;
      controller.down(1, e.guide.start);
      for (final point in e.guide.points) {
        controller.move(1, point);
      }
      controller.up(1);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(controller.state.index, index);
      expect(finishes, 0);
      final button = find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(
          ElevatedButton,
          index == 2 ? 'Terminar práctica' : 'Siguiente recorrido',
        ),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    }
    expect(finishes, 1);
    expect(controller.attempts, hasLength(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('small screen with large text supports explicit pause and demo', (
    tester,
  ) async {
    await pumpPractice(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Ver una ayuda'), findsNothing);
    expect(find.text('Deshacer último tramo'), findsNothing);
    final restart = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Empezar de nuevo'),
    );
    final pause = tester.getRect(
      find.widgetWithText(ElevatedButton, 'Pausar práctica'),
    );
    expect(restart.top, closeTo(pause.top, 1));
    expect(restart.right, lessThan(pause.left));
    await tester.ensureVisible(find.text('Pausar práctica'));
    await tester.tap(find.text('Pausar práctica'));
    await tester.pump();
    expect(find.text('Continuar práctica'), findsOneWidget);
    await tester.tap(find.text('Continuar práctica'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ver cómo hacerlo'));
    await tester.tap(find.text('Ver cómo hacerlo'));
    await tester.pumpAndSettle();
    expect(find.text('Cómo recorrer la figura'), findsOneWidget);
    final demoSize = tester.getSize(
      find.byKey(const ValueKey('trazado_demo_canvas')),
    );
    expect(demoSize.width, closeTo(demoSize.height, .1));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Volver al recorrido'));
    await tester.tap(find.text('Volver al recorrido'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Empezar de nuevo'));
    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Volver a empezar?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continuar recorrido'));
    await tester.tap(find.text('Continuar recorrido'));
    await tester.pumpAndSettle();
  });

  testWidgets('drawing gesture stays on the board instead of scrolling', (
    tester,
  ) async {
    await pumpPractice(tester, size: const Size(400, 900));
    final board = find.byKey(const ValueKey('trazado_board'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrazadoGuiadoScreen)),
    );
    final controller = container.read(
      trazadoGuiadoProvider(GameLevel.facil).notifier,
    );
    final evaluator = controller.state.evaluator!;
    final origin = tester.getTopLeft(board);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = scroll.position.pixels;
    final gesture = await tester.startGesture(origin + evaluator.guide.start);
    for (var i = 0; i < evaluator.guide.points.length; i += 4) {
      await gesture.moveTo(origin + evaluator.guide.points[i]);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await gesture.moveTo(origin + evaluator.guide.end);
    await gesture.up();
    await tester.pump();
    expect(scroll.position.pixels, before);
    expect(controller.state.paused, isFalse);
    expect(controller.state.completed, isTrue);
    expect(controller.state.index, 0);
    expect(find.text('Siguiente recorrido'), findsOneWidget);
    expect(find.text('Practicar otra vez'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // La figura se anima antes de solicitar una decisión en primer plano.
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    final activeTime = evaluator.tiempoMs;
    final attempts = controller.attempts.length;
    await tester.pump(const Duration(minutes: 10));
    expect(controller.state.index, 0);
    expect(evaluator.tiempoMs, activeTime);
    expect(controller.attempts.length, attempts);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Practicar otra vez'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(controller.state.completed, isFalse);
    expect(controller.state.index, 0);
    expect(controller.attempts.length, attempts);
  });
}
