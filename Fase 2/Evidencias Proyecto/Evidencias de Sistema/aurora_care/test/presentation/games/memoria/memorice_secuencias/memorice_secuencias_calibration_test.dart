import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_secuencias/memorice_secuencias_controller.dart';

/// Fija los valores de calibración de Memorice de secuencias (planilla de
/// Daniela): rondas mínimas/máximas, rango de errores y las constantes
/// de tiempo por nivel. Si un cambio futuro en el juego corre estos
/// valores, debe fallar un test acá, no descubrirse en el backend.
List<Override> _fastOverrides() => [
  memoriceSecuenciaHighlightDurationProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  memoriceSecuenciaPauseDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
  memoriceSecuenciaFeedbackDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
];

Future<void> _esperarFase(
  ProviderContainer container,
  ProviderListenable<MemoriceSecuenciaState> provider,
  MemoriceSecuenciaFase fase,
) async {
  for (var i = 0; i < 100; i++) {
    if (container.read(provider).fase == fase) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('No se alcanzó la fase $fase a tiempo');
}

void main() {
  test('rondas: mínimo 5 (para ganar), máximo 8 (jugadas)', () {
    expect(memoriceSecuenciaRondasCorrectasParaGanar, 5);
    expect(memoriceSecuenciaMaxRondasJugadas, 8);
  });

  test('longitud de secuencia por nivel: 3/4/5', () {
    expect(memoriceSecuenciaLongitudFacil, 3);
    expect(memoriceSecuenciaLongitudIntermedio, 4);
    expect(memoriceSecuenciaLongitudAvanzado, 5);
    expect(
      longitudSecuenciaParaNivel(GameLevel.facil),
      memoriceSecuenciaLongitudFacil,
    );
    expect(
      longitudSecuenciaParaNivel(GameLevel.intermedio),
      memoriceSecuenciaLongitudIntermedio,
    );
    expect(
      longitudSecuenciaParaNivel(GameLevel.avanzado),
      memoriceSecuenciaLongitudAvanzado,
    );
  });

  test(
    'constantes de tiempo por nivel (planilla de Daniela): exposición '
    '2,0/1,5/1,2 s, pausa 0,5 s (tras cada imagen), retroalimentación 1,8 s',
    () {
      expect(
        memoriceSecuenciaExposicionFacil,
        const Duration(milliseconds: 2000),
      );
      expect(
        memoriceSecuenciaExposicionIntermedio,
        const Duration(milliseconds: 1500),
      );
      expect(
        memoriceSecuenciaExposicionAvanzado,
        const Duration(milliseconds: 1200),
      );
      expect(
        memoriceSecuenciaPausaEntreImagenes,
        const Duration(milliseconds: 500),
      );
      expect(
        memoriceSecuenciaDuracionRetroalimentacion,
        const Duration(milliseconds: 1800),
      );
    },
  );

  test(
    'intentos mínimo: 5 rondas correctas seguidas terminan la partida en '
    'intentos=5, errores=0',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      for (var ronda = 0; ronda < 5; ronda++) {
        await _esperarFase(
          container,
          provider,
          MemoriceSecuenciaFase.esperandoRespuesta,
        );
        final secuencia = container.read(provider).secuencia;
        for (final i in secuencia) {
          notifier.tapImage(i);
        }
      }

      final metrics = container.read(provider).metrics!;
      expect(metrics, isA<MemoriaMetrics>());
      expect(metrics.intentos, 5);
      expect(metrics.errores, 0);
      expect(metrics.tasaAciertoPct, 100.0);
    },
  );

  test(
    'errores máximo: 8 rondas falladas seguidas terminan la partida en '
    'intentos=8, errores=8',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      for (var ronda = 0; ronda < 8; ronda++) {
        await _esperarFase(
          container,
          provider,
          MemoriceSecuenciaFase.esperandoRespuesta,
        );
        final secuencia = container.read(provider).secuencia;
        final incorrecto = List.generate(
          memoriceSecuenciaPoolSize,
          (i) => i,
        ).firstWhere((i) => i != secuencia[0]);
        notifier.tapImage(incorrecto);
      }

      final metrics = container.read(provider).metrics!;
      expect(metrics.intentos, 8);
      expect(metrics.errores, 8);
      expect(metrics.tasaAciertoPct, 0.0);
    },
  );
}
