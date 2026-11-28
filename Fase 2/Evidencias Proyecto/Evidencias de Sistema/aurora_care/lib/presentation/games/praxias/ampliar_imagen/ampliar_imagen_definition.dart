import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'ampliar_imagen_screen.dart';

const phoneZoomDefinition = GameDefinition(
  gameType: 'ampliar_imagen',
  domain: 'praxias',
  title: 'Ampliar una imagen',
  instructions:
      'Apoye dos dedos sobre la imagen y sepárelos para ampliarla. '
      'Después júntelos para volver al tamaño inicial. Puede realizar varios gestos, sin apuro. '
      'La imagen pertenece a esta práctica; no accedemos a sus fotos.',
  icon: Icons.zoom_in_rounded,
  phonePractice: true,
  showElapsedTime: false,
  maxDuration: _unlimited,
  levelPrompt: '¿Cómo quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Ampliación suave',
    GameLevel.intermedio: 'Ver más de cerca',
    GameLevel.avanzado: 'Ampliación mayor',
  },
  builder: _build,
);
Duration _unlimited(GameLevel _) => Duration.zero;
Widget _build(BuildContext context, GameRun run) => PhoneZoomScreen(run: run);
