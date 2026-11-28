import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'buscar_en_lista_screen.dart';

const phoneListDefinition = GameDefinition(
  gameType: 'buscar_en_lista',
  domain: 'praxias',
  title: 'Buscar en una lista',
  instructions:
      'Deslice la lista hacia arriba o abajo hasta encontrar el lugar indicado. '
      'Después toque su nombre. La indicación seguirá a la vista y puede tomarse su tiempo. '
      'Todos los lugares pertenecen a esta práctica; no abriremos otras aplicaciones.',
  icon: Icons.format_list_bulleted_rounded,
  phonePractice: true,
  showElapsedTime: false,
  maxDuration: _unlimited,
  levelPrompt: '¿Cómo quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Lista breve',
    GameLevel.intermedio: 'Lista mediana',
    GameLevel.avanzado: 'Lista más larga',
  },
  builder: _build,
);
Duration _unlimited(GameLevel _) => Duration.zero;
Widget _build(BuildContext context, GameRun run) => PhoneListScreen(run: run);
