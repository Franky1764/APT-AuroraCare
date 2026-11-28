// lib/presentation/games/shared/game_definition.dart
import 'package:flutter/material.dart';

import '../../../domain/entities/cognitive_metrics.dart';
import '../../../domain/entities/game_level.dart';

/// Lo que el cascarón le entrega a cada juego mientras se juega.
class GameRun {
  const GameRun({
    required this.nivel,
    required this.maxDuration,
    required this.elapsed,
    required this.finish,
    this.pauseClock,
    this.resumeClock,
    this.startClock,
  });

  final GameLevel nivel;

  /// Tiempo máximo del nivel (SCORING §2).
  final Duration maxDuration;

  /// Tiempo transcurrido desde que empezó la partida.
  final Duration Function() elapsed;

  final VoidCallback? pauseClock;
  final VoidCallback? resumeClock;

  /// Arranca el reloj visible de GameShell cuando el juego todavía no lo
  /// hizo por su cuenta (ver GameDefinition.startClockImmediately).
  /// null en los juegos que no lo necesitan (arrancan de inmediato, como
  /// siempre). Llamarlo más de una vez no hace nada raro: si el reloj ya
  /// está corriendo, seguir corriendo es el comportamiento normal.
  final VoidCallback? startClock;

  /// El juego llama a esto al terminar, con sus métricas.
  final void Function(CognitiveMetrics metrics) finish;
}

typedef GameBuilder = Widget Function(BuildContext context, GameRun run);

class GameDefinition {
  const GameDefinition({
    required this.gameType,
    required this.domain,
    required this.title,
    required this.instructions,
    required this.icon,
    required this.maxDuration,
    required this.builder,
    this.levelLabels = const {},
    this.levelPrompt = '¿En qué nivel quiere jugar?',
    this.showElapsedTime = true,
    this.phonePractice = false,
    this.startClockImmediately = true,
  });

  /// Uno de los 9 valores de SCORING §2.1, ej. 'memorice_clasico'.
  final String gameType;

  /// 'memoria', 'atencion' o 'praxias' (en la interfaz: Motricidad).
  final String domain;

  final String title;
  final String instructions;
  final IconData icon;
  final Duration Function(GameLevel nivel) maxDuration;
  final GameBuilder builder;
  final Map<GameLevel, String> levelLabels;
  final String levelPrompt;
  final bool showElapsedTime;
  final bool phonePractice;

  /// true (de siempre) en todos los juegos salvo que necesiten retrasar
  /// el arranque del reloj visible de GameShell (ver GameRun.startClock) —
  /// hoy, solo Memorice clásico, por su vista previa.
  final bool startClockImmediately;
}
