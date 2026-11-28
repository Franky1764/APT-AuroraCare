// lib/presentation/games/memoria/memorice_clasico/memorice_clasico_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'memorice_clasico_screen.dart';

/// Definición de Memorice clásico (SCORING.md §2.1-§2.2) para registrarla
/// en GameLevelScreen.
const memoriceClasicoDefinition = GameDefinition(
  gameType: 'memorice_clasico',
  domain: 'memoria',
  title: 'Memorice clásico',
  instructions:
      'Dé vuelta dos cartas a la vez para encontrar sus parejas. Trate de '
      'recordar dónde está cada una.',
  icon: Icons.spa,
  maxDuration: _maxDuration,
  builder: _builder,
  // El reloj visible arranca recién cuando se tapan las cartas (fin de
  // la vista previa), no al entrar al nivel: ver MemoriceClasicoScreen.
  startClockImmediately: false,
);

/// SCORING §2.2: Fácil 240s, Intermedio 300s, Avanzado 360s.
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
  return MemoriceClasicoScreen(run: run);
}
