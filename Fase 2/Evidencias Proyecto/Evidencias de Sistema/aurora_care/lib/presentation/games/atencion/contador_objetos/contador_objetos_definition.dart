// lib/presentation/games/atencion/contador_objetos/contador_objetos_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'contador_objetos_screen.dart';

/// Definición de Contador de objetos (SCORING.md §2.1 y §2.3) para el
/// catálogo.
const contadorObjetosDefinition = GameDefinition(
  gameType: 'contador_objetos',
  domain: 'atencion',
  title: 'Contador de objetos',
  instructions:
      'Aparecerán figuras por unos segundos. Cuéntelas y luego elija '
      'cuántas había.',
  icon: Icons.format_list_numbered,
  maxDuration: _maxDuration,
  builder: _builder,
);

/// Propuesta (SCORING aún no define el tiempo máximo de este juego):
/// Fácil 150 s, Intermedio 180 s, Avanzado 210 s.
Duration _maxDuration(GameLevel nivel) {
  switch (nivel) {
    case GameLevel.facil:
      return const Duration(seconds: 150);
    case GameLevel.intermedio:
      return const Duration(seconds: 180);
    case GameLevel.avanzado:
      return const Duration(seconds: 210);
  }
}

Widget _builder(BuildContext context, GameRun run) {
  return ContadorObjetosScreen(run: run);
}
