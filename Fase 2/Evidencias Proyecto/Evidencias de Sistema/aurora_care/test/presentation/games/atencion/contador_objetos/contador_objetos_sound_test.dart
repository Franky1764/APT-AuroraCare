import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/contador_objetos/contador_objetos_controller.dart';
import 'package:aurora_care/presentation/games/atencion/contador_objetos/contador_objetos_screen.dart';
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
    maxDuration: const Duration(seconds: 150),
    elapsed: () => Duration.zero,
    finish: (_) {},
  );
}

ProviderContainer _buildContainer({
  required bool soundsEnabled,
  required FakeSoundService soundService,
  int seed = 5,
}) {
  final container = ProviderContainer(
    overrides: [
      contadorAutoPlayProvider.overrideWithValue(false),
      contadorRandomProvider.overrideWithValue(Random(seed)),
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      soundServiceProvider.overrideWithValue(soundService),
    ],
  );
  container.listen(
    contadorObjetosControllerProvider(GameLevel.facil),
    (_, _) {},
  );
  return container;
}

ContadorObjetosController _notifier(ProviderContainer c) =>
    c.read(contadorObjetosControllerProvider(GameLevel.facil).notifier);

ContadorObjetosState _state(ProviderContainer c) =>
    c.read(contadorObjetosControllerProvider(GameLevel.facil));

Future<void> _pumpBoard(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: ContadorObjetosScreen(run: _fakeRun()))),
    ),
  );
}

Future<void> _responder(WidgetTester tester, ProviderContainer c, int valor) async {
  await tester.tap(find.byKey(Key('contador_opcion_$valor')));
  await tester.pump();
}

void main() {
  testWidgets('con sonidos activados, acertar la ronda suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    _notifier(container).mostrar();
    _notifier(container).ocultar();
    await tester.pump();

    await _responder(tester, container, _state(container).cantidad);

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha de aciertos sube hasta acierto_5 y se queda ahí, y un '
    'error la reinicia',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);

      for (var ronda = 0; ronda < 5; ronda++) {
        _notifier(container).mostrar();
        _notifier(container).ocultar();
        await tester.pump();
        await _responder(tester, container, _state(container).cantidad);
        _notifier(container).continuar();
        await tester.pump();
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
      ]);

      // Una 6ta ronda fallada reinicia la racha.
      _notifier(container).mostrar();
      _notifier(container).ocultar();
      await tester.pump();
      final s = _state(container);
      final incorrecta = s.opciones.firstWhere((o) => o != s.cantidad);
      await _responder(tester, container, incorrecta);

      expect(fakeSound.played.last, SoundEffect.errorSuave);
    },
  );

  testWidgets('con sonidos desactivados, no suena nada ni al acertar ni al fallar', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: false, soundService: fakeSound);
    addTearDown(container.dispose);

    await _pumpBoard(tester, container);
    _notifier(container).mostrar();
    _notifier(container).ocultar();
    await tester.pump();

    final s = _state(container);
    final incorrecta = s.opciones.firstWhere((o) => o != s.cantidad);
    await _responder(tester, container, incorrecta);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (todavía mostrando las figuras) no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _notifier(container).mostrar();
      await tester.pump();
      // Todavía en "mostrando": no hay botones de opción en el árbol
      // (solo aparecen en "respondiendo"), así que no hay nada que
      // tocar — confirma que no suena nada en esa fase.
      expect(find.byType(ElevatedButton), findsNothing);

      expect(fakeSound.played, isEmpty);
    },
  );

  testWidgets(
    'responder una ronda ya resuelta (retro) no suena otra vez',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      await _pumpBoard(tester, container);
      _notifier(container).mostrar();
      _notifier(container).ocultar();
      await tester.pump();

      final cantidad = _state(container).cantidad;
      await _responder(tester, container, cantidad);
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // Un segundo llamado a responder() en fase "retro" es ignorado
      // por el controller (solo actúa en "respondiendo").
      _notifier(container).responder(cantidad);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );
}
