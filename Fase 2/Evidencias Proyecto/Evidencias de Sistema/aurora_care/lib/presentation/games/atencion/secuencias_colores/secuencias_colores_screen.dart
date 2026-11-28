// lib/presentation/games/atencion/secuencias_colores/secuencias_colores_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';
import '../shared/jugador_nombre_provider.dart';
import 'secuencias_colores_controller.dart';

/// Un color del tablero. Además del color lleva un ícono y un nombre, para
/// que se pueda jugar aunque la persona distinga mal algunos colores.
class SecuenciaColor {
  const SecuenciaColor(this.nombre, this.color, this.icono, this.colorTexto);
  final String nombre;
  final Color color;
  final IconData icono;

  /// Color del ícono y del nombre. Contraste mínimo 4.5:1 (ARCHITECTURE §11).
  final Color colorTexto;
}

/// Los 4 colores, en el mismo orden que los valores 0..3 del controller.
/// Contraste del texto: rojo 5.6:1, azul 5.8:1, verde 5.1:1, amarillo 6.9:1.
final secuenciaColores = [
  SecuenciaColor('Rojo', Color(0xFFC62828), Icons.favorite, Colors.white),
  SecuenciaColor('Azul', Color(0xFF1565C0), Icons.water_drop, Colors.white),
  SecuenciaColor('Verde', Color(0xFF2E7D32), Icons.eco, Colors.white),
  SecuenciaColor(
    'Amarillo',
    Color(0xFFFBC02D),
    Icons.wb_sunny,
    AppColors.textPrimary,
  ),
];

/// Cuánto se ve la celebración final antes de pasar al resultado.
const Duration secuenciasPausaCelebracion = Duration(milliseconds: 2000);

/// Tablero de Secuencias de colores. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y tiempo; este widget solo juega la partida y
/// llama a run.finish() al terminar la última ronda.
class SecuenciasColoresScreen extends ConsumerStatefulWidget {
  const SecuenciasColoresScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<SecuenciasColoresScreen> createState() =>
      _SecuenciasColoresScreenState();
}

class _SecuenciasColoresScreenState
    extends ConsumerState<SecuenciasColoresScreen> {
  Timer? _finTimer;

  /// Aciertos consecutivos (rondas), para SoundEffect.acierto(_racha). Se
  /// reinicia a 0 en cada error y empieza en 0 al abrir la partida.
  int _racha = 0;

  @override
  void dispose() {
    _finTimer?.cancel();
    super.dispose();
  }

  void _sonarEfecto(SoundEffect effect) {
    if (ref.read(soundsEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).play(effect));
    }
  }

  String _mensaje(SecuenciasColoresState s) {
    switch (s.fase) {
      case SecuenciaFase.mostrando:
        return 'Mire con atención…';
      case SecuenciaFase.turno:
        return 'Su turno: toque los colores en el mismo orden';
      case SecuenciaFase.acierto:
      case SecuenciaFase.error:
      case SecuenciaFase.terminado:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = secuenciasColoresControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final nombre = ref.watch(jugadorNombreProvider);

    // Al terminar, se deja ver la celebración y luego se pasa al resultado.
    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        final metrics = next.metrics!;
        _finTimer?.cancel();
        _finTimer = Timer(secuenciasPausaCelebracion, () {
          if (mounted) widget.run.finish(metrics);
        });
      }
      if (previous == null) return;

      // Nota de cada color encendido durante el revelado: ligada al
      // color (índice 0..3), no al paso, para que el mismo color
      // siempre suene igual, tanto al revelarse como al tocarlo.
      if (next.fase == SecuenciaFase.mostrando &&
          next.iluminado != null &&
          next.iluminado != previous.iluminado) {
        _sonarEfecto(SoundEffect.secuenciaNota(next.iluminado!));
      }

      // Toque que avanza la entrada SIN completar la ronda: la nota del
      // color tocado. Si el toque completa la ronda o se equivoca, el
      // fase ya no es "turno" (pasa a acierto/error) — no se suena la
      // nota ahí, solo el acierto/error (más abajo), para que no se
      // pisen.
      if (next.fase == SecuenciaFase.turno &&
          next.posicionEntrada > previous.posicionEntrada) {
        _sonarEfecto(SoundEffect.secuenciaNota(next.secuencia[next.posicionEntrada - 1]));
      }

      // Acierto/error al resolver la ronda, con racha.
      if (previous.fase == SecuenciaFase.turno &&
          next.fase == SecuenciaFase.acierto) {
        _racha++;
        _sonarEfecto(SoundEffect.acierto(_racha));
      } else if (previous.fase == SecuenciaFase.turno &&
          next.fase == SecuenciaFase.error) {
        _racha = 0;
        _sonarEfecto(SoundEffect.errorSuave);
      }
    });

    final esTurno = state.fase == SecuenciaFase.turno;
    final hayMensajeGrande = state.fase == SecuenciaFase.acierto ||
        state.fase == SecuenciaFase.error ||
        state.fase == SecuenciaFase.terminado;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              'Ronda ${state.ronda} de $secuenciasRondasPorPartida',
              key: ValueKey(state.ronda),
              style: AppTextStyles.bodySecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _mensaje(state),
                key: ValueKey(state.fase),
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _Progreso(
            total: state.longitud,
            completados: state.fase == SecuenciaFase.mostrando
                ? state.pasoMostrado
                : state.posicionEntrada,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 16.0;
                    final ancho = (constraints.maxWidth - spacing) / 2;
                    final alto = (constraints.maxHeight - spacing) / 2;
                    final size =
                        (ancho < alto ? ancho : alto).clamp(96.0, 170.0);
                    return Center(
                      child: SizedBox(
                        width: size * 2 + spacing,
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (var i = 0; i < secuenciaColores.length; i++)
                              _BotonColor(
                                key: Key('secuencias_color_$i'),
                                size: size,
                                datos: secuenciaColores[i],
                                encendido: state.iluminado == i,
                                atenuado:
                                    state.fase == SecuenciaFase.mostrando &&
                                        state.iluminado != i,
                                onTap: esTurno
                                    ? () => controller.tocarColor(i)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !hayMensajeGrande,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: hayMensajeGrande
                          ? _MensajeAnimo(
                              key: ValueKey('${state.fase}-${state.ronda}'),
                              fase: state.fase,
                              nombre: nombre,
                            )
                          : const SizedBox.shrink(),
                    ),
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

/// Tarjeta grande que aparece con un rebote sobre el tablero: felicita al
/// acertar, anima a seguir al equivocarse y celebra al terminar.
/// Nunca usa palabras negativas ni muestra puntaje.
class _MensajeAnimo extends StatelessWidget {
  const _MensajeAnimo({super.key, required this.fase, required this.nombre});

  final SecuenciaFase fase;
  final String? nombre;

  String get _conNombre => nombre == null ? '' : ', $nombre';

  @override
  Widget build(BuildContext context) {
    final (IconData icono, Color color, Color fondo, String titulo, String texto) =
        switch (fase) {
      SecuenciaFase.acierto => (
          Icons.star_rounded,
          AppColors.accent,
          AppColors.successBackground,
          '¡Muy bien$_conNombre!',
          'Repitió la secuencia completa.',
        ),
      SecuenciaFase.terminado => (
          Icons.celebration_rounded,
          AppColors.accent,
          AppColors.successBackground,
          '¡Excelente trabajo$_conNombre!',
          'Terminó las $secuenciasRondasPorPartida rondas.',
        ),
      _ => (
          Icons.refresh_rounded,
          AppColors.primary,
          AppColors.primaryLight,
          '¡Buen intento$_conNombre!',
          'Sigamos con la siguiente.',
        ),
    };

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
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconoGirando(icono: icono, color: color),
              const SizedBox(height: 12),
              Text(
                titulo,
                key: const Key('secuencias_mensaje_animo'),
                style: AppTextStyles.greeting,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono que entra girando y creciendo.
class _IconoGirando extends StatelessWidget {
  const _IconoGirando({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * -1.2,
        child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
      ),
      child: Icon(icono, size: 80, color: color),
    );
  }
}

/// Puntos que muestran cuántos colores lleva la secuencia. El punto actual
/// crece para que se note el avance.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.total, required this.completados});

  final int total;
  final int completados;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: i < completados ? 18 : 14,
            height: i < completados ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < completados ? AppColors.primary : AppColors.border,
            ),
          ),
      ],
    );
  }
}

/// Botón de color. Cuando el juego lo enciende brilla y crece; cuando la
/// persona lo toca hace un pequeño rebote.
class _BotonColor extends StatefulWidget {
  const _BotonColor({
    super.key,
    required this.size,
    required this.datos,
    required this.encendido,
    required this.atenuado,
    required this.onTap,
  });

  final double size;
  final SecuenciaColor datos;
  final bool encendido;
  final bool atenuado;
  final VoidCallback? onTap;

  @override
  State<_BotonColor> createState() => _BotonColorState();
}

class _BotonColorState extends State<_BotonColor>
    with SingleTickerProviderStateMixin {
  // Estado solo visual (rebote al tocar), sin lógica de negocio.
  late final AnimationController _rebote = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _rebote.dispose();
    super.dispose();
  }

  void _tocar() {
    _rebote.forward(from: 0).then((_) {
      if (mounted) _rebote.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    final radio = BorderRadius.circular(24);

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: d.nombre,
      child: AnimatedBuilder(
        animation: _rebote,
        builder: (context, child) => Transform.scale(
          scale: 1 - 0.08 * _rebote.value,
          child: child,
        ),
        child: AnimatedScale(
          scale: widget.encendido ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: widget.atenuado ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: d.color,
                borderRadius: radio,
                border: Border.all(
                  color: widget.encendido ? Colors.white : Colors.transparent,
                  width: 6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.encendido
                        ? d.color.withValues(alpha: 0.8)
                        : Colors.black12,
                    blurRadius: widget.encendido ? 28 : 4,
                    spreadRadius: widget.encendido ? 6 : 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: radio,
                child: InkWell(
                  borderRadius: radio,
                  onTap: widget.onTap == null ? null : _tocar,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(d.icono, color: d.colorTexto, size: widget.size * 0.35),
                      const SizedBox(height: 4),
                      Text(
                        d.nombre,
                        style: AppTextStyles.body.copyWith(
                          color: d.colorTexto,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
