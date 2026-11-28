import 'package:aurora_care/core/audio/background_music_lifecycle_observer.dart';
import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sound_service.dart';

void main() {
  testWidgets(
    'pausa la música al pasar a segundo plano (inactive/paused) y la '
    'reanuda al volver, porque estaba sonando antes',
    (tester) async {
      final sound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [soundServiceProvider.overrideWithValue(sound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BackgroundMusicLifecycleObserver(child: SizedBox()),
          ),
        ),
      );

      await sound.playMusic(MusicTrack.menu);
      expect(sound.isMusicPlaying, isTrue);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      expect(sound.musicPausedCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // inactive y paused pueden llegar los dos: pausar de nuevo no es
      // un problema, pero "qué sonaba antes" se fija solo una vez.
      expect(sound.musicPausedCount, 2);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      expect(sound.musicResumedCount, 1);
      expect(sound.isMusicPlaying, isTrue);
    },
  );

  testWidgets(
    'si no había música sonando antes de pasar a segundo plano, no la '
    'reanuda al volver',
    (tester) async {
      final sound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [soundServiceProvider.overrideWithValue(sound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BackgroundMusicLifecycleObserver(child: SizedBox()),
          ),
        ),
      );

      expect(sound.isMusicPlaying, isFalse);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(sound.musicResumedCount, 0);
    },
  );

  testWidgets(
    'no reanuda música que el usuario desactivó mientras la app estaba '
    'en segundo plano',
    (tester) async {
      final sound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [soundServiceProvider.overrideWithValue(sound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BackgroundMusicLifecycleObserver(child: SizedBox()),
          ),
        ),
      );

      await sound.playMusic(MusicTrack.menu);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      sound.setMusicEnabled(false);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(sound.musicResumedCount, 0);
      expect(sound.isMusicPlaying, isFalse);
    },
  );
}
