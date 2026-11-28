// lib/presentation/games/memoria/recuerde_numero/recuerde_numero_demo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Ilustración animada de "cómo se juega" Recuerde el número: aparece
/// un número de 3 dígitos, desaparece, y los dígitos se escriben uno a
/// uno en un casillero, con un visto verde al final. Pausa breve y
/// vuelve a empezar. Widget sin lógica del juego — solo parámetros de
/// tamaño, siguiendo el mismo patrón que QueCambioDemo,
/// MemoriceClasicoDemo, MemoriceSecuenciasDemo y MisRecuerdosDemo para
/// copiarse en los otros juegos de Memoria.
///
/// Con MediaQuery.disableAnimations activo, muestra directamente el
/// cuadro final (los 3 casilleros llenos y marcados), sin animar.
class RecuerdeNumeroDemo extends StatefulWidget {
  const RecuerdeNumeroDemo({super.key});

  @override
  State<RecuerdeNumeroDemo> createState() => _RecuerdeNumeroDemoState();
}

class _RecuerdeNumeroDemoState extends State<RecuerdeNumeroDemo>
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
          'Animación: aparece un número de 3 dígitos y desaparece. '
          'Luego los dígitos se escriben uno a uno en un casillero, y '
          'aparece un visto verde.',
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
                ? const _EscenaRecuerdeNumero(
                    numeroVisible: 0,
                    casillero1: 1,
                    casillero2: 1,
                    casillero3: 1,
                    check: 1,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return _EscenaRecuerdeNumero(
                        numeroVisible: _tramo(t, 0, 0.08, salida: 0.20),
                        casillero1: _tramo(t, 0.32, 0.38),
                        casillero2: _tramo(t, 0.44, 0.50),
                        casillero3: _tramo(t, 0.56, 0.62),
                        check: _tramo(t, 0.66, 0.74),
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
  /// entre [salida] y 1.
  double _tramo(double t, double inicio, double fin, {double? salida}) {
    if (t < inicio) return 0;
    if (t < fin) return (t - inicio) / (fin - inicio);
    if (salida == null || t < salida) return 1;
    if (t < 1) return 1 - (t - salida) / (1 - salida);
    return 0;
  }
}

/// Cuadro estático en un momento de la animación (o el final, sin
/// animar). Cada parámetro es 0..1: cuánto se ve ese estado.
class _EscenaRecuerdeNumero extends StatelessWidget {
  const _EscenaRecuerdeNumero({
    required this.numeroVisible,
    required this.casillero1,
    required this.casillero2,
    required this.casillero3,
    required this.check,
  });

  final double numeroVisible;
  final double casillero1;
  final double casillero2;
  final double casillero3;
  final double check;

  static const List<String> _digitos = ['4', '8', '2'];
  static const double _anchoCasillero = 28;
  static const double _altoCasillero = 36;
  static const double _gap = 6;

  Widget _casillero(int indice, double lleno) {
    return Container(
      width: _anchoCasillero,
      height: _altoCasillero,
      decoration: BoxDecoration(
        color: lleno > 0
            ? Color.lerp(AppColors.surface, AppColors.primaryLight, lleno)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: lleno > 0 ? AppColors.primary : AppColors.border,
          width: lleno > 0 ? 2 : 1,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: lleno,
          child: Text(_digitos[indice], style: AppTextStyles.cardTitle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _anchoCasillero * 3 + _gap * 4 + 22,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: numeroVisible,
            child: Text(
              _digitos.join(' '),
              style: AppTextStyles.greeting.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          Opacity(
            opacity: 1 - numeroVisible,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _casillero(0, casillero1),
                const SizedBox(width: _gap),
                _casillero(1, casillero2),
                const SizedBox(width: _gap),
                _casillero(2, casillero3),
                const SizedBox(width: _gap),
                Opacity(
                  opacity: check,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
