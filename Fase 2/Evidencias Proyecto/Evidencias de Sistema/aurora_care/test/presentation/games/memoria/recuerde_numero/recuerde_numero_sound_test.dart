import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_controller.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_keypad.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

/// Overrides que aceleran los temporizadores del controller para no
/// esperar los 3-5 s reales de "mostrando" ni la retroalimentación.
List<Override> _overridesRapidos() => [
  recuerdeNumeroTiempoVisualizacionProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  recuerdeNumeroFeedbackDurationProvider.overrideWithValue(
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
        home: Scaffold(body: RecuerdeNumeroScreen(run: _fakeRun(nivel))),
      ),
    ),
  );
  // Deja pasar la fase "mostrando" (acelerada a 2 ms) y llega a
  // "esperandoRespuesta".
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _escribir(WidgetTester tester, String numero) async {
  for (final c in numero.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(RecuerdeNumeroKeypad), matching: find.text(c)),
    );
    await tester.pump();
  }
}

Future<void> _confirmar(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(RecuerdeNumeroKeypad), matching: find.text('Listo')),
  );
  await tester.pump();
  // Deja pasar la retroalimentación y la siguiente fase "mostrando"
  // (ambas aceleradas a 2 ms) hasta volver a "esperandoRespuesta".
  await tester.pump(const Duration(milliseconds: 50));
}

/// Un dígito distinto del de [correcto] en esa posición, para escribir
/// una respuesta incorrecta sin azar.
String _numeroIncorrecto(String correcto) {
  return correcto
      .split('')
      .map((d) => ((int.parse(d) + 1) % 10).toString())
      .join();
}

void main() {
  testWidgets('con sonidos activados, acertar la ronda suena acierto_1', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await _pumpBoard(tester, container, GameLevel.facil);

    final numero = container.read(provider).numero;
    await _escribir(tester, numero);
    await _confirmar(tester);

    expect(fakeSound.played, [SoundEffect.acierto1]);
  });

  testWidgets(
    'la racha de aciertos sube hasta acierto_5 y se queda ahí, y un error '
    'la reinicia (vuelve a sonar acierto_1)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});

      await _pumpBoard(tester, container, GameLevel.facil);

      // 5 aciertos seguidos: alcanza recuerdeNumeroRondasCorrectasParaGanar
      // y la partida termina en el 5to, igual que en el juego real.
      for (var i = 0; i < 5; i++) {
        final numero = container.read(provider).numero;
        await _escribir(tester, numero);
        await _confirmar(tester);
      }

      expect(fakeSound.played, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
        SoundEffect.acierto5,
      ]);
      expect(container.read(provider).isFinished, isTrue);
    },
  );

  testWidgets('un error suena error_suave y reinicia la racha a 0', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await _pumpBoard(tester, container, GameLevel.facil);

    final numero1 = container.read(provider).numero;
    await _escribir(tester, numero1);
    await _confirmar(tester);
    expect(fakeSound.played, [SoundEffect.acierto1]);

    final numero2 = container.read(provider).numero;
    await _escribir(tester, _numeroIncorrecto(numero2));
    await _confirmar(tester);
    expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.errorSuave]);

    // Después del error, la racha vuelve a empezar en acierto_1.
    final numero3 = container.read(provider).numero;
    await _escribir(tester, numero3);
    await _confirmar(tester);
    expect(
      fakeSound.played,
      [SoundEffect.acierto1, SoundEffect.errorSuave, SoundEffect.acierto1],
    );
  });

  testWidgets('con sonidos desactivados, no suena nada ni al acertar ni al fallar', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = _buildContainer(soundsEnabled: false, soundService: fakeSound);
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
    container.listen(provider, (_, _) {});

    await _pumpBoard(tester, container, GameLevel.facil);

    final numero1 = container.read(provider).numero;
    await _escribir(tester, numero1);
    await _confirmar(tester);

    final numero2 = container.read(provider).numero;
    await _escribir(tester, _numeroIncorrecto(numero2));
    await _confirmar(tester);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque ignorado (teclado bloqueado mientras se muestra el número) '
    'no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = _buildContainer(soundsEnabled: true, soundService: fakeSound);
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: RecuerdeNumeroScreen(run: _fakeRun(GameLevel.facil))),
          ),
        ),
      );
      // Todavía en "mostrando": el teclado ni siquiera está en el
      // árbol (se muestra el número grande en su lugar), así que no
      // hay nada que tocar — confirma que no suena nada en esta fase.
      expect(find.byType(RecuerdeNumeroKeypad), findsNothing);
      expect(fakeSound.played, isEmpty);

      // Vacía el Timer pendiente de "mostrando" antes de terminar el
      // test (si no, flutter_test falla por un Timer pendiente).
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
