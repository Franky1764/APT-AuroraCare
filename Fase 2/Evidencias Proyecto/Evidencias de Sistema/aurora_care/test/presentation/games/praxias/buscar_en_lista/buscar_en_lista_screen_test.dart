import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/buscar_en_lista/buscar_en_lista_controller.dart';
import 'package:aurora_care/presentation/games/praxias/buscar_en_lista/buscar_en_lista_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SoundsDisabled extends SoundsEnabledNotifier {
  @override
  bool build() => false;
}

void main() {
  testWidgets('scroll, find and use help without inventing manual gestures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PhoneListMetrics? result;
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
            body: PhoneListScreen(
              run: GameRun(
                nivel: GameLevel.facil,
                maxDuration: Duration.zero,
                elapsed: () => Duration.zero,
                finish: (metrics) => result = metrics as PhoneListMetrics,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneListScreen)),
    );
    final controller = container.read(
      phoneListProvider(GameLevel.facil).notifier,
    );
    final scroll = find.byKey(const ValueKey('phone_list_scroll'));
    await tester.ensureVisible(scroll);
    await tester.drag(scroll, const Offset(0, -130));
    await tester.pumpAndSettle();
    expect(controller.state.scrolls, greaterThan(0));
    for (var step = 0; step < 3; step++) {
      final manual = controller.state.scrolls;
      await tester.ensureVisible(find.text('Ver cómo buscar'));
      await tester.tap(find.text('Ver cómo buscar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mostrar dónde está'));
      await tester.tap(find.text('Mostrar dónde está'));
      await tester.pumpAndSettle();
      expect(controller.state.scrolls, manual);
      final target = find.byKey(
        ValueKey('phone_list_item_${controller.targetIndex}'),
      );
      await tester.ensureVisible(scroll);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(controller.state.found, step + 1);
      expect(find.text('Continuar'), findsNothing);
    }
    expect(find.text('Práctica completada'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Ver mi resumen').last,
    );
    await tester.pumpAndSettle();
    expect(result!.completedSearches, 3);
    expect(result!.searchesWithHelp, 3);
    expect(tester.takeException(), isNull);
  });
}
