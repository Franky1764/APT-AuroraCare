// lib/presentation/games/memoria/que_cambio/que_cambio_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'que_cambio_screen.dart';

/// Definición de ¿Qué cambió? (SCORING.md §2.1-§2.2, gameType 'que_cambio')
/// para registrarla en game_catalog.dart.
const queCambioDefinition = GameDefinition(
  gameType: 'que_cambio',
  domain: 'memoria',
  title: '¿Qué cambió?',
  instructions:
      'Compare las dos imágenes y toque las partes donde encuentre un '
      'cambio.',
  icon: Icons.compare,
  maxDuration: _maxDuration,
  builder: _builder,
);

/// Propuesta a Daniela (SCORING.md): igual a los otros 2 juegos de
/// Memoria — Fácil 240s, Intermedio 300s, Avanzado 360s.
Duration _maxDuration(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 240);
    case GameLevel.intermedio:
      return const Duration(seconds: 300);
    case GameLevel.avanzado:
      return const Duration(seconds: 360);
  }
}

Widget _builder(BuildContext context, GameRun run) {
  return QueCambioScreen(run: run);
}
