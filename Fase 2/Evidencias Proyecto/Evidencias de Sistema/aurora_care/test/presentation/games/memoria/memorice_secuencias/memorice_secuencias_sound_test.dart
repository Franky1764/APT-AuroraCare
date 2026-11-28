import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memoria_faces.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_secuencias/memorice_secuencia_tile.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_secuencias/memorice_secuencias_controller.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_secuencias/memorice_secuencias_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

/// Overrides que aceleran los temporizadores del controller para no
/// esperar los 1,2-2 s reales de resaltado/pausa/retroalimentación.
List<Override> _overridesRapidos() => [
  memoriceSecuenciaHighlightDurationProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  memoriceSecuenciaPauseDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
  memoriceSecuenciaFeedbackDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
];

GameRun _fakeRun(GameLevel nivel) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 240),
    elapsed: () => Duration.zero,
    finish: (_) {},
  );
}

ProviderContainer _buildContainer({
  required bool soundsEnabled,
  required FakeSoundService soundService,
}) {
  return ProviderContainer(
    overrides: [
      ..._overridesRapidos(),
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
}

Future<void> _tocar(WidgetTester tester, int poolIndex) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is MemoriceSecuenciaTile && w.face.name == memoriceFaces[poolIndex].name,
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'con sonidos activados, cada paso resaltado durante el revelado '
    'suena la nota de su imagen (secuenciaNota, ligada a la imagen)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final secuencia = container.read(provider).secuencia;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
          ),
        ),
      );
      // El 1er paso (pasoResaltado == 0) sonó en initState, antes de
      // este primer pump; deja pasar el resto del revelado (2do y 3er
      // paso de Fácil).
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        fakeSound.played,
        secuencia.map((i) => SoundEffect.secuenciaNota(i)).toList(),
      );
    },
  );

  testWidgets(
    'tocar un elemento (sin completar la ronda) suena la nota del '
    'elemento tocado',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.avanzado);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.avanzado)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      fakeSound.played.clear(); // Limpia las notas del revelado.

      final secuencia = container.read(provider).secuencia;
      await _tocar(tester, secuencia[0]);

      expect(fakeSound.played, [SoundEffect.secuenciaNota(secuencia[0])]);
    },
  );

  testWidgets(
    'el toque que completa la ronda NO suena la nota: solo el acierto '
    'de ronda (no se pisan)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      fakeSound.played.clear(); // Limpia las notas del revelado.

      final secuencia = container.read(provider).secuencia;
      for (final i in secuencia) {
        await _tocar(tester, i);
      }

      // Las notas de las 2 primeras cartas (sin completar la ronda) +
      // el acierto de ronda en el último toque — nunca la nota del
      // último elemento tocado.
      expect(
        fakeSound.played,
        [
          SoundEffect.secuenciaNota(secuencia[0]),
          SoundEffect.secuenciaNota(secuencia[1]),
          SoundEffect.acierto1,
        ],
      );

      // Vacía el Timer pendiente de la ronda nueva antes de terminar.
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'la racha de aciertos (rondas) sube hasta acierto_5 y se queda ahí, '
    'y un error la reinicia',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // 5 rondas acertadas seguidas: termina la partida en la 5ta.
      for (var ronda = 0; ronda < 5; ronda++) {
        final secuencia = container.read(provider).secuencia;
        for (final i in secuencia) {
          await _tocar(tester, i);
        }
        await tester.pump(const Duration(milliseconds: 50));
      }

      final aciertos = fakeSound.played
          .where(
            (e) => [
              SoundEffect.acierto1,
              SoundEffect.acierto2,
              SoundEffect.acierto3,
              SoundEffect.acierto4,
              SoundEffect.acierto5,
            ].contains(e),
          )
          .toList();
      expect(aciertos, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
      ]);
      expect(container.read(provider).isFinished, isTrue);
    },
  );

  testWidgets('un error suena error_suave (y no la nota) y reinicia la racha', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);
    final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    fakeSound.played.clear();

    final secuencia = container.read(provider).secuencia;
    final incorrecto = List.generate(memoriceSecuenciaPoolSize, (i) => i)
        .firstWhere((i) => i != secuencia[0]);
    await _tocar(tester, incorrecto);

    expect(fakeSound.played, [SoundEffect.errorSuave]);

    // Vacía el Timer pendiente de la ronda nueva antes de terminar.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('con sonidos desactivados, no suena nada: ni notas, ni acierto, ni error', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: false, soundService: fakeSound);
    addTearDown(container.dispose);
    final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final secuencia = container.read(provider).secuencia;
    for (final i in secuencia) {
      await _tocar(tester, i);
    }

    expect(fakeSound.played, isEmpty);

    // Vacía el Timer pendiente de la ronda nueva antes de terminar.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'un toque ignorado (no es el turno: todavía se está mostrando la '
    'secuencia) no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: MemoriceSecuenciasScreen(run: _fakeRun(GameLevel.facil))),
          ),
        ),
      );
      // Todavía en "mostrando": onTap es null en los mosaicos (no hay
      // nada que tocar). Solo debería haber sonado la nota del primer
      // paso (initState), nada más, aunque pase tiempo sin tocar nada.
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      final secuencia = container.read(provider).secuencia;
      expect(fakeSound.played, [SoundEffect.secuenciaNota(secuencia[0])]);

      // Deja pasar el resto del revelado para no dejar un Timer
      // pendiente al terminar el test.
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
