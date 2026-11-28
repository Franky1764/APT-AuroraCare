import 'dart:math';

import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_controller.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_screen.dart';
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
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectDotsRandomProvider.overrideWithValue(Random(3)),
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
        soundServiceProvider.overrideWithValue(soundService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ConectaPuntosScreen(
            run: GameRun(
              nivel: GameLevel.facil,
              maxDuration: const Duration(minutes: 2),
              elapsed: () => Duration.zero,
              finish: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ConectaPuntosScreen)),
  );
}

/// Une todos los puntos de la figura actual, en orden, uno por uno.
Future<void> _conectarFigura(WidgetTester tester, ProviderContainer container) async {
  final provider = connectDotsProvider(GameLevel.facil);
  final controller = container.read(provider.notifier);
  final points = container.read(provider).evaluator!.points;
  controller.down(1, points.first);
  await tester.pump();
  for (final point in points.skip(1)) {
    controller.move(1, point);
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'con sonidos activados, alcanzar un punto (sin cerrar la figura) '
    'suena acierto_1',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final provider = connectDotsProvider(GameLevel.facil);
      final controller = container.read(provider.notifier);
      final points = container.read(provider).evaluator!.points;

      controller.down(1, points.first); // Alcanza el punto 1.
      await tester.pump();
      controller.move(1, points[1]); // Alcanza el punto 2 (no cierra).
      await tester.pump();

      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto2]);
    },
  );

  testWidgets(
    'cerrar la 1ra figura (intermedia) suena trazado_completo, nunca '
    'nota + acierto a la vez (no se pisan)',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );

      await _conectarFigura(tester, container);

      expect(fakeSound.played.last, SoundEffect.trazadoCompleto);
      expect(
        container.read(connectDotsProvider(GameLevel.facil)).index,
        0,
      ); // Sigue en la figura 1 (el avance de figura lo hace el diálogo).
    },
  );

  testWidgets(
    'cerrar la figura final de la sesión no suena nada propio',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final provider = connectDotsProvider(GameLevel.facil);
      final figurasTotales = container.read(provider).figures.length;

      for (var i = 0; i < figurasTotales; i++) {
        fakeSound.played.clear();
        await _conectarFigura(tester, container);
        final esUltima = i == figurasTotales - 1;
        if (esUltima) {
          expect(fakeSound.played, isNot(contains(SoundEffect.trazadoCompleto)));
        } else {
          expect(fakeSound.played.last, SoundEffect.trazadoCompleto);
          // Avanza a la siguiente figura "a mano" (sin el diálogo real).
          container.read(provider.notifier).next();
          await tester.pump();
        }
      }
    },
  );

  testWidgets(
    'un toque fuera de orden queda en silencio (nunca error_suave) y '
    'reinicia la racha',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final provider = connectDotsProvider(GameLevel.facil);
      final controller = container.read(provider.notifier);
      final points = container.read(provider).evaluator!.points;

      controller.down(1, points.first); // acierto_1.
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]);

      // Toca un punto bien adelantado (no el siguiente esperado): fuera
      // de orden.
      controller.move(1, points[points.length - 2]);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1]); // Nada se agregó.
      expect(fakeSound.played, isNot(contains(SoundEffect.errorSuave)));

      // Tras el toque fuera de orden, la racha vuelve a empezar en
      // acierto_1 al alcanzar el punto correcto.
      controller.move(1, points[1]);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto1]);
    },
  );

  testWidgets('con sonidos desactivados, no suena nada', (tester) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: false,
      soundService: fakeSound,
    );

    await _conectarFigura(tester, container);

    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    '"Empezar de nuevo" (restart) reinicia la racha: vuelve a sonar '
    'acierto_1',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _show(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final provider = connectDotsProvider(GameLevel.facil);
      final controller = container.read(provider.notifier);
      var points = container.read(provider).evaluator!.points;

      controller.down(1, points.first);
      await tester.pump();
      controller.move(1, points[1]);
      await tester.pump();
      expect(fakeSound.played, [SoundEffect.acierto1, SoundEffect.acierto2]);

      controller.restart();
      await tester.pump();
      points = container.read(provider).evaluator!.points;
      controller.down(1, points.first);
      await tester.pump();

      expect(
        fakeSound.played,
        [SoundEffect.acierto1, SoundEffect.acierto2, SoundEffect.acierto1],
      );
    },
  );

  testWidgets('la demostración ("Ver cómo unir los puntos") no suena nada', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _show(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      connectDotsProvider(GameLevel.facil).notifier,
    );

    controller.beginDemo();
    await tester.pump();
    controller.endDemo();
    await tester.pump();

    expect(fakeSound.played, isEmpty);
  });
}
