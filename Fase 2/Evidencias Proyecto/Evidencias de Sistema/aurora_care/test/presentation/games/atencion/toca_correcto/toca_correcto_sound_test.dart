import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_controller.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

GameRun _fakeRun([GameLevel nivel = GameLevel.facil]) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 150),
    elapsed: () => Duration.zero,
    finish: (_) {},
  );
}

ProviderContainer _buildContainer({
  required bool soundsEnabled,
  required FakeSoundService soundService,
  int seed = 3,
}) {
  final container = ProviderContainer(
    overrides: [
      tocaAutoPlayProvider.overrideWithValue(false),
      tocaRandomProvider.overrideWithValue(Random(seed)),
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
  container.listen(tocaCorrectoControllerProvider(GameLevel.facil), (_, _) {});
  return container;
}

TocaCorrectoController _notifier(
  ProviderContainer c, [
  GameLevel nivel = GameLevel.facil,
]) => c.read(tocaCorrectoControllerProvider(nivel).notifier);

Future<void> _pumpBoard(
  WidgetTester tester,
  ProviderContainer container, [
  GameLevel nivel = GameLevel.facil,
]) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: TocaCorrectoScreen(run: _fakeRun(nivel)))),
    ),
  );
}

Future<void> _tocarFigura(WidgetTester tester) async {
  // pumpAndSettle antes de tocar: AnimatedSwitcher puede mantener la
  // figura anterior montada durante la transición (2 widgets con esta
  // key a la vez), y la que queda sin asentar no tiene onTap.
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('toca_figura')).first);
  await tester.pump();
}

/// Avanza hasta que la figura actual sea el objetivo, dejando pasar
/// (expirando) las que no lo son.
void _avanzarHastaObjetivo(
  ProviderContainer c, [
  GameLevel nivel = GameLevel.facil,
]) {
  final provider = tocaCorrectoControllerProvider(nivel);
  while (!c.read(provider).esObjetivo) {
    _notifier(c, nivel).expirar();
    _notifier(c, nivel).continuar();
  }
}

void main() {
  testWidgets('con sonidos activados, tocar el objetivo suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    _notifier(container).empezar();
    _avanzarHastaObjetivo(container);
    await tester.pump();

    await _tocarFigura(tester);

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'tocar un distractor suena error_suave y reinicia la racha (reusa '
    'rachaActual del controller, que ya sube/reinicia igual)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _notifier(container).empezar();
      _avanzarHastaObjetivo(container);
      await tester.pump();
      await _tocarFigura(tester);
      expect(fakeSound.played, [SoundEffect.acierto1]);
      _notifier(container).continuar();
      await tester.pump();

      // Avanza a una figura que NO es el objetivo y la toca (error).
      final provider = tocaCorrectoControllerProvider(GameLevel.facil);
      if (container.read(provider).esObjetivo) {
        _notifier(container).expirar();
        _notifier(container).continuar();
      }
      await tester.pump();
      await _tocarFigura(tester);

      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.errorSuave]);
      _notifier(container).continuar();
      await tester.pump();

      // Tras el error, la racha vuelve a empezar en acierto_1.
      _avanzarHastaObjetivo(container);
      await tester.pump();
      await _tocarFigura(tester);
      expect(
        fakeSound.played,
        [SoundEffect.acierto1, SoundEffect.errorSuave, SoundEffect.acierto1],
      );
    },
  );

  testWidgets(
    '"se le pasó" (no tocó a tiempo) y "dejó pasar" (no tocó una '
    'distinta, correcto) no suenan nada',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _notifier(container).empezar();
      await tester.pump();

      // Deja pasar varias figuras (algunas objetivo -> "se le pasó",
      // otras no -> "dejó pasar"), sin tocar ninguna.
      for (var i = 0; i < 5; i++) {
        _notifier(container).expirar();
        _notifier(container).continuar();
        await tester.pump();
      }

      expect(fakeSound.played, isEmpty);
    },
  );

  testWidgets('con sonidos desactivados, no suena nada', (tester) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: false, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    _notifier(container).empezar();
    _avanzarHastaObjetivo(container);
    await tester.pump();
    await _tocarFigura(tester);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (figura ya resuelta, fase retro) no suena otra vez',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _notifier(container).empezar();
      _avanzarHastaObjetivo(container);
      await tester.pump();
      await _tocarFigura(tester);
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // tocar() ya no hace nada fuera de "mostrando" (ahora está en
      // "retro"): un segundo llamado no debe sonar de nuevo.
      _notifier(container).tocar();
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );

  testWidgets(
    'una ráfaga de aciertos consecutivos (acierto_5 repetido) no falla: '
    'el AudioPool limita a 2 simultáneos por efecto, sin romper nada',
    (tester) async {
      // Avanzado: 8 objetivos en la partida (40% de 20 estímulos),
      // suficientes para 6 aciertos seguidos sin terminar la partida.
      const nivel = GameLevel.avanzado;
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, nivel);
      _notifier(container, nivel).empezar();

      // 6 aciertos seguidos: la racha llega a 5 y se queda ahí, así
      // que varios de estos aciertos suenan el mismo efecto
      // (acierto_5) en sucesión rápida.
      for (var i = 0; i < 6; i++) {
        _avanzarHastaObjetivo(container, nivel);
        await tester.pump();
        await _tocarFigura(tester);
        _notifier(container, nivel).continuar();
        await tester.pump();
      }

      final aciertos = fakeSound.played
          .where((e) => e != SoundEffect.errorSuave)
          .toList();
      expect(aciertos.length, 6);
      expect(aciertos.sublist(4), [SoundEffect.acierto5, SoundEffect.acierto5]);
    },
  );
}
