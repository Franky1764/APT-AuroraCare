// lib/presentation/games/memoria/que_cambio/que_cambio_demo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

/// Ilustración animada de "cómo se juega" ¿Qué cambió?: dos imágenes
/// casi iguales; en una aparece un elemento con suavidad, un dedo se
/// mueve hasta ese lugar y lo toca, y aparece un visto verde. Pausa
/// breve y vuelve a empezar. Widget sin lógica del juego — solo
/// parámetros de tamaño, pensado para copiarse en los otros juegos de
/// Memoria.
///
/// Con MediaQuery.disableAnimations activo, muestra directamente el
/// cuadro final (el elemento ya visible y marcado), sin animar.
class QueCambioDemo extends StatefulWidget {
  const QueCambioDemo({super.key});

  @override
  State<QueCambioDemo> createState() => _QueCambioDemoState();
}

class _QueCambioDemoState extends State<QueCambioDemo>
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
          'Animación: dos imágenes casi iguales. En una de ellas aparece '
          'un elemento. Un dedo toca ese lugar y queda marcado con un '
          'visto verde.',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: MediaQuery.disableAnimationsOf(context)
                ? const _EscenaQueCambio(
                    apareceElemento: 1,
                    dedoVisible: 0,
                    checkVisible: 1,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return _EscenaQueCambio(
                        apareceElemento: _tramo(t, 0.10, 0.35),
                        dedoVisible: _tramo(t, 0.35, 0.55),
                        checkVisible: _tramo(t, 0.60, 0.80, salida: 0.92),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Progreso (0 a 1) de un tramo de la animación: sube entre [inicio] y
  /// [inicio]+ancho del tramo, se mantiene en 1, y si se da [salida]
  /// baja de vuelta a 0 entre [salida] y 1 (para que la escena quede en
  /// blanco otra vez antes de que el bucle reinicie).
  double _tramo(double t, double inicio, double fin, {double? salida}) {
    if (t < inicio) return 0;
    if (t < fin) return (t - inicio) / (fin - inicio);
    if (salida == null || t < salida) return 1;
    if (t < 1) return 1 - (t - salida) / (1 - salida);
    return 0;
  }
}

/// Cuadro estático en un momento de la animación (o el final, sin
/// animar). Cada parámetro es 0..1: cuánto se ve ese elemento.
class _EscenaQueCambio extends StatelessWidget {
  const _EscenaQueCambio({
    required this.apareceElemento,
    required this.dedoVisible,
    required this.checkVisible,
  });

  final double apareceElemento;
  final double dedoVisible;
  final double checkVisible;

  static final _caraBase = memoriceFaces[0];
  static final _caraNueva = memoriceFaces[1];

  Widget _imagen({required bool conElementoNuevo}) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(_caraBase.icon, color: _caraBase.color, size: 36),
          if (conElementoNuevo)
            Positioned(
              right: 10,
              bottom: 10,
              child: Opacity(
                opacity: apareceElemento,
                child: Icon(_caraNueva.icon, color: _caraNueva.color, size: 26),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _imagen(conElementoNuevo: false),
              const SizedBox(width: 20),
              _imagen(conElementoNuevo: true),
            ],
          ),
          // El dedo se desliza desde abajo hacia el elemento nuevo
          // (sobre la segunda imagen) y luego aparece el check en el
          // mismo lugar.
          Positioned(
            right: 24,
            bottom: 40 - 30 * dedoVisible,
            child: Opacity(
              opacity: dedoVisible * (1 - checkVisible),
              child: Icon(
                Icons.front_hand_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 18,
            child: Opacity(
              opacity: checkVisible,
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
