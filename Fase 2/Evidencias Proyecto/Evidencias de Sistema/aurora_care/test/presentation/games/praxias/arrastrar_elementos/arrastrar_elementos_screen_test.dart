import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_controller.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// soundsEnabledProvider es un NotifierProvider: no tiene overrideWithValue.
/// Sin esto, necesitaría sharedPreferencesProvider (que lanza si no se
/// sobreescribe) en cada test que arrastre algo, aunque no le importe
/// el sonido — este fija el valor sin tocar prefs.
class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

void main() {
  Future<void> show(
    WidgetTester tester,
    void Function(CognitiveMetrics) finish,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: PhoneDragScreen(
              run: GameRun(
                nivel: GameLevel.facil,
                maxDuration: Duration.zero,
                elapsed: () => Duration.zero,
                finish: finish,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hold, drag, retry and complete without intermediate buttons', (
    tester,
  ) async {
    PhoneDragMetrics? result;
    await show(tester, (metrics) => result = metrics as PhoneDragMetrics);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneDragScreen)),
    );
    final controller = container.read(
      phoneDragProvider(GameLevel.facil).notifier,
    );
    final board = find.byKey(const ValueKey('phone_drag_board'));
    final item = find.byKey(const ValueKey('phone_drag_item'));
    final destination = find.byKey(const ValueKey('phone_drag_destination'));
    await tester.ensureVisible(board);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(controller.state.attempts, 0);
    Future<void> drag({bool correct = true}) async {
      await tester.ensureVisible(board);
      final start = tester.getCenter(item);
      final end = correct
          ? tester.getCenter(destination)
          : start + const Offset(0, 20);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scroll.position.pixels;
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.state.dragging, isTrue);
      await gesture.moveTo(end);
      await tester.pump();
      if (correct) {
        final box =
            tester.widget<AnimatedContainer>(destination).decoration
                as BoxDecoration;
        expect((box.border as Border).top.width, 3);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, offset);
    }

    await drag(correct: false);
    expect(controller.state.misses, 1);
    expect(controller.state.completedActions, 0);
    for (var index = 0; index < 4; index++) {
      await drag();
      expect(controller.state.completedActions, index + 1);
      expect(find.text('Continuar'), findsNothing);
    }
    expect(find.text('Práctica completada'), findsOneWidget);
    expect(result, isNull);
    await tester.pump(const Duration(minutes: 10));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Ver mi resumen').last,
    );
    await tester.pumpAndSettle();
    expect(result!.successfulDrags, 4);
    expect(result!.dragAttempts, 5);
    expect(result!.dropsOutsideTarget, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help is scrollable and button support is recorded separately', (
    tester,
  ) async {
    await show(tester, (_) => fail('Must not finish early'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneDragScreen)),
    );
    final controller = container.read(
      phoneDragProvider(GameLevel.facil).notifier,
    );
    await tester.ensureVisible(find.text('Ver cómo hacerlo'));
    await tester.tap(find.text('Ver cómo hacerlo'));
    await tester.pumpAndSettle();
    expect(find.text('Cómo arrastrar'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.ensureVisible(find.text('Colocar con un botón'));
    await tester.tap(find.text('Colocar con un botón'));
    await tester.pumpAndSettle();
    expect(controller.state.completedActions, 1);
    expect(controller.state.assisted, 1);
    expect(controller.state.drags, 0);
    expect(controller.state.attempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tras tres dificultades aparece el botón de apoyo visible', (
    tester,
  ) async {
    await show(tester, (_) => fail('Must not finish early'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneDragScreen)),
    );
    final controller = container.read(
      phoneDragProvider(GameLevel.facil).notifier,
    );
    final item = find.byKey(const ValueKey('phone_drag_item'));
    final assist = find.byKey(const ValueKey('phone_drag_assist'));
    expect(assist, findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(item);
      await tester.tap(item);
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
