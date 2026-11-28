import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'toque_preciso_screen.dart';

const phoneTouchDefinition = GameDefinition(
  gameType: 'toque_preciso',
  domain: 'praxias',
  title: 'Tocar botones e imágenes',
  instructions:
      'Practique tocar un botón o una imagen con el dedo. '
      'Cada elemento permanecerá quieto mientras lo intenta. '
      'Puede hacerlo a su ritmo y descansar cuando quiera. '
      'Todo ocurre dentro de esta práctica.',
  icon: Icons.touch_app_outlined,
  maxDuration: _unlimitedPractice,
  showElapsedTime: false,
  phonePractice: true,
  levelPrompt: '¿Cómo quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Elementos grandes',
    GameLevel.intermedio: 'Distintas posiciones',
    GameLevel.avanzado: 'Toques más precisos',
  },
  builder: _build,
);

Duration _unlimitedPractice(GameLevel _) => Duration.zero;
Widget _build(BuildContext context, GameRun run) => PhoneTouchScreen(run: run);
