import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/deslizar_imagenes/deslizar_imagenes_controller.dart';
import 'package:aurora_care/presentation/games/praxias/deslizar_imagenes/deslizar_imagenes_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

void main() {
  testWidgets(
    'swipe slowly, retry, navigate back and finish explicitly with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PhoneSwipeMetrics? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: PhoneSwipeScreen(
                  run: GameRun(
                    nivel: GameLevel.facil,
                    maxDuration: Duration.zero,
                    elapsed: () => Duration.zero,
                    finish: (metrics) => result = metrics as PhoneSwipeMetrics,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneSwipeScreen)),
      );
      final controller = container.read(
        phoneSwipeProvider(GameLevel.facil).notifier,
      );
      final board = find.byKey(const ValueKey('phone_swipe_board'));
      Future<void> swipe(double ratio) async {
        await tester.ensureVisible(board);
        final rect = tester.getRect(board);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offset = scroll.position.pixels;
        final gesture = await tester.startGesture(rect.center);
        await gesture.moveBy(Offset(rect.width * ratio, 4));
        await tester.pump(const Duration(seconds: 3));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, offset);
      }

      await swipe(.35);
      expect(controller.state.imageIndex, 0);
      await swipe(-.05);
      expect(controller.state.imageIndex, 0);
      for (var step = 0; step < 4; step++) {
        await swipe(step < 2 ? -.35 : .35);
        expect(controller.state.completedActions, step + 1);
        expect(find.text('Continuar'), findsNothing);
        if (step == 1) {
          expect(
            find.text('Muy bien. Ahora deslice hacia la derecha para volver.'),
            findsOneWidget,
          );
        }
      }
      expect(find.text('Práctica completada'), findsOneWidget);
      expect(result, isNull);
      await tester.pump(const Duration(minutes: 10));
      expect(controller.state.imageIndex, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Ver mi resumen').last,
      );
      await tester.pumpAndSettle();
      expect(result!.successfulSwipes, 4);
      expect(result!.gestureAttempts, 6);
      expect(result!.assistedActions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'help demonstrates one gesture and records button support separately',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: PhoneSwipeScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: Duration.zero,
                  elapsed: () => Duration.zero,
                  finish: (_) => fail('Must not finish early'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneSwipeScreen)),
      );
      final controller = container.read(
        phoneSwipeProvider(GameLevel.facil).notifier,
      );
      await tester.ensureVisible(find.text('Ver cómo hacerlo'));
      await tester.tap(find.text('Ver cómo hacerlo'));
      await tester.pumpAndSettle();
      expect(controller.state.paused, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.ensureVisible(find.text('Cambiar con un botón'));
      await tester.tap(find.text('Cambiar con un botón'));
      await tester.pumpAndSettle();
      expect(controller.state.imageIndex, 1);
      expect(controller.state.swipes, 0);
      expect(controller.state.assisted, 1);
      expect(controller.state.attempts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tras tres intentos cortos aparece el botón de apoyo visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PhoneSwipeScreen(
              run: GameRun(
                nivel: GameLevel.facil,
                maxDuration: Duration.zero,
                elapsed: () => Duration.zero,
                finish: (_) => fail('Must not finish early'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneSwipeScreen)),
    );
    final controller = container.read(
      phoneSwipeProvider(GameLevel.facil).notifier,
    );
    final board = find.byKey(const ValueKey('phone_swipe_board'));
    final assist = find.byKey(const ValueKey('phone_swipe_assist'));
    expect(assist, findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(board);
      final gesture = await tester.startGesture(tester.getCenter(board));
      await gesture.moveBy(const Offset(-12, 2));
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(assist, findsOneWidget);
    await tester.ensureVisible(assist);
    await tester.tap(assist);
    await tester.pumpAndSettle();
    expect(controller.state.assisted, 1);
    expect(controller.state.imageIndex, 1);
    expect(assist, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
