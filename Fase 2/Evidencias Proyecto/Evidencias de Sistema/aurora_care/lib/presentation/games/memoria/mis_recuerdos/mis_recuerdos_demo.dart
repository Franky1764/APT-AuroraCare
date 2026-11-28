// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_demo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Ilustración animada de "cómo se juega" Mis recuerdos: aparece una
/// pregunta con 4 opciones; un dedo toca una de ellas y aparece un
/// visto verde. Pausa breve y vuelve a empezar. Widget sin lógica del
/// juego — solo parámetros de tamaño, siguiendo el mismo patrón que
/// QueCambioDemo, MemoriceClasicoDemo y MemoriceSecuenciasDemo para
/// copiarse en los otros juegos de Memoria.
///
/// Con MediaQuery.disableAnimations activo, muestra directamente el
/// cuadro final (la opción ya elegida y marcada), sin animar.
class MisRecuerdosDemo extends StatefulWidget {
  const MisRecuerdosDemo({super.key});

  @override
  State<MisRecuerdosDemo> createState() => _MisRecuerdosDemoState();
}

class _MisRecuerdosDemoState extends State<MisRecuerdosDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Animación: aparece una pregunta con 4 opciones. Un dedo '
          'toca una de ellas y aparece un visto verde.',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: MediaQuery.disableAnimationsOf(context)
                ? const _EscenaMisRecuerdos(dedo: 0, elegida: 1, check: 1)
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return _EscenaMisRecuerdos(
                        dedo: _pulso(t, 0.10, 0.34),
                        elegida: _tramo(t, 0.20, 0.30),
                        check: _tramo(t, 0.34, 0.42),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Progreso (0 a 1) de un tramo de la animación: sube entre [inicio] y
  /// [fin] y se mantiene en 1 hasta el final.
  double _tramo(double t, double inicio, double fin) {
    if (t < inicio) return 0;
    if (t < fin) return (t - inicio) / (fin - inicio);
    return 1;
  }

  /// Pulso triangular (0 a 1 a 0) dentro de [inicio, fin]: usado para el
  /// dedo que aparece sobre una opción y luego se retira.
  double _pulso(double t, double inicio, double fin) {
    if (t < inicio || t > fin) return 0;
    final mitad = (inicio + fin) / 2;
    if (t < mitad) return (t - inicio) / (mitad - inicio);
    return 1 - (t - mitad) / (fin - mitad);
  }
}

/// Cuadro estático en un momento de la animación (o el final, sin
/// animar). [dedo] y [check] son 0..1: cuánto se ven. [elegida] es 0..1:
/// cuánto se resalta la segunda opción (la que se "elige").
class _EscenaMisRecuerdos extends StatelessWidget {
  const _EscenaMisRecuerdos({
    required this.dedo,
    required this.elegida,
    required this.check,
  });

  final double dedo;
  final double elegida;
  final double check;

  static const double _anchoOpcion = 150;
  static const double _altoOpcion = 16;
  static const double _gap = 5;

  Widget _opcion({required bool esLaElegida}) {
    final activo = esLaElegida ? elegida : 0.0;
    return Container(
      width: _anchoOpcion,
      height: _altoOpcion,
      decoration: BoxDecoration(
        color: activo > 0
            ? Color.lerp(AppColors.surface, AppColors.successBackground, activo)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: activo > 0 ? AppColors.success : AppColors.border,
          width: activo > 0 ? 2 : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _anchoOpcion + 20,
      height: 4 * _altoOpcion + 3 * _gap + 12,
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 0,
            child: Container(
              width: _anchoOpcion * 0.7,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 12,
            child: Column(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  _opcion(esLaElegida: i == 1),
                ],
              ],
            ),
          ),
          Positioned(
            left: 10,
            top: 12 + _altoOpcion + _gap + _altoOpcion / 2 - 9,
            child: Opacity(
              opacity: dedo,
              child: Icon(
                Icons.front_hand_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 12 + _altoOpcion + _gap + _altoOpcion / 2 - 8,
            child: Opacity(
              opacity: check,
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
