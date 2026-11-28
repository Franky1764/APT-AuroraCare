// lib/presentation/games/atencion/toca_correcto/toca_correcto_figuras.dart
import 'package:flutter/material.dart';

import 'toca_correcto_controller.dart';

/// Una forma con su nombre y género (para decir "la estrella amarilla" o
/// "el corazón amarillo").
class TocaForma {
  const TocaForma(this.nombre, this.icono, {required this.femenina});
  final String nombre;
  final IconData icono;
  final bool femenina;
}

/// Un color con su nombre en masculino y femenino.
class TocaColor {
  const TocaColor(this.masculino, this.femenino, this.color);
  final String masculino;
  final String femenino;
  final Color color;
}

/// Mismo orden y cantidad que tocaCantidadFormas del controller.
const tocaFormas = [
  TocaForma('estrella', Icons.star_rounded, femenina: true),
  TocaForma('corazón', Icons.favorite_rounded, femenina: false),
  TocaForma('hoja', Icons.eco_rounded, femenina: true),
  TocaForma('gota', Icons.water_drop_rounded, femenina: true),
  TocaForma('sol', Icons.wb_sunny_rounded, femenina: false),
  TocaForma('flor', Icons.local_florist_rounded, femenina: true),
];

/// Mismo orden y cantidad que tocaCantidadColores del controller. Las
/// figuras se dibujan con un contorno oscuro para que el amarillo se vea
/// bien sobre fondo claro.
const tocaColores = [
  TocaColor('amarillo', 'amarilla', Color(0xFFFBC02D)),
  TocaColor('rojo', 'roja', Color(0xFFC62828)),
  TocaColor('verde', 'verde', Color(0xFF2E7D32)),
  TocaColor('azul', 'azul', Color(0xFF1565C0)),
  TocaColor('morado', 'morada', Color(0xFF6A1B9A)),
];

extension TocaFiguraTexto on TocaFiguraId {
  TocaForma get formaDatos => tocaFormas[forma];
  TocaColor get colorDatos => tocaColores[color];

  /// "estrella amarilla", "corazón rojo".
  String get nombre {
    final f = formaDatos;
    final c = colorDatos;
    return '${f.nombre} ${f.femenina ? c.femenino : c.masculino}';
  }

  /// "Estrella amarilla" (para mostrar debajo de la figura).
  String get nombreTitulo => nombre[0].toUpperCase() + nombre.substring(1);

  /// "la" o "el".
  String get articulo => formaDatos.femenina ? 'la' : 'el';
}
