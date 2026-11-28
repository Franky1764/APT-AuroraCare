// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencias_demo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

/// Ilustración animada de "cómo se juega" Memorice de secuencias: 3
/// imágenes se iluminan en orden (1, 2, 3); luego un dedo las toca en
/// ese mismo orden y aparece un visto verde. Pausa breve y vuelve a
/// empezar. Widget sin lógica del juego — solo parámetros de tamaño,
/// siguiendo el mismo patrón que QueCambioDemo y MemoriceClasicoDemo
/// para copiarse en los otros juegos de Memoria.
///
/// Con MediaQuery.disableAnimations activo, muestra directamente el
/// cuadro final (las 3 tocadas en orden y marcadas), sin animar.
class MemoriceSecuenciasDemo extends StatefulWidget {
  const MemoriceSecuenciasDemo({super.key});

  @override
  State<MemoriceSecuenciasDemo> createState() =>
      _MemoriceSecuenciasDemoState();
}

class _MemoriceSecuenciasDemoState extends State<MemoriceSecuenciasDemo>
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
          'Animación: 3 imágenes se iluminan en orden. Luego un dedo '
          'las toca en ese mismo orden y aparece un visto verde.',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: MediaQuery.disableAnimationsOf(context)
                ? const _EscenaMemoriceSecuencias(
                    resaltado1: 0,
                    resaltado2: 0,
                    resaltado3: 0,
                    tocado1: 1,
                    tocado2: 1,
                    tocado3: 1,
                    dedo1: 0,
                    dedo2: 0,
                    dedo3: 0,
                    check: 1,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return _EscenaMemoriceSecuencias(
                        resaltado1: _tramo(t, 0.05, 0.14, salida: 0.19),
                        resaltado2: _tramo(t, 0.22, 0.31, salida: 0.36),
                        resaltado3: _tramo(t, 0.39, 0.48, salida: 0.53),
                        tocado1: _tramo(t, 0.56, 0.62),
                        tocado2: _tramo(t, 0.66, 0.72),
                        tocado3: _tramo(t, 0.76, 0.82),
                        dedo1: _pulso(t, 0.53, 0.63),
                        dedo2: _pulso(t, 0.63, 0.73),
                        dedo3: _pulso(t, 0.73, 0.83),
                        check: _tramo(t, 0.83, 0.90),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Progreso (0 a 1) de un tramo de la animación: sube entre [inicio] y
  /// [fin], se mantiene en 1, y si se da [salida] baja de vuelta a 0
  /// entre [salida] y 1 (para que la imagen se apague antes de iluminar
  /// la siguiente, como en el juego real).
  double _tramo(double t, double inicio, double fin, {double? salida}) {
    if (t < inicio) return 0;
    if (t < fin) return (t - inicio) / (fin - inicio);
    if (salida == null || t < salida) return 1;
    if (t < 1) return 1 - (t - salida) / (1 - salida);
    return 0;
  }

  /// Pulso triangular (0 a 1 a 0) dentro de [inicio, fin]: usado para el
  /// dedo que aparece sobre una imagen y luego se retira.
  double _pulso(double t, double inicio, double fin) {
    if (t < inicio || t > fin) return 0;
    final mitad = (inicio + fin) / 2;
    if (t < mitad) return (t - inicio) / (mitad - inicio);
    return 1 - (t - mitad) / (fin - mitad);
  }
}

/// Cuadro estático en un momento de la animación (o el final, sin
/// animar). Cada parámetro es 0..1: cuánto se ve ese estado.
class _EscenaMemoriceSecuencias extends StatelessWidget {
  const _EscenaMemoriceSecuencias({
    required this.resaltado1,
    required this.resaltado2,
    required this.resaltado3,
    required this.tocado1,
    required this.tocado2,
    required this.tocado3,
    required this.dedo1,
    required this.dedo2,
    required this.dedo3,
    required this.check,
  });

  final double resaltado1;
  final double resaltado2;
  final double resaltado3;
  final double tocado1;
  final double tocado2;
  final double tocado3;
  final double dedo1;
  final double dedo2;
  final double dedo3;
  final double check;

  static final _caras = [memoriceFaces[0], memoriceFaces[1], memoriceFaces[2]];

  static const double _tamImagen = 32;

  Widget _imagen(int indice, double activo) {
    final cara = _caras[indice];
    return Container(
      width: _tamImagen,
      height: _tamImagen,
      decoration: BoxDecoration(
        color: activo > 0
            ? Color.lerp(AppColors.surface, AppColors.primaryLight, activo)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activo > 0 ? AppColors.primary : AppColors.border,
          width: activo > 0 ? 2 : 1,
        ),
      ),
      child: Center(child: Icon(cara.icon, color: cara.color, size: 18)),
    );
  }

  Widget _dedo(double visible) {
    return Opacity(
      opacity: visible,
      child: Icon(
        Icons.front_hand_rounded,
        color: AppColors.primary,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final activo1 = resaltado1 > 0 ? resaltado1 : tocado1;
    final activo2 = resaltado2 > 0 ? resaltado2 : tocado2;
    final activo3 = resaltado3 > 0 ? resaltado3 : tocado3;
    return SizedBox(
      width: _tamImagen * 3 + gap * 2,
      height: _tamImagen + 14,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Row(
              children: [
                _imagen(0, activo1),
                const SizedBox(width: gap),
                _imagen(1, activo2),
                const SizedBox(width: gap),
                _imagen(2, activo3),
              ],
            ),
          ),
          Positioned(
            left: _tamImagen / 2 - 8,
            bottom: 0,
            child: _dedo(dedo1),
          ),
          Positioned(
            left: _tamImagen + gap + _tamImagen / 2 - 8,
            bottom: 0,
            child: _dedo(dedo2),
          ),
          Positioned(
            left: 2 * (_tamImagen + gap) + _tamImagen / 2 - 8,
            bottom: 0,
            child: _dedo(dedo3),
          ),
          Positioned(
            right: 0,
            top: 0,
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
