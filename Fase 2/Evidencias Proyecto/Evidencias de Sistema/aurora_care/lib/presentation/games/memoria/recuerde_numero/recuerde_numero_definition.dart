// lib/presentation/games/memoria/recuerde_numero/recuerde_numero_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'recuerde_numero_screen.dart';

/// Definición de Recuerde el número (dominio memoria, gameType
/// 'recuerde_numero') para registrarla en game_catalog.dart. Juego nuevo,
/// todavía no está en SCORING.md — ver tabla de niveles y traducción de
/// métricas propuestas en el resumen de la tarea.
const recuerdeNumeroDefinition = GameDefinition(
  gameType: 'recuerde_numero',
  domain: 'memoria',
  title: 'Recuerde el número',
  instructions:
      'Memorice el número que aparece en pantalla y luego escríbalo con '
      'el teclado.',
  icon: Icons.pin,
  maxDuration: _maxDuration,
  builder: _builder,
);

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
  return RecuerdeNumeroScreen(run: run);
}
