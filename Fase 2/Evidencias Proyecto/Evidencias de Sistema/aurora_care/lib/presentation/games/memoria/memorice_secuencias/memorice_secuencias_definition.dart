// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencias_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'memorice_secuencias_screen.dart';

/// Definición de Memorice de secuencias (SCORING.md §2.1-§2.2) para
/// registrarla en game_catalog.dart.
const memoriceSecuenciasDefinition = GameDefinition(
  gameType: 'memorice_secuencias',
  domain: 'memoria',
  title: 'Memorice de secuencias',
  instructions:
      'Observe el orden en que se iluminan las imágenes y luego tóquelas '
      'en ese mismo orden.',
  icon: Icons.format_list_numbered,
  maxDuration: _maxDuration,
  builder: _builder,
);

/// Propuesta a Daniela (SCORING.md): igual a Memorice clásico — Fácil
/// 240s, Intermedio 300s, Avanzado 360s.
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
  return MemoriceSecuenciasScreen(run: run);
}
