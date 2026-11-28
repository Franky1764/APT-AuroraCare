import 'package:flutter/material.dart';

import '../../../../domain/entities/game_level.dart';
import '../../shared/game_definition.dart';
import 'arrastrar_elementos_screen.dart';

const phoneDragDefinition = GameDefinition(
  gameType: 'arrastrar_elementos',
  domain: 'praxias',
  title: 'Arrastrar a su lugar',
  instructions:
      'Mantenga presionada la imagen hasta que se destaque. '
      'Sin levantar el dedo, muévala hacia el recuadro y suéltela cuando se resalte. '
      'Puede repetirlo con calma. Usaremos elementos de práctica; sus fotos y aplicaciones no se modifican.',
  icon: Icons.open_with_rounded,
  phonePractice: true,
  showElapsedTime: false,
  maxDuration: _unlimitedPractice,
  levelPrompt: '¿Cómo quiere practicar?',
  levelLabels: {
    GameLevel.facil: 'Destino amplio',
    GameLevel.intermedio: 'Destino mediano',
    GameLevel.avanzado: 'Destino más ajustado',
  },
  builder: _build,
);
Duration _unlimitedPractice(GameLevel _) => Duration.zero;
Widget _build(BuildContext context, GameRun run) => PhoneDragScreen(run: run);
