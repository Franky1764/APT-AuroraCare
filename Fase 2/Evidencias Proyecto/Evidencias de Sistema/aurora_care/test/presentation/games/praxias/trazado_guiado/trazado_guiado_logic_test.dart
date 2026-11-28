// test/presentation/games/praxias/trazado_guiado/trazado_guiado_logic_test.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_config.dart';
import 'package:aurora_care/presentation/games/praxias/trazado_guiado/trazado_guiado_logic.dart';

final _t0 = DateTime(2026, 1, 1, 10);
DateTime _t(int ms) => _t0.add(Duration(milliseconds: ms));

/// Línea horizontal de (0,150) a (300,150).
GuidePath _linea() => GuidePath.fromUnitPoints(const [
  Offset(0, 0.5),
  Offset(1, 0.5),
], const Rect.fromLTWH(0, 0, 300, 300));

TraceEvaluator _eval(GuidePath g, {double tol = 15}) =>
    TraceEvaluator(guide: g, tolerancePx: tol);

/// Mueve el dedo por la línea de [desde] a [hasta] (en x), a y = [y].
void _recorrerLinea(
  TraceEvaluator e, {
  required double desde,
  required double hasta,
  double y = 150,
}) {
  for (var x = desde + 5; x <= hasta; x += 5) {
    e.pointerMove(Offset(x, y), _t0);
  }
}

GuidePath _guia(TrazadoFigure f, {double lado = 240}) =>
    GuidePath.fromUnitPoints(
      f.puntosUnitarios,
      Rect.fromLTWH(0, 0, lado, lado),
    );

/// Sigue la guía punto a punto (cada [cada] puntos), desplazado hacia un
/// costado una distancia [desvio] que oscila. Solo mueve el dedo: no lo
/// levanta.
void _seguir(TraceEvaluator e, {double desvio = 0, int cada = 6}) {
  final pts = e.guide.points;
  var primero = true;
  for (var i = 0; i < pts.length; i += cada) {
    final j = math.min(i + 1, pts.length - 1);
    final k = math.max(i - 1, 0);
    final t = pts[j] - pts[k];
    final largo = t.distance == 0 ? 1.0 : t.distance;
    final normal = Offset(-t.dy / largo, t.dx / largo);
    final p = pts[i] + normal * (desvio * math.sin(i / 7));
    if (primero) {
      e.pointerDown(p, _t0);
      primero = false;
    } else {
      e.pointerMove(p, _t0);
    }
  }
  e.pointerMove(pts.last, _t0);
}

void main() {
  group('configuración', () {
    test('hay 10 figuras y cada nivel toma una ventana de 5', () {
      expect(TrazadoFigure.values.length, 10);
      for (final n in GameLevel.values) {
        expect(figurasDelNivelTrazado(n).length, 5, reason: n.name);
      }
      expect(
        figurasDelNivelTrazado(GameLevel.facil).first,
        TrazadoFigure.recta,
      );
      expect(
        figurasDelNivelTrazado(GameLevel.avanzado).last,
        TrazadoFigure.espiral,
      );
    });

    test('tolerancia de 15, 10 y 7 px y tiempos máximos de sesión', () {
      expect(toleranciaPx(GameLevel.facil), 15);
      expect(toleranciaPx(GameLevel.intermedio), 10);
      expect(toleranciaPx(GameLevel.avanzado), 7);
      expect(tiempoMaximoTrazado(GameLevel.facil).inSeconds, 90);
      expect(tiempoMaximoTrazado(GameLevel.intermedio).inSeconds, 135);
      expect(tiempoMaximoTrazado(GameLevel.avanzado).inSeconds, 180);
    });

    test('toda figura tiene puntos dentro de 0..1', () {
      for (final f in TrazadoFigure.values) {
        final p = f.puntosUnitarios;
        expect(p.length, greaterThanOrEqualTo(2), reason: f.name);
        for (final o in p) {
          expect(o.dx, inInclusiveRange(0, 1), reason: f.name);
          expect(o.dy, inInclusiveRange(0, 1), reason: f.name);
        }
      }
    });

    test('las figuras cerradas terminan donde empiezan; las abiertas no', () {
      const cerradas = {
        TrazadoFigure.circulo,
        TrazadoFigure.cuadrado,
        TrazadoFigure.triangulo,
        TrazadoFigure.casita,
        TrazadoFigure.estrella,
      };
      for (final f in TrazadoFigure.values) {
        expect(_guia(f).isClosed, cerradas.contains(f), reason: f.name);
      }
    });

    test('las longitudes de referencia coinciden con las del nivel', () {
      for (final n in GameLevel.values) {
        final pool = figurasDelNivelTrazado(n);
        final media =
            pool.map((f) => f.longitudUnitaria).reduce((a, b) => a + b) /
            pool.length;
        expect(longitudReferenciaTrazado(n), closeTo(3 * media, 1e-9));
      }
      for (final f in TrazadoFigure.values) {
        expect(f.longitudUnitaria, greaterThan(0.5), reason: f.name);
      }
    });

    test('nombres con artículo', () {
      expect(TrazadoFigure.recta.nombreConArticulo, 'la línea recta');
      expect(TrazadoFigure.circulo.nombreConArticulo, 'el círculo');
      expect(TrazadoFigure.espiral.nombreConArticulo, 'la espiral');
      expect(TrazadoFigure.zigzag.nombreConArticulo, 'el zigzag');
    });
  });

  group('sorteo de figuras', () {
    test('saca 3 distintas, todas del nivel', () {
      for (final n in GameLevel.values) {
        final s = elegirFigurasTrazado(n, math.Random(1));
        expect(s.length, 3);
        expect(s.toSet().length, 3);
        expect(figurasDelNivelTrazado(n), containsAll(s));
      }
    });

    test('es reproducible con la misma semilla', () {
      expect(
        elegirFigurasTrazado(GameLevel.intermedio, math.Random(7)),
        elegirFigurasTrazado(GameLevel.intermedio, math.Random(7)),
      );
    });

    test('no parte con la misma figura que la sesión anterior', () {
      final anterior = [
        TrazadoFigure.recta,
        TrazadoFigure.curva,
        TrazadoFigure.onda,
      ];
      for (var seed = 0; seed < 60; seed++) {
        final s = elegirFigurasTrazado(
          GameLevel.facil,
          math.Random(seed),
          anterior: anterior,
        );
        expect(s.first, isNot(anterior.first), reason: 'semilla $seed');
      }
    });
  });

  group('tiempo normalizado', () {
    test('con la longitud de referencia el tiempo no cambia', () {
      for (final n in GameLevel.values) {
        expect(
          tiempoNormalizadoTrazadoSeg(60000, longitudReferenciaTrazado(n), n),
          60,
        );
      }
    });

    test('figuras más largas bajan el tiempo, más cortas lo suben', () {
      final ref = longitudReferenciaTrazado(GameLevel.facil);
      expect(tiempoNormalizadoTrazadoSeg(60000, ref * 2, GameLevel.facil), 30);
      expect(tiempoNormalizadoTrazadoSeg(60000, ref / 2, GameLevel.facil), 120);
      expect(tiempoNormalizadoTrazadoSeg(60000, 0, GameLevel.facil), 0);
    });
  });

  group('GuidePath', () {
    test('la línea de 300 px mide 300 y se densifica', () {
      final g = _linea();
      expect(g.length, closeTo(300, 1e-6));
      expect(g.points.length, greaterThan(50));
      expect(g.start, const Offset(0, 150));
      expect(g.end, const Offset(300, 150));
      expect(g.isClosed, isFalse);
    });

    test('pointAt, pointsUpTo y angleAt', () {
      final g = _linea();
      expect(g.pointAt(0), const Offset(0, 150));
      expect(g.pointAt(150).dx, closeTo(150, 3));
      expect(g.pointAt(1000).dx, 300);
      final hasta = g.pointsUpTo(100);
      expect(hasta.first, g.start);
      expect(hasta.last.dx, closeTo(100, 3));
      expect(g.angleAt(50), closeTo(0, 1e-9));
    });
  });

  group('TraceEvaluator', () {
    test('trazo exacto: se completa solo al llegar, sin levantar el dedo', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 300);
      expect(e.completed, isTrue);
      expect(e.precisionPct, 100);
      expect(e.correcciones, 0);
    });

    test('no se completa a mitad de camino', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 150);
      expect(e.completed, isFalse);
      expect(e.progress, closeTo(0.5, 0.03));
    });

    test('levantar el dedo al 86 % no completa ni penaliza', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 255);
      e.pointerMove(const Offset(258, 150), _t(0));
      // Avance 86 %, a 42 px del final: aún no completa sola.
      expect(e.completed, isFalse);
      final lista = e.pointerUp(_t(500));
      expect(lista, isFalse);
      expect(e.completed, isFalse);
      expect(e.correcciones, 0);
    });

    test('levantar el dedo permite retomar sin contar una corrección', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 100);
      expect(e.pointerUp(_t(100)), isFalse);
      expect(e.correcciones, 0);
      e.pointerDown(const Offset(100, 150), _t(200));
      _recorrerLinea(e, desde: 100, hasta: 300);
      expect(e.completed, isTrue);
      expect(e.correcciones, 0);
    });

    test('un primer toque lejos de la guía se ignora', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(150, 280), _t(0));
      e.pointerMove(const Offset(160, 280), _t(10));
      expect(e.strokes, isEmpty);
      expect(e.puntosTotales, 0);
      expect(e.pointerUp(_t(20)), isFalse);
      expect(e.correcciones, 0);
      expect(e.tiempoMs, 0);
    });

    test('justo en el límite del toque inicial: 44 px sí, 46 px no', () {
      final cerca = _eval(_linea())..pointerDown(const Offset(0, 194), _t(0));
      expect(cerca.strokes.length, 1);
      final lejos = _eval(_linea())..pointerDown(const Offset(0, 196), _t(0));
      expect(lejos.strokes, isEmpty);
    });

    test('un trazo fuera del corredor no completa por mera proximidad', () {
      final e = _eval(_linea());
      // A 25 px de la línea: fuera de la tolerancia (15) pero dentro de la
      // antigua banda de avance (30). Ahora debe retomar el recorrido.
      e.pointerDown(const Offset(0, 175), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 300, y: 175);
      expect(e.completed, isFalse);
      expect(e.precisionPct, lessThan(50));
    });

    test('un desvío grande requiere volver al tramo pendiente', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      for (var x = 5.0; x <= 300; x += 5) {
        e.pointerMove(Offset(x, x >= 100 && x <= 150 ? 170 : 150), _t(0));
      }
      expect(e.completed, isFalse);
      expect(e.precisionPct, lessThan(100));
      expect(e.precisionPct, greaterThan(60));
    });

    test('un trazo más lejos que la banda de avance no progresa', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 190), _t(0)); // 40 px: se acepta el toque
      _recorrerLinea(e, desde: 0, hasta: 300, y: 190);
      expect(e.completed, isFalse);
      expect(e.progress, 0);
    });

    test('justo en el borde de la tolerancia cuenta; un píxel más no', () {
      // La guía tiene un punto cada 3 px: x = 9 cae justo sobre uno.
      final dentro = _eval(_linea());
      dentro.pointerDown(const Offset(9, 165), _t(0)); // exactamente 15 px
      expect(dentro.precisionPct, 100);
      final fuera = _eval(_linea());
      fuera.pointerDown(const Offset(9, 166), _t(0)); // 16 px
      expect(fuera.precisionPct, 0);
    });

    test('un movimiento rápido (salto grande) también avanza y completa', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      e.pointerMove(const Offset(100, 150), _t(0));
      e.pointerMove(const Offset(200, 150), _t(0));
      e.pointerMove(const Offset(300, 150), _t(0));
      expect(e.completed, isTrue);
      expect(e.precisionPct, 100);
    });

    test('el tiempo va del primer toque al momento de completar', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(1000));
      for (var x = 5.0; x <= 300; x += 5) {
        e.pointerMove(Offset(x, 150), _t(1000 + (x * 10).round()));
      }
      expect(e.completed, isTrue);
      // Se completa cuando el avance alcanza el final; el reloj marca el
      // instante de esa muestra, no el de levantar el dedo.
      expect(e.tiempoMs, greaterThan(0));
      expect(e.tiempoMs, lessThanOrEqualTo(3000));
    });

    test('tocar solo el inicio de una figura cerrada no la completa', () {
      final e = _eval(_guia(TrazadoFigure.circulo), tol: 10);
      e.pointerDown(e.guide.start, _t(0));
      expect(e.completed, isFalse);
      expect(e.pointerUp(_t(10)), isFalse);
      expect(e.correcciones, 0);
    });

    test(
      'una raya recta de punta a punta en la espiral no avanza (sin atajos)',
      () {
        final e = _eval(_guia(TrazadoFigure.espiral), tol: 7);
        final c = e.guide.start;
        final f = e.guide.end;
        e.pointerDown(c, _t(0));
        for (var k = 1; k <= 59; k++) {
          e.pointerMove(c + (f - c) * (k / 59), _t(0));
        }
        expect(e.completed, isFalse);
        expect(e.progress, lessThan(0.2));
      },
    );

    test('tras completar, los gestos nuevos se ignoran', () {
      final e = _eval(_linea());
      e.pointerDown(const Offset(0, 150), _t(0));
      _recorrerLinea(e, desde: 0, hasta: 300);
      expect(e.completed, isTrue);
      final total = e.puntosTotales;
      e.pointerDown(const Offset(50, 150), _t(5000));
      e.pointerMove(const Offset(90, 150), _t(5000));
      expect(e.puntosTotales, total);
      expect(e.pointerUp(_t(6000)), isTrue);
      expect(e.correcciones, 0);
    });
  });

  group('todas las figuras, en todos los niveles', () {
    test('seguir la guía exacta completa con 100 % y sin correcciones', () {
      for (final n in GameLevel.values) {
        for (final f in figurasDelNivelTrazado(n)) {
          final e = _eval(_guia(f), tol: toleranciaPx(n));
          _seguir(e);
          final r = '${n.name} / ${f.name}';
          expect(e.completed, isTrue, reason: r);
          expect(e.precisionPct, 100, reason: r);
          expect(e.correcciones, 0, reason: r);
        }
      }
    });

    test('un temblor dentro de la tolerancia sigue dando 100 %', () {
      for (final n in GameLevel.values) {
        for (final f in figurasDelNivelTrazado(n)) {
          final tol = toleranciaPx(n);
          final e = _eval(_guia(f), tol: tol);
          _seguir(e, desvio: tol * 0.9);
          final r = '${n.name} / ${f.name}';
          expect(e.completed, isTrue, reason: r);
          expect(e.precisionPct, 100, reason: r);
        }
      }
    });

    test(
      'desvíos fuera del corredor conservan precisión y avance por separado',
      () {
        for (final n in GameLevel.values) {
          for (final f in figurasDelNivelTrazado(n)) {
            final tol = toleranciaPx(n);
            final e = _eval(_guia(f), tol: tol);
            _seguir(e, desvio: tol * 1.6);
            final r = '${n.name} / ${f.name}';
            expect(e.progress, inInclusiveRange(0, 1), reason: r);
            expect(e.precisionPct, lessThan(100), reason: r);
          }
        }
      },
    );
  });
  group('práctica autónoma', () {
    test('puede retomar desde otra parte sin deshacer ni saltar el tramo pendiente', () {
      final e = _eval(_linea());
      e.pointerDown(e.guide.start, _t(0));
      _recorrerLinea(e, desde: 0, hasta: 100);
      e.pointerUp(_t(100));
      final progress = e.progress;
      e.pointerDown(e.guide.end, _t(200));
      expect(e.isDrawing, isTrue);
      expect(e.progress, progress);
      e.pointerMove(e.progressPoint, _t(300));
      _recorrerLinea(e, desde: 100, hasta: 300);
      expect(e.completed, isTrue);
      expect(e.correcciones, 0);
      expect(e.strokes, hasLength(2));
    });
    test(
      'retomar por delante no adelanta hasta volver a la zona pendiente',
      () {
        final e = _eval(_linea());
        e.pointerDown(const Offset(44, 150), _t(0));
        e.pointerMove(const Offset(46, 150), _t(100));
        expect(e.progress, 0);
        e.pointerMove(const Offset(0, 150), _t(200));
        _recorrerLinea(e, desde: 0, hasta: 300);
        expect(e.completed, isTrue);
      },
    );
    test('no permite saltar al destino mediante toques separados', () {
      final e = _eval(_linea());
      e.pointerDown(e.guide.end, _t(0));
      expect(e.strokes, isEmpty);
      e.pointerDown(e.guide.start, _t(0));
      _recorrerLinea(e, desde: 0, hasta: 100);
      e.pointerUp(_t(100));
      final before = e.progress;
      e.pointerDown(e.guide.end, _t(200));
      expect(e.progress, before);
      expect(e.completed, isFalse);
    });

    test('descansos entre trazos no forman parte del tiempo activo', () {
      final e = _eval(_linea());
      e.pointerDown(e.guide.start, _t(0));
      e.pointerMove(const Offset(60, 150), _t(1000));
      e.pointerUp(_t(1000));
      e.pointerDown(const Offset(60, 150), _t(61000));
      e.pointerMove(const Offset(120, 150), _t(62000));
      e.pause(_t(62000));
      expect(e.tiempoMs, 2000);
      expect(e.correcciones, 0);
      expect(e.lifts, 2);
    });

    test(
      'deshacer restaura el tramo anterior conservando el tiempo de práctica',
      () {
        final e = _eval(_linea());
        e.pointerDown(e.guide.start, _t(0));
        e.pointerMove(const Offset(60, 150), _t(100));
        e.pointerUp(_t(100));
        final progress = e.progress;
        e.pointerDown(const Offset(60, 150), _t(200));
        e.pointerMove(const Offset(120, 150), _t(300));
        e.pointerUp(_t(300));
        expect(e.undoLastStroke(_t(400)), isTrue);
        expect(e.progress, progress);
        expect(e.strokes, hasLength(1));
        expect(e.tiempoMs, 200);
        expect(e.correcciones, 1);
      },
    );

    test('las muestras inmóviles no inflan la precisión', () {
      final e = _eval(_linea());
      e.pointerDown(e.guide.start, _t(0));
      e.pointerMove(const Offset(40, 150), _t(100));
      e.pointerMove(const Offset(60, 185), _t(200));
      final before = e.precisionPct;
      for (var i = 0; i < 1000; i++) {
        e.pointerMove(const Offset(60, 185), _t(300));
      }
      expect(e.precisionPct, before);
    });

    test('cambiar el tamaño conserva trazos, cobertura y contexto', () {
      final e = _eval(_linea());
      e.pointerDown(e.guide.start, _t(0));
      e.pointerMove(const Offset(120, 150), _t(100));
      e.pointerUp(_t(100));
      final before = e.progress;
      final larger = GuidePath.fromUnitPoints(const [
        Offset(0, .5),
        Offset(1, .5),
      ], const Rect.fromLTWH(0, 0, 600, 600));
      e.reframe(
        larger,
        const Rect.fromLTWH(0, 0, 300, 300),
        const Rect.fromLTWH(0, 0, 600, 600),
        _t(200),
      );
      expect(e.progress, closeTo(before, 1e-6));
      expect(e.strokes.last.last, const Offset(240, 300));
      expect(e.precisionPct, 100);
      expect(e.undoLastStroke(_t(300)), isTrue);
      expect(e.progress, 0);
    });

    test(
      'precisión espacial es estable con distintas frecuencias de eventos',
      () {
        TraceEvaluator trace(double step) {
          final e = _eval(_linea());
          e.pointerDown(e.guide.start, _t(0));
          for (var x = step; x <= 120; x += step) {
            e.pointerMove(Offset(x, 150 + x / 4), _t(100));
          }
          return e;
        }

        expect(trace(2).precisionPct, closeTo(trace(20).precisionPct, 2));
      },
    );
  });
}
