import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/audio/music_route_scope.dart';
import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/presentation/breathing/breathing_duration_screen.dart';
import 'package:aurora_care/presentation/challenges/daily_challenge_provider.dart';
import 'package:aurora_care/presentation/home/home_flow.dart';

import '../../helpers/fake_sound_service.dart';

// Tamaño de teléfono para que las 4 tarjetas sean visibles sin scroll.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _FixedMusicEnabled extends MusicEnabledNotifier {
  _FixedMusicEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

void main() {
  testWidgets(
    'desde Inicio, tocar la tarjeta Respiración abre la pantalla de '
    'duración (vía buildHomeScreen, no otra instancia de HomeScreen)',
    (WidgetTester tester) async {
      _usePhoneSize(tester);

      // BreathingDurationScreen lee la última duración guardada vía
      // preferencesLocalSourceProvider -> sharedPreferencesProvider.
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: buildHomeScreen('Rosa')),
        ),
      );

      await tester.tap(find.text('Respiración'));
      await tester.pumpAndSettle();

      final screen = tester.widget<BreathingDurationScreen>(
        find.byType(BreathingDurationScreen),
      );
      expect(screen.userName, 'Rosa');
    },
  );

  testWidgets(
    'Home pide musica_menu al entrar, y la retoma (sin reiniciarla) al '
    'volver desde una pantalla que la detuvo, como un juego',
    (tester) async {
      _usePhoneSize(tester);
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final sound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          soundServiceProvider.overrideWithValue(sound),
          musicEnabledProvider.overrideWith(() => _FixedMusicEnabled(true)),
          // Evita que DailyChallengeCard busque sesiones en Firestore
          // (fuera del alcance de este test, que solo cubre la música).
          dailyChallengeProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(navigationSessionProvider.notifier)
          .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => buildHomeScreen('Rosa')),
                  ),
                  child: const Text('ir a inicio'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ir a inicio'));
      await tester.pumpAndSettle();
      expect(sound.musicStarted, [MusicTrack.menu]);

      await tester.tap(find.text('Respiración'));
      await tester.pumpAndSettle();
      // La duración de respiración, como DomainGamesScreen, no toca
      // música: musica_menu sigue sonando sin interrupción.
      expect(sound.musicStarted, [MusicTrack.menu]);

      // Simula lo que hace GameShell.initState al entrar a un juego.
      await sound.stopMusic();
      expect(sound.isMusicPlaying, isFalse);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(BreathingDurationScreen), findsNothing);
      expect(sound.musicStarted, [MusicTrack.menu, MusicTrack.menu]);
      expect(sound.isMusicPlaying, isTrue);
    },
  );

  testWidgets(
    'con "Música de fondo" desactivada, Home no pide ninguna pista',
    (tester) async {
      _usePhoneSize(tester);
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final sound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          soundServiceProvider.overrideWithValue(sound),
          musicEnabledProvider.overrideWith(() => _FixedMusicEnabled(false)),
          dailyChallengeProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(navigationSessionProvider.notifier)
          .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: buildHomeScreen('Rosa'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sound.musicStarted, isEmpty);
    },
  );
}
