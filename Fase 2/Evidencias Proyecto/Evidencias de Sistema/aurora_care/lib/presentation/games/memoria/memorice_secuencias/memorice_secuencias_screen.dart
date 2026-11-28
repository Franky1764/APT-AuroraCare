// lib/presentation/games/memoria/memorice_secuencias/memorice_secuencias_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../shared/game_definition.dart';
import '../../shared/status_banner.dart';
import '../memoria_faces.dart';
import '../memoria_progress_indicator.dart';
import '../shared/memoria_help_dialog.dart';
import 'memorice_secuencia_progress_box.dart';
import 'memorice_secuencia_tile.dart';
import 'memorice_secuencias_controller.dart';
import 'memorice_secuencias_demo.dart';

/// Panel de Memorice de secuencias. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y tiempo transcurrido; este widget solo juega la
/// partida y llama a run.finish() al terminar.
///
/// El encabezado (indicador de rondas + mensaje + fila de casilleros)
/// tiene SIEMPRE la misma altura en "mostrando" y "esperandoRespuesta",
/// para que el tablero de abajo no cambie de tamaño al pasar de una fase
/// a la otra. En "retroalimentacion" el mensaje puede ser más largo
/// (lista la secuencia correcta) y se le permite crecer un poco — esa
/// fase es transitoria y no tiene el mismo requisito.
class MemoriceSecuenciasScreen extends ConsumerStatefulWidget {
  const MemoriceSecuenciasScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<MemoriceSecuenciasScreen> createState() =>
      _MemoriceSecuenciasScreenState();
}

class _MemoriceSecuenciasScreenState
    extends ConsumerState<MemoriceSecuenciasScreen> {
  /// Aciertos consecutivos (rondas), para elegir SoundEffect.acierto(_racha).
  /// Se reinicia a 0 en cada error y empieza en 0 al abrir la partida.
  int _racha = 0;

  @override
  void initState() {
    super.initState();
    // El build() inicial del controller (1er paso resaltado de la 1ra
    // ronda) no pasa por ref.listen (no hay "previous" todavía), así
    // que esa única nota se resuelve acá, leyendo el estado ya creado.
    final inicial = ref.read(
      memoriceSecuenciasControllerProvider(widget.run.nivel),
    );
    if (inicial.fase == MemoriceSecuenciaFase.mostrando &&
        inicial.pasoResaltado == 0) {
      _sonarNota(inicial.secuencia[0]);
    }
  }

  /// La nota de la imagen [poolIndex] (0..5): la misma imagen siempre
  /// suena igual, tanto al revelarse como al tocarla, para que quede
  /// ligada a ella.
  void _sonarNota(int poolIndex) {
    _sonarEfecto(SoundEffect.secuenciaNota(poolIndex));
  }

  void _sonarEfecto(SoundEffect effect) {
    if (ref.read(soundsEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).play(effect));
    }
  }

  static const double _tableroColumnas = 3;
  static const double _tableroFilas = 2;
  static const double _tableroSpacing = 12.0;
  static const double _mensajeAlturaCompacta = 28.0;

  /// Franja para "Ver cómo se juega", reservada con esta altura desde el
  /// primer frame y hasta el final de la partida (no solo mientras el
  /// botón está visible): si cambiara de alto, el tablero de abajo
  /// saltaría de tamaño justo cuando el botón desaparece.
  static const double _tutorialAltura = 48.0;

  /// Solo disponible en la ronda 1, antes de resolverla
  /// (state.rondasJugadas == 0). El controlador pausa la medición de
  /// tiempo Y el Timer que va mostrando la secuencia mientras el
  /// diálogo está abierto (si no, la secuencia seguiría avanzando de
  /// fondo y la persona podría perder la ronda sin verla completa), y
  /// reanuda siempre al cerrar, sea con "Volver al juego", el botón
  /// atrás o tocando fuera del diálogo (el Future de showDialog se
  /// resuelve en los 3 casos).
  Future<void> _verComoSeJuega(
    BuildContext context,
    MemoriceSecuenciaController controller,
  ) async {
    controller.pausar();
    try {
      await showMemoriaHelpDialog(
        context: context,
        run: widget.run,
        title: 'Cómo jugar',
        badgeIcon: Icons.play_circle_outline_rounded,
        puntos: const [
          'Mire el orden en que se iluminan las imágenes.',
          'Luego tóquelas en ese mismo orden.',
          'Si se equivoca, no importa: inténtelo de nuevo.',
        ],
        illustration: const Center(child: MemoriceSecuenciasDemo()),
      );
    } finally {
      if (context.mounted) controller.reanudar();
    }
  }

  /// Mensaje visible. Corto y de una sola línea en "mostrando" y
  /// "esperandoRespuesta" (puede crecer en "retroalimentacion").
  String _mensajePrincipal(MemoriceSecuenciaState state) {
    switch (state.fase) {
      case MemoriceSecuenciaFase.mostrando:
        return 'Mire con atención';
      case MemoriceSecuenciaFase.esperandoRespuesta:
        final n = state.secuencia.length;
        return 'Su turno: toque en el mismo orden '
            '(${state.progresoRespuesta} de $n)';
      case MemoriceSecuenciaFase.retroalimentacion:
        if (state.ultimaRondaCorrecta == true) return '¡Muy bien, en orden!';
        if (state.isFinished) {
          // Terminó por el tope de rondas jugadas sin llegar a 5 aciertos:
          // mensaje de cierre positivo, sin hablar de fracaso ni mostrar
          // cuántas rondas se jugaron.
          return 'Completó las rondas de hoy.';
        }
        final nombres = state.secuencia
            .map((i) => memoriceFaces[i].name)
            .join(', ');
        return 'No importa, siga intentando. Así era la secuencia: $nombres.';
    }
  }

  /// Etiqueta de accesibilidad del mensaje: en "esperandoRespuesta" es más
  /// rica que el texto visible (anuncia también qué imagen se eligió).
  String _mensajeAnuncio(MemoriceSecuenciaState state, String mensaje) {
    if (state.fase != MemoriceSecuenciaFase.esperandoRespuesta) {
      return mensaje;
    }
    final n = state.secuencia.length;
    if (state.progresoRespuesta == 0) {
      return '${state.progresoRespuesta} de $n';
    }
    final nombre =
        memoriceFaces[state.secuencia[state.progresoRespuesta - 1]].name;
    return 'Eligió $nombre, ${state.progresoRespuesta} de $n';
  }

  /// Indicador de rondas logradas (componente compartido de games/memoria/,
  /// el mismo que usan los otros juegos). Solo avanza con aciertos: los
  /// errores no se muestran aquí ni la hacen retroceder.
  Widget _buildRondaIndicator(MemoriceSecuenciaState state) {
    final logradas = state.rondasCorrectas;
    const total = memoriceSecuenciaRondasCorrectasParaGanar;
    return MemoriaProgressIndicator(
      logrados: logradas,
      total: total,
      etiquetaVisible: 'Rondas logradas: $logradas de $total',
      etiquetaAnuncio: 'Ronda lograda, $logradas de $total',
    );
  }

  Widget _buildMensaje(MemoriceSecuenciaState state) {
    final mensaje = _mensajePrincipal(state);
    final anuncio = _mensajeAnuncio(state, mensaje);
    final esCompacto = state.fase != MemoriceSecuenciaFase.retroalimentacion;

    if (esCompacto) {
      final texto = Text(
        mensaje,
        textAlign: TextAlign.center,
        style: AppTextStyles.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      return Semantics(
        liveRegion: true,
        label: anuncio,
        child: ExcludeSemantics(
          child: SizedBox(
            height: _mensajeAlturaCompacta,
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: texto),
            ),
          ),
        ),
      );
    }

    // retroalimentacion: se muestra ícono solo cuando el intento ya
    // tiene un veredicto claro (acierto o error). El cierre sin acierto
    // final (se acabaron las rondas) queda neutro, sin ícono — la app
    // nunca presenta esto como un fracaso.
    if (state.ultimaRondaCorrecta == true) {
      return StatusBanner(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        text: mensaje,
      );
    }
    if (!state.isFinished) {
      return StatusBanner(
        icon: Icons.cancel_outlined,
        color: AppColors.error,
        text: mensaje,
      );
    }
    return Semantics(
      liveRegion: true,
      label: anuncio,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBox(MemoriceSecuenciaState state, int i) {
    final orden = i + 1;
    final esErrorAqui =
        state.fase == MemoriceSecuenciaFase.retroalimentacion &&
        state.ultimaRondaCorrecta == false &&
        state.progresoRespuesta == i;

    if (esErrorAqui) {
      return MemoriceSecuenciaProgressBox(
        orden: orden,
        face: memoriceFaces[state.indiceTocadoIncorrecto!],
        estado: MemoriceSecuenciaProgressBoxEstado.incorrecto,
      );
    }
    if (i < state.progresoRespuesta) {
      return MemoriceSecuenciaProgressBox(
        orden: orden,
        face: memoriceFaces[state.secuencia[i]],
        estado: MemoriceSecuenciaProgressBoxEstado.correcto,
      );
    }
    return MemoriceSecuenciaProgressBox(
      orden: orden,
      face: null,
      estado: MemoriceSecuenciaProgressBoxEstado.vacio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = memoriceSecuenciasControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        widget.run.finish(next.metrics!);
      }
      if (previous == null) return;

      // Nota de cada imagen resaltada durante el revelado: ligada a la
      // imagen (poolIndex), no al paso, para que la misma imagen suene
      // siempre igual, tanto al revelarse como al tocarla. El primer
      // paso de la primera ronda de la partida se resolvió en
      // initState (acá nunca hay "previous" para esa transición).
      if (next.fase == MemoriceSecuenciaFase.mostrando &&
          next.pasoResaltado >= 0 &&
          next.pasoResaltado != previous.pasoResaltado) {
        _sonarNota(next.secuencia[next.pasoResaltado]);
      }

      // Toque que avanza la respuesta SIN completar la ronda: la nota
      // del elemento tocado. Si el toque completa la ronda, no se
      // suena la nota acá — el acierto de ronda (más abajo) ya es el
      // sonido de ese toque, para que no se pisen.
      if (next.fase == MemoriceSecuenciaFase.esperandoRespuesta &&
          next.progresoRespuesta > previous.progresoRespuesta &&
          next.progresoRespuesta < next.secuencia.length) {
        _sonarNota(next.secuencia[next.progresoRespuesta - 1]);
      }

      // Acierto/error al completar o fallar la ronda, con racha.
      if (next.rondasJugadas > previous.rondasJugadas) {
        if (next.ultimaRondaCorrecta == true) {
          _racha++;
          _sonarEfecto(SoundEffect.acierto(_racha));
        } else {
          _racha = 0;
          _sonarEfecto(SoundEffect.errorSuave);
        }
      }
    });

    final puedeTocar = state.fase == MemoriceSecuenciaFase.esperandoRespuesta;
    final n = state.secuencia.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRondaIndicator(state),
          const SizedBox(height: 6),
          _buildMensaje(state),
          const SizedBox(height: 6),
          // Fila de casilleros: tamaño fijo (no son táctiles, no necesitan
          // el mínimo de 48dp) y presente siempre con la misma altura, en
          // las 3 fases, para no mover el tablero de abajo.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: _buildProgressBox(state, i),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _tutorialAltura,
            child: state.rondasJugadas == 0
                ? Center(
                    child: TextButton.icon(
                      onPressed: () => _verComoSeJuega(context, controller),
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
          const SizedBox(height: 10),
          // Expanded + LayoutBuilder: el tamaño de cada casilla se calcula
          // con el espacio REAL disponible (ancho y alto), no se asume.
          // SingleChildScrollView queda solo como respaldo (textScale muy
          // alto); en el caso normal el contenido ya cabe y no se activa.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth =
                    (constraints.maxWidth -
                        _tableroSpacing * (_tableroColumnas - 1)) /
                    _tableroColumnas;
                final cellHeight =
                    (constraints.maxHeight -
                        _tableroSpacing * (_tableroFilas - 1)) /
                    _tableroFilas;
                final rawSize = cellWidth < cellHeight ? cellWidth : cellHeight;
                final size = rawSize.clamp(48.0, 120.0);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: SizedBox(
                        width:
                            size * _tableroColumnas +
                            _tableroSpacing * (_tableroColumnas - 1),
                        child: GridView.count(
                          crossAxisCount: _tableroColumnas.toInt(),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: _tableroSpacing,
                          crossAxisSpacing: _tableroSpacing,
                          children: [
                            for (var i = 0; i < memoriceSecuenciaPoolSize; i++)
                              MemoriceSecuenciaTile(
                                face: memoriceFaces[i],
                                isHighlighted:
                                    state.fase ==
                                        MemoriceSecuenciaFase.mostrando &&
                                    state.pasoResaltado >= 0 &&
                                    state.secuencia[state.pasoResaltado] == i,
                                isDimmed:
                                    state.fase ==
                                        MemoriceSecuenciaFase.mostrando &&
                                    !(state.pasoResaltado >= 0 &&
                                        state.secuencia[state.pasoResaltado] ==
                                            i),
                                isWrong:
                                    state.fase ==
                                        MemoriceSecuenciaFase
                                            .retroalimentacion &&
                                    state.indiceTocadoIncorrecto == i,
                                onTap: puedeTocar
                                    ? () => controller.tapImage(i)
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
