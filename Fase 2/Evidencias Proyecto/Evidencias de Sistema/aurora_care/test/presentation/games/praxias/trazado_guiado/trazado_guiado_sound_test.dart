import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_controller.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_screen.dart';
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

Future<ProviderContainer> _pumpPractice(
  WidgetTester tester, {
  required bool soundsEnabled,
  required FakeSoundService soundService,
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
              body: TrazadoGuiadoScreen(
                run: GameRun(
                  nivel: GameLevel.facil,
                  maxDuration: const Duration(minutes: 2),
                  elapsed: () => Duration.zero,
                  finish: (_) {},
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

/// Recorre la figura actual completa (down, todos los puntos de la
/// guía, up), dejándola en completed == true.
void _completarFigura(TrazadoGuiadoController controller) {
  final e = controller.state.evaluator!;
  controller.down(1, e.guide.start);
  for (final point in e.guide.points) {
    controller.move(1, point);
  }
  controller.up(1);
}

void main() {
  testWidgets(
    'con sonidos activados, completar el trazado suena trazado_completo',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _pumpPractice(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        trazadoGuiadoProvider(GameLevel.facil).notifier,
      );

      _completarFigura(controller);
      await tester.pumpAndSettle();

      expect(fakeSound.played, [SoundEffect.trazadoCompleto]);
    },
  );

  testWidgets('sin sonido durante el trazo (antes de completarlo)', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _pumpPractice(
      tester,
      soundsEnabled: true,
      soundService: fakeSound,
    );
    final controller = container.read(
      trazadoGuiadoProvider(GameLevel.facil).notifier,
    );

    final e = controller.state.evaluator!;
    controller.down(1, e.guide.start);
    // Recorre solo hasta la mitad: todavía no completa la figura.
    for (final point in e.guide.points.take(e.guide.points.length ~/ 2)) {
      controller.move(1, point);
    }
    await tester.pump();

    expect(fakeSound.played, isEmpty);

    controller.up(1);
    await tester.pump();
    expect(fakeSound.played, isEmpty);
  });

  testWidgets(
    'completarla ya no suena una segunda vez (mismo evaluador), pero '
    'empezar de nuevo y volver a completarla sí suena otra vez',
    (tester) async {
      final fakeSound = FakeSoundService();
      final container = await _pumpPractice(
        tester,
        soundsEnabled: true,
        soundService: fakeSound,
      );
      final controller = container.read(
        trazadoGuiadoProvider(GameLevel.facil).notifier,
      );

      _completarFigura(controller);
      await tester.pumpAndSettle();
      expect(fakeSound.played, [SoundEffect.trazadoCompleto]);

      // Cerrar el diálogo de "Recorrido completado" sin avanzar, para
      // no tocar más el estado antes de comprobar que no vuelve a sonar.
      final seguirMismaFigura = find.widgetWithText(
        OutlinedButton,
        'Practicar otra vez',
      );
      await tester.ensureVisible(seguirMismaFigura);
      await tester.tap(seguirMismaFigura);
      await tester.pumpAndSettle();
      // restart() crea un evaluador nuevo: vuelve a completarla.
      _completarFigura(controller);
      await tester.pumpAndSettle();

      expect(
        fakeSound.played,
        [SoundEffect.trazadoCompleto, SoundEffect.trazadoCompleto],
      );
    },
  );

  testWidgets('con sonidos desactivados, completar el trazado no suena nada', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    final container = await _pumpPractice(
      tester,
      soundsEnabled: false,
      soundService: fakeSound,
    );
    final controller = container.read(
      trazadoGuiadoProvider(GameLevel.facil).notifier,
    );

    _completarFigura(controller);
    await tester.pumpAndSettle();

    expect(fakeSound.played, isEmpty);
  });

  testWidgets('la demostración ("Ver cómo hacerlo") no suena nada', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    await _pumpPractice(tester, soundsEnabled: true, soundService: fakeSound);

    await tester.ensureVisible(find.text('Ver cómo hacerlo'));
    await tester.tap(find.text('Ver cómo hacerlo'));
    await tester.pumpAndSettle();
    expect(find.text('Cómo recorrer la figura'), findsOneWidget);

    expect(fakeSound.played, isEmpty);

    await tester.ensureVisible(find.text('Volver al recorrido'));
    await tester.tap(find.text('Volver al recorrido'));
    await tester.pumpAndSettle();

    expect(fakeSound.played, isEmpty);
  });
}
