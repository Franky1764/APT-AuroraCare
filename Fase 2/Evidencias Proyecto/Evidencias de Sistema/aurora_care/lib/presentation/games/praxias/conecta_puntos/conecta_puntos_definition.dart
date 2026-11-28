// lib/presentation/games/praxias/conecta_puntos/conecta_puntos_definition.dart
import 'package:flutter/material.dart';

import '../../shared/game_definition.dart';
import '../../../../domain/entities/game_level.dart';
import 'conecta_puntos_config.dart';
import 'conecta_puntos_screen.dart';

/// Definición de Conecta los puntos (SCORING.md §2.1 y §2.4) para registrarla
/// en GameLevelScreen. En la interfaz el dominio se muestra como Motricidad.
const conectaPuntosDefinition = GameDefinition(
  gameType: 'conecta_puntos',
  domain: 'praxias',
  title: 'Conecta los puntos',
  instructions:
      'Una los puntos en orden, desde el 1, y vuelva al 1 para cerrar la figura. '
      'Priorice la precisión y practique a su ritmo. Puede levantar el dedo, '
      'retomar donde quedó, pausar y ver una demostración. Practicará tres figuras.',
  showElapsedTime: false,
  levelPrompt: '¿Qué quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Figuras con pocos puntos',
    GameLevel.intermedio: 'Figuras con más puntos',
    GameLevel.avanzado: 'Figuras con más detalle',
  },
  icon: Icons.timeline,
  maxDuration: tiempoMaximoConecta,
  builder: _builder,
);

Widget _builder(BuildContext context, GameRun run) {
  return ConectaPuntosScreen(run: run);
}
