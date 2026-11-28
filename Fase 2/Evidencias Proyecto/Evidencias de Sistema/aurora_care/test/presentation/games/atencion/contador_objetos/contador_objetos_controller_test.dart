import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/contador_objetos/contador_objetos_controller.dart';

/// Reloj falso: cada llamada avanza 700 ms.
DateTime Function() _relojFalso() {
  var t = DateTime(2026, 1, 1);
  return () {
    t = t.add(const Duration(milliseconds: 700));
    return t;
  };
}

ProviderContainer _container({int semilla = 5}) {
  return ProviderContainer(
    overrides: [
      contadorAutoPlayProvider.overrideWithValue(false),
      contadorRandomProvider.overrideWithValue(Random(semilla)),
      contadorClockProvider.overrideWithValue(_relojFalso()),
    ],
  );
}

void main() {
  test('rango de figuras por nivel: 3-5 / 5-8 / 7-10', () {
    expect(contadorNivel(GameLevel.facil).minimo, 3);
    expect(contadorNivel(GameLevel.facil).maximo, 5);
    expect(contadorNivel(GameLevel.intermedio).minimo, 5);
    expect(contadorNivel(GameLevel.intermedio).maximo, 8);
    expect(contadorNivel(GameLevel.avanzado).minimo, 7);
    expect(contadorNivel(GameLevel.avanzado).maximo, 10);
  });

  test('cada ronda respeta el rango, sin casillas repetidas y con 3 opciones',
      () {
    for (var semilla = 0; semilla < 30; semilla++) {
      for (final nivel in GameLevel.values) {
        final container = _container(semilla: semilla);
        final s = container.read(contadorObjetosControllerProvider(nivel));
        final rango = contadorNivel(nivel);

        expect(s.cantidad, inInclusiveRange(rango.minimo, rango.maximo));
        expect(s.casillas.length, s.cantidad);
        expect(s.casillas.toSet().length, s.cantidad);
        expect(s.opciones.length, contadorOpciones);
        expect(s.opciones, contains(s.cantidad));
        expect(s.opciones.toSet().length, contadorOpciones);
        expect(s.opciones.every((o) => o > 0), isTrue);
        expect(s.opciones, orderedEquals([...s.opciones]..sort()));
        container.dispose();
      }
    }
  });

  test('las fases avanzan: preparando → mostrando → respondiendo → retro', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = contadorObjetosControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    expect(container.read(provider).fase, ContadorFase.preparando);
    notifier.responder(3); // todavía no se puede responder
    expect(container.read(provider).respuesta, isNull);

    notifier.mostrar();
    expect(container.read(provider).fase, ContadorFase.mostrando);
    notifier.ocultar();
    expect(container.read(provider).fase, ContadorFase.respondiendo);
    notifier.responder(container.read(provider).cantidad);
    expect(container.read(provider).fase, ContadorFase.retro);
    expect(container.read(provider).acerto, isTrue);
  });

  test('responder mal suma una ronda mal y no cambia el alcance', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = contadorObjetosControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    notifier.mostrar();
    notifier.ocultar();
    final s = container.read(provider);
    final incorrecta = s.opciones.firstWhere((o) => o != s.cantidad);
    notifier.responder(incorrecta);

    expect(container.read(provider).acerto, isFalse);
    expect(container.read(provider).rondasMal, 1);
    expect(container.read(provider).alcance, 0);
  });

  test('al terminar las 6 rondas entrega las métricas de Atención', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = contadorObjetosControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    var mayorCorrecta = 0;
    for (var ronda = 1; ronda <= contadorRondasPorPartida; ronda++) {
      expect(container.read(provider).ronda, ronda);
      notifier.mostrar();
      notifier.ocultar();
      final s = container.read(provider);
      if (ronda == 1) {
        // Una ronda mal.
        notifier.responder(s.opciones.firstWhere((o) => o != s.cantidad));
      } else {
        notifier.responder(s.cantidad);
        mayorCorrecta = max(mayorCorrecta, s.cantidad);
      }
      notifier.continuar();
    }

    final state = container.read(provider);
    expect(state.fase, ContadorFase.terminado);
    final m = state.metrics!;
    expect(m.tasaErrorPct, closeTo(1 / 6 * 100, 0.001));
    expect(m.alcance, mayorCorrecta);
    expect(m.tiempoRespuestaMs, 700);
  });
}
