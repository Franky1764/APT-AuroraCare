import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_controller.dart';
import 'package:aurora_care/presentation/games/praxias/ampliar_imagen/ampliar_imagen_screen.dart';
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
              body: PhoneZoomScreen(
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

/// Pellizco con dos dedos que logra el paso actual (ampliar o reducir,
/// según corresponda).
void _pellizcoLogrado(PhoneZoomController controller) {
  controller.begin(2);
  controller.update(controller.state.enlarging ? 2.0 : 0.3, 2);
  controller.end();
}

/// Gesto real con dos dedos que NO logra el paso (movimiento insuficiente).
void _pellizcoFallido(PhoneZoomController controller) {
  controller.begin(2);
  controller.update(1.02, 2);
  controller.end();
}

/// Ni siquiera es un intento válido (un solo dedo): se ignora del todo.
void _toqueIgnorado(PhoneZoomController controller) {
  controller.begin(1);
  controller.update(2, 1);
  controller.end();
}

void main() {
  testWidgets('con sonidos activados, lograr el primer pellizco suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneZoomProvider(GameLevel.facil).notifier,
    );

    _pellizcoLogrado(controller);
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha sube con el 2do pellizco (incluido el último: sin '
    'silenciar la acción final en esta práctica plana)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneZoomProvider(GameLevel.facil).notifier,
      );

      _pellizcoLogrado(controller); // Ampliar.
      await tester.pump();
      _pellizcoLogrado(controller); // Reducir.
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto2]);
    },
  );

  testWidgets(
    'un gesto real que no logra el paso queda en silencio (nunca '
    'error_suave) y reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneZoomProvider(GameLevel.facil).notifier,
      );

      _pellizcoLogrado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      _pellizcoFallido(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]); // Nada se agregó.
      expect(fakeSound.played, isNot(contains(SoundEffect.errorSuave)));

      _pellizcoLogrado(controller);
      await tester.pump();
      // Tras el intento fallido, la racha vuelve a empezar en acierto_1.
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
      phoneZoomProvider(GameLevel.facil).notifier,
    );

    _pellizcoFallido(controller);
    await tester.pump();
    _pellizcoLogrado(controller);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un gesto con un solo dedo (toque ignorado) no suena ni reinicia '
    'la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneZoomProvider(GameLevel.facil).notifier,
      );

      _pellizcoLogrado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      _toqueIgnorado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // La racha sigue viva: el siguiente logro suena acierto_2, no
      // acierto_1 (el toque de un dedo no la reinició).
      _pellizcoLogrado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto2]);
    },
  );
}
