import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_controller.dart';
import 'package:aurora_care/presentation/games/praxias/arrastrar_elementos/arrastrar_elementos_screen.dart';
import 'package:aurora_care/presentation/games/shared/game_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_sound_service.dart';

class _FixedSoundsEnabled extends SoundsEnabledNotifier {
  _FixedSoundsEnabled(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

Future<ProviderContainer> _show(
  WidgetTester tester, {
  required bool soundsEnabled,
  required FakeSoundService soundService,
  void Function(CognitiveMetrics)? finish,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
        soundServiceProvider.overrideWithValue(soundService),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PhoneDragScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: Duration.zero,
                  elapsed: () => Duration.zero,
                  finish: finish ?? (_) {},
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Mantiene presionada la imagen, la mueve al destino (o cerca, si
/// [correct] es false) y la suelta.
Future<void> _drag(WidgetTester tester, {bool correct = true}) async {
  final item = find.byKey(const ValueKey('phone_drag_item'));
  final destination = find.byKey(const ValueKey('phone_drag_destination'));
  await tester.ensureVisible(item);
  final start = tester.getCenter(item);
  final end = correct ? tester.getCenter(destination) : start + const Offset(0, 20);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(end);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'con sonidos activados, empezar a arrastrar suena arrastrar_tomar '
    'una sola vez (no en cada movimiento)',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      final item = find.byKey(const ValueKey('phone_drag_item'));
      final destination = find.byKey(const ValueKey('phone_drag_destination'));
      await tester.ensureVisible(item);
      final start = tester.getCenter(item);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));

      expect(fakeSound.played, [SoundEffect.arrastrarTomar]);

      // Moverla varias veces no debe sonar de nuevo.
      await gesture.moveTo(start + const Offset(10, 0));
      await tester.pump();
      await gesture.moveTo(start + const Offset(20, 5));
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.arrastrarTomar]);

      await gesture.moveTo(tester.getCenter(destination));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'soltar y lograrlo suena acierto_1 (racha), nunca arrastrar_soltar',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      await _drag(tester);

      expect(fakeSound.played, [SoundEffect.arrastrarTomar, SoundEffect.acierto1]);
    },
  );

  testWidgets(
    'la racha sube en cada colocación lograda (1, 2, 3, 4: esta '
    'práctica solo tiene 4 imágenes por partida)',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      for (var i = 0; i < 4; i++) {
        await _drag(tester);
      }

      final aciertos = fakeSound.played
          .where((e) => e != SoundEffect.arrastrarTomar)
          .toList();
      expect(aciertos, [
        SoundEffect.acierto1,
        SoundEffect.acierto2,
        SoundEffect.acierto3,
        SoundEffect.acierto4,
      ]);
    },
  );

  testWidgets(
    'soltar sin lograrlo suena arrastrar_soltar (nunca error_suave) y '
    'reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      await _drag(tester); // Acierto 1.
      await _drag(tester, correct: false); // Soltar sin lograrlo.

      expect(
        fakeSound.played,
        [
          SoundEffect.arrastrarTomar,
          SoundEffect.acierto1,
          SoundEffect.arrastrarTomar,
          SoundEffect.arrastrarSoltar,
        ],
      );
      expect(fakeSound.played, isNot(contains(SoundEffect.errorSuave)));

      // Tras el intento sin lograrlo, la racha vuelve a empezar en 1.
      await _drag(tester);
      expect(fakeSound.played.last, SoundEffect.acierto1);
    },
  );

  testWidgets(
    'colocar con el botón de apoyo también suena acierto(racha), como '
    'cualquier colocación lograda (feedback queda en "achieved" igual)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneDragProvider(GameLevel.facil).notifier,
      );

      controller.placeWithButton();
      await tester.pumpAndSettle();

      expect(fakeSound.played, [SoundEffect.acierto1]);
    },
  );

  testWidgets('con sonidos desactivados, no suena nada en toda la partida', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    await _show(tester, soundsEnabled: false, soundService: fakeSound);

    await _drag(tester, correct: false);
    await _drag(tester);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'un toque fuera de la imagen (no agarra nada) no suena',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        phoneDragProvider(GameLevel.facil).notifier,
      );

      controller.touch();
      await tester.pumpAndSettle();

      expect(fakeSound.played, isEmpty);
    },
  );
}
