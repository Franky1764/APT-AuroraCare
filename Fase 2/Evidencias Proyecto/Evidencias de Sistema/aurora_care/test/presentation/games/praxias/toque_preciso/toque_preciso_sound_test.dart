import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/toque_preciso/toque_preciso_controller.dart';
import 'package:aurora_care/presentation/games/praxias/toque_preciso/toque_preciso_screen.dart';
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
              body: PhoneTouchScreen(
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
  testWidgets('con sonidos activados, tocar dentro del objetivo suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneTouchProvider(GameLevel.facil).notifier,
    );

    controller.touchTarget();
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha sube con cada acierto (1..6: incluido el último, sin '
    'silenciar la acción final en esta práctica plana)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneTouchProvider(GameLevel.facil).notifier,
      );

      for (var i = 0; i < 6; i++) {
        controller.touchTarget();
        await tester.pump();
        controller.next();
        await tester.pump();
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
        SoundEffect.acierto5,
      ]);
    },
  );

  testWidgets(
    'un toque fuera del objetivo queda en silencio (nunca error_suave) '
    'y reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneTouchProvider(GameLevel.facil).notifier,
      );

      controller.touchTarget();
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
      controller.next();
      await tester.pump();

      controller.touchOutside();
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]); // Nada más se agregó.
      expect(fakeSound.played, isNot(contains(SoundEffect.errorSuave)));

      controller.touchTarget();
      await tester.pump();
      // Tras el toque fuera, la racha vuelve a empezar en acierto_1.
      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto1]);
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
      phoneTouchProvider(GameLevel.facil).notifier,
    );

    controller.touchTarget();
    await tester.pump();
    controller.next();
    await tester.pump();
    controller.touchOutside();
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (acción ya resuelta, bloqueada hasta "Continuar") '
    'no suena otra vez',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneTouchProvider(GameLevel.facil).notifier,
      );

      controller.touchTarget();
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // Blocked (acknowledged == true) hasta next(): un segundo toque
      // no debe sonar de nuevo.
      controller.touchTarget();
      await tester.pump();
      controller.touchOutside();
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );
}
