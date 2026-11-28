import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/providers/accessibility_providers.dart';
import 'package:aurora_care/core/providers/sound_providers.dart';
import 'package:aurora_care/core/theme/app_theme.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/colorear_contorno/colorear_contorno_screen.dart';
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

Future<void> _show(
  WidgetTester tester, {
  required bool soundsEnabled,
  required FakeSoundService soundService,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundsEnabledProvider.overrideWith(() => _FixedSoundsEnabled(soundsEnabled)),
        soundServiceProvider.overrideWithValue(soundService),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ColorearContornoScreen(
            run: GameRun(
              nivel: GameLevel.facil,
              maxDuration: Duration.zero,
              elapsed: () => Duration.zero,
              finish: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Pinta la figura actual con un barrido denso de todo el tablero (no se
/// puede elegir la figura: elegirFigurasColorear usa Random() sin
/// semilla inyectable), suficiente para superar la cobertura exigida
/// (80% en Fácil) sin importar cuál de las 5 figuras tocó.
Future<void> _pintarFigura(WidgetTester tester) async {
  final rect = tester.getRect(
    find.byKey(const ValueKey('colorear_contorno_board')),
  );
  final gesture = await tester.startGesture(rect.center);
  const paso = 10.0;
  for (var y = rect.top + 4; y < rect.bottom - 4; y += paso) {
    final izquierdaADerecha = ((y - rect.top) / paso).floor().isEven;
    final x0 = izquierdaADerecha ? rect.left + 4 : rect.right - 4;
    final x1 = izquierdaADerecha ? rect.right - 4 : rect.left + 4;
    await gesture.moveTo(Offset(x0, y));
    await gesture.moveTo(Offset(x1, y));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'con sonidos activados, cerrar la 1ra figura (intermedia) suena '
    'trazado_completo',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      expect(find.textContaining('Figura 1 de 3'), findsOneWidget);
      await _pintarFigura(tester);

      expect(fakeSound.played, [SoundEffect.trazadoCompleto]);
    },
  );

  testWidgets(
    'cerrar las 3 figuras: trazado_completo en la 1ra y la 2da '
    '(intermedias), nada propio en la 3ra (última)',
    (tester) async {
      final fakeSound = FakeSoundService();
      await _show(tester, soundsEnabled: true, soundService: fakeSound);

      await _pintarFigura(tester); // Figura 1.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.textContaining('Figura 2 de 3'), findsOneWidget);
      expect(fakeSound.played, [SoundEffect.trazadoCompleto]);

      await _pintarFigura(tester); // Figura 2.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.textContaining('Figura 3 de 3'), findsOneWidget);
      expect(
        fakeSound.played,
        [SoundEffect.trazadoCompleto, SoundEffect.trazadoCompleto],
      );

      await _pintarFigura(tester); // Figura 3 (última).
      // Nada propio al cerrar la última: ya suena el resultado de GameShell.
      expect(
        fakeSound.played,
        [SoundEffect.trazadoCompleto, SoundEffect.trazadoCompleto],
      );
    },
  );

  testWidgets('con sonidos desactivados, cerrar una figura no suena nada', (
    tester,
  ) async {
    final fakeSound = FakeSoundService();
    await _show(tester, soundsEnabled: false, soundService: fakeSound);

    await _pintarFigura(tester);

    expect(fakeSound.played, isEmpty);
  });
}
