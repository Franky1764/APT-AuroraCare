import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_config.dart';
import 'package:aurora_care/presentation/games/praxias/conecta_puntos/conecta_puntos_logic.dart';

final _t0 = DateTime(2026, 1, 1, 10);
const _area = Rect.fromLTWH(0, 0, 264, 264);

ConectaEvaluator _eval(ConectaFigure f, {double tol = 15}) => ConectaEvaluator(
  points: scalePoints(f.puntosUnitarios, _area),
  tolerancePx: tol,
  hitRadiusPx: conectaHitRadiusPx,
);

/// Arrastra el dedo en línea recta de [a] a [b] en pasos de 5 px.
void _drag(ConectaEvaluator e, Offset a, Offset b, DateTime now) {
  final steps = ((b - a).distance / 5).ceil();
  for (var k = 1; k <= steps; k++) {
    e.pointerMove(a + (b - a) * (k / steps), now);
  }
}

/// Une todos los puntos en orden, exacto.
void _unirTodo(ConectaEvaluator e, {int hasta = -1}) {
  final pts = e.points;
  final fin = hasta < 0 ? pts.length : hasta;
  e.pointerDown(pts.first, _t0);
  for (var i = 1; i < fin; i++) {
    _drag(e, pts[i - 1], pts[i], _t0.add(Duration(seconds: i * 2)));
  }
}

void main() {
  group('configuración por nivel', () {
    test('los objetivos de 48 dp no se solapan en el tablero de una pantalla de 320 dp', () {
      for (final figure in ConectaFigure.values) {
        final points = scalePoints(
          figure.puntosUnitarios,
          const Rect.fromLTWH(26, 26, 228, 228),
        );
        for (var i = 0; i < points.length; i++) {
          for (var j = i + 1; j < points.length; j++) {
            expect(
              (points[i] - points[j]).distance,
              greaterThanOrEqualTo(48),
              reason: figure.name,
            );
          }
        }
      }
    });

    test('hay 10 figuras y cada nivel toma una ventana de 5', () {
      expect(ConectaFigure.values.length, 10);
      for (final nivel in GameLevel.values) {
        expect(figurasDelNivel(nivel).length, 5);
      }
      expect(figurasDelNivel(GameLevel.facil).first, ConectaFigure.pentagono);
      expect(
        figurasDelNivel(GameLevel.avanzado).last,
        ConectaFigure.estrellaSeisPuntas,
      );
    });

    test('la complejidad (puntos) sube con el nivel', () {
      double promedio(GameLevel n) =>
          figurasDelNivel(n)
              .map((f) => f.puntosUnitarios.length)
              .reduce((a, b) => a + b) /
          5;
      expect(
        promedio(GameLevel.facil),
        lessThan(promedio(GameLevel.intermedio)),
      );
      expect(
        promedio(GameLevel.intermedio),
        lessThan(promedio(GameLevel.avanzado)),
      );
    });

    test('toda figura tiene nombre y nombre con artículo', () {
      for (final f in ConectaFigure.values) {
        expect(f.nombre, isNotEmpty);
        expect(
          f.nombreConArticulo,
          matches(RegExp(r'^(el|la) ')),
          reason: f.name,
        );
        expect(f.nombreConArticulo, endsWith(f.nombre), reason: f.name);
      }
    });

    test('tolerancia de 15, 10 y 7 px, igual que Trazado guiado', () {
      expect(toleranciaConectaPx(GameLevel.facil), 15);
      expect(toleranciaConectaPx(GameLevel.intermedio), 10);
      expect(toleranciaConectaPx(GameLevel.avanzado), 7);
    });

    test('los puntos caben en 0..1 y no se solapan en un área de 240 px', () {
      for (final f in ConectaFigure.values) {
        final pts = scalePoints(
          f.puntosUnitarios,
          const Rect.fromLTWH(0, 0, 240, 240),
        );
        for (final p in f.puntosUnitarios) {
          expect(p.dx, inInclusiveRange(0, 1), reason: f.name);
          expect(p.dy, inInclusiveRange(0, 1), reason: f.name);
        }
        for (var i = 0; i < pts.length; i++) {
          for (var j = i + 1; j < pts.length; j++) {
            expect(
              (pts[i] - pts[j]).distance,
              greaterThan(2 * conectaHitRadiusPx),
              reason: '${f.name}: puntos ${i + 1} y ${j + 1}',
            );
          }
        }
      }
    });

    test('ningún punto queda dentro del radio de un tramo que no es suyo', () {
      const area = Rect.fromLTWH(0, 0, 240, 240);
      for (final f in ConectaFigure.values) {
        final pts = scalePoints(f.puntosUnitarios, area);
        for (var i = 0; i < pts.length; i++) {
          final a = pts[i];
          final b = pts[(i + 1) % pts.length];
          for (var j = 0; j < pts.length; j++) {
            if (j == i || j == (i + 1) % pts.length) continue;
            expect(
              distanceToSegment(pts[j], a, b),
              greaterThan(conectaHitRadiusPx),
              reason: '${f.name}: tramo ${i + 1} pasa por el punto ${j + 1}',
            );
          }
        }
      }
    });
  });

  group('sorteo de figuras de la sesión', () {
    test('siempre 3 figuras distintas, del pool del nivel', () {
      final random = math.Random(1);
      for (final nivel in GameLevel.values) {
        final pool = figurasDelNivel(nivel);
        for (var i = 0; i < 50; i++) {
          final s = elegirFigurasSesion(nivel, random);
          expect(s.length, figurasPorSesion);
          expect(s.toSet().length, figurasPorSesion);
          expect(s.every(pool.contains), isTrue);
        }
      }
    });

    test('con el tiempo salen todas las figuras del nivel', () {
      final random = math.Random(2);
      for (final nivel in GameLevel.values) {
        final vistas = <ConectaFigure>{};
        for (var i = 0; i < 100; i++) {
          vistas.addAll(elegirFigurasSesion(nivel, random));
        }
        expect(vistas, figurasDelNivel(nivel).toSet());
      }
    });

    test('es reproducible con la misma semilla', () {
      expect(
        elegirFigurasSesion(GameLevel.facil, math.Random(7)),
        elegirFigurasSesion(GameLevel.facil, math.Random(7)),
      );
    });

    test(
      'no repite la secuencia ni la figura inicial de la sesión anterior',
      () {
        final random = math.Random(3);
        for (final nivel in GameLevel.values) {
          var anterior = elegirFigurasSesion(nivel, random);
          for (var i = 0; i < 200; i++) {
            final s = elegirFigurasSesion(nivel, random, anterior: anterior);
            expect(s.first, isNot(anterior.first));
            expect(s, isNot(anterior));
            anterior = s;
          }
        }
      },
    );
  });

  group('tiempo normalizado', () {
    test('puntos de referencia: 20, 25 y 31', () {
      expect(puntosReferencia(GameLevel.facil), 20);
      expect(puntosReferencia(GameLevel.intermedio), 25);
      expect(puntosReferencia(GameLevel.avanzado), 31);
    });

    test(
      'una sesión con más puntos que la referencia se reescala hacia abajo',
      () {
        // 24 puntos en 120 s equivale a 100 s en una sesión de 20 puntos.
        expect(tiempoNormalizadoSeg(120000, 24, GameLevel.facil), 100);
      },
    );

    test('una sesión con la cantidad de referencia no cambia', () {
      expect(tiempoNormalizadoSeg(90000, 20, GameLevel.facil), 90);
    });

    test('sin puntos devuelve 0', () {
      expect(tiempoNormalizadoSeg(5000, 0, GameLevel.facil), 0);
    });
  });

  group('distanceToSegment', () {
    test('perpendicular, extremos y segmento degenerado', () {
      const a = Offset(0, 0);
      const b = Offset(10, 0);
      expect(distanceToSegment(const Offset(5, 3), a, b), closeTo(3, 1e-9));
      expect(distanceToSegment(const Offset(-4, 3), a, b), closeTo(5, 1e-9));
      expect(distanceToSegment(const Offset(13, 4), a, b), closeTo(5, 1e-9));
      expect(distanceToSegment(const Offset(3, 4), a, a), closeTo(5, 1e-9));
    });
  });

  group('ConectaEvaluator', () {
    test('los eventos estacionarios no cambian la precisión por distancia', () {
      final evaluator = _eval(ConectaFigure.hexagono);
      final start = evaluator.points.first;
      final outside =
          Offset.lerp(start, evaluator.points[1], .5)! + const Offset(0, -60);
      evaluator.pointerDown(start, _t0);
      evaluator.pointerMove(outside, _t0);
      final precision = evaluator.precisionPct;
      final distance = evaluator.totalDistance;
      for (var i = 0; i < 100; i++) {
        evaluator.pointerMove(outside, _t0.add(Duration(milliseconds: i)));
      }
      expect(evaluator.totalDistance, distance);
      expect(evaluator.precisionPct, precision);
    });

    test('unir todo en orden: completa, 100% y sin fuera de orden', () {
      for (final f in ConectaFigure.values) {
        final e = _eval(f);
        _unirTodo(e);

        expect(e.completed, isTrue, reason: f.name);
        expect(e.precisionPct, 100, reason: f.name);
        expect(e.correcciones, 0, reason: f.name);
        expect(e.alcanzados, e.totalPuntos);
        expect(e.tiempoMs, (e.totalPuntos - 1) * 2000);
      }
    });

    test('tocar lejos del punto 1 no empieza el juego', () {
      final e = _eval(ConectaFigure.hexagono);
      e.pointerDown(const Offset(130, 130), _t0);
      _drag(e, const Offset(130, 130), e.points[1], _t0);

      expect(e.alcanzados, 0);
      expect(e.puntosTotales, 0);
      expect(e.strokes, isEmpty);
    });

    test('pasar por un punto que no toca cuenta una vez, aunque se quede', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      // Va directo al punto 3 (índice 2) en vez del 2.
      _drag(e, p[0], p[2], _t0);
      // Se queda moviéndose dentro del punto 3.
      e.pointerMove(p[2] + const Offset(3, 0), _t0);
      e.pointerMove(p[2] + const Offset(-3, 2), _t0);

      expect(e.correcciones, 1);
      expect(e.alcanzados, 1);
    });

    test('salir y volver a entrar al punto equivocado suma otra', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      _drag(e, p[0], p[2], _t0);
      _drag(e, p[2], p[2] + const Offset(0, -60), _t0);
      _drag(e, p[2] + const Offset(0, -60), p[2], _t0);

      expect(e.correcciones, 2);
    });

    test('un punto ya unido no cuenta como fuera de orden', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      _drag(e, p[0], p[1], _t0);
      // Vuelve al punto 1 (ya unido) y sigue.
      _drag(e, p[1], p[0], _t0);
      _drag(e, p[0], p[1], _t0);

      expect(e.correcciones, 0);
    });

    test('levantar el dedo no es corrección y se retoma desde el último', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      _drag(e, p[0], p[1], _t0);
      _drag(e, p[1], p[2], _t0);
      e.pointerUp();
      expect(e.correcciones, 0);
      expect(e.alcanzados, 3);

      // Tocar lejos no retoma.
      e.pointerDown(const Offset(130, 130), _t0);
      expect(e.strokes.length, 1);

      // Tocar el último punto alcanzado sí.
      e.pointerDown(p[2], _t0.add(const Duration(seconds: 5)));
      _drag(e, p[2], p[3], _t0.add(const Duration(seconds: 6)));
      _drag(e, p[3], p[4], _t0.add(const Duration(seconds: 7)));
      _drag(e, p[4], p[5], _t0.add(const Duration(seconds: 8)));

      expect(e.completed, isTrue);
      expect(e.correcciones, 0);
      expect(e.strokes.length, 2);
      expect(e.tiempoMs, 8000);
    });

    test('un trazo que se aleja del tramo baja la precisión', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      // Da un rodeo lejos de la línea p0-p1 y recién entonces llega a p1.
      final mid = (p[0] + p[1]) / 2 + const Offset(0, -45);
      _drag(e, p[0], mid, _t0);
      _drag(e, mid, p[1], _t0);

      expect(e.alcanzados, 2);
      expect(e.precisionPct, lessThan(100));
      expect(e.precisionPct, greaterThan(0));
    });

    test('un movimiento rápido (salto grande) también avanza', () {
      final e = _eval(ConectaFigure.hexagono);
      final p = e.points;
      e.pointerDown(p[0], _t0);
      e.pointerMove(p[1], _t0);

      expect(e.alcanzados, 2);
      expect(e.precisionPct, 100);
    });

    test('tras completar, los gestos nuevos se ignoran', () {
      final e = _eval(ConectaFigure.hexagono);
      _unirTodo(e);
      final total = e.puntosTotales;

      e.pointerDown(e.points.last, _t0.add(const Duration(minutes: 1)));
      e.pointerMove(const Offset(10, 10), _t0.add(const Duration(minutes: 1)));

      expect(e.puntosTotales, total);
      expect(e.tiempoMs, 10000);
    });
  });
}
