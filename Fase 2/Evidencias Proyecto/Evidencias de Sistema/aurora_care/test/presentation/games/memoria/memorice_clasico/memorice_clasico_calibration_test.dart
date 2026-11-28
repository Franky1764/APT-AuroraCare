import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_controller.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_clasico/memorice_clasico_definition.dart';

/// Timer falso para la vista previa: en vez de esperar la duración real,
/// guarda el callback y lo deja disparar a mano con [endPreview].
class _FakePreviewTimer implements Timer {
  bool _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

class _FakePreviewTimerFactory {
  void Function()? _callback;

  Timer call(Duration duration, void Function() callback) {
    _callback = callback;
    return _FakePreviewTimer();
  }

  void endPreview() => _callback!();
}

/// Encuentra el primer par (i, j) con faceIndex igual que todavía no esté
/// emparejado.
(int, int) _findPair(MemoriceClasicoState state) {
  for (var i = 0; i < state.cards.length; i++) {
    if (state.cards[i].isMatched) continue;
    for (var j = i + 1; j < state.cards.length; j++) {
      if (state.cards[j].isMatched) continue;
      if (state.cards[i].faceIndex == state.cards[j].faceIndex) return (i, j);
    }
  }
  throw StateError('No quedan pares sin emparejar');
}

/// Test de regresión: Memorice clásico está "Calibrado" (SCORING §2.2) y
/// no se tocó en esta tarea. Confirma que sigue emitiendo
/// errores/intentos/tiempoSegundos/tasaAciertoPct (las mismas 4 claves
/// que los 3 juegos "por calibrar") y que pares/maxDuration por nivel no
/// cambiaron.
void main() {
  test(
    'paresParaNivel y maxDuration no cambiaron: 6/8/10 pares, '
    '240/300/360 s',
    () {
      expect(paresParaNivel(GameLevel.facil), 6);
      expect(paresParaNivel(GameLevel.intermedio), 8);
      expect(paresParaNivel(GameLevel.avanzado), 10);
      expect(
        memoriceClasicoDefinition.maxDuration(GameLevel.facil),
        const Duration(seconds: 240),
      );
      expect(
        memoriceClasicoDefinition.maxDuration(GameLevel.intermedio),
        const Duration(seconds: 300),
      );
      expect(
        memoriceClasicoDefinition.maxDuration(GameLevel.avanzado),
        const Duration(seconds: 360),
      );
    },
  );

  for (final nivel in GameLevel.values) {
    test(
      '${nivel.label}: una partida perfecta emite MemoriaMetrics con '
      'errores=0, intentos=2×pares y tasaAciertoPct=100',
      () async {
        final fakePreview = _FakePreviewTimerFactory();
        var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
        final container = ProviderContainer(
          overrides: [
            memoricePreviewTimerFactoryProvider.overrideWithValue(
              fakePreview.call,
            ),
            memoriceClockProvider.overrideWithValue(() => fakeNow),
          ],
        );
        addTearDown(container.dispose);

        final provider = memoriceClasicoControllerProvider(nivel);
        container.listen(provider, (_, _) {});
        final notifier = container.read(provider.notifier);
        fakePreview.endPreview();

        final pares = paresParaNivel(nivel);
        fakeNow = fakeNow.add(const Duration(seconds: 7));
        for (var p = 0; p < pares; p++) {
          final state = container.read(provider);
          if (state.isFinished) break;
          final (i, j) = _findPair(state);
          notifier.flipCard(i);
          notifier.flipCard(j);
        }

        final metrics = container.read(provider).metrics!;
        expect(metrics, isA<MemoriaMetrics>());
        expect(metrics.errores, 0);
        expect(metrics.intentos, pares * 2);
        expect(metrics.tiempoSegundos, 7);
        expect(metrics.tasaAciertoPct, 100.0);
      },
    );
  }
}
