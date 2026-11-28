// lib/presentation/games/memoria/memoria_faces.dart
import 'package:flutter/material.dart';

/// Una "cara": ícono + color + nombre accesible, compartida por los juegos
/// del dominio Memoria (Memorice clásico, Memorice de secuencias). Lista
/// única y reemplazable: cuando haya assets reales, solo se cambia este
/// archivo, sin tocar los controllers ni las pantallas.
class MemoriceFace {
  const MemoriceFace({
    required this.icon,
    required this.color,
    required this.name,
  });

  final IconData icon;
  final Color color;

  /// Nombre accesible para el lector de pantalla (ej. "Corazón rojo").
  final String name;
}

/// Las 10 caras disponibles (el máximo que usa cualquier juego del dominio,
/// hoy Memorice clásico en el nivel Avanzado). Cada una se distingue por
/// forma Y color, con tonos oscuros/saturados para mantener contraste
/// 4,5:1 sobre fondo claro.
const List<MemoriceFace> memoriceFaces = [
  MemoriceFace(icon: Icons.favorite, color: Color(0xFFD64545), name: 'Corazón rojo'),
  MemoriceFace(icon: Icons.star, color: Color(0xFFB8860B), name: 'Estrella dorada'),
  MemoriceFace(icon: Icons.eco, color: Color(0xFF2E9E5B), name: 'Hoja verde'),
  MemoriceFace(icon: Icons.water_drop, color: Color(0xFF1C5FB0), name: 'Gota azul'),
  MemoriceFace(icon: Icons.local_florist, color: Color(0xFF9B3FAE), name: 'Flor morada'),
  MemoriceFace(icon: Icons.wb_sunny, color: Color(0xFFC25A14), name: 'Sol naranjo'),
  MemoriceFace(icon: Icons.pets, color: Color(0xFF6B4423), name: 'Huella café'),
  MemoriceFace(icon: Icons.anchor, color: Color(0xFF156366), name: 'Ancla turquesa'),
  MemoriceFace(icon: Icons.umbrella, color: Color(0xFFA83B63), name: 'Paraguas rosado'),
  MemoriceFace(icon: Icons.ac_unit, color: Color(0xFF2E3F8F), name: 'Copo de nieve azul'),
];
