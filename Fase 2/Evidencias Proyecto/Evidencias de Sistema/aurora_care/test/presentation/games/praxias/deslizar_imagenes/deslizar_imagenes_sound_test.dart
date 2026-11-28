import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/usecases/evaluate_phone_swipe.dart';
import 'package:aurora_care/presentation/games/praxias/deslizar_imagenes/deslizar_imagenes_controller.dart';
import 'package:aurora_care/presentation/games/praxias/deslizar_imagenes/deslizar_imagenes_screen.dart';
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
              body: PhoneSwipeScreen(
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

void _swipeLogrado(PhoneSwipeController controller) {
  final dx = controller.state.direction == SwipeDirection.left ? -145.0 : 145.0;
  controller.down(1, 150, 100, 300);
  controller.move(1, 150 + dx, 110);
  controller.up(1);
}

/// Un intento real que no logra el desplazamiento mínimo (corto, pero
/// en la dirección correcta): cuenta como intento fallido (failuresOnStep).
void _swipeCorto(PhoneSwipeController controller) {
  final dx = controller.state.direction == SwipeDirection.left ? -30.0 : 30.0;
  controller.down(1, 150, 100, 300);
  controller.move(1, 150 + dx, 100);
  controller.up(1);
}

void main() {
  testWidgets('con sonidos activados, un deslizamiento logrado suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      phoneSwipeProvider(GameLevel.facil).notifier,
    );

    _swipeLogrado(controller);
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha sube con cada deslizamiento logrado (1..4, incluido el '
    'último: sin silenciar la acción final en esta práctica plana)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneSwipeProvider(GameLevel.facil).notifier,
      );

      for (var i = 0; i < 4; i++) {
        _swipeLogrado(controller);
        await tester.pump();
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
      ]);
    },
  );

  testWidgets(
    'un intento corto (fallido real) queda en silencio (nunca '
    'error_suave) y reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneSwipeProvider(GameLevel.facil).notifier,
      );

      _swipeLogrado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      _swipeCorto(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]); // Nada se agregó.
      expect(fakeSound.played, isNot(contains(SoundEffect.errorSuave)));

      _swipeLogrado(controller);
      await tester.pump();
      // Tras el intento corto, la racha vuelve a empezar en acierto_1.
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
      phoneSwipeProvider(GameLevel.facil).notifier,
    );

    _swipeCorto(controller);
    await tester.pump();
    _swipeLogrado(controller);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un "tap" (sin desplazamiento) es un toque ignorado: no suena ni '
    'reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneSwipeProvider(GameLevel.facil).notifier,
      );

      _swipeLogrado(controller);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // Un toque sin mover el dedo: SwipeOutcome.tap, no es un intento.
      controller.down(1, 150, 100, 300);
      controller.up(1);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // La racha sigue viva: el siguiente logro suena acierto_2, no
      // acierto_1 (el tap no la reinició).
      _swipeLogrado(controller);
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.acierto1, SoundEffect.acierto2],
      );
    },
  );
}
