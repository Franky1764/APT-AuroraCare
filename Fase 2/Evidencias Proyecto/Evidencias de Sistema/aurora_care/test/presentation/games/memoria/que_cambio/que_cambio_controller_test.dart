import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_controller.dart';

void main() {
  test('columnasParaNivel y diferenciasParaNivel: 3/4/5 en los 3 niveles', () {
    expect(columnasParaNivel(GameLevel.facil), 3);
    expect(columnasParaNivel(GameLevel.intermedio), 4);
    expect(columnasParaNivel(GameLevel.avanzado), 5);
    expect(diferenciasParaNivel(GameLevel.facil), 3);
    expect(diferenciasParaNivel(GameLevel.intermedio), 4);
    expect(diferenciasParaNivel(GameLevel.avanzado), 5);
  });

  test(
    'la grilla generada tiene N diferencias distintas entre sí, con el '
    'ícono modificado distinto al original en cada una, e igual al '
    'original en el resto',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.avanzado);
      final state = container.read(provider);

      expect(state.columnas, 5);
      expect(state.original.length, 15); // 5 columnas x 3 filas
      expect(state.modificada.length, 15);
      expect(state.diferenciaIndices.length, 5);

      for (final i in state.diferenciaIndices) {
        expect(state.modificada[i], isNot(state.original[i]));
      }
      for (var i = 0; i < state.original.length; i++) {
        if (!state.diferenciaIndices.contains(i)) {
          expect(state.modificada[i], state.original[i]);
        }
      }
    },
  );

  test('acertar una diferencia suma a encontradas e intentos', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = queCambioControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    final diferencia = container.read(provider).diferenciaIndices.first;
    notifier.tapCelda(diferencia);

    final state = container.read(provider);
    expect(state.encontradas, {diferencia});
    expect(state.intentos, 1);
    expect(state.ultimoResultado, QueCambioResultado.acierto);
    expect(state.marcadasIncorrectas, isEmpty);
  });

  test('tocar una celda que no es diferencia suma a marcadasIncorrectas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = queCambioControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    final state0 = container.read(provider);
    final noDiferencia = List.generate(
      state0.original.length,
      (i) => i,
    ).firstWhere((i) => !state0.diferenciaIndices.contains(i));
    notifier.tapCelda(noDiferencia);

    final state = container.read(provider);
    expect(state.marcadasIncorrectas, {noDiferencia});
    expect(state.intentos, 1);
    expect(state.ultimoResultado, QueCambioResultado.error);
    expect(state.encontradas, isEmpty);
  });

  test('un re-toque sobre una celda ya marcada no cuenta', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = queCambioControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    final diferencia = container.read(provider).diferenciaIndices.first;
    notifier.tapCelda(diferencia);
    final after1 = container.read(provider);

    notifier.tapCelda(diferencia); // re-toque sobre una ya encontrada
    expect(container.read(provider), same(after1));
  });

  test(
    'al encontrar todas las diferencias termina con metrics correctos '
    '(sin errores)',
    () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [queCambioClockProvider.overrideWithValue(() => fakeNow)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);

      final diferencias = container.read(provider).diferenciaIndices.toList();
      fakeNow = fakeNow.add(const Duration(seconds: 37));
      for (final i in diferencias) {
        notifier.tapCelda(i);
      }

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      final metrics = state.metrics!;
      expect(metrics.errores, 0);
      expect(metrics.intentos, 3);
      expect(metrics.tasaAciertoPct, 100.0);
      expect(metrics.tiempoSegundos, 37);

      // Ya terminó: no acepta más toques.
      final before = container.read(provider);
      notifier.tapCelda(0);
      expect(container.read(provider), same(before));
    },
  );

  test(
    'pausar() y reanudar() 30 s después: ese tiempo no cuenta en '
    'tiempoSegundos, y el estado de la partida no cambia',
    () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [queCambioClockProvider.overrideWithValue(() => fakeNow)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);

      final estadoAntes = container.read(provider);

      notifier.pausar();
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      notifier.reanudar();

      // Pausar/reanudar no tocan el state puntuable: mismo objeto.
      expect(container.read(provider), same(estadoAntes));

      final diferencias = container.read(provider).diferenciaIndices.toList();
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      for (final i in diferencias) {
        notifier.tapCelda(i);
      }

      final metrics = container.read(provider).metrics!;
      // Solo los 10 s jugados; los 30 s de pausa no cuentan.
      expect(metrics.tiempoSegundos, 10);
    },
  );

  test(
    'reanudar() sin haber pausado antes no hace nada (idempotente)',
    () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final container = ProviderContainer(
        overrides: [queCambioClockProvider.overrideWithValue(() => fakeNow)],
      );
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);

      notifier.reanudar();

      final diferencias = container.read(provider).diferenciaIndices.toList();
      fakeNow = fakeNow.add(const Duration(seconds: 5));
      for (final i in diferencias) {
        notifier.tapCelda(i);
      }
      expect(container.read(provider).metrics!.tiempoSegundos, 5);
    },
  );

  test(
    'declararTerminado cuenta lo que falte como omisión, sumado a las '
    'marcas incorrectas',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = queCambioControllerProvider(GameLevel.facil);
      final notifier = container.read(provider.notifier);

      final state0 = container.read(provider);
      final diferencias = state0.diferenciaIndices.toList();
      final noDiferencia = List.generate(
        state0.original.length,
        (i) => i,
      ).firstWhere((i) => !state0.diferenciaIndices.contains(i));

      // Encuentra 1 de las 3, marca 1 error, deja 2 sin encontrar.
      notifier.tapCelda(diferencias[0]);
      notifier.tapCelda(noDiferencia);
      notifier.declararTerminado();

      final state = container.read(provider);
      expect(state.isFinished, isTrue);
      final metrics = state.metrics!;
      // 2 omisiones + 1 marca incorrecta.
      expect(metrics.errores, 3);
      expect(metrics.intentos, 2);
      expect(metrics.tasaAciertoPct, closeTo(33.3, 0.1));
    },
  );
}
