// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_quiz_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/memory_category.dart';
import '../../shared/status_banner.dart';
import '../shared/memoria_help_dialog.dart';
import 'mis_recuerdos_button_style.dart';
import 'mis_recuerdos_demo.dart';
import 'mis_recuerdos_quiz_controller.dart';

/// Pantalla de juego de "Mis recuerdos": 5 preguntas de opción múltiple
/// (4 opciones cada una), sin temporizador ni puntaje numérico. No pasa
/// por GameShell/FinishSession — no hay score ni UUID cognitivo
/// involucrados, igual que Respiración guiada.
class MisRecuerdosQuizScreen extends ConsumerStatefulWidget {
  const MisRecuerdosQuizScreen({
    super.key,
    required this.categoria,
    required this.uid,
  });

  final MemoryCategory categoria;
  final String uid;

  @override
  ConsumerState<MisRecuerdosQuizScreen> createState() =>
      _MisRecuerdosQuizScreenState();
}

class _MisRecuerdosQuizScreenState
    extends ConsumerState<MisRecuerdosQuizScreen> {
  /// Aciertos consecutivos, para SoundEffect.acierto(_racha). Se
  /// reinicia a 0 al empezar el quiz (incluso con "Jugar otra vez", que
  /// reusa esta misma pantalla vía ref.invalidate) y tras cada error.
  int _racha = 0;

  void _sonarEfecto(SoundEffect effect) {
    if (ref.read(soundsEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).play(effect));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = misRecuerdosQuizControllerProvider((
      widget.uid,
      widget.categoria.id,
    ));
    final asyncState = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      final nextData = next.valueOrNull;
      if (nextData == null) return;
      // "Jugar otra vez" reusa esta misma pantalla (ref.invalidate, sin
      // crear un widget nuevo): una ronda recién empezada reinicia la
      // racha, igual que al abrir el quiz por primera vez.
      if (nextData.indiceActual == 0 &&
          nextData.aciertos == 0 &&
          nextData.opcionElegida == null) {
        _racha = 0;
      }

      final prevData = previous?.valueOrNull;
      if (prevData == null) return;

      // Al elegir una opción (misma transición que fija el banner de
      // resultado): acierto con racha, o error_suave.
      if (prevData.opcionElegida == null && nextData.opcionElegida != null) {
        if (nextData.esCorrectaElegida) {
          _racha++;
          _sonarEfecto(SoundEffect.acierto(_racha));
        } else {
          _racha = 0;
          _sonarEfecto(SoundEffect.errorSuave);
        }
        return;
      }

      // Cierre del quiz (pantalla de resultado final): un solo sonido
      // según aciertos/total, reutilizando los mismos umbrales que
      // GameShell usa al terminar una partida. El quiz no pasa por
      // GameShell, así que no hay otro sonido de cierre con el que se
      // pise.
      if (!prevData.terminada && nextData.terminada) {
        final pct = nextData.aciertos / nextData.total * 100;
        _sonarEfecto(SoundEffect.resultado(pct));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoria.name)),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se pudo cargar el juego. Intente de nuevo.'),
            ),
          ),
          data: (state) {
            if (state.terminada) {
              return _ResultadoFinal(
                aciertos: state.aciertos,
                total: state.total,
                onJugarOtraVez: () => ref.invalidate(provider),
                onVolver: () => Navigator.of(context).pop(),
              );
            }
            return _PreguntaActual(
              state: state,
              onElegir: (i) => ref.read(provider.notifier).elegirOpcion(i),
              onSiguiente: () => ref.read(provider.notifier).siguiente(),
            );
          },
        ),
      ),
    );
  }
}

class _PreguntaActual extends StatelessWidget {
  const _PreguntaActual({
    required this.state,
    required this.onElegir,
    required this.onSiguiente,
  });

  final MisRecuerdosQuizState state;
  final void Function(int) onElegir;
  final VoidCallback onSiguiente;

  /// Franja para "Ver cómo se juega". Constante en 48dp SOLO dentro de
  /// la pregunta 1 (antes y después de responderla): ahí es donde el
  /// botón puede estar visible, y si la altura cambiara entre esos dos
  /// momentos, las opciones de abajo se correrían de lugar justo al
  /// responder — lo que el diseño de esta pantalla ya evita (ver el
  /// comentario sobre mainAxisAlignment.start más abajo). Desde la
  /// pregunta 2 en adelante el botón ya no puede volver a aparecer, así
  /// que se reduce a 0 para no empeorar el scroll de respaldo del banner
  /// de error en esas preguntas; no hay salto porque es una pregunta
  /// nueva (otro texto, otras opciones), no una transición dentro de la
  /// misma pregunta.
  double _tutorialAltura(MisRecuerdosQuizState state) =>
      state.indiceActual == 0 ? 48.0 : 0.0;

  /// Sin reloj ni puntaje numérico: este juego no mide tiempo (no hay
  /// clockProvider ni metrics con tiempoSegundos, a diferencia de los
  /// otros juegos de Memoria), así que abrir el tutorial no puede
  /// inflar ninguna medición. El único estado puntuable (aciertos)
  /// cambia solo con siguiente(), que requiere haber respondido antes
  /// (elegirOpcion), imposible mientras el diálogo modal está abierto.
  /// Se limita a la pregunta 1 sin responder, por consistencia con el
  /// resto de los juegos de Memoria (visible solo antes de la primera
  /// acción real).
  Future<void> _verComoSeJuega(BuildContext context) {
    return showMemoriaHelpDialog(
      context: context,
      title: 'Cómo jugar',
      badgeIcon: Icons.play_circle_outline_rounded,
      puntos: const [
        'Lea la pregunta y las 4 opciones.',
        'Toque la que crea correcta.',
        'Si se equivoca, no importa: vea la respuesta correcta.',
      ],
      illustration: const Center(child: MisRecuerdosDemo()),
    );
  }

  String get _mensajeResultado {
    if (!state.respondioActual) return '';
    if (state.esCorrectaElegida) return '¡Muy bien! Esa es la respuesta correcta.';
    return 'No es esa. La respuesta correcta es "${state.actual.pregunta.answer}".';
  }

  @override
  Widget build(BuildContext context) {
    final pregunta = state.actual;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // Antes se centraba verticalmente (MainAxisAlignment.center):
            // al responder aparecen el mensaje y el botón "Siguiente", el
            // contenido crece y la columna se recentra, lo que corre las
            // opciones de lugar. Anclado arriba (start), las opciones
            // quedan siempre en la misma posición; lo único que cambia es
            // cuánto espacio libre queda abajo.
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: _tutorialAltura(state),
                child: (!state.respondioActual && state.indiceActual == 0)
                    ? Center(
                        child: TextButton.icon(
                          onPressed: () => _verComoSeJuega(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 22,
                          ),
                          label: const Text('Ver cómo se juega'),
                        ),
                      )
                    : null,
              ),
              Text(
                'Pregunta ${state.indiceActual + 1} de ${state.total}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 12),
              Text(
                pregunta.pregunta.quizPrompt,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < pregunta.opciones.length; i++) ...[
                _OpcionBoton(
                  texto: pregunta.opciones[i],
                  estado: !state.respondioActual
                      ? _OpcionEstado.normal
                      : i == pregunta.indiceCorrecto
                      ? _OpcionEstado.correcta
                      : i == state.opcionElegida
                      ? _OpcionEstado.incorrectaElegida
                      : _OpcionEstado.normal,
                  onTap: state.respondioActual ? null : () => onElegir(i),
                ),
                const SizedBox(height: 12),
              ],
              if (state.respondioActual) ...[
                const SizedBox(height: 8),
                StatusBanner(
                  icon: state.esCorrectaElegida
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  color: state.esCorrectaElegida
                      ? AppColors.success
                      : AppColors.error,
                  text: _mensajeResultado,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: misRecuerdosBotonPadding,
                  ),
                  onPressed: onSiguiente,
                  child: const Text('Siguiente', textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _OpcionEstado { normal, correcta, incorrectaElegida }

class _OpcionBoton extends StatelessWidget {
  const _OpcionBoton({
    required this.texto,
    required this.estado,
    required this.onTap,
  });

  final String texto;
  final _OpcionEstado estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color? background;
    final Color borderColor;
    final IconData? icono;
    final String sufijoSemantica;
    switch (estado) {
      case _OpcionEstado.correcta:
        background = AppColors.successBackground;
        borderColor = AppColors.success;
        icono = Icons.check_circle;
        sufijoSemantica = ', respuesta correcta';
      case _OpcionEstado.incorrectaElegida:
        background = AppColors.errorBackground;
        borderColor = AppColors.error;
        icono = Icons.cancel;
        sufijoSemantica = ', no es la respuesta correcta';
      case _OpcionEstado.normal:
        background = null;
        borderColor = AppColors.border;
        icono = null;
        sufijoSemantica = '';
    }

    return Semantics(
      label: '$texto$sufijoSemantica',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: background,
              side: BorderSide(color: borderColor, width: 2),
              padding: misRecuerdosBotonPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icono != null) ...[
                  Icon(icono, color: borderColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultadoFinal extends StatelessWidget {
  const _ResultadoFinal({
    required this.aciertos,
    required this.total,
    required this.onJugarOtraVez,
    required this.onVolver,
  });

  final int aciertos;
  final int total;
  final VoidCallback onJugarOtraVez;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    // Sin puntaje numérico visible: el conteo solo decide el tono del
    // mensaje de cierre.
    final mensaje = aciertos >= (total / 2).ceil()
        ? 'Muy bien, repasó sus recuerdos.'
        : 'Gracias por repasar, cada intento ayuda.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.favorite, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: misRecuerdosBotonPadding,
                ),
                onPressed: onJugarOtraVez,
                child: const Text(
                  'Jugar otra vez',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: misRecuerdosBotonPadding,
                ),
                onPressed: onVolver,
                child: const Text('Volver', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
