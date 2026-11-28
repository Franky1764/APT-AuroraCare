import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'deslizar_imagenes_screen.dart';

const phoneSwipeDefinition = GameDefinition(
  gameType: 'deslizar_imagenes',
  domain: 'praxias',
  title: 'Deslizar entre imágenes',
  instructions:
      'Apoye el dedo sobre la imagen, muévalo hacia el lado indicado y levántelo. '
      'Practicará pasar a otra imagen y volver a la anterior. '
      'No hay límite de tiempo. Usaremos imágenes de práctica, sin acceder a sus fotos.',
  icon: Icons.swipe_rounded,
  showElapsedTime: false,
  phonePractice: true,
  maxDuration: _unlimitedPractice,
  levelPrompt: '¿Cómo quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Deslizamientos cortos',
    GameLevel.intermedio: 'Recorridos medios',
    GameLevel.avanzado: 'Recorridos más amplios',
  },
  builder: _build,
);

Duration _unlimitedPractice(GameLevel _) => Duration.zero;
Widget _build(BuildContext context, GameRun run) => PhoneSwipeScreen(run: run);
