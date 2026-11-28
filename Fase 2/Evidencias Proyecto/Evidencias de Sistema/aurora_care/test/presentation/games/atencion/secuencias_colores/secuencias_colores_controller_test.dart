import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/atencion/secuencias_colores/secuencias_colores_controller.dart';

/// Reloj falso: cada llamada avanza 500 ms.
DateTime Function() _relojFalso() {
  var t = DateTime(2026, 1, 1);
  return () {
    t = t.add(const Duration(milliseconds: 500));
    return t;
  };
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      secuenciasAutoPlayProvider.overrideWithValue(false),
      secuenciasRandomProvider.overrideWithValue(Random(42)),
      secuenciasClockProvider.overrideWithValue(_relojFalso()),
    ],
  );
}

/// Muestra toda la secuencia a mano hasta llegar al turno de la persona.
void _mostrarTodo(SecuenciasColoresController notifier) {
  for (var i = 0; i < 100; i++) {
    notifier.avanzarEstimulo();
  }
}

void main() {
  test('longitud inicial por nivel: 3/5/7', () {
    expect(longitudInicialParaNivel(GameLevel.facil), 3);
    expect(longitudInicialParaNivel(GameLevel.intermedio), 5);
    expect(longitudInicialParaNivel(GameLevel.avanzado), 7);
  });

  test('velocidad por nivel: 1,5 s / 1,0 s / 0,7 s', () {
    expect(duracionEstimuloParaNivel(GameLevel.facil).inMilliseconds, 1500);
    expect(duracionEstimuloParaNivel(GameLevel.intermedio).inMilliseconds, 1000);
    expect(duracionEstimuloParaNivel(GameLevel.avanzado).inMilliseconds, 700);
  });

  test('la partida empieza mostrando una secuencia sin colores repetidos seguidos',
      () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);

    final state = container.read(provider);
    expect(state.fase, SecuenciaFase.mostrando);
    expect(state.ronda, 1);
    expect(state.longitud, 3);
    for (var i = 1; i < state.secuencia.length; i++) {
      expect(state.secuencia[i], isNot(state.secuencia[i - 1]));
    }
  });

  test('mientras se muestra la secuencia, tocar no hace nada', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);

    container.read(provider.notifier).tocarColor(0);
    expect(container.read(provider).toquesTotales, 0);
  });

  test('se encienden los colores en orden y luego es el turno', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);
    final secuencia = container.read(provider).secuencia;

    final encendidos = <int>[];
    for (var i = 0; i < 100; i++) {
      notifier.avanzarEstimulo();
      final s = container.read(provider);
      if (s.iluminado != null) encendidos.add(s.iluminado!);
      if (s.fase == SecuenciaFase.turno) break;
    }
    expect(encendidos, secuencia);
    expect(container.read(provider).fase, SecuenciaFase.turno);
  });

  test('repetir bien la secuencia da acierto y la siguiente tiene un color más',
      () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    _mostrarTodo(notifier);
    for (final color in container.read(provider).secuencia) {
      notifier.tocarColor(color);
    }

    var state = container.read(provider);
    expect(state.fase, SecuenciaFase.acierto);
    expect(state.alcance, 3);
    expect(state.toquesIncorrectos, 0);

    notifier.continuar();
    state = container.read(provider);
    expect(state.ronda, 2);
    expect(state.longitud, 4);
    expect(state.fase, SecuenciaFase.mostrando);
  });

  test('un toque incorrecto da error y la siguiente mantiene el largo', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    _mostrarTodo(notifier);
    final primero = container.read(provider).secuencia.first;
    notifier.tocarColor((primero + 1) % secuenciasCantidadColores);

    var state = container.read(provider);
    expect(state.fase, SecuenciaFase.error);
    expect(state.toquesIncorrectos, 1);
    expect(state.alcance, 0);

    notifier.continuar();
    state = container.read(provider);
    expect(state.ronda, 2);
    expect(state.longitud, 3);
  });

  test('al terminar las 5 rondas entrega las métricas de Atención', () {
    final container = _container();
    addTearDown(container.dispose);
    final provider = secuenciasColoresControllerProvider(GameLevel.facil);
    final notifier = container.read(provider.notifier);

    for (var ronda = 1; ronda <= secuenciasRondasPorPartida; ronda++) {
      _mostrarTodo(notifier);
      final secuencia = container.read(provider).secuencia;
      if (ronda == 2) {
        // Una ronda con error en el primer toque.
        notifier.tocarColor((secuencia.first + 1) % secuenciasCantidadColores);
      } else {
        for (final color in secuencia) {
          notifier.tocarColor(color);
        }
      }
      notifier.continuar();
    }

    final state = container.read(provider);
    expect(state.fase, SecuenciaFase.terminado);
    expect(state.isFinished, isTrue);

    // Largos: 3 (bien), 4 (error), 4 (bien), 5 (bien), 6 (bien).
    // Toques: 3 + 1 + 4 + 5 + 6 = 19, de los cuales 1 incorrecto.
    final m = state.metrics!;
    expect(m.alcance, 6);
    expect(m.tasaErrorPct, closeTo(1 / 19 * 100, 0.001));
    expect(m.tiempoRespuestaMs, 500);
  });
}
