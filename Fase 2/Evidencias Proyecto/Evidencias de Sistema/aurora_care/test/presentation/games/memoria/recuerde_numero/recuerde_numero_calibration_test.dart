import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_controller.dart';

/// Fija los valores de calibración de Recuerde el número (planilla de
/// Daniela): rondas mínimas/máximas, rango de errores y las constantes
/// de tiempo por nivel.
List<Override> _fastOverrides() => [
  recuerdeNumeroTiempoVisualizacionProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  recuerdeNumeroFeedbackDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
];

Future<void> _esperarFase(
  ProviderContainer container,
  ProviderListenable<RecuerdeNumeroState> provider,
  RecuerdeNumeroFase fase,
) async {
  for (var i = 0; i < 100; i++) {
    if (container.read(provider).fase == fase) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('No se alcanzó la fase $fase a tiempo');
}

void _escribir(RecuerdeNumeroController notifier, String numero) {
  for (final digito in numero.split('')) {
    notifier.tocarDigito(int.parse(digito));
  }
}

void main() {
  test('rondas: mínimo 5 (para ganar), máximo 8 (jugadas)', () {
    expect(recuerdeNumeroRondasCorrectasParaGanar, 5);
    expect(recuerdeNumeroMaxRondasJugadas, 8);
  });

  test('dígitos por nivel: 3/4/5', () {
    expect(recuerdeNumeroDigitosFacil, 3);
    expect(recuerdeNumeroDigitosIntermedio, 4);
    expect(recuerdeNumeroDigitosAvanzado, 5);
    expect(digitosParaNivel(GameLevel.facil), recuerdeNumeroDigitosFacil);
    expect(
      digitosParaNivel(GameLevel.intermedio),
      recuerdeNumeroDigitosIntermedio,
    );
    expect(
      digitosParaNivel(GameLevel.avanzado),
      recuerdeNumeroDigitosAvanzado,
    );
  });

  test(
    'constantes de tiempo por nivel (planilla de Daniela): visualización '
    '3/4/5 s, retroalimentación 1,8 s',
    () {
      expect(
        recuerdeNumeroVisualizacionFacil,
        const Duration(milliseconds: 3000),
      );
      expect(
        recuerdeNumeroVisualizacionIntermedio,
        const Duration(milliseconds: 4000),
      );
      expect(
        recuerdeNumeroVisualizacionAvanzado,
        const Duration(milliseconds: 5000),
      );
      expect(
        recuerdeNumeroDuracionRetroalimentacion,
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
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      for (var ronda = 0; ronda < 5; ronda++) {
        await _esperarFase(
          container,
          provider,
          RecuerdeNumeroFase.esperandoRespuesta,
        );
        final numero = container.read(provider).numero;
        _escribir(notifier, numero);
        notifier.confirmar();
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
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      for (var ronda = 0; ronda < 8; ronda++) {
        await _esperarFase(
          container,
          provider,
          RecuerdeNumeroFase.esperandoRespuesta,
        );
        final digitos = container.read(provider).digitos;
        // El número real nunca empieza en 0 (_generarNumero), así que
        // "000...0" siempre es una respuesta incorrecta.
        _escribir(notifier, '0' * digitos);
        notifier.confirmar();
      }

      final metrics = container.read(provider).metrics!;
      expect(metrics.intentos, 8);
      expect(metrics.errores, 8);
      expect(metrics.tasaAciertoPct, 0.0);
    },
  );
}
