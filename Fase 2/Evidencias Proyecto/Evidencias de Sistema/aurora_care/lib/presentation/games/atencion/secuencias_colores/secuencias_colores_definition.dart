// lib/presentation/games/atencion/secuencias_colores/secuencias_colores_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'secuencias_colores_screen.dart';

/// Definición de Secuencias de colores (SCORING.md §2.1 y §2.3) para
/// registrarla en GameLevelScreen.
const secuenciasColoresDefinition = GameDefinition(
  gameType: 'secuencias_colores',
  domain: 'atencion',
  title: 'Secuencias de colores',
  instructions:
      'Los colores se encenderán uno por uno. Cuando terminen, tóquelos en '
      'el mismo orden.',
  icon: Icons.palette,
  maxDuration: _maxDuration,
  builder: _builder,
);

/// Propuesta (SCORING §2.3 no define tiempo máximo para este juego):
/// Fácil 180 s, Intermedio 240 s, Avanzado 300 s.
Duration _maxDuration(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 180);
    case GameLevel.intermedio:
      return const Duration(seconds: 240);
    case GameLevel.avanzado:
      return const Duration(seconds: 300);
  }
}

Widget _builder(BuildContext context, GameRun run) {
  return SecuenciasColoresScreen(run: run);
}
