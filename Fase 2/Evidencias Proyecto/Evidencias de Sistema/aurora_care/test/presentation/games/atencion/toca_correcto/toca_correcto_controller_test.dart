import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_controller.dart';
import 'package:aurora_care/presentation/games/atencion/toca_correcto/toca_correcto_figuras.dart';

/// Reloj falso: cada llamada avanza 600 ms.
DateTime Function() _relojFalso() {
  var t = DateTime(2026, 1, 1);
  return () {
    t = t.add(const Duration(milliseconds: 600));
    return t;
  };
}

ProviderContainer _container({int semilla = 3}) {
  return ProviderContainer(
    overrides: [
      tocaAutoPlayProvider.overrideWithValue(false),
      tocaRandomProvider.overrideWithValue(Random(semilla)),
      tocaClockProvider.overrideWithValue(_relojFalso()),
    ],
  );
}

void main() {
  test('las listas de formas y colores calzan con el controller', () {
    expect(tocaFormas.length, tocaCantidadFormas);
    expect(tocaColores.length, tocaCantidadColores);
  });

  test('nombres con género correcto', () {
    expect((forma: 0, color: 0).nombre, 'estrella amarilla');
    expect((forma: 0, color: 0).articulo, 'la');
    expect((forma: 1, color: 1).nombre, 'corazón rojo');
    expect((forma: 1, color: 1).articulo, 'el');
    expect((forma: 4, color: 0).nombreTitulo, 'Sol amarillo');
  });

  test('parámetros por nivel: 12/16/20 figuras y 2,5/1,8/1,2 s', () {
    expect(tocaNivel(GameLevel.facil).estimulos, 12);
    expect(tocaNivel(GameLevel.intermedio).estimulos, 16);
    expect(tocaNivel(GameLevel.avanzado).estimulos, 20);
    expect(tocaNivel(GameLevel.facil).tiempoVisible.inMilliseconds, 2500);
    expect(tocaNivel(GameLevel.intermedio).tiempoVisible.inMilliseconds, 1800);
    expect(tocaNivel(GameLevel.avanzado).tiempoVisible.inMilliseconds, 1200);
  });

  test('el objetivo cambia entre partidas', () {
    final objetivos = <TocaFiguraId>{};
    for (var semilla = 0; semilla < 20; semilla++) {
      final c = _container(semilla: semilla);
      objetivos.add(
        c.read(tocaCorrectoControllerProvider(GameLevel.facil)).objetivo,
      );
      c.dispose();
    }
    expect(objetivos.length, greaterThan(1));
  });

  test('40% objetivos; Fácil con figuras distintas y Avanzado parecidas', () {
    for (var semilla = 0; semilla < 20; semilla++) {
      final c = _container(semilla: semilla);

      final facil = c.read(tocaCorrectoControllerProvider(GameLevel.facil));
      expect(facil.figuras.where((f) => f == facil.objetivo).length, 5);
      for (final f in facil.figuras.where((f) => f != facil.objetivo)) {
        expect(f.forma, isNot(facil.objetivo.forma));
        expect(f.color, isNot(facil.objetivo.color));
      }

      final avanzado =
          c.read(tocaCorrectoControllerProvider(GameLevel.avanzado));
      expect(avanzado.figuras.where((f) => f == avanzado.objetivo).length, 8);
      for (final f in avanzado.figuras.where((f) => f != avanzado.objetivo)) {
        expect(tocaEsParecida(f, avanzado.objetivo), isTrue);
      }
      c.dispose();
    }
  });

  test('tocar antes de empezar no hace nada', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = tocaCorrectoControllerProvider(GameLevel.facil);

    container.read(provider.notifier).tocar();
    expect(container.read(provider).aciertos, 0);
    expect(container.read(provider).errores, 0);
  });

  test('tocar el objetivo es acierto; tocar otra figura es error', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = tocaCorrectoControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);
    notifier.empezar();

    var vioAcierto = false;
    var vioError = false;
    while (!container.read(provider).isFinished) {
      final s = container.read(provider);
      notifier.tocar();
      final r = container.read(provider).ultimoResultado;
      if (s.esObjetivo) {
        expect(r, TocaResultado.acierto);
        vioAcierto = true;
      } else {
        expect(r, TocaResultado.tocoDistractor);
        vioError = true;
      }
      notifier.continuar();
    }
    expect(vioAcierto && vioError, isTrue);
  });

  test('dejar pasar el objetivo es error; dejar pasar otra figura no', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = tocaCorrectoControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);
    notifier.empezar();

    while (!container.read(provider).isFinished) {
      final s = container.read(provider);
      notifier.expirar();
      expect(
        container.read(provider).ultimoResultado,
        s.esObjetivo ? TocaResultado.seLePaso : TocaResultado.dejoPasar,
      );
      notifier.continuar();
    }
    final m = container.read(provider).metrics!;
    expect(m.tasaErrorPct, 100);
    expect(m.alcance, 0);
  });

  test('partida perfecta: 0% error, alcance 5 y reacción de 600 ms', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = tocaCorrectoControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);
    notifier.empezar();

    while (!container.read(provider).isFinished) {
      if (container.read(provider).esObjetivo) {
        notifier.tocar();
      } else {
        notifier.expirar();
      }
      notifier.continuar();
    }

    final state = container.read(provider);
    expect(state.fase, TocaFase.terminado);
    final m = state.metrics!;
    expect(m.tasaErrorPct, 0);
    expect(m.alcance, 5);
    expect(m.tiempoRespuestaMs, 600);
  });
}
