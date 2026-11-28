import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_card.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_controller.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';

import '../../../../helpers/fake_sound_service.dart';

/// Igual que SoundsEnabledNotifier/MusicEnabledNotifier, pero fija el
/// valor sin necesitar sharedPreferencesProvider — este test no quiere
/// mockear SharedPreferences, solo controlar soundsEnabledProvider.
class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

Future<void> _saltarVistaPrevia(WidgetTester tester, GameLevel nivel) {
  return tester.pump(memoricePreviewDuration(nivel));
}

int _pairIndexOf(List<MemoriceCardModel> cards, int i) {
  final face = cards[i].faceIndex;
  for (var j = 0; j < cards.length; j++) {
    if (j != i && cards[j].faceIndex == face) return j;
  }
  throw StateError('sin pareja');
}

int _mismatchIndexOf(List<MemoriceCardModel> cards, int i) {
  final face = cards[i].faceIndex;
  for (var j = 0; j < cards.length; j++) {
    if (cards[j].faceIndex != face) return j;
  }
  throw StateError('sin carta distinta');
}

GameRun _fakeRun(GameLevel nivel) {
  return GameRun(
    nivel: nivel,
    maxDuration: const Duration(seconds: 240),
    elapsed: () => Duration.zero,
    finish: (_) {},
  );
}

Future<ProviderContainer> _buildContainer({
  required bool soundsEnabled,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
      ...overrides,
    ],
  );
  container.listen(
    memoriceClasicoControllerProvider(GameLevel.facil),
    (_, _) {},
  );
  return container;
}

Future<void> _pumpBoard(
  WidgetTester tester,
  ProviderContainer container,
  GameLevel nivel,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: MemoriceClasicoScreen(run: _fakeRun(nivel))),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'la vista previa (que voltea todas las cartas automáticamente) no '
    'reproduce ningún sonido',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      // Deja pasar la vista previa completa, que voltea las 12 cartas
      // automáticamente al empezar y las tapa todas de nuevo al terminar.
      await _saltarVistaPrevia(tester, GameLevel.facil);

      expect(fakeSound.played, isEmpty);
    },
  );

  testWidgets(
    'con sonidos activados, voltear una carta suena carta_voltear',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.cartaVoltear]);
    },
  );

  testWidgets(
    'un par correcto suena carta_voltear (solo al voltear la 1ra carta) '
    'y pareja_encontrada (no carta_voltear otra vez, ni acierto_1..5)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final cards = container.read(provider).cards;
      final pairB = _pairIndexOf(cards, 0);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(pairB));
      await tester.pump();

      expect(
        fakeSound.played,
        [SoundEffect.cartaVoltear, SoundEffect.parejaEncontrada],
      );
      expect(fakeSound.played, isNot(contains(SoundEffect.acierto1)));
    },
  );

  testWidgets(
    'un par incorrecto suena carta_voltear (solo al voltear la 1ra '
    'carta) y error_suave una sola vez por intento (no carta_voltear '
    'otra vez al voltear la 2da)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();

      expect(
        fakeSound.played,
        [SoundEffect.cartaVoltear, SoundEffect.errorSuave],
      );

      // El temporizador tapa las cartas de nuevo: no debe sonar una
      // segunda vez por la misma falla.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        fakeSound.played.where((e) => e == SoundEffect.errorSuave).length,
        1,
      );
    },
  );

  testWidgets(
    'con sonidos desactivados, no suena nada: ni al voltear, ni al '
    'acertar, ni al fallar',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: false,
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(milliseconds: 5),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final cards = container.read(provider).cards;
      final pairB = _pairIndexOf(cards, 0);
      final wrongC = _mismatchIndexOf(cards, pairB == 0 ? 1 : 0);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(pairB));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final cardsRestantes = container
          .read(provider)
          .cards
          .asMap()
          .entries
          .where((e) => !e.value.isMatched)
          .map((e) => e.key)
          .toList();
      await tester.tap(find.byType(MemoriceCard).at(cardsRestantes.first));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongC));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeSound.played, isEmpty);
    },
  );

  testWidgets(
    'un toque ignorado (carta ya volteada) no suena, aunque el onTap '
    'se dispare',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [soundServiceProvider.overrideWithValue(fakeSound)],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.cartaVoltear]);

      // La misma carta, ya volteada: flipCard la ignora (no cambia
      // "intentos"), así que no debe sonar una segunda vez.
      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.cartaVoltear]);
    },
  );

  testWidgets(
    'un toque ignorado durante el bloqueo (tablero mostrando un error) '
    'no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _buildContainer(
        soundsEnabled: true,
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          memoriceMismatchDelayProvider.overrideWithValue(
            const Duration(seconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpBoard(tester, container, GameLevel.facil);
      await _saltarVistaPrevia(tester, GameLevel.facil);

      final provider = memoriceClasicoControllerProvider(GameLevel.facil);
      final cards = container.read(provider).cards;
      final wrongB = _mismatchIndexOf(cards, 0);
      final tercera = cards.indexWhere(
        (c) => c.faceIndex != cards[0].faceIndex && c.faceIndex != cards[wrongB].faceIndex,
      );

      await tester.tap(find.byType(MemoriceCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(MemoriceCard).at(wrongB));
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.cartaVoltear, SoundEffect.errorSuave],
      );

      // Tablero bloqueado (locked): onTap es null en la UI, pero aunque
      // llegara a flipCard, el controlador lo ignora igual.
      await tester.tap(find.byType(MemoriceCard).at(tercera));
      await tester.pump();
      expect(
        fakeSound.played,
        [SoundEffect.cartaVoltear, SoundEffect.errorSuave],
      );

      // Vacía el temporizador de 10 s del bloqueo antes de terminar el
      // test (si no, flutter_test falla por un Timer pendiente).
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
