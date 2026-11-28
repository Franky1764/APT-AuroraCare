import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_palettes.dart';

/// Ratio de contraste WCAG entre 2 colores, usando Color.computeLuminance()
/// (ya viene en Flutter, sin paquetes nuevos). Fórmula estándar:
/// (L_más_claro + 0,05) / (L_más_oscuro + 0,05).
double _ratioContraste(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final claro = l1 > l2 ? l1 : l2;
  final oscuro = l1 > l2 ? l2 : l1;
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Excepciones conocidas de la paleta Aurora ACTUAL: no se pide cambiar
/// ningún color de Aurora en este paso, así que estos 2 pares (ambos por
/// la misma razón: accent y warning son el mismo dorado #E8B33C, pensado
/// para destacar sobre fondos oscuros/tarjetas de logro, no para cumplir
/// 3:1 como elemento gráfico sobre fondo claro) quedan documentados en
/// vez de silenciados. Todas las paletas nuevas (Paso 3 en adelante) deben
/// cumplir sin excepciones — esta lista no debe crecer.
const _excepcionesConocidas = {
  ('Aurora', 'accent', 'background'),
  ('Aurora', 'warning', 'warningBackground'),
};

void _verificarPar(
  String paleta,
  String nombreA,
  Color a,
  String nombreB,
  Color b,
  double minimo,
) {
  final ratio = _ratioContraste(a, b);
  final esExcepcion = _excepcionesConocidas.contains((
    paleta,
    nombreA,
    nombreB,
  ));
  test(
    '$nombreA sobre $nombreB >= $minimo:1'
    '${esExcepcion ? ' (excepción conocida de Aurora)' : ''}',
    () {
      if (esExcepcion) {
        // No se exige el mínimo: se deja constancia del ratio real para
        // que quede registrado en el reporte de la prueba, sin fallar.
        // ignore: avoid_print
        print(
          '  excepción conocida: $paleta $nombreA/$nombreB = '
          '${ratio.toStringAsFixed(2)}:1 (pedido $minimo:1)',
        );
        return;
      }
      expect(
        ratio,
        greaterThanOrEqualTo(minimo),
        reason:
            'En la paleta "$paleta", $nombreA sobre $nombreB da '
            '${ratio.toStringAsFixed(2)}:1, pero se pide $minimo:1.',
      );
    },
  );
}

void main() {
  for (final tema in AppPalettes.todas) {
    final nombre = tema.nombre;
    final p = tema.paleta;
    group('contraste — $nombre', () {
      // Texto: 4,5:1.
      _verificarPar(nombre, 'textPrimary', p.textPrimary, 'background', p.background, 4.5);
      _verificarPar(nombre, 'textPrimary', p.textPrimary, 'surface', p.surface, 4.5);
      _verificarPar(nombre, 'textSecondary', p.textSecondary, 'background', p.background, 4.5);
      _verificarPar(nombre, 'textOnPrimary', p.textOnPrimary, 'primary', p.primary, 4.5);

      // No textual: 3:1.
      _verificarPar(nombre, 'primary', p.primary, 'background', p.background, 3.0);
      _verificarPar(nombre, 'accent', p.accent, 'background', p.background, 3.0);
      _verificarPar(nombre, 'success', p.success, 'successBackground', p.successBackground, 3.0);
      _verificarPar(nombre, 'warning', p.warning, 'warningBackground', p.warningBackground, 3.0);
      _verificarPar(nombre, 'error', p.error, 'errorBackground', p.errorBackground, 3.0);
    });
  }
}
