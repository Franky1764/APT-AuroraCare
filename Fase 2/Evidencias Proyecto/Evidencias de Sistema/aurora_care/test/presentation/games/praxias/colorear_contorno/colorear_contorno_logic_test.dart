// test/presentation/games/praxias/colorear_contorno/colorear_contorno_logic_test.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/praxias/colorear_contorno/colorear_contorno_config.dart';
import 'package:aurora_care/presentation/games/praxias/colorear_contorno/colorear_contorno_logic.dart';

const double _lado = 240;
const Rect _area = Rect.fromLTWH(0, 0, _lado, _lado);

List<Offset> _poligono(ColorearFigure f) =>
    escalarPuntos(f.puntosUnitarios, _area);

ColorearEvaluator _evaluador(ColorearFigure f, GameLevel nivel) =>
    ColorearEvaluator(
      poligono: _poligono(f),
      tolerancePx: toleranciaColorearPx(nivel),
      brushRadiusPx: radioPincelPx(nivel),
      coberturaObjetivo: coberturaObjetivo(nivel),
    );

/// Pasadas horizontales de lado a lado del interior, separadas [paso] px,
/// recortadas 1 px hacia adentro del borde. Sirve de "coloreado ideal".
List<List<Offset>> _barrido(List<Offset> poly, double paso) {
  final ys = poly.map((p) => p.dy);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final pasadas = <List<Offset>>[];
  var invertir = false;
  for (var y = minY + paso / 2; y < maxY; y += paso) {
    final xs = <double>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if ((a.dy > y) != (b.dy > y)) {
        xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    xs.sort();
    var tramos = <List<Offset>>[
      for (var k = 0; k + 1 < xs.length; k += 2)
        if (xs[k + 1] - xs[k] > 2)
          [Offset(xs[k] + 1, y), Offset(xs[k + 1] - 1, y)],
    ];
    if (invertir) {
      tramos = [for (final t in tramos.reversed) t.reversed.toList()];
    }
    pasadas.addAll(tramos);
    invertir = !invertir;
  }
  return pasadas;
}

bool _cruzan(Offset a, Offset b, Offset c, Offset d) {
  double ccw(Offset p, Offset q, Offset r) =>
      (r.dy - p.dy) * (q.dx - p.dx) - (q.dy - p.dy) * (r.dx - p.dx);
  return ccw(a, c, d) * ccw(b, c, d) < 0 && ccw(a, b, c) * ccw(a, b, d) < 0;
}

void main() {
  group('configuración', () {
    test('hay 10 figuras y cada nivel toma una ventana de 5', () {
      expect(ColorearFigure.values.length, 10);
      for (final n in GameLevel.values) {
        expect(figurasDelNivelColorear(n).length, 5, reason: n.name);
      }
      expect(figurasDelNivelColorear(GameLevel.facil).first,
          ColorearFigure.circulo);
      expect(figurasDelNivelColorear(GameLevel.avanzado).last,
          ColorearFigure.estrella);
    });

    test('la tolerancia, el pincel y la meta son coherentes por nivel', () {
      expect(toleranciaColorearPx(GameLevel.facil), 15);
      expect(toleranciaColorearPx(GameLevel.intermedio), 10);
      expect(toleranciaColorearPx(GameLevel.avanzado), 7);
      expect(radioPincelPx(GameLevel.facil), greaterThan(radioPincelPx(GameLevel.intermedio)));
      expect(radioPincelPx(GameLevel.intermedio), greaterThan(radioPincelPx(GameLevel.avanzado)));
      expect(coberturaObjetivo(GameLevel.facil), lessThan(coberturaObjetivo(GameLevel.avanzado)));
      expect(tiempoMaximoColorear(GameLevel.facil).inSeconds, 150);
      expect(tiempoMaximoColorear(GameLevel.avanzado).inSeconds, 270);
    });

    test('todos los puntos caen dentro del cuadrado unitario', () {
      for (final f in ColorearFigure.values) {
        for (final p in f.puntosUnitarios) {
          expect(p.dx, inInclusiveRange(0.02, 0.98), reason: f.name);
          expect(p.dy, inInclusiveRange(0.02, 0.98), reason: f.name);
        }
      }
    });

    test('ningún contorno se cruza consigo mismo', () {
      for (final f in ColorearFigure.values) {
        final p = f.puntosUnitarios;
        final n = p.length;
        for (var i = 0; i < n; i++) {
          for (var j = i + 2; j < n; j++) {
            if (i == 0 && j == n - 1) continue;
            expect(
              _cruzan(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n]),
              isFalse,
              reason: '${f.name}: aristas $i y $j',
            );
          }
        }
      }
    });

    test('las áreas son razonables y las de referencia coinciden', () {
      for (final f in ColorearFigure.values) {
        expect(f.areaUnitaria, inInclusiveRange(0.2, 0.75), reason: f.name);
      }
      for (final n in GameLevel.values) {
        final pool = figurasDelNivelColorear(n);
        final media =
            pool.map((f) => f.areaUnitaria).reduce((a, b) => a + b) / pool.length;
        expect(areaReferencia(n), closeTo(3 * media, 1e-9));
      }
    });

    test('nombres con artículo', () {
      expect(ColorearFigure.casita.nombreConArticulo, 'la casita');
      expect(ColorearFigure.circulo.nombreConArticulo, 'el círculo');
      expect(ColorearFigure.estrella.nombreConArticulo, 'la estrella');
      expect(ColorearFigure.pez.nombreConArticulo, 'el pez');
    });
  });

  group('sorteo de figuras', () {
    test('saca 3 distintas, todas del nivel', () {
      for (final n in GameLevel.values) {
        final s = elegirFigurasColorear(n, math.Random(1));
        expect(s.length, 3);
        expect(s.toSet().length, 3);
        expect(figurasDelNivelColorear(n), containsAll(s));
      }
    });

    test('es reproducible con la misma semilla', () {
      final a = elegirFigurasColorear(GameLevel.intermedio, math.Random(7));
      final b = elegirFigurasColorear(GameLevel.intermedio, math.Random(7));
      expect(a, b);
    });

    test('no parte con la misma figura ni repite la secuencia anterior', () {
      final anterior = [
        ColorearFigure.circulo,
        ColorearFigure.cuadrado,
        ColorearFigure.triangulo,
      ];
      for (var seed = 0; seed < 60; seed++) {
        final s = elegirFigurasColorear(
          GameLevel.facil,
          math.Random(seed),
          anterior: anterior,
        );
        expect(s.first, isNot(anterior.first), reason: 'semilla $seed');
      }
    });
  });

  group('tiempo normalizado', () {
    test('con el área de referencia el tiempo no cambia', () {
      for (final n in GameLevel.values) {
        expect(
          tiempoNormalizadoColorearSeg(60000, areaReferencia(n), n),
          60,
        );
      }
    });

    test('figuras más grandes bajan el tiempo, más chicas lo suben', () {
      final ref = areaReferencia(GameLevel.facil);
      expect(
        tiempoNormalizadoColorearSeg(60000, ref * 2, GameLevel.facil),
        30,
      );
      expect(
        tiempoNormalizadoColorearSeg(60000, ref / 2, GameLevel.facil),
        120,
      );
      expect(tiempoNormalizadoColorearSeg(60000, 0, GameLevel.facil), 0);
    });
  });

  group('geometría', () {
    test('punto en polígono y distancia por fuera', () {
      final cuadrado = [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];
      expect(puntoEnPoligono(const Offset(50, 50), cuadrado), isTrue);
      expect(puntoEnPoligono(const Offset(150, 50), cuadrado), isFalse);
      expect(distanciaPorFuera(const Offset(50, 50), cuadrado), 0);
      expect(distanciaPorFuera(const Offset(110, 50), cuadrado), closeTo(10, 1e-9));
      expect(distanciaPorFuera(const Offset(103, 104), cuadrado), closeTo(5, 1e-9));
    });
  });

  group('evaluador', () {
    test('un coloreado completo y prolijo termina con 100 % y 0 salidas', () {
      for (final nivel in GameLevel.values) {
        for (final f in figurasDelNivelColorear(nivel)) {
          final ev = _evaluador(f, nivel);
          final t0 = DateTime(2026, 1, 1);
          var k = 0;
          for (final pasada in _barrido(_poligono(f), radioPincelPx(nivel) * 1.5)) {
            if (ev.completed) break;
            ev.pointerDown(pasada.first, t0.add(Duration(milliseconds: 50 * k++)));
            ev.pointerMove(pasada.last, t0.add(Duration(milliseconds: 50 * k++)));
            ev.pointerUp();
          }
          final razon = '${nivel.name} / ${f.name}';
          expect(ev.completed, isTrue, reason: razon);
          expect(ev.precisionPct, 100, reason: razon);
          expect(ev.correcciones, 0, reason: razon);
          expect(ev.cobertura, greaterThanOrEqualTo(coberturaObjetivo(nivel)), reason: razon);
        }
      }
    });

    test('recorrer solo el borde no alcanza para completar', () {
      for (final nivel in GameLevel.values) {
        for (final f in figurasDelNivelColorear(nivel)) {
          final poly = _poligono(f);
          final ev = _evaluador(f, nivel);
          final t0 = DateTime(2026, 1, 1);
          ev.pointerDown(poly.first, t0);
          for (var i = 1; i <= poly.length; i++) {
            ev.pointerMove(poly[i % poly.length], t0);
          }
          expect(ev.completed, isFalse, reason: '${nivel.name} / ${f.name}');
          expect(ev.cobertura, lessThan(0.7), reason: '${nivel.name} / ${f.name}');
        }
      }
    });

    test('el tiempo va del primer toque al momento de completar', () {
      const nivel = GameLevel.facil;
      const f = ColorearFigure.cuadrado;
      final ev = _evaluador(f, nivel);
      final t0 = DateTime(2026, 1, 1);
      DateTime? alCompletar;
      var k = 0;
      for (final pasada in _barrido(_poligono(f), radioPincelPx(nivel) * 1.5)) {
        if (ev.completed) break;
        ev.pointerDown(pasada.first, t0.add(Duration(milliseconds: 100 * k++)));
        final ahora = t0.add(Duration(milliseconds: 100 * k++));
        ev.pointerMove(pasada.last, ahora);
        ev.pointerUp();
        if (ev.completed) alCompletar = ahora;
      }
      expect(alCompletar, isNotNull);
      expect(ev.tiempoMs, alCompletar!.difference(t0).inMilliseconds);
    });

    test('salir menos que la tolerancia no cuenta; salir más, sí (una vez)', () {
      final ev = _evaluador(ColorearFigure.cuadrado, GameLevel.facil);
      final t = DateTime(2026, 1, 1);
      // Cuadrado de 24 a 216 px. Tolerancia fácil: 15 px.
      ev.pointerDown(const Offset(120, 120), t);
      ev.pointerMove(const Offset(230, 120), t); // 14 px fuera: tolerado
      expect(ev.correcciones, 0);
      ev.pointerMove(const Offset(250, 120), t); // 34 px fuera
      expect(ev.correcciones, 1);
      ev.pointerMove(const Offset(252, 130), t); // sigue fuera: misma salida
      expect(ev.correcciones, 1);
      ev.pointerMove(const Offset(120, 120), t); // vuelve
      ev.pointerMove(const Offset(250, 120), t); // sale otra vez
      expect(ev.correcciones, 2);
      expect(ev.precisionPct, lessThan(100));
      expect(ev.precisionPct, greaterThan(0));
    });

    test('levantar el dedo no es una corrección', () {
      final ev = _evaluador(ColorearFigure.cuadrado, GameLevel.facil);
      final t = DateTime(2026, 1, 1);
      ev.pointerDown(const Offset(60, 60), t);
      ev.pointerMove(const Offset(60, 100), t);
      ev.pointerUp();
      ev.pointerDown(const Offset(100, 100), t);
      ev.pointerMove(const Offset(140, 100), t);
      ev.pointerUp();
      expect(ev.correcciones, 0);
      expect(ev.precisionPct, 100);
      expect(ev.strokes.length, 2);
    });

  test('un toque inicial lejos del contorno se ignora', () {
    final ev = _evaluador(ColorearFigure.cuadrado, GameLevel.facil);
    // A 84 px del borde izquierdo (el cuadrado parte en x = 24): más allá de
    // los 45 px que se aceptan para el primer toque en Fácil.
    ev.pointerDown(const Offset(-60, 120), DateTime(2026, 1, 1));
    ev.pointerMove(const Offset(-50, 120), DateTime(2026, 1, 1));
    expect(ev.puntosTotales, 0);
    expect(ev.strokes, isEmpty);
    expect(ev.tiempoMs, 0);
  });

    test('empezar fuera pero cerca cuenta como una salida', () {
      final ev = _evaluador(ColorearFigure.cuadrado, GameLevel.facil);
      // 30 px fuera del borde: dentro del límite de 45 px para aceptar el
      // toque, pero más allá de la tolerancia de 15 px.
      ev.pointerDown(const Offset(246, 120), DateTime(2026, 1, 1));
      expect(ev.strokes.length, 1);
      expect(ev.correcciones, 1);
    });

    test('al completar se ignoran los gestos siguientes', () {
      const nivel = GameLevel.facil;
      const f = ColorearFigure.cuadrado;
      final ev = _evaluador(f, nivel);
      final t = DateTime(2026, 1, 1);
      for (final pasada in _barrido(_poligono(f), radioPincelPx(nivel) * 1.5)) {
        if (ev.completed) break;
        ev.pointerDown(pasada.first, t);
        ev.pointerMove(pasada.last, t);
        ev.pointerUp();
      }
      expect(ev.completed, isTrue);
      final total = ev.puntosTotales;
      final trazos = ev.strokes.length;
      ev.pointerDown(const Offset(100, 100), t);
      ev.pointerMove(const Offset(150, 150), t);
      expect(ev.puntosTotales, total);
      expect(ev.strokes.length, trazos);
    });

    test('el avance sube con lo pintado y llega a 1 al completar', () {
      const nivel = GameLevel.facil;
      const f = ColorearFigure.circulo;
      final ev = _evaluador(f, nivel);
      final t = DateTime(2026, 1, 1);
      expect(ev.avance, 0);
      var previo = 0.0;
      for (final pasada in _barrido(_poligono(f), radioPincelPx(nivel) * 1.5)) {
        if (ev.completed) break;
        ev.pointerDown(pasada.first, t);
        ev.pointerMove(pasada.last, t);
        ev.pointerUp();
        expect(ev.avance, greaterThanOrEqualTo(previo));
        previo = ev.avance;
      }
      expect(ev.avance, 1);
    });
  });
}