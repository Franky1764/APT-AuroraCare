import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_cell.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_controller.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

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
  final container = ProviderContainer(
    overrides: [
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
  container.listen(queCambioControllerProvider(GameLevel.facil), (_, _) {});
  return container;
}

Future<void> _pumpBoard(
  WidgetTester tester,
  ProviderContainer container,
  GameLevel nivel,
) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(appBar: AppBar(), body: QueCambioScreen(run: _fakeRun(nivel))),
      ),
    ),
  );
}

Future<void> _tapCelda(WidgetTester tester, QueCambioState state, int indice) {
  final fila = indice ~/ state.columnas + 1;
  final columna = indice % state.columnas + 1;
  return tester.tap(
    find.byWidgetPredicate(
      (w) => w is QueCambioCell && w.esArriba && w.fila == fila && w.columna == columna,
    ),
  );
}

void main() {
  testWidgets('con sonidos activados, acertar suena acierto_1 en la primera racha', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);

    final provider = queCambioControllerProvider(GameLevel.facil);
    await _pumpBoard(tester, container, GameLevel.facil);

    final state0 = container.read(provider);
    await _tapCelda(tester, state0, state0.diferenciaIndices.first);
    await tester.pump();

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha de aciertos sube hasta acierto_5 y se queda ahí, y un error la '
    'reinicia (vuelve a sonar acierto_1)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [
          soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(true)),
          soundServiceProvider.overrideWithValue(fakeSound),
        ],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.avanzado);
      container.listen(provider, (_, _) {});

      await _pumpBoard(tester, container, GameLevel.avanzado);

      // Avanzado tiene 5 diferencias: acierta las 5, una por una.
      final diferencias = container.read(provider).diferenciaIndices.toList();
      for (final i in diferencias) {
        await _tapCelda(tester, container.read(provider), i);
        await tester.pump();
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
      ]);
    },
  );

  testWidgets('un error suena error_suave y reinicia la racha a 0', (tester) async {
    final fakeSound = FakeSoundService();
    final container = ProviderContainer(
      overrides: [
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(true)),
        soundServiceProvider.overrideWithValue(fakeSound),
      ],
    );
    addTearDown(container.dispose);
    final provider = queCambioControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await _pumpBoard(tester, container, GameLevel.facil);

    final state0 = container.read(provider);
    await _tapCelda(tester, state0, state0.diferenciaIndices.first);
    await tester.pump();
    expect(fakeSound.played, [SoundEffect.acierto1]);

    final totalCeldas = state0.columnas * 3;
    final sinDiferencia = [
      for (var i = 0; i < totalCeldas; i++) i,
    ].firstWhere((i) => !state0.diferenciaIndices.contains(i));
    await _tapCelda(tester, container.read(provider), sinDiferencia);
    await tester.pump();
    expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.errorSuave]);

    // Después del error, la racha vuelve a empezar en acierto_1.
    final diferencias = state0.diferenciaIndices.toList();
    await _tapCelda(tester, container.read(provider), diferencias[1]);
    await tester.pump();
    expect(
      fakeSound.played,
      [SoundEffect.acierto1, SoundEffect.errorSuave, SoundEffect.acierto1],
    );
  });

  testWidgets('con sonidos desactivados, no suena nada ni al acertar ni al fallar', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = ProviderContainer(
      overrides: [
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(false)),
        soundServiceProvider.overrideWithValue(fakeSound),
      ],
    );
    addTearDown(container.dispose);
    final provider = queCambioControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await _pumpBoard(tester, container, GameLevel.facil);

    final state0 = container.read(provider);
    await _tapCelda(tester, state0, state0.diferenciaIndices.first);
    await tester.pump();

    final totalCeldas = state0.columnas * 3;
    final sinDiferencia = [
      for (var i = 0; i < totalCeldas; i++) i,
    ].firstWhere((i) => !state0.diferenciaIndices.contains(i));
    await _tapCelda(tester, container.read(provider), sinDiferencia);
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (celda ya marcada) no suena, aunque el onTap se '
    'dispare',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = ProviderContainer(
        overrides: [
          soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(true)),
          soundServiceProvider.overrideWithValue(fakeSound),
        ],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pumpBoard(tester, container, GameLevel.facil);

      final state0 = container.read(provider);
      final diferencia = state0.diferenciaIndices.first;
      await _tapCelda(tester, state0, diferencia);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // La misma celda, ya encontrada: tapCelda la ignora (esMarcada),
      // no cambia "intentos", así que no debe sonar otra vez.
      await _tapCelda(tester, container.read(provider), diferencia);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );
}
