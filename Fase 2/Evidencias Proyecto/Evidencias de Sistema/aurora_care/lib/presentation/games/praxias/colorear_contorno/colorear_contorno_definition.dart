// lib/presentation/games/praxias/colorear_contorno/colorear_contorno_definition.dart
import 'package:flutter/material.dart';

import '../../shared/game_definition.dart';
import 'colorear_contorno_config.dart';
import 'colorear_contorno_screen.dart';

/// Definición de Colorear dentro del contorno (SCORING.md §2.1 y §2.4) para
/// registrarla en el catálogo. En la interfaz el dominio se muestra como
/// Motricidad.
const colorearContornoDefinition = GameDefinition(
  gameType: 'colorear_contorno',
  domain: 'praxias',
  title: 'Colorear dentro del contorno',
  instructions:
      'Pinte con el dedo el interior de la figura, sin salirse del borde. '
      'Verá 3 figuras distintas, una tras otra. Si levanta el dedo, puede '
      'seguir pintando donde quiera dentro de la figura.',
  icon: Icons.brush,
  maxDuration: tiempoMaximoColorear,
  builder: _builder,
);

Widget _builder(BuildContext context, GameRun run) {
  return ColorearContornoScreen(run: run);
}