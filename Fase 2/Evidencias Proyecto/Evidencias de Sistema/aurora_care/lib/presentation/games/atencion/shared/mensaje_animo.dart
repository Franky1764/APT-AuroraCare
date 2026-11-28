// lib/presentation/games/atencion/shared/mensaje_animo.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// "¡Muy bien, Rosa!" o "¡Muy bien!" si no hay nombre.
String saludoConNombre(String texto, String? nombre) =>
    nombre == null ? '¡$texto!' : '¡$texto, $nombre!';

/// Tarjeta grande que aparece con un rebote sobre el tablero, con un ícono
/// que entra girando. La usan los juegos de Atención para felicitar, animar
/// a seguir y celebrar el final. Nunca muestra puntaje.
class MensajeAnimo extends StatelessWidget {
  const MensajeAnimo({
    super.key,
    required this.icono,
    required this.colorIcono,
    required this.fondo,
    required this.titulo,
    this.texto,
  });

  /// Felicitación al acertar.
  factory MensajeAnimo.acierto({Key? key, String? nombre, String? texto}) =>
      MensajeAnimo(
        key: key,
        icono: Icons.star_rounded,
        colorIcono: AppColors.accent,
        fondo: AppColors.successBackground,
        titulo: saludoConNombre('Muy bien', nombre),
        texto: texto,
      );

  /// Ánimo para seguir después de un error. Sin palabras negativas.
  factory MensajeAnimo.intento({Key? key, String? nombre, String? texto}) =>
      MensajeAnimo(
        key: key,
        icono: Icons.refresh_rounded,
        colorIcono: AppColors.primary,
        fondo: AppColors.primaryLight,
        titulo: saludoConNombre('Buen intento', nombre),
        texto: texto,
      );

  /// Celebración al terminar la partida.
  factory MensajeAnimo.terminado({Key? key, String? nombre, String? texto}) =>
      MensajeAnimo(
        key: key,
        icono: Icons.celebration_rounded,
        colorIcono: AppColors.accent,
        fondo: AppColors.successBackground,
        titulo: saludoConNombre('Excelente trabajo', nombre),
        texto: texto,
      );

  final IconData icono;
  final Color colorIcono;
  final Color fondo;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, escala, child) =>
            Transform.scale(scale: escala, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.rotate(
                  angle: (1 - t) * -1.2,
                  child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
                ),
                child: Icon(icono, size: 80, color: colorIcono),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: AppTextStyles.greeting,
                textAlign: TextAlign.center,
              ),
              if (texto != null) ...[
                const SizedBox(height: 8),
                Text(
                  texto!,
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
