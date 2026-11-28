import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/constants/app_palettes.dart';

/// Matrices de Machado, Oliveira y Fernandes (2009) para simular, con
/// severidad 1,0, cómo se ve un color para una persona con protanopia o
/// deuteranopia. Se aplican en espacio RGB lineal (por eso se pasa por
/// _linealizar/_aSrgb), no directo sobre los valores 0-255 de pantalla.
const _matrizProtanopia = [
  [0.152286, 1.052583, -0.204868],
  [0.114503, 0.786281, 0.099216],
  [-0.003882, -0.048116, 1.051998],
];
const _matrizDeuteranopia = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.011820, 0.042940, 0.968881],
];

double _linealizar(double c) {
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _aSrgb(double c) {
  final acotado = c.clamp(0.0, 1.0);
  return acotado <= 0.0031308
      ? acotado * 12.92
      : 1.055 * math.pow(acotado, 1 / 2.4).toDouble() - 0.055;
}

Color _simular(Color color, List<List<double>> matriz) {
  final r = _linealizar(color.r);
  final g = _linealizar(color.g);
  final b = _linealizar(color.b);
  final rSim = matriz[0][0] * r + matriz[0][1] * g + matriz[0][2] * b;
  final gSim = matriz[1][0] * r + matriz[1][1] * g + matriz[1][2] * b;
  final bSim = matriz[2][0] * r + matriz[2][1] * g + matriz[2][2] * b;
  return Color.from(alpha: 1.0, red: _aSrgb(rSim), green: _aSrgb(gSim), blue: _aSrgb(bSim));
}

/// Distancia euclidiana simple en RGB (0-255) entre 2 colores ya
/// simulados. No es una métrica perceptual exacta (eso requeriría CIEDE2000
/// y un paquete nuevo, que no vamos a agregar), pero alcanza para detectar
/// si 2 colores se volvieron casi idénticos bajo una simulación de
/// daltonismo: ese es el caso que de verdad importa evitar.
double _distancia(Color a, Color b) {
  final dr = (a.r - b.r) * 255.0;
  final dg = (a.g - b.g) * 255.0;
  final db = (a.b - b.b) * 255.0;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  final paleta = AppPalettes.daltonismo.paleta;
  final trio = {
    'success': paleta.success,
    'warning': paleta.warning,
    'error': paleta.error,
  };

  for (final entry in [
    ('protanopia', _matrizProtanopia),
    ('deuteranopia', _matrizDeuteranopia),
  ]) {
    final condicion = entry.$1;
    final matriz = entry.$2;
    group('daltonismo — success/warning/error se distinguen bajo $condicion', () {
      final simulados = trio.map((nombre, color) => MapEntry(nombre, _simular(color, matriz)));

      for (final par in [('success', 'warning'), ('success', 'error'), ('warning', 'error')]) {
        test('${par.$1} vs ${par.$2}', () {
          final distancia = _distancia(simulados[par.$1]!, simulados[par.$2]!);
          // Umbral conservador: en los intentos de diseño que fallaban (ej.
          // warning y error ambos de la familia naranja-amarilla) la
          // distancia bajaba a 16-23; la paleta final da 95 o más en ambas
          // condiciones. 40 separa claramente un diseño roto de uno válido.
          expect(
            distancia,
            greaterThanOrEqualTo(40),
            reason:
                'Bajo $condicion, ${par.$1} y ${par.$2} de la paleta Daltonismo '
                'quedan a distancia ${distancia.toStringAsFixed(1)} — muy '
                'parecidos para alguien con esa condición. Además del color, '
                'estos estados siempre deben mostrarse con ícono y texto.',
          );
        });
      }
    });
  }
}
