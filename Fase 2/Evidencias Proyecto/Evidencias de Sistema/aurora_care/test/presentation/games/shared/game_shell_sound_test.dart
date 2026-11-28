import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/cognitive_profile.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session_analysis.dart';
import 'package:aurora_care/domain/repositories/session_analyzer.dart';
import 'package:aurora_care/domain/repositories/session_repository.dart';
import 'package:aurora_care/domain/usecases/finish_session.dart';
import 'package:aurora_care/domain/usecases/finish_session.provider.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:aurora_care/presentation/games/shared/game_providers.dart';
import 'package:aurora_care/presentation/games/shared/game_shell.dart';

import '../../../helpers/fake_sound_service.dart';

/// Devuelve siempre el mismo [SessionResult], sin tocar Firestore: permite
/// controlar el score de la partida sin construir un SessionRepository real.
class _StubFinishSession implements FinishSession {
  const _StubFinishSession(this._result);
  final SessionResult _result;

  @override
  Future<SessionResult> call(FinishSessionParams params) async => _result;

  @override
  SessionAnalyzer get analyzer => throw UnimplementedError();

  @override
  SessionRepository get repository => throw UnimplementedError();
}

GameDefinition _definicionDePrueba() {
  return GameDefinition(
    gameType: 'memorice_clasico',
    domain: 'memoria',
    title: 'Juego de prueba',
    instructions: 'Instrucciones de prueba',
    icon: Icons.videogame_asset,
    maxDuration: (_) => const Duration(minutes: 5),
    showElapsedTime: false,
    builder: (context, run) => Center(
      child: ElevatedButton(
        onPressed: () => run.finish(
          const MemoriaMetrics(
            errores: 0,
            intentos: 5,
            tiempoSegundos: 30,
            tasaAciertoPct: 100,
          ),
        ),
        child: const Text('Terminar'),
      ),
    ),
  );
}

Future<ProviderContainer> _buildContainer({
  Map<String, Object> initialPrefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
}

void main() {
  testWidgets(
    'con sonidos activados, al entrar al juego suena inicio_partida y se '
    'detiene la música',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': true},
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.inicioPartida]);
      expect(fakeSound.musicStoppedCount, 1);
    },
  );

  testWidgets(
    'con sonidos desactivados, al entrar al juego no suena nada pero sí '
    'se detiene la música',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': false},
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(fakeSound.played, isEmpty);
      expect(fakeSound.musicStoppedCount, 1);
    },
  );

  testWidgets(
    'sin perfil activo (sesión sin analizar), al terminar suena '
    'resultado_bien',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': true},
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(fakeSound.played.last, SoundEffect.resultadoBien);
    },
  );

  testWidgets(
    'con sonidos desactivados, al terminar no suena ningún resultado',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': false},
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(fakeSound.played, isEmpty);
    },
  );

  testWidgets(
    'con un análisis de score 85, al terminar suena resultado_excelente',
    (tester) async {
      final fakeSound = FakeSoundService();
      final perfil = CognitiveProfile(
        uuid: 'uuid-test',
        deviceId: 'device-test',
        createdAt: DateTime(2026, 1, 1),
        activeMode: 2,
      );
      const analysis = SessionAnalysis(
        scoreSesion: 85,
        nivelJugado: GameLevel.facil,
        sugerirAvance: false,
        sesionesEnVentana: 1,
        senal: TrendSignal.estable,
      );
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': true},
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          activeProfileProvider.overrideWith((ref) async => perfil),
          finishSessionProvider.overrideWithValue(
            const _StubFinishSession(SessionResult(analysis)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(fakeSound.played.last, SoundEffect.resultadoExcelente);
    },
  );

  testWidgets(
    'con un análisis de score 20, al terminar suena resultado_animo',
    (tester) async {
      final fakeSound = FakeSoundService();
      final perfil = CognitiveProfile(
        uuid: 'uuid-test',
        deviceId: 'device-test',
        createdAt: DateTime(2026, 1, 1),
        activeMode: 2,
      );
      const analysis = SessionAnalysis(
        scoreSesion: 20,
        nivelJugado: GameLevel.facil,
        sugerirAvance: false,
        sesionesEnVentana: 1,
        senal: TrendSignal.atencion,
      );
      final container = await _buildContainer(
        initialPrefs: {'pref_sounds': true},
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          activeProfileProvider.overrideWith((ref) async => perfil),
          finishSessionProvider.overrideWithValue(
            const _StubFinishSession(SessionResult(analysis)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GameShell(
              definition: _definicionDePrueba(),
              nivel: GameLevel.facil,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(fakeSound.played.last, SoundEffect.resultadoAnimo);
    },
  );
}
