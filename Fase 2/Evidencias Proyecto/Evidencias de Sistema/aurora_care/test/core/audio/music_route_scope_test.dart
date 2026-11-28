import 'package:aurora_care/core/audio/music_route_scope.dart';
import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sound_service.dart';

class _FixedMusicEnabled extends MusicEnabledNotifier {
  _FixedMusicEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

class _Pantalla extends StatelessWidget {
  const _Pantalla({required this.label, this.onPush, this.onPop});

  final String label;
  final VoidCallback? onPush;
  final VoidCallback? onPop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (onPush != null)
              ElevatedButton(onPressed: onPush, child: const Text('push')),
            if (onPop != null)
              ElevatedButton(onPressed: onPop, child: const Text('pop')),
          ],
        ),
      ),
    );
  }
}

ProviderContainer _container({
  required FakeSoundService sound,
  bool musicEnabled = true,
  bool conSesion = true,
}) {
  final container = ProviderContainer(
    overrides: [
      soundServiceProvider.overrideWithValue(sound),
      musicEnabledProvider.overrideWith(() => _FixedMusicEnabled(musicEnabled)),
    ],
  );
  if (conSesion) {
    container
        .read(navigationSessionProvider.notifier)
        .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));
  }
  return container;
}

void main() {
  testWidgets(
    'al entrar a una pantalla envuelta en MusicRouteScope, pide su pista',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: const MusicRouteScope(
              track: MusicTrack.menu,
              child: _Pantalla(label: 'menu'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(sound.musicStarted, [MusicTrack.menu]);
    },
  );

  testWidgets(
    'volver a una pantalla ya visitada (pop de lo que se abrió arriba) '
    'retoma su pista; pedir la misma que ya suena es idempotente',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: Builder(
              builder: (context) => MusicRouteScope(
                track: MusicTrack.menu,
                child: _Pantalla(
                  label: 'menu',
                  onPush: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _Pantalla(
                        label: 'juego',
                        onPop: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(sound.musicStarted, [MusicTrack.menu]);

      // Abre una pantalla "normal" (como pasa con DomainGamesScreen antes
      // de entrar a un juego): nada detiene la música, sigue sonando.
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('juego'), findsOneWidget);
      expect(sound.musicStarted, [MusicTrack.menu]); // Sin cambios.

      // Vuelve al menú: pide musica_menu de nuevo, pero como ya estaba
      // sonando esa misma pista, no se reinicia (no hay una 2da entrada).
      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('menu'), findsOneWidget);
      expect(sound.musicStarted, [MusicTrack.menu]);
    },
  );

  testWidgets(
    'si algo detuvo la música (como GameShell al entrar a un juego), '
    'volver al menú la retoma de verdad',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: Builder(
              builder: (context) => MusicRouteScope(
                track: MusicTrack.menu,
                child: _Pantalla(
                  label: 'menu',
                  onPush: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _Pantalla(
                        label: 'juego',
                        onPop: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(sound.musicStarted, [MusicTrack.menu]);

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      // GameShell.initState detiene la música incondicionalmente al entrar.
      await sound.stopMusic();
      expect(sound.isMusicPlaying, isFalse);

      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();

      expect(sound.musicStarted, [MusicTrack.menu, MusicTrack.menu]);
      expect(sound.isMusicPlaying, isTrue);
    },
  );

  testWidgets(
    'al salir de una pantalla con otra pista (como la sesión de '
    'respiración), vuelve musica_menu de inmediato, sin depender de qué '
    'pantalla quede debajo',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: Builder(
              builder: (context) => MusicRouteScope(
                track: MusicTrack.menu,
                child: _Pantalla(
                  label: 'menu',
                  onPush: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicRouteScope(
                        track: MusicTrack.calma,
                        child: _Pantalla(
                          label: 'respiracion',
                          onPop: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(sound.musicStarted, [MusicTrack.menu]);

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(sound.musicStarted, [MusicTrack.menu, MusicTrack.calma]);

      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('menu'), findsOneWidget);
      expect(
        sound.musicStarted,
        [MusicTrack.menu, MusicTrack.calma, MusicTrack.menu],
      );
    },
  );

  testWidgets(
    'con "Música de fondo" desactivada, no se pide ninguna pista',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound, musicEnabled: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: const MusicRouteScope(
              track: MusicTrack.menu,
              child: _Pantalla(label: 'menu'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(sound.musicStarted, isEmpty);
    },
  );

  testWidgets(
    'sin una sesión de adulto mayor activa, no se pide ninguna pista '
    '(evita que el cierre de sesión la vuelva a encender)',
    (tester) async {
      final sound = FakeSoundService();
      final container = _container(sound: sound, conSesion: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: const MusicRouteScope(
              track: MusicTrack.menu,
              child: _Pantalla(label: 'menu'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(sound.musicStarted, isEmpty);
    },
  );
}
