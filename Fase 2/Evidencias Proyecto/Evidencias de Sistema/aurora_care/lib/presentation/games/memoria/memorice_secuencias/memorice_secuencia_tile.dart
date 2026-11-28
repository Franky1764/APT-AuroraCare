// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencia_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/accessibility_providers.dart';

import '../../../../core/constants/app_colors.dart';
import '../memoria_faces.dart';

/// Una imagen del panel de respuesta (6 fijas, mismas posiciones toda la
/// partida). Mantiene su propia animación breve de toque (independiente
/// del estado del controller) para que la retroalimentación sea
/// inmediata, sin esperar a que se repinte el resto de la pantalla.
class MemoriceSecuenciaTile extends ConsumerStatefulWidget {
  const MemoriceSecuenciaTile({
    super.key,
    required this.face,
    required this.isHighlighted,
    required this.isDimmed,
    required this.isWrong,
    required this.onTap,
  });

  final MemoriceFace face;

  /// true mientras esta imagen es la que se está mostrando de la secuencia.
  final bool isHighlighted;

  /// true durante "mostrando" para las imágenes que no son la resaltada:
  /// se ven atenuadas, reforzando que no es su turno.
  final bool isDimmed;

  /// true si la persona la tocó por error en la última ronda.
  final bool isWrong;
  final VoidCallback? onTap;

  @override
  ConsumerState<MemoriceSecuenciaTile> createState() =>
      _MemoriceSecuenciaTileState();
}

class _MemoriceSecuenciaTileState extends ConsumerState<MemoriceSecuenciaTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _tapScale = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_tapController);
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    _vibrarSeleccion();
    _tapController.forward(from: 0).then((_) {
      if (mounted) _tapController.reverse();
    });
    onTap();
  }

  /// Si el dispositivo no tiene vibración (o el canal falla), no debe
  /// interrumpir el juego.
  void _vibrarSeleccion() {
    ref.read(exerciseVibrationProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    final Color borderColor;
    final Color backgroundColor;
    final double borderWidth;
    if (widget.isWrong) {
      borderColor = AppColors.error;
      backgroundColor = AppColors.errorBackground;
      borderWidth = 3;
    } else if (widget.isHighlighted) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primaryLight;
      borderWidth = 3;
    } else {
      borderColor = AppColors.border;
      backgroundColor = AppColors.surface;
      borderWidth = 1;
    }

    return Semantics(
      label: widget.face.name,
      button: true,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.isDimmed ? 0.35 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap == null ? null : _handleTap,
              child: ScaleTransition(
                scale: _tapScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: radius,
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                  child: Center(
                    child: Icon(
                      widget.face.icon,
                      color: widget.face.color,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
