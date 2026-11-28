import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/secuencias_colores/secuencias_colores_controller.dart';
import 'package:aurora_care/presentation/games/atencion/secuencias_colores/secuencias_colores_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

GameRun _fakeRun() {
  return GameRun(
    nivel: GameLevel.facil,
    maxDuration: const Duration(seconds: 180),
    elapsed: () => Duration.zero,
    finish: (_) {},
  );
}

ProviderContainer _buildContainer({
  required bool soundsEnabled,
  required FakeSoundService soundService,
  int seed = 7,
}) {
  final container = ProviderContainer(
    overrides: [
      secuenciasAutoPlayProvider.overrideWithValue(false),
      secuenciasRandomProvider.overrideWithValue(Random(seed)),
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
  container.listen(
    secuenciasColoresControllerProvider(GameLevel.facil),
    (_, _) {},
  );
  return container;
}

SecuenciasColoresController _notifier(ProviderContainer c) =>
    c.read(secuenciasColoresControllerProvider(GameLevel.facil).notifier);

SecuenciasColoresState _state(ProviderContainer c) =>
    c.read(secuenciasColoresControllerProvider(GameLevel.facil));

Future<void> _pumpBoard(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: SecuenciasColoresScreen(run: _fakeRun()))),
    ),
  );
}

/// Deja pasar todo el revelado (sin tocar nada) hasta llegar al turno.
void _revelarSecuencia(ProviderContainer c) {
  for (var i = 0; i < 100; i++) {
    _notifier(c).avanzarEstimulo();
  }
}

Future<void> _tocarColor(WidgetTester tester, int color) async {
  await tester.tap(find.byKey(Key('secuencias_color_$color')));
  await tester.pump();
}

Future<void> _jugarRondaBien(WidgetTester tester, ProviderContainer c) async {
  _revelarSecuencia(c);
  await tester.pump();
  for (final color in _state(c).secuencia) {
    await _tocarColor(tester, color);
  }
}

void main() {
  testWidgets(
    'con sonidos activados, cada color revelado suena la nota de ese '
    'color (secuenciaNota, ligada al color)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      final secuencia = _state(container).secuencia;

      _revelarSecuencia(container);
      await tester.pump();

      expect(
        fakeSound.played,
        secuencia.map((i) => SoundEffect.secuenciaNota(i)).toList(),
      );
    },
  );

  testWidgets(
    'tocar un color (sin completar la ronda) suena la nota del color '
    'tocado',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _revelarSecuencia(container);
      await tester.pump();
      fakeSound.played.clear();

      final secuencia = _state(container).secuencia;
      await _tocarColor(tester, secuencia[0]);

      expect(fakeSound.played, [SoundEffect.secuenciaNota(secuencia[0])]);
    },
  );

  testWidgets(
    'el toque que completa la ronda NO suena la nota: solo el acierto '
    '(no se pisan)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      final secuencia = _state(container).secuencia; // Fácil: 3 colores.
      _revelarSecuencia(container);
      await tester.pump();
      fakeSound.played.clear();

      for (final color in secuencia) {
        await _tocarColor(tester, color);
      }

      expect(
        fakeSound.played,
        [
          SoundEffect.secuenciaNota(secuencia[0]),
          SoundEffect.secuenciaNota(secuencia[1]),
          SoundEffect.acierto1,
        ],
      );
    },
  );

  testWidgets(
    'la racha de aciertos (rondas) sube hasta acierto_5 y se queda ahí',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);

      for (var ronda = 0; ronda < secuenciasRondasPorPartida; ronda++) {
        await _jugarRondaBien(tester, container);
        _notifier(container).continuar();
        await tester.pump();
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
    },
  );

  testWidgets('un error suena error_suave (y no la nota) y reinicia la racha', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    _revelarSecuencia(container);
    await tester.pump();
    fakeSound.played.clear();

    final incorrecto =
        (_state(container).secuencia.first + 1) % secuenciasCantidadColores;
    await _tocarColor(tester, incorrecto);

    expect(fakeSound.played, [SoundEffect.errorSuave]);
  });

  testWidgets('con sonidos desactivados, no suena nada en toda la ronda', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: false, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    await _jugarRondaBien(tester, container);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (todavía en "mostrando", no es el turno) no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      // Sin revelar la secuencia (sigue en "mostrando"): el botón no
      // tiene onTap, así que tocarlo no hace nada.
      await tester.tap(
        find.byKey(const Key('secuencias_color_0')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(fakeSound.played, isEmpty);
    },
  );
}
