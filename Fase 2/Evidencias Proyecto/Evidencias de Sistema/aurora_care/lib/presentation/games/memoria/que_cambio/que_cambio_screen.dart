// lib/presentation/games/memoria/que_cambio/que_cambio_screen.dart
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
import 'que_cambio_cell.dart';
import 'que_cambio_controller.dart';
import 'que_cambio_demo.dart';

/// Pantalla de ¿Qué cambió?. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y tiempo transcurrido; este widget solo juega la
/// partida y llama a run.finish() al terminar.
///
/// Las dos grillas (siempre 3 filas; solo cambian las columnas por nivel)
/// se dimensionan dentro de un Expanded + LayoutBuilder, usando el alto
/// REAL que queda después del indicador, el mensaje y el botón — no una
/// estimación fija — para que las celdas no bajen de 48dp sin necesitar
/// scroll.
class QueCambioScreen extends ConsumerStatefulWidget {
  const QueCambioScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<QueCambioScreen> createState() => _QueCambioScreenState();
}

class _QueCambioScreenState extends ConsumerState<QueCambioScreen> {
  /// Aciertos consecutivos, para elegir SoundEffect.acierto(_racha). Se
  /// reinicia a 0 en cada error y empieza en 0 al abrir la partida.
  int _racha = 0;

  static const double _spacing = 8.0;
  static const double _labelHeight = 22.0;
  static const double _interGridGap = 8.0;

  /// Separación visible entre cada etiqueta ("Imagen original"/
  /// "Imagen modificada") y su cuadrícula: antes no había ninguna y la
  /// etiqueta quedaba pegada a la primera fila.
  static const double _labelGap = 6.0;

  /// Mensajes de los 3 estados que deben mantener el tablero del mismo
  /// tamaño (inicial, acierto, error — ver _mensaje): se reserva el
  /// alto del más largo de ESTOS. "Diferencia encontrada, 5 de 5" cubre
  /// el caso más largo de esa plantilla (nivel Avanzado). Los mensajes
  /// de partida terminada ("¡Felicitaciones!..."/"Buen trabajo...")
  /// quedan afuera a propósito: ese estado es transitorio y, si
  /// necesita más alto, el banner lo toma (crece libre, ver más abajo)
  /// sin tener que inflar el tablero el resto de la partida para un
  /// mensaje que solo se ve una vez, al final.
  ///
  /// NO se mide con un TextPainter aparte: se probó (con un
  /// RenderParagraph real en pantalla) que ese cálculo puede no
  /// coincidir con el alto real que ocupa el mismo texto una vez
  /// pintado — Atkinson Hyperlegible viene de Google Fonts y se
  /// descarga en tiempo de ejecución, así que una medición hecha por
  /// separado puede usar una fuente de reemplazo con otra métrica de
  /// línea. En vez de eso, estos 3 mensajes se "prueban" con el layout
  /// real: en el Stack del build(), cada uno se dibuja invisible pero
  /// ocupando su espacio (Visibility con maintainSize), con el mismo
  /// ancho y estilo que usa el banner visible, y el Stack se dimensiona
  /// solo al más alto de todos sus hijos — así la medición usa SIEMPRE
  /// la misma fuente que el texto visible, sin importar si ya terminó
  /// de cargar o no.
  static const List<String> _mensajesPosibles = [
    'Diferencia encontrada, 5 de 5',
    'No es una diferencia',
    'Toque la imagen donde note un cambio',
  ];

  /// Ícono (24dp, el tamaño por defecto de Icon — AuroraCare no define
  /// un IconTheme propio que lo cambie) + el SizedBox(width: 10) que
  /// StatusBanner pone entre el ícono y el texto. StatusBanner no
  /// expone estos valores como parámetros: se reproducen acá para que
  /// los mensajes invisibles de referencia envuelvan en el mismo ancho
  /// que el texto real (si no, envolverían distinto y la medición por
  /// layout real dejaría de ser comparable).
  static const double _bannerIconoYEspacio = 24.0 + 10.0;

  String _mensaje(QueCambioState state) {
    if (state.isFinished) {
      final omisiones = state.totalDiferencias - state.encontradas.length;
      if (omisiones == 0) {
        return '¡Felicitaciones! Encontró todas las diferencias.';
      }
      return 'Buen trabajo revisando las imágenes.';
    }
    switch (state.ultimoResultado) {
      case QueCambioResultado.acierto:
        return 'Diferencia encontrada, ${state.encontradas.length} de '
            '${state.totalDiferencias}';
      case QueCambioResultado.error:
        return 'No es una diferencia';
      case QueCambioResultado.ninguno:
        return 'Toque la imagen donde note un cambio';
    }
  }

  /// Ícono y color del banner de estado, según el mismo criterio que
  /// `_mensaje`: acierto → check verde, error → equis roja, sin
  /// resultado todavía (o partida terminada) → tono neutro/éxito.
  (IconData, Color) _iconoYColor(QueCambioState state) {
    if (state.isFinished) {
      return (Icons.check_circle_outline_rounded, AppColors.success);
    }
    switch (state.ultimoResultado) {
      case QueCambioResultado.acierto:
        return (Icons.check_circle_outline_rounded, AppColors.success);
      case QueCambioResultado.error:
        return (Icons.cancel_outlined, AppColors.error);
      case QueCambioResultado.ninguno:
        return (Icons.touch_app_outlined, AppColors.primary);
    }
  }

  QueCambioCellEstado _estadoDe(QueCambioState state, int i) {
    if (state.encontradas.contains(i)) return QueCambioCellEstado.encontrada;
    if (state.marcadasIncorrectas.contains(i)) {
      return QueCambioCellEstado.incorrecta;
    }
    return QueCambioCellEstado.normal;
  }

  Widget _buildGrilla({
    required bool esArriba,
    required List<int> datos,
    required QueCambioState state,
    required double size,
    required void Function(int) onTapCelda,
  }) {
    final columnas = state.columnas;
    return SizedBox(
      width: size * columnas + _spacing * (columnas - 1),
      child: GridView.count(
        crossAxisCount: columnas,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: _spacing,
        crossAxisSpacing: _spacing,
        children: [
          for (var i = 0; i < datos.length; i++)
            QueCambioCell(
              esArriba: esArriba,
              fila: (i ~/ columnas) + 1,
              columna: (i % columnas) + 1,
              face: memoriceFaces[datos[i]],
              estado: _estadoDe(state, i),
              onTap: state.isFinished || state.esMarcada(i)
                  ? null
                  : () => onTapCelda(i),
            ),
        ],
      ),
    );
  }

  /// Solo disponible antes del primer toque (state.intentos == 0).
  /// El controlador pausa la medición de tiempo mientras el diálogo
  /// está abierto (no hay ningún Timer de fondo en este juego, así que
  /// pausar() solo evita que ese rato cuente en tiempoSegundos) y la
  /// reanuda siempre al cerrar, sea con "Volver al juego", el botón
  /// atrás o tocando fuera del diálogo (el Future de showDialog se
  /// resuelve en los 3 casos).
  Future<void> _verComoSeJuega(
    BuildContext context,
    QueCambioController controller,
  ) async {
    controller.pausar();
    try {
      await showMemoriaHelpDialog(
        context: context,
        run: widget.run,
        title: 'Cómo jugar',
        badgeIcon: Icons.play_circle_outline_rounded,
        puntos: const [
          'Mire las dos imágenes con atención.',
          'Una de ellas tiene un cambio.',
          'Toque el lugar donde está la diferencia.',
        ],
        illustration: const Center(child: QueCambioDemo()),
      );
    } finally {
      if (context.mounted) controller.reanudar();
    }
  }

  Widget _buildLabel(String texto) {
    return SizedBox(
      height: _labelHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(texto, style: AppTextStyles.cardTitle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = queCambioControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        widget.run.finish(next.metrics!);
      }
      // Un toque ignorado (celda ya marcada, partida terminada) no
      // cambia "intentos": solo entra aquí un toque que de verdad
      // contó, con acierto o error (misma transición que ya fija el
      // banner, ver ultimoResultado).
      if (previous != null && next.intentos > previous.intentos) {
        if (next.ultimoResultado == QueCambioResultado.acierto) {
          _racha++;
          if (ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
            );
          }
        } else if (next.ultimoResultado == QueCambioResultado.error) {
          _racha = 0;
          if (ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.errorSuave),
            );
          }
        }
      }
    });

    final mensaje = _mensaje(state);
    final (icono, colorIcono) = _iconoYColor(state);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemoriaProgressIndicator(
            logrados: state.encontradas.length,
            total: state.totalDiferencias,
            etiquetaVisible:
                'Diferencias encontradas: ${state.encontradas.length} de '
                '${state.totalDiferencias}',
            etiquetaAnuncio:
                'Diferencia encontrada, ${state.encontradas.length} de '
                '${state.totalDiferencias}',
          ),
          const SizedBox(height: 6),
          // Stack, no SizedBox/ConstrainedBox con un alto calculado
          // aparte: cada mensaje de _mensajesPosibles se dibuja acá
          // mismo, invisible pero ocupando su espacio real (Visibility
          // con maintainSize), con el mismo ancho que le queda al texto
          // del banner visible (Padding replica el ícono + separación
          // de StatusBanner). El Stack se dimensiona solo al más alto
          // de todos sus hijos — incluido el banner visible — así que
          // si el mensaje actual (ej. el de partida terminada, más
          // largo) necesita más que los 3 de referencia, el Stack
          // crece con él en vez de recortarlo.
          Stack(
            key: const ValueKey('que_cambio_banner_stack'),
            alignment: Alignment.topLeft,
            children: [
              for (final texto in _mensajesPosibles)
                Padding(
                  padding: const EdgeInsets.only(
                    left: _bannerIconoYEspacio,
                  ),
                  child: Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(texto, style: AppTextStyles.bodySecondary),
                  ),
                ),
              StatusBanner(icon: icono, color: colorIcono, text: mensaje),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnas = state.columnas;

                final cellWidth =
                    (constraints.maxWidth - _spacing * (columnas - 1)) /
                    columnas;
                final availableForGrids =
                    constraints.maxHeight -
                    2 * _labelHeight -
                    2 * _labelGap -
                    _interGridGap;
                final perGridBudget = availableForGrids / 2;
                final cellHeightFromHeight =
                    (perGridBudget - _spacing * (queCambioFilas - 1)) /
                    queCambioFilas;
                final rawSize = cellWidth < cellHeightFromHeight
                    ? cellWidth
                    : cellHeightFromHeight;
                final size = rawSize.clamp(48.0, 90.0);

                // SingleChildScrollView como respaldo: a textScale 1.3
                // el banner (que ahora reserva el alto real de sus
                // mensajes más largos, varias líneas) deja tan poco
                // alto que, con celdas ya en el piso de 48dp, las 3
                // filas fijas no caben por unos pocos píxeles. En el
                // caso normal (textScale 1.0) ya cabe todo y no se
                // activa — mismo patrón que Memorice clásico y
                // Memorice de secuencias.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLabel('Imagen original'),
                        const SizedBox(height: _labelGap),
                        Center(
                          child: _buildGrilla(
                            esArriba: true,
                            datos: state.original,
                            state: state,
                            size: size,
                            onTapCelda: controller.tapCelda,
                          ),
                        ),
                        const SizedBox(height: _interGridGap),
                        _buildLabel('Imagen modificada'),
                        const SizedBox(height: _labelGap),
                        Center(
                          child: _buildGrilla(
                            esArriba: false,
                            datos: state.modificada,
                            state: state,
                            size: size,
                            onTapCelda: controller.tapCelda,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Antes del primer toque, "Ya no encuentro más" no tiene
          // mucho sentido todavía — se usa ese mismo espacio para "Ver
          // cómo se juega" (reemplazo, no agregado) para no sumar una
          // fila nueva al presupuesto de alto que ya está calibrado al
          // límite en Avanzado.
          if (state.intentos == 0)
            Center(
              child: TextButton.icon(
                onPressed: () => _verComoSeJuega(context, controller),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                label: const Text('Ver cómo se juega'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isFinished
                    ? null
                    : controller.declararTerminado,
                child: const Text('Ya no encuentro más'),
              ),
            ),
        ],
      ),
    );
  }
}
