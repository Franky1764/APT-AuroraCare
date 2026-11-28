// lib/presentation/games/atencion/toca_correcto/toca_correcto_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'toca_correcto_screen.dart';

/// Definición de Toca el correcto (SCORING.md §2.1 y §2.3) para el catálogo.
const tocaCorrectoDefinition = GameDefinition(
  gameType: 'toca_correcto',
  domain: 'atencion',
  title: 'Toca el correcto',
  instructions:
      'Aparecerán figuras una por una. Toque solo la figura que se indica '
      'arriba de la pantalla. Si aparece otra figura, no la toque.',
  icon: Icons.touch_app,
  maxDuration: _maxDuration,
  builder: _builder,
);

/// Propuesta (SCORING aún no define el tiempo máximo de este juego):
/// Fácil 120 s, Intermedio 150 s, Avanzado 180 s.
Duration _maxDuration(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 120);
    case GameLevel.intermedio:
      return const Duration(seconds: 150);
    case GameLevel.avanzado:
      return const Duration(seconds: 180);
  }
}

Widget _builder(BuildContext context, GameRun run) {
  return TocaCorrectoScreen(run: run);
}
