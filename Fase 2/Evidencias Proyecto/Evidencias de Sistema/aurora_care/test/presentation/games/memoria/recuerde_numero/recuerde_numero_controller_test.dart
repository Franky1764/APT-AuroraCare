import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/recuerde_numero/recuerde_numero_controller.dart';

List<Override> _fastOverrides() => [
  recuerdeNumeroTiempoVisualizacionProvider.overrideWith(
    (ref, nivel) => const Duration(milliseconds: 2),
  ),
  recuerdeNumeroFeedbackDurationProvider.overrideWithValue(
    const Duration(milliseconds: 2),
  ),
];

/// Espera a que el controller pase por [fase]. Se suscribe con
/// `container.listen` en vez de sondear cada N ms: con duraciones de
/// prueba muy cortas, una fase intermedia (ej. "mostrando" entre dos
/// temporizadores de pocos milisegundos) puede durar menos que el
/// intervalo de sondeo y "desaparecer" antes de que se la alcance a leer
/// — eso hacía el test inestable. Al escuchar cada cambio de estado, no
/// se puede perder ninguna fase por breve que sea.
Future<void> _esperarFase(
  ProviderContainer container,
  ProviderListenable<RecuerdeNumeroState> provider,
  RecuerdeNumeroFase fase,
) async {
  if (container.read(provider).fase == fase) return;
  final completer = Completer<void>();
  final sub = container.listen(provider, (_, next) {
    if (next.fase == fase && !completer.isCompleted) {
      completer.complete();
    }
  });
  try {
    await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail('No se alcanzó la fase $fase a tiempo'),
    );
  } finally {
    sub.close();
  }
}

void main() {
  test('digitosParaNivel: 3/4/5 según Fácil/Intermedio/Avanzado', () {
    expect(digitosParaNivel(GameLevel.facil), 3);
    expect(digitosParaNivel(GameLevel.intermedio), 4);
    expect(digitosParaNivel(GameLevel.avanzado), 5);
  });

  test('esNumeroTrivial detecta dígitos iguales y secuencias consecutivas', () {
    expect(esNumeroTrivial('111'), isTrue);
    expect(esNumeroTrivial('2222'), isTrue);
    expect(esNumeroTrivial('123'), isTrue);
    expect(esNumeroTrivial('4321'), isTrue);
    expect(esNumeroTrivial('12345'), isTrue);
    expect(esNumeroTrivial('472'), isFalse);
    expect(esNumeroTrivial('190'), isFalse);
    expect(esNumeroTrivial('1021'), isFalse);
  });

  test(
    'el número generado no empieza en 0 y nunca es trivial (se prueba '
    'muchas veces para cubrir el azar real)',
    () {
      for (var i = 0; i < 50; i++) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        for (final nivel in GameLevel.values) {
          final provider = recuerdeNumeroControllerProvider(nivel);
          final state = container.read(provider);
          expect(state.numero.length, digitosParaNivel(nivel));
          expect(state.numero.startsWith('0'), isFalse);
          expect(esNumeroTrivial(state.numero), isFalse);
        }
      }
    },
  );

  test(
    'tocarDigito agrega dígitos a la respuesta y borrar quita el último',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );

      notifier.tocarDigito(4);
      notifier.tocarDigito(7);
      expect(container.read(provider).respuesta, '47');

      notifier.borrar();
      expect(container.read(provider).respuesta, '4');

      notifier.tocarDigito(7);
      notifier.tocarDigito(2);
      // Ya hay 3 dígitos (nivel Fácil): un 4to toque se ignora.
      notifier.tocarDigito(9);
      expect(container.read(provider).respuesta, '472');
    },
  );

  test(
    'confirmar con la respuesta correcta suma a rondasCorrectas, sin '
    'errores',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );
      final numero = container.read(provider).numero;
      for (final c in numero.split('')) {
        notifier.tocarDigito(int.parse(c));
      }
      notifier.confirmar();

      final state = container.read(provider);
      expect(state.fase, RecuerdeNumeroFase.retroalimentacion);
      expect(state.ultimaRondaCorrecta, isTrue);
      expect(state.rondasJugadas, 1);
      expect(state.rondasCorrectas, 1);
      expect(state.rondasConError, 0);
    },
  );

  test(
    'confirmar con una respuesta incorrecta suma a rondasConError y '
    'arma una ronda nueva',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );
      final numeroCorrecto = container.read(provider).numero;
      // Construye una respuesta distinta cambiando el primer dígito.
      final primerDigito = int.parse(numeroCorrecto[0]);
      final otroDigito = (primerDigito + 1) % 10 == 0 ? 1 : (primerDigito + 1) % 10;
      notifier.tocarDigito(otroDigito);
      for (var i = 1; i < numeroCorrecto.length; i++) {
        notifier.tocarDigito(int.parse(numeroCorrecto[i]));
      }
      notifier.confirmar();

      var state = container.read(provider);
      expect(state.fase, RecuerdeNumeroFase.retroalimentacion);
      expect(state.ultimaRondaCorrecta, isFalse);
      expect(state.rondasJugadas, 1);
      expect(state.rondasConError, 1);
      expect(state.rondasCorrectas, 0);

      await _esperarFase(container, provider, RecuerdeNumeroFase.mostrando);
      state = container.read(provider);
      expect(state.respuesta, isEmpty);
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
          recuerdeNumeroClockProvider.overrideWithValue(() => fakeNow),
        ],
      );
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
        if (ronda == 4) {
          fakeNow = fakeNow.add(const Duration(seconds: 50));
        }
        final numero = container.read(provider).numero;
        for (final c in numero.split('')) {
          notifier.tocarDigito(int.parse(c));
        }
        notifier.confirmar();
      }

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      final metrics = state.metrics!;
      expect(metrics.errores, 0);
      expect(metrics.intentos, 5);
      expect(metrics.tasaAciertoPct, 100.0);
      expect(metrics.tiempoSegundos, 50);
    },
  );

  test(
    'termina tras 8 rondas jugadas aunque no se llegue a 5 correctas',
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
        final numeroCorrecto = container.read(provider).numero;
        final acertar = ronda.isOdd; // 4 correctas, 4 con error.
        if (acertar) {
          for (final c in numeroCorrecto.split('')) {
            notifier.tocarDigito(int.parse(c));
          }
        } else {
          final primerDigito = int.parse(numeroCorrecto[0]);
          final otroDigito = (primerDigito + 1) % 10 == 0
              ? 1
              : (primerDigito + 1) % 10;
          notifier.tocarDigito(otroDigito);
          for (var i = 1; i < numeroCorrecto.length; i++) {
            notifier.tocarDigito(int.parse(numeroCorrecto[i]));
          }
        }
        notifier.confirmar();
      }

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      expect(state.metrics!.intentos, 8);
      expect(state.metrics!.errores, 4);
      expect(state.rondasCorrectas, 4);
    },
  );

  test(
    'reanudar() reinicia el tiempo de visualización completo del '
    'número (no sigue donde quedó al pausar)',
    () async {
      final container = ProviderContainer(
        overrides: [
          recuerdeNumeroTiempoVisualizacionProvider.overrideWith(
            (ref, nivel) => const Duration(milliseconds: 40),
          ),
          recuerdeNumeroFeedbackDurationProvider.overrideWithValue(
            const Duration(milliseconds: 2),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      expect(container.read(provider).fase, RecuerdeNumeroFase.mostrando);
      notifier.pausar();

      // Sin pausa, en 100 ms ya se habría ocultado el número (40 ms de
      // visualización). Pausado, debe seguir mostrando.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(provider).fase, RecuerdeNumeroFase.mostrando);

      notifier.reanudar();
      // El tiempo de visualización se reinicia completo: 10 ms después
      // de reanudar (muy por debajo de los 40 ms) todavía debe seguir
      // mostrando, no ocultarse de inmediato con lo que quedaba.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(provider).fase, RecuerdeNumeroFase.mostrando);

      await _esperarFase(
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );
    },
  );

  test(
    'pausar()/reanudar() durante "esperandoRespuesta" no cambian nada '
    '(no había Timer corriendo) y el juego sigue funcionando normal',
    () async {
      final container = ProviderContainer(overrides: _fastOverrides());
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      await _esperarFase(
        container,
        provider,
        RecuerdeNumeroFase.esperandoRespuesta,
      );
      final estadoAntes = container.read(provider);

      notifier.pausar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(provider), same(estadoAntes));

      notifier.reanudar();
      expect(container.read(provider), same(estadoAntes));

      notifier.tocarDigito(5);
      expect(container.read(provider).respuesta, '5');
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
          recuerdeNumeroClockProvider.overrideWithValue(() => fakeNow),
        ],
      );
      addTearDown(container.dispose);
      final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
      container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);

      notifier.pausar();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      notifier.reanudar();

      for (var ronda = 0; ronda < 5; ronda++) {
        await _esperarFase(
          container,
          provider,
          RecuerdeNumeroFase.esperandoRespuesta,
        );
        if (ronda == 4) {
          fakeNow = fakeNow.add(const Duration(seconds: 9));
        }
        final numero = container.read(provider).numero;
        for (final c in numero.split('')) {
          notifier.tocarDigito(int.parse(c));
        }
        notifier.confirmar();
      }

      final metrics = container.read(provider).metrics!;
      // Solo los 9 s jugados; los 30 s de pausa no cuentan.
      expect(metrics.tiempoSegundos, 9);
    },
  );

  test('tocar un dígito fuera de turno no hace nada', () {
    final container = ProviderContainer(overrides: _fastOverrides());
    addTearDown(container.dispose);
    final provider = recuerdeNumeroControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    final before = container.read(provider);
    expect(before.fase, RecuerdeNumeroFase.mostrando);

    notifier.tocarDigito(5);
    expect(container.read(provider), same(before));
  });
}
