import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/music_route_scope.dart';
import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/presentation/breathing/breathing_complete_screen.dart';
import 'package:aurora_care/presentation/breathing/breathing_session_screen.dart';

import '../../helpers/fake_sound_service.dart';

class _FixedMusicEnabled extends MusicEnabledNotifier {
  _FixedMusicEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

ProviderContainer _musicContainer({
  required FakeSoundService sound,
  bool musicEnabled = true,
}) {
  final container = ProviderContainer(
    overrides: [
      soundServiceProvider.overrideWithValue(sound),
      musicEnabledProvider.overrideWith(() => _FixedMusicEnabled(musicEnabled)),
    ],
  );
  container
      .read(navigationSessionProvider.notifier)
      .restore(const SessionInfo(uid: 'u1', email: 'u1@example.com'));
  return container;
}

void main() {
  testWidgets(
    'guía el ciclo: inhalar al inicio, sostener a los 4 s y exhalar a los 5 s',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(minutes: 5, userName: 'Rosa'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inhale suavemente'), findsOneWidget);
      expect(find.text('Sostenga un instante'), findsNothing);
      expect(find.text('Exhale despacio'), findsNothing);

      // El ciclo dura 9 s: 4 s inhalar, 1 s sostener, 4 s exhalar. El +1 ms
      // evita quedar justo en el borde de cada fase.
      await tester.pump(const Duration(seconds: 4, milliseconds: 1));

      expect(find.text('Sostenga un instante'), findsOneWidget);
      expect(find.text('Inhale suavemente'), findsNothing);

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Exhale despacio'), findsOneWidget);
      expect(find.text('Sostenga un instante'), findsNothing);
    },
  );

  testWidgets('existe el botón "Salir" y cierra la pantalla al tocarlo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BreathingSessionScreen(
                        minutes: 5,
                        userName: 'Rosa',
                      ),
                    ),
                  ),
                  child: const Text('Abrir sesión'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // OJO: nunca pumpAndSettle() mientras BreathingSessionScreen está
    // activa — su animación se reanuda indefinidamente sola (vía
    // addStatusListener que llama forward()/reverse() en cada ciclo), así
    // que pumpAndSettle() avanza el reloj falso hasta que la sesión de 5
    // min termina sola y navega a la pantalla de cierre, antes de que
    // lleguemos a comprobar nada aquí. Se usa pump() con duraciones
    // acotadas en su lugar.
    await tester.tap(find.text('Abrir sesión'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Salir'), findsOneWidget);
    expect(find.byType(BreathingSessionScreen), findsOneWidget);

    await tester.tap(find.text('Salir'));
    await tester.pump();
    expect(find.byType(BreathingSessionScreen), findsNothing);
    expect(find.text('Abrir sesión'), findsOneWidget);
  });

  testWidgets(
    'al terminar el tiempo aparece la pantalla de cierre, se llama '
    'onSessionCompleted y no existe ningún puntaje',
    (WidgetTester tester) async {
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(
              minutes: 1,
              userName: 'Rosa',
              onSessionCompleted: () => completed = true,
            ),
          ),
        ),
      );

      // 1 minuto = 60 ticks de 1 s.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.byType(BreathingCompleteScreen), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d')), findsNothing);
    },
  );

  testWidgets(
    'Pausar detiene el tiempo y la animación; Continuar reanuda desde el '
    'mismo punto',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(minutes: 5, userName: 'Rosa'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      await tester.tap(find.text('Pausar'));
      await tester.pump();

      expect(find.text('En pausa'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      // En pausa, ni el tiempo ni la animación deben avanzar.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('En pausa'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('04:59'), findsOneWidget);
    },
  );

  testWidgets(
    'en pausa no se pasa a la pantalla de cierre aunque el tiempo llegue a 0',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(minutes: 1, userName: 'Rosa'),
          ),
        ),
      );
      await tester.pump();

      for (var i = 0; i < 55; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:05'), findsOneWidget);

      await tester.tap(find.text('Pausar'));
      await tester.pump();

      // El Timer está cancelado: por más que "pase" el tiempo no navega.
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(BreathingSessionScreen), findsOneWidget);
      expect(find.byType(BreathingCompleteScreen), findsNothing);
      expect(find.text('00:05'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();

      expect(find.byType(BreathingCompleteScreen), findsOneWidget);
    },
  );

  testWidgets(
    'existen etiquetas de semántica para la instrucción, el tiempo y los '
    'botones',
    (WidgetTester tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(minutes: 5, userName: 'Rosa'),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Inhale suavemente'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tiempo restante 5 minutos 0 segundos'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
      expect(find.bySemanticsLabel('Salir'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('se construye sin overflow con textScaler 1.3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const ProviderScope(
          child: MaterialApp(
            home: BreathingSessionScreen(minutes: 5, userName: 'Rosa'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'con "Música de fondo" activa, entrar a la sesión pide musica_calma, y '
    'salir (botón Salir) devuelve musica_menu de inmediato',
    (tester) async {
      final sound = FakeSoundService();
      final container = _musicContainer(sound: sound);
      addTearDown(container.dispose);

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
                    MaterialPageRoute(
                      builder: (_) => const BreathingSessionScreen(
                        minutes: 5,
                        userName: 'Rosa',
                      ),
                    ),
                  ),
                  child: const Text('abrir sesión'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir sesión'));
      await tester.pump();
      await tester.pump();
      expect(sound.musicStarted, [MusicTrack.calma]);

      await tester.tap(find.text('Salir'));
      await tester.pump();

      expect(sound.musicStarted, [MusicTrack.calma, MusicTrack.menu]);
    },
  );

  testWidgets(
    'con "Música de fondo" desactivada, la sesión de respiración no pide '
    'ninguna pista',
    (tester) async {
      final sound = FakeSoundService();
      final container = _musicContainer(sound: sound, musicEnabled: false);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [musicRouteObserver],
            home: const BreathingSessionScreen(minutes: 5, userName: 'Rosa'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(sound.musicStarted, isEmpty);
    },
  );
}
