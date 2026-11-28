import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_controller.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_screen.dart';
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
    'zoom button support is distinct from two-finger practice with reduced motion',
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
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: PhoneZoomScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: Duration.zero,
                  elapsed: () => Duration.zero,
                  finish: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneZoomScreen)),
      );
      final controller = container.read(
        phoneZoomProvider(GameLevel.facil).notifier,
      );
      for (final action in ['Ampliar con un botón', 'Reducir con un botón']) {
        await tester.ensureVisible(find.text('Ver cómo hacerlo'));
        await tester.tap(find.text('Ver cómo hacerlo'));
        await tester.pumpAndSettle();
        expect(controller.state.paused, isTrue);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.ensureVisible(find.text(action));
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }
      expect(controller.state.completedActions, 2);
      expect(controller.state.assisted, 2);
      expect(controller.state.pinches, 0);
      expect(controller.state.attempts, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real two-finger gestures enlarge and restore the image with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PhoneZoomMetrics? result;
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
              body: PhoneZoomScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: Duration.zero,
                  elapsed: () => Duration.zero,
                  finish: (metrics) => result = metrics as PhoneZoomMetrics,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneZoomScreen)),
      );
      final controller = container.read(
        phoneZoomProvider(GameLevel.facil).notifier,
      );
      final board = find.byKey(const ValueKey('phone_zoom_board'));
      await tester.ensureVisible(board);
      final one = await tester.startGesture(tester.getCenter(board));
      await one.moveBy(const Offset(30, 0));
      await one.up();
      await tester.pumpAndSettle();
      expect(controller.state.attempts, 0);
      expect(controller.state.scale, 1);
      Future<void> pinch(double from, double to) async {
        await tester.ensureVisible(board);
        final center = tester.getCenter(board);
        final first = await tester.startGesture(
          center - Offset(from, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + Offset(from, 0),
          pointer: 2,
        );
        for (var i = 1; i <= 12; i++) {
          final distance = from + (to - from) * i / 12;
          await first.moveTo(center - Offset(distance, 0));
          await second.moveTo(center + Offset(distance, 0));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
      }

      await pinch(28, 100);
      expect(
        controller.state.completedActions,
        1,
        reason:
            'scale=${controller.state.scale}, attempts=${controller.state.attempts}, feedback=${controller.state.feedback}, active=${controller.state.gestureActive}',
      );
      expect(find.text('Continuar'), findsNothing);
      await pinch(90, 20);
      expect(controller.state.completedActions, 2);
      expect(controller.state.scale, closeTo(1, .08));
      expect(find.text('Práctica completada'), findsOneWidget);
      await tester.pump(const Duration(minutes: 10));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Ver mi resumen').last,
      );
      await tester.pumpAndSettle();
      expect(result!.successfulPinches, 2);
      expect(result!.assistedActions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tras tres toques con un dedo aparece el botón de apoyo', (
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
            body: PhoneZoomScreen(
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
      tester.element(find.byType(PhoneZoomScreen)),
    );
    final controller = container.read(
      phoneZoomProvider(GameLevel.facil).notifier,
    );
    final board = find.byKey(const ValueKey('phone_zoom_board'));
    final assist = find.byKey(const ValueKey('phone_zoom_assist'));
    expect(assist, findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(board);
      final one = await tester.startGesture(tester.getCenter(board));
      // Con un solo dedo el gesto de escala parte tras ~36 px de recorrido
      // (kPanSlop); con menos no llega a contar como intento.
      await one.moveBy(const Offset(70, 0));
      await one.up();
      await tester.pumpAndSettle();
    }
    expect(assist, findsOneWidget);
    await tester.ensureVisible(assist);
    await tester.tap(assist);
    await tester.pumpAndSettle();
    expect(controller.state.assisted, 1);
    expect(controller.state.completedActions, 1);
    expect(assist, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
