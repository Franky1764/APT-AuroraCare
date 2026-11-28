// lib/presentation/games/atencion/toca_correcto/toca_correcto_screen.dart
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
import 'toca_correcto_controller.dart';
import 'toca_correcto_figuras.dart';

/// Cuánto se ve la celebración final antes de pasar al resultado.
const Duration tocaPausaCelebracion = Duration(milliseconds: 2000);

class TocaCorrectoScreen extends ConsumerStatefulWidget {
  const TocaCorrectoScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<TocaCorrectoScreen> createState() => _TocaCorrectoScreenState();
}

class _TocaCorrectoScreenState extends ConsumerState<TocaCorrectoScreen> {
  Timer? _finTimer;

  @override
  void dispose() {
    _finTimer?.cancel();
    super.dispose();
  }

  String _retro(TocaCorrectoState s, String? nombre) {
    final objetivo = '${s.objetivo.articulo} ${s.objetivo.nombre}';
    switch (s.ultimoResultado) {
      case TocaResultado.acierto:
        return saludoConNombre('Muy bien', nombre);
      case TocaResultado.tocoDistractor:
        return 'Recuerde: solo $objetivo';
      case TocaResultado.seLePaso:
        return 'Ahí estaba $objetivo';
      case TocaResultado.dejoPasar:
        return 'Bien, esa no se tocaba';
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = tocaCorrectoControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final nombre = ref.watch(jugadorNombreProvider);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        final metrics = next.metrics!;
        _finTimer?.cancel();
        _finTimer = Timer(tocaPausaCelebracion, () {
          if (mounted) widget.run.finish(metrics);
        });
      }
      // Acierto/error solo al tocar de verdad (acierto o distractor
      // tocado): "se le pasó" (no tocó a tiempo) y "dejó pasar" (no
      // tocó una distinta, lo correcto) no suenan — no son una acción
      // activa. tocar() ya cancela el Timer e ignora un segundo toque
      // fuera de "mostrando", así que esta transición ocurre una sola
      // vez por figura. Usa rachaActual, que el controller ya lleva
      // con la misma lógica que pedías (sube con cada acierto, se
      // reinicia en error): no hace falta duplicarla en la pantalla.
      if (previous != null &&
          previous.fase != TocaFase.retro &&
          next.fase == TocaFase.retro &&
          ref.read(soundsEnabledProvider)) {
        final sound = ref.read(soundServiceProvider);
        if (next.ultimoResultado == TocaResultado.acierto) {
          unawaited(sound.play(SoundEffect.acierto(next.rachaActual)));
        } else if (next.ultimoResultado == TocaResultado.tocoDistractor) {
          unawaited(sound.play(SoundEffect.errorSuave));
        }
      }
    });

    final total = state.figuras.length;
    final numero = state.fase == TocaFase.preparando ? 0 : state.indice + 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            children: [
              _Instruccion(objetivo: state.objetivo),
              const SizedBox(height: 12),
              Text(
                'Figura $numero de $total',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: numero / total),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, valor, _) => LinearProgressIndicator(
                    value: valor,
                    minHeight: 10,
                    color: AppColors.primary,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: switch (state.fase) {
                      TocaFase.preparando => Column(
                          key: const ValueKey('preparando'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Esta vez busque:',
                              style: AppTextStyles.heading,
                            ),
                            const SizedBox(height: 16),
                            _FiguraGrande(figura: state.objetivo),
                          ],
                        ),
                      TocaFase.mostrando => _FiguraGrande(
                          key: ValueKey('figura-${state.indice}'),
                          figura: state.figuraActual,
                          onTap: controller.tocar,
                        ),
                      TocaFase.retro => _FiguraGrande(
                          key: ValueKey('retro-${state.indice}'),
                          figura: state.figuraActual,
                          resaltada:
                              state.ultimoResultado == TocaResultado.acierto,
                          atenuada:
                              state.ultimoResultado != TocaResultado.acierto,
                        ),
                      TocaFase.terminado => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 72,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    state.fase == TocaFase.retro
                        ? _retro(state, nombre)
                        : '',
                    key: ValueKey('retro-texto-${state.indice}-${state.fase}'),
                    style: AppTextStyles.heading,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          if (state.fase == TocaFase.terminado)
            Positioned.fill(
              child: MensajeAnimo.terminado(
                nombre: nombre,
                texto: 'Terminó las $total figuras.',
              ),
            ),
        ],
      ),
    );
  }
}

/// Recuadro fijo arriba que recuerda qué figura hay que tocar.
class _Instruccion extends StatelessWidget {
  const _Instruccion({required this.objetivo});

  final TocaFiguraId objetivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Toque solo ${objetivo.articulo}', style: AppTextStyles.body),
          const SizedBox(width: 8),
          _IconoConContorno(figura: objetivo, size: 36),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              objetivo.nombre,
              key: const Key('toca_objetivo_nombre'),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícono con un contorno oscuro para que se distinga bien sobre fondo claro
/// (el amarillo solo no tiene contraste suficiente).
class _IconoConContorno extends StatelessWidget {
  const _IconoConContorno({required this.figura, required this.size});

  final TocaFiguraId figura;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      figura.formaDatos.icono,
      size: size,
      color: figura.colorDatos.color,
      shadows: [
        Shadow(color: AppColors.textPrimary, blurRadius: 3),
        Shadow(color: AppColors.textPrimary, blurRadius: 1),
      ],
    );
  }
}

/// La figura grande del centro. Se puede tocar solo mientras se muestra.
class _FiguraGrande extends StatelessWidget {
  const _FiguraGrande({
    super.key,
    required this.figura,
    this.onTap,
    this.resaltada = false,
    this.atenuada = false,
  });

  final TocaFiguraId figura;
  final VoidCallback? onTap;
  final bool resaltada;
  final bool atenuada;

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return Semantics(
      button: onTap != null,
      label: figura.nombreTitulo,
      child: AnimatedOpacity(
        opacity: atenuada ? 0.4 : 1,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: resaltada ? 1.08 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Material(
            color: AppColors.surface,
            shape: CircleBorder(
              side: BorderSide(
                color: resaltada ? AppColors.success : AppColors.border,
                width: resaltada ? 8 : 3,
              ),
            ),
            elevation: resaltada ? 10 : 3,
            child: InkWell(
              key: const Key('toca_figura'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IconoConContorno(figura: figura, size: 110),
                    const SizedBox(height: 8),
                    Text(
                      figura.nombreTitulo,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
