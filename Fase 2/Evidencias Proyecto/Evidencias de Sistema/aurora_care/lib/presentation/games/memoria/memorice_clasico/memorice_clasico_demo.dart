// lib/presentation/games/memoria/memorice_clasico/memorice_clasico_demo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

/// Ilustración animada de "cómo se juega" Memorice clásico: una
/// cuadrícula de 4 cartas. Primero se ven las 4 boca arriba (vista
/// previa); se tapan todas juntas; luego un dedo toca dos cartas
/// iguales, que quedan destapadas con un visto verde. Pausa breve y
/// vuelve a empezar. Widget sin lógica del juego — solo parámetros de
/// tamaño, siguiendo el mismo patrón que QueCambioDemo para copiarse en
/// los otros juegos de Memoria.
///
/// Con MediaQuery.disableAnimations activo, muestra directamente el
/// cuadro final (el par ya destapado y marcado), sin animar.
class MemoriceClasicoDemo extends StatefulWidget {
  const MemoriceClasicoDemo({super.key});

  @override
  State<MemoriceClasicoDemo> createState() => _MemoriceClasicoDemoState();
}

class _MemoriceClasicoDemoState extends State<MemoriceClasicoDemo>
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
          'Animación: se ven 4 cartas boca arriba. Se tapan todas juntas. '
          'Luego un dedo toca dos cartas iguales, que quedan destapadas '
          'con un visto verde.',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: MediaQuery.disableAnimationsOf(context)
                ? const _EscenaMemoriceClasico(
                    aFlip: 1,
                    bFlip: 1,
                    checkAB: 1,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return _EscenaMemoriceClasico(
                        aFlip: _vueltaConVistaPrevia(
                          t,
                          taparInicio: 0.24,
                          taparFin: 0.32,
                          toqueInicio: 0.44,
                          toqueFin: 0.50,
                        ),
                        bFlip: _vueltaConVistaPrevia(
                          t,
                          taparInicio: 0.24,
                          taparFin: 0.32,
                          toqueInicio: 0.52,
                          toqueFin: 0.58,
                        ),
                        checkAB: _tramo(t, 0.58, 0.66),
                        dedoA: _pulso(t, 0.38, 0.50),
                        dedoB: _pulso(t, 0.50, 0.62),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Progreso (0 a 1) de una carta que: se ve boca arriba (vista previa),
  /// se tapa entre [taparInicio] y [taparFin], queda tapada esperando el
  /// toque, se destapa entre [toqueInicio] y [toqueFin] al tocarla, y
  /// queda destapada (acierto) hasta que el bucle reinicia.
  double _vueltaConVistaPrevia(
    double t, {
    required double taparInicio,
    required double taparFin,
    required double toqueInicio,
    required double toqueFin,
  }) {
    if (t < taparInicio) return 1;
    if (t < taparFin) return 1 - (t - taparInicio) / (taparFin - taparInicio);
    if (t < toqueInicio) return 0;
    if (t < toqueFin) return (t - toqueInicio) / (toqueFin - toqueInicio);
    return 1;
  }

  /// Progreso (0 a 1) de un tramo de la animación: sube entre [inicio] y
  /// [fin] y se mantiene en 1 (usado para el visto de acierto).
  double _tramo(double t, double inicio, double fin) {
    if (t < inicio) return 0;
    if (t < fin) return (t - inicio) / (fin - inicio);
    return 1;
  }

  /// Pulso triangular (0 a 1 a 0) dentro de [inicio, fin]: usado para el
  /// dedo que aparece sobre una carta y luego se retira.
  double _pulso(double t, double inicio, double fin) {
    if (t < inicio || t > fin) return 0;
    final mitad = (inicio + fin) / 2;
    if (t < mitad) return (t - inicio) / (mitad - inicio);
    return 1 - (t - mitad) / (fin - mitad);
  }
}

/// Cuadro estático en un momento de la animación (o el final, sin
/// animar). Cada parámetro de carta es 0..1: cuánto se ve destapada; el
/// de dedo es 0..1: cuánto se ve el dedo tocando esa carta.
class _EscenaMemoriceClasico extends StatelessWidget {
  const _EscenaMemoriceClasico({
    required this.aFlip,
    required this.bFlip,
    required this.checkAB,
    this.dedoA = 0,
    this.dedoB = 0,
  });

  final double aFlip;
  final double bFlip;
  final double checkAB;
  final double dedoA;
  final double dedoB;

  static final _caraIgual = memoriceFaces[0];

  static const double _tamCarta = 40;

  Widget _cartaBase() {
    return Container(
      width: _tamCarta,
      height: _tamCarta,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
    );
  }

  Widget _carta({
    required double flip,
    required MemoriceFace cara,
    double check = 0,
  }) {
    return SizedBox(
      width: _tamCarta,
      height: _tamCarta,
      child: Stack(
        children: [
          _cartaBase(),
          if (flip > 0)
            Opacity(
              opacity: flip,
              child: Container(
                width: _tamCarta,
                height: _tamCarta,
                decoration: BoxDecoration(
                  color: check > 0
                      ? AppColors.successBackground
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: check > 0 ? AppColors.success : AppColors.border,
                    width: check > 0 ? 2 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(cara.icon, color: cara.color, size: 20),
                    if (check > 0)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Opacity(
                          opacity: check,
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dedo(double visible) {
    return Opacity(
      opacity: visible,
      child: Icon(
        Icons.front_hand_rounded,
        color: AppColors.primary,
        size: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    return SizedBox(
      width: _tamCarta * 2 + gap,
      height: _tamCarta * 2 + gap,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _carta(flip: aFlip, cara: _caraIgual, check: checkAB),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _carta(flip: bFlip, cara: _caraIgual, check: checkAB),
          ),
          Positioned(left: 0, bottom: 0, child: _cartaBase()),
          Positioned(right: 0, bottom: 0, child: _cartaBase()),
          Positioned(
            left: _tamCarta - 14,
            top: _tamCarta - 14,
            child: _dedo(dedoA),
          ),
          Positioned(
            right: _tamCarta - 14,
            top: _tamCarta - 14,
            child: _dedo(dedoB),
          ),
        ],
      ),
    );
  }
}
