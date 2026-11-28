// lib/presentation/games/atencion/contador_objetos/contador_objetos_screen.dart
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
import '../shared/mensaje_animo.dart';
import 'contador_objetos_controller.dart';

/// Una figura para contar. Contraste mínimo 3:1 sobre blanco (gráficos).
class ContadorFigura {
  const ContadorFigura(this.plural, this.icono, this.color);
  final String plural;
  final IconData icono;
  final Color color;
}

/// Mismo orden que los índices 0..4 del controller.
/// Contraste sobre blanco: 5.9, 5.6, 5.1, 3.8 y 5.8 : 1.
const contadorFiguras = [
  ContadorFigura('flores', Icons.local_florist, Color(0xFFC2185B)),
  ContadorFigura('corazones', Icons.favorite, Color(0xFFC62828)),
  ContadorFigura('hojas', Icons.eco, Color(0xFF2E7D32)),
  ContadorFigura('estrellas', Icons.star, Color(0xFFE65100)),
  ContadorFigura('gotas', Icons.water_drop, Color(0xFF1565C0)),
];

/// Cuánto se ve la celebración final antes de pasar al resultado.
const Duration contadorPausaCelebracion = Duration(milliseconds: 2000);

class ContadorObjetosScreen extends ConsumerStatefulWidget {
  const ContadorObjetosScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<ContadorObjetosScreen> createState() =>
      _ContadorObjetosScreenState();
}

class _ContadorObjetosScreenState extends ConsumerState<ContadorObjetosScreen> {
  Timer? _finTimer;

  /// Aciertos consecutivos (rondas), para SoundEffect.acierto(_racha). Se
  /// reinicia a 0 en cada error y empieza en 0 al abrir la partida.
  int _racha = 0;

  @override
  void dispose() {
    _finTimer?.cancel();
    super.dispose();
  }

  String _mensaje(ContadorObjetosState s) {
    final plural = contadorFiguras[s.figura].plural;
    switch (s.fase) {
      case ContadorFase.preparando:
        return 'Prepárese para contar…';
      case ContadorFase.mostrando:
        return '¡Cuente las $plural!';
      case ContadorFase.respondiendo:
        return '¿Cuántas $plural había?';
      case ContadorFase.retro:
      case ContadorFase.terminado:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = contadorObjetosControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final nombre = ref.watch(jugadorNombreProvider);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        final metrics = next.metrics!;
        _finTimer?.cancel();
        _finTimer = Timer(contadorPausaCelebracion, () {
          if (mounted) widget.run.finish(metrics);
        });
      }
      // Acierto/error al llegar a la retroalimentación, una sola vez
      // por ronda (la transición solo ocurre una vez: responder() ya
      // ignora un segundo toque fuera de "respondiendo").
      if (previous != null &&
          previous.fase != ContadorFase.retro &&
          next.fase == ContadorFase.retro) {
        if (ref.read(soundsEnabledProvider)) {
          final sound = ref.read(soundServiceProvider);
          if (next.acerto) {
            _racha++;
            unawaited(sound.play(SoundEffect.acierto(_racha)));
          } else {
            _racha = 0;
            unawaited(sound.play(SoundEffect.errorSuave));
          }
        }
      }
    });

    final figurasVisibles = state.fase == ContadorFase.mostrando ||
        state.fase == ContadorFase.retro;

    Widget? mensajeGrande;
    if (state.fase == ContadorFase.retro) {
      final texto = 'Eran ${state.cantidad}.';
      mensajeGrande = state.acerto
          ? MensajeAnimo.acierto(
              key: ValueKey('acierto-${state.ronda}'),
              nombre: nombre,
              texto: texto,
            )
          : MensajeAnimo.intento(
              key: ValueKey('intento-${state.ronda}'),
              nombre: nombre,
              texto: texto,
            );
    } else if (state.fase == ContadorFase.terminado) {
      mensajeGrande = MensajeAnimo.terminado(
        key: const ValueKey('terminado'),
        nombre: nombre,
        texto: 'Terminó las $contadorRondasPorPartida rondas.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Ronda ${state.ronda} de $contadorRondasPorPartida',
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
                key: ValueKey('${state.fase}-${state.ronda}'),
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: _Tablero(
                    key: ValueKey('tablero-${state.ronda}'),
                    figura: contadorFiguras[state.figura],
                    casillas: state.casillas,
                    visibles: figurasVisibles,
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: mensajeGrande ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 88,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: state.fase == ContadorFase.respondiendo
                  ? Row(
                      key: ValueKey('opciones-${state.ronda}'),
                      children: [
                        for (final valor in state.opciones)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: _BotonNumero(
                                valor: valor,
                                onTap: () => controller.responder(valor),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadrícula de 4 x 4. Las figuras aparecen una tras otra con un pequeño
/// rebote y se tapan con tarjetas "?" cuando hay que responder.
class _Tablero extends StatelessWidget {
  const _Tablero({
    super.key,
    required this.figura,
    required this.casillas,
    required this.visibles,
  });

  final ContadorFigura figura;
  final List<int> casillas;
  final bool visibles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final lado = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight)
            .clamp(200.0, 420.0);
        return SizedBox(
          width: lado,
          height: lado,
          child: Column(
            children: [
              for (var fila = 0; fila < contadorColumnas; fila++) ...[
                if (fila > 0) const SizedBox(height: spacing),
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < contadorColumnas; col++) ...[
                        if (col > 0) const SizedBox(width: spacing),
                        Expanded(
                          child: _Casilla(
                            figura: figura,
                            ocupada: casillas
                                .contains(fila * contadorColumnas + col),
                            visible: visibles,
                            retraso: casillas
                                .indexOf(fila * contadorColumnas + col),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.figura,
    required this.ocupada,
    required this.visible,
    required this.retraso,
  });

  final ContadorFigura figura;
  final bool ocupada;
  final bool visible;

  /// Orden de aparición de la figura (para escalonar la animación).
  final int retraso;

  @override
  Widget build(BuildContext context) {
    final tapada = !visible;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: tapada ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: tapada
            ? Text(
                '?',
                key: const ValueKey('tapada'),
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.primary,
                ),
              )
            : ocupada
                ? TweenAnimationBuilder<double>(
                    key: const ValueKey('figura'),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + 60 * retraso),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          figura.icono,
                          color: figura.color,
                          semanticLabel: figura.plural,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('vacia')),
      ),
    );
  }
}

/// Botón grande con un número (área táctil mucho mayor a 48 x 48).
class _BotonNumero extends StatelessWidget {
  const _BotonNumero({required this.valor, required this.onTap});

  final int valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: Key('contador_opcion_$valor'),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(80),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        '$valor',
        style: AppTextStyles.greeting.copyWith(
          fontSize: 34,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
