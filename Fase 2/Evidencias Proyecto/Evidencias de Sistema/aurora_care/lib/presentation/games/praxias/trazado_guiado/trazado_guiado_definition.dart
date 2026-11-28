// lib/presentation/games/praxias/trazado_guiado/trazado_guiado_definition.dart
import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';

import '../../shared/game_definition.dart';
import 'trazado_guiado_config.dart';
import 'trazado_guiado_screen.dart';

/// Definición de Trazado guiado (SCORING.md §2.1 y §2.4) para registrarla en
/// el catálogo. En la interfaz el dominio se muestra como Motricidad.
const trazadoGuiadoDefinition = GameDefinition(
  gameType: 'trazado_guiado',
  domain: 'praxias',
  title: 'Trazado guiado',
  instructions:
      'Siga el recorrido hasta el final con la mayor precisión que pueda. '
      'Puede hacerlo a su ritmo, levantar el dedo y retomar cuando quiera. '
      'Practicará tres recorridos y podrá pedir una ayuda o ver una demostración.',
  icon: Icons.gesture,
  maxDuration: tiempoMaximoTrazado,
  builder: _builder,
  levelPrompt: '¿Qué quiere practicar?',
  showElapsedTime: false,
  levelLabels: {
    GameLevel.facil: 'Líneas y curvas',
    GameLevel.intermedio: 'Formas',
    GameLevel.avanzado: 'Recorridos con más detalle',
  },
);

Widget _builder(BuildContext context, GameRun run) {
  return TrazadoGuiadoScreen(run: run);
}
