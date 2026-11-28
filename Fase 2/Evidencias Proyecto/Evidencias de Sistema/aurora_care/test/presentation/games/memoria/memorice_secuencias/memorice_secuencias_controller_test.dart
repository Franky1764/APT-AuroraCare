import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/memorice_secuencias/memorice_secuencias_controller.dart';

/// Overrides comunes: temporizadores casi instantáneos para no esperar
/// tiempo real en los tests.
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

/// Espera (en tiempo real, corto) hasta que el estado alcance la fase
/// indicada. El provider es autoDispose: el llamador debe mantenerlo vivo
/// con container.listen(...) antes de usar esto.
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
  test('longitudSecuenciaParaNivel: 3/4/5 según Fácil/Intermedio/Avanzado', () {
    expect(longitudSecuenciaParaNivel(GameLevel.facil), 3);
    expect(longitudSecuenciaParaNivel(GameLevel.intermedio), 4);
    expect(longitudSecuenciaParaNivel(GameLevel.avanzado), 5);
  });

  test(
    'el estado inicial arranca mostrando una secuencia de largo correcto, '
    'sin índices repetidos',
    () {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      final state = container.read(provider);

      expect(state.fase, MemoriceSecuenciaFase.mostrando);
      expect(state.secuencia.length, 3);
      expect(state.secuencia.toSet().length, 3); // sin repetidos
      expect(state.secuencia.every((i) => i >= 0 && i < memoriceSecuenciaPoolSize), isTrue);
      expect(state.rondasJugadas, 0);
    },
  );

  test(
    'completar una ronda correctamente suma 1 a rondasJugadas y a '
    'rondasCorrectas, sin errores',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(container, provider, MemoriceSecuenciaFase.esperandoRespuesta);
      final secuencia = container.read(provider).secuencia;
      for (final i in secuencia) {
        notifier.tapImage(i);
      }

      final state = container.read(provider);
      expect(state.fase, MemoriceSecuenciaFase.retroalimentacion);
      expect(state.ultimaRondaCorrecta, isTrue);
      expect(state.rondasJugadas, 1);
      expect(state.rondasCorrectas, 1);
      expect(state.rondasConError, 0);
    },
  );

  test(
    'un toque incorrecto termina la ronda de inmediato y arma una '
    'secuencia nueva del mismo largo',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(container, provider, MemoriceSecuenciaFase.esperandoRespuesta);
      final secuencia = container.read(provider).secuencia;
      final incorrecto = List.generate(
        memoriceSecuenciaPoolSize,
        (i) => i,
      ).firstWhere((i) => i != secuencia[0]);

      notifier.tapImage(incorrecto);

      var state = container.read(provider);
      expect(state.fase, MemoriceSecuenciaFase.retroalimentacion);
      expect(state.ultimaRondaCorrecta, isFalse);
      expect(state.indiceTocadoIncorrecto, incorrecto);
      expect(state.rondasJugadas, 1);
      expect(state.rondasConError, 1);
      expect(state.rondasCorrectas, 0);

      // Debe armar una ronda nueva del mismo largo tras la retroalimentación.
      await _esperarFase(container, provider, MemoriceSecuenciaFase.mostrando);
      state = container.read(provider);
      expect(state.secuencia.length, 3);
      expect(state.rondasJugadas, 1); // la ronda nueva todavía no termina
    },
  );

  test(
    'termina tras 5 rondas correctas con errores=0, intentos=5, '
    'tasaAciertoPct=100 y tiempoSegundos correcto',
    () async {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          ..._fastOverrides(),
          memoriceSecuenciaClockProvider.overrideWithValue(() => fakeNow),
        ],
      );
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
        if (ronda == 4) {
          fakeNow = fakeNow.add(const Duration(seconds: 42));
        }
        final secuencia = container.read(provider).secuencia;
        for (final i in secuencia) {
          notifier.tapImage(i);
        }
      }

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      final metrics = state.metrics!;
      expect(metrics.errores, 0);
      expect(metrics.intentos, 5);
      expect(metrics.tasaAciertoPct, 100.0);
      expect(metrics.tiempoSegundos, 42);
    },
  );

  test(
    'termina tras 8 rondas jugadas aunque no se llegue a 5 correctas',
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
        final acertar = ronda.isOdd; // 4 correctas, 4 con error.
        if (acertar) {
          for (final i in secuencia) {
            notifier.tapImage(i);
          }
        } else {
          final incorrecto = List.generate(
            memoriceSecuenciaPoolSize,
            (i) => i,
          ).firstWhere((i) => i != secuencia[0]);
          notifier.tapImage(incorrecto);
        }
      }

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      expect(state.metrics!.intentos, 8);
      expect(state.metrics!.errores, 4);
      expect(state.rondasCorrectas, 4);
    },
  );

  test(
    'reanudar() reinicia la secuencia desde el paso 0 (no sigue donde '
    'quedó al pausar)',
    () async {
      final container = ProviderContainer(
        overrides: [
          memoriceSecuenciaHighlightDurationProvider.overrideWith(
            (ref, nivel) => const Duration(milliseconds: 20),
          ),
          memoriceSecuenciaPauseDurationProvider.overrideWithValue(
            const Duration(milliseconds: 2),
          ),
          memoriceSecuenciaFeedbackDurationProvider.overrideWithValue(
            const Duration(milliseconds: 2),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      // Deja avanzar hasta el paso 1 antes de pausar.
      for (var i = 0; i < 200; i++) {
        if (container.read(provider).pasoResaltado == 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(container.read(provider).pasoResaltado, 1);

      notifier.pausar();
      final pasoAlPausar = container.read(provider).pasoResaltado;

      // Sin pausa, en 100 ms ya se habría completado toda la secuencia.
      // Pausado, nada debe avanzar: ni el paso ni la fase.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(provider).pasoResaltado, pasoAlPausar);
      expect(container.read(provider).fase, MemoriceSecuenciaFase.mostrando);

      notifier.reanudar();
      // Se reinicia desde el principio, no desde el paso 1.
      expect(container.read(provider).pasoResaltado, 0);

      await _esperarFase(
        container,
        provider,
        MemoriceSecuenciaFase.esperandoRespuesta,
      );
    },
  );

  test(
    'pausar()/reanudar() durante "esperandoRespuesta" no cambian nada '
    '(no había Timer corriendo) y el juego sigue funcionando normal',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(
        container,
        provider,
        MemoriceSecuenciaFase.esperandoRespuesta,
      );
      final estadoAntes = container.read(provider);

      notifier.pausar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(provider), same(estadoAntes));

      notifier.reanudar();
      expect(container.read(provider), same(estadoAntes));

      final secuencia = container.read(provider).secuencia;
      notifier.tapImage(secuencia[0]);
      expect(container.read(provider).progresoRespuesta, 1);
    },
  );

  test(
    'pausar() + 30 s de reloj falso + reanudar(): ese tiempo no cuenta '
    'en tiempoSegundos',
    () async {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [
          ..._fastOverrides(),
          memoriceSecuenciaClockProvider.overrideWithValue(() => fakeNow),
        ],
      );
      addTearDown(container.dispose);

      final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      notifier.pausar();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      notifier.reanudar();

      for (var ronda = 0; ronda < 5; ronda++) {
        await _esperarFase(
          container,
          provider,
          MemoriceSecuenciaFase.esperandoRespuesta,
        );
        if (ronda == 4) {
          fakeNow = fakeNow.add(const Duration(seconds: 8));
        }
        final secuencia = container.read(provider).secuencia;
        for (final i in secuencia) {
          notifier.tapImage(i);
        }
      }

      final metrics = container.read(provider).metrics!;
      // Solo los 8 s jugados; los 30 s de pausa no cuentan.
      expect(metrics.tiempoSegundos, 8);
    },
  );

  test('tocar una imagen fuera de turno no hace nada', () {
    final container = ProviderContainer(overrides: _fastOverrides());
    addTearDown(container.dispose);

    final provider = memoriceSecuenciasControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    final before = container.read(provider);
    expect(before.fase, MemoriceSecuenciaFase.mostrando);

    notifier.tapImage(0);
    expect(container.read(provider), same(before));
  });
}
