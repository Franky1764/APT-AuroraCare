import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/buscar_en_lista/buscar_en_lista_controller.dart';
import 'package:aurora_care/presentation/games/praxias/buscar_en_lista/buscar_en_lista_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

Future<ProviderContainer> _show(
  WidgetTester tester, {
  required bool soundsEnabled,
  required FakeSoundService soundService,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
        soundServiceProvider.overrideWithValue(soundService),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PhoneListScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: Duration.zero,
                  elapsed: () => Duration.zero,
                  finish: (_) {},
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(PhoneListController.resetHistory);

  testWidgets(
    'con sonidos activados, encontrar la 1ra búsqueda (intermedia) '
    'suena nivel_completado',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneListProvider(GameLevel.facil).notifier,
      );

      controller.select(controller.targetIndex);
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.nivelCompletado]);
    },
  );

  testWidgets(
    'encontrar la 2da búsqueda (intermedia) vuelve a sonar '
    'nivel_completado; la 3ra (última) no suena nada propio',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneListProvider(GameLevel.facil).notifier,
      );

      controller.select(controller.targetIndex); // Búsqueda 1.
      await tester.pump();
      controller.select(controller.targetIndex); // Búsqueda 2.
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.nivelCompletado, SoundEffect.nivelCompletado],
      );

      controller.select(controller.targetIndex); // Búsqueda 3 (última).
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.nivelCompletado, SoundEffect.nivelCompletado],
      ); // Nada se agregó: ya suena el resultado de GameShell.
    },
  );

  testWidgets('con sonidos desactivados, no suena nada', (tester) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: false,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneListProvider(GameLevel.facil).notifier,
    );

    controller.select(controller.targetIndex);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets('un elemento incorrecto no suena nada', (tester) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneListProvider(GameLevel.facil).notifier,
    );

    final wrong = List.generate(
      controller.items.length,
      (i) => i,
    ).firstWhere((i) => i != controller.targetIndex);
    controller.select(wrong);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets('un toque ignorado (índice fuera de rango) no suena', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneListProvider(GameLevel.facil).notifier,
    );

    controller.select(-1);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });
}
