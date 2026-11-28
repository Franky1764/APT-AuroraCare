import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/toque_preciso/toque_preciso_controller.dart';
import 'package:aurora_care/presentation/games/praxias/toque_preciso/toque_preciso_screen.dart';
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
    'stationary targets, missed taps and manual completion on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PhoneTouchMetrics? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundsEnabledProvider.overrideWith(_SoundsDisabled.new)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: PhoneTouchScreen(
                  run: GameRun(
                    nivel: GameLevel.facil,
                    maxDuration: Duration.zero,
                    elapsed: () => Duration.zero,
                    finish: (metrics) => result = metrics as PhoneTouchMetrics,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneTouchScreen)),
      );
      final controller = container.read(
        phoneTouchProvider(GameLevel.facil).notifier,
      );
      final target = find.byKey(const ValueKey('phone_touch_target'));
      final board = find.byKey(const ValueKey('phone_touch_board'));
      await tester.ensureVisible(board);
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(board);
      final position = tester.getCenter(target);
      await tester.tapAt(tester.getTopLeft(board) + const Offset(10, 10));
      await tester.pump();
      expect(controller.state.misses, 1);
      expect(tester.getCenter(target), position);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(controller.state.hits, 1);
      expect(controller.state.misses, 1);
      await tester.pump(const Duration(minutes: 10));
      expect(controller.state.index, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.textContaining('Toque '), findsOneWidget);
      expect(target, findsNothing);
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      // La indicación queda visible mientras se eligen las opciones.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('phone_touch_instruction')),
          matching: find.textContaining('Toque '),
        ),
        findsOneWidget,
      );
      for (var index = 1; index < 6; index++) {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        if (index < 5) {
          await tester.ensureVisible(find.text('Continuar'));
          await tester.tap(find.text('Continuar'));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('Práctica completada'), findsOneWidget);
      expect(result, isNull);
      await tester.pump(const Duration(minutes: 5));
      expect(result, isNull);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Ver mi resumen').last,
      );
      await tester.pumpAndSettle();
      expect(result!.completedTargets, 6);
      expect(result!.touchesOutsideTarget, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
