// lib/presentation/games/memoria/memorice_clasico/memorice_clasico_screen.dart
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
import 'memorice_card.dart';
import 'memorice_clasico_controller.dart';
import 'memorice_clasico_demo.dart';

/// Resultado del último intento de par ya resuelto (no de cada volteo
/// individual). Se limpia al empezar el siguiente intento (primera
/// carta del par nuevo), no apenas se tapan las cartas que no coinciden.
enum _ResultadoIntento { ninguno, acierto, error }

/// Tablero de Memorice clásico. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y tiempo transcurrido; este widget solo juega la
/// partida y llama a run.finish() al encontrar el último par.
class MemoriceClasicoScreen extends ConsumerStatefulWidget {
  const MemoriceClasicoScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<MemoriceClasicoScreen> createState() =>
      _MemoriceClasicoScreenState();
}

class _MemoriceClasicoScreenState extends ConsumerState<MemoriceClasicoScreen> {
  _ResultadoIntento _resultado = _ResultadoIntento.ninguno;

  /// Cuenta regresiva (en segundos) de la vista previa, solo para
  /// mostrarla en pantalla — quien de verdad decide cuándo termina la
  /// vista previa es el controlador (su propio Timer inyectable). Este
  /// ticker es puramente cosmético: si por algo quedara desincronizado
  /// un segundo, igual se corrige apenas el controlador avisa el cambio
  /// de fase (ver ref.listen).
  Timer? _tickTimer;
  int? _segundosRestantesVistaPrevia;

  /// true justo al terminar la vista previa y hasta que se toca la
  /// primera carta: muestra "Ahora busque las parejas".
  bool _mostrarFinVistaPrevia = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(
      memoriceClasicoControllerProvider(widget.run.nivel),
    );
    if (state.isPreviewPhase) {
      _segundosRestantesVistaPrevia = memoricePreviewDuration(
        widget.run.nivel,
      ).inSeconds;
      _startTick();
    }
  }

  void _startTick() {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final restantes = _segundosRestantesVistaPrevia;
      if (restantes == null || restantes <= 1) return;
      setState(() => _segundosRestantesVistaPrevia = restantes - 1);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  /// Los mensajes que puede mostrar el banner (ver _mensajeDe), para
  /// reservarles su alto real dentro de la franja — igual criterio que
  /// ¿Qué cambió? (que_cambio_screen.dart): "Encontró la pareja" ya
  /// necesita 2 líneas a 360dp de ancho y se recortaba con la franja
  /// fija de 48dp. No se mide con un TextPainter aparte por la misma
  /// razón explicada ahí (Atkinson Hyperlegible se carga de Google
  /// Fonts en tiempo de ejecución y una medición por separado puede no
  /// coincidir con la fuente realmente pintada): se reservan dibujando
  /// estos mensajes invisibles pero ocupando su espacio real dentro
  /// del mismo Stack que el banner visible (ver build()).
  static const List<String> _mensajesPosibles = [
    'Encontró la pareja',
    'No es la pareja',
  ];

  /// Ídem, para los mensajes de la vista previa — estos no llevan ícono,
  /// así que no se les suma _bannerIconoYEspacio.
  static const List<String> _mensajesVistaPreviaPosibles = [
    // 13 = la duración más larga posible (Avanzado, 10 pares).
    'Memorice las imágenes: 13',
    'Ahora busque las parejas',
  ];

  /// Ícono (24dp, tamaño por defecto de Icon) + el SizedBox(width: 10)
  /// que StatusBanner pone entre el ícono y el texto — StatusBanner no
  /// expone estos valores, así que se reproducen acá para que los
  /// mensajes de referencia envuelvan en el mismo ancho que el texto
  /// real.
  static const double _bannerIconoYEspacio = 24.0 + 10.0;

  /// Columnas x filas por cantidad de pares (SCORING §2.2: 6/8/10).
  (int columnas, int filas) _grid(int totalPares) {
    switch (totalPares) {
      case 6:
        return (3, 4);
      case 8:
        return (4, 4);
      default:
        return (4, 5);
    }
  }

  /// Solo disponible entre el fin de la vista previa y el primer
  /// volteo (state.intentos == 0, !isPreviewPhase). El reloj de la
  /// partida ya está corriendo en esa ventana (arranca al taparse las
  /// cartas, no en el primer volteo), así que hay que pausarlo mientras
  /// el diálogo está abierto — mismo patrón que ¿Qué cambió?,
  /// Memorice de secuencias y Recuerde el número: pausar() antes,
  /// reanudar() en un finally (se cierre como se cierre: botón, atrás o
  /// tocando fuera, el Future de showDialog se resuelve en los 3
  /// casos). showMemoriaHelpDialog ya pausa/reanuda el reloj VISIBLE de
  /// GameShell (run.pauseClock/resumeClock); acá además hay que pausar
  /// el reloj de la MÉTRICA, que vive en el controlador.
  Future<void> _verComoSeJuega(
    BuildContext context,
    MemoriceClasicoController controller,
  ) async {
    controller.pausar();
    try {
      await showMemoriaHelpDialog(
        context: context,
        run: widget.run,
        title: 'Cómo jugar',
        badgeIcon: Icons.play_circle_outline_rounded,
        puntos: const [
          'Primero mire dónde está cada imagen.',
          'Cuando se tapen, toque dos cartas.',
          'Si son iguales, quedan abiertas.',
        ],
        illustration: const Center(child: MemoriceClasicoDemo()),
      );
    } finally {
      if (context.mounted) controller.reanudar();
    }
  }

  String _mensajeDe(_ResultadoIntento resultado) {
    switch (resultado) {
      case _ResultadoIntento.acierto:
        return 'Encontró la pareja';
      case _ResultadoIntento.error:
        return 'No es la pareja';
      case _ResultadoIntento.ninguno:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = memoriceClasicoControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        widget.run.finish(next.metrics!);
      }
      if (previous == null) return;
      // Termina la vista previa: arranca el reloj visible de GameShell
      // (el de la métrica ya arrancó dentro del controlador, en el
      // mismo instante), deja de tiquetear el contador propio de la
      // vista previa (la fuente de verdad ya pasó a "Ahora busque las
      // parejas") y muestra el mensaje de transición hasta el primer
      // toque.
      if (previous.isPreviewPhase && !next.isPreviewPhase) {
        widget.run.startClock?.call();
        _tickTimer?.cancel();
        _tickTimer = null;
        setState(() {
          _segundosRestantesVistaPrevia = null;
          _mostrarFinVistaPrevia = true;
        });
        return;
      }
      // Primera carta de un intento nuevo: recién ahí se limpia el
      // mensaje del intento anterior (no cuando el temporizador tapa
      // solo las cartas que no coincidían), y también el mensaje de
      // fin de vista previa, si todavía estaba visible. Es también el
      // único volteo que no resuelve nada (a diferencia del volteo de
      // la 2da carta, que siempre acierta o falla), así que es el
      // único que suena carta_voltear: el volteo que resuelve el par
      // ya suena pareja_encontrada o error_suave, sin sumarle también
      // carta_voltear.
      if (previous.revealedIndices.isEmpty &&
          next.revealedIndices.length == 1) {
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.cartaVoltear),
          );
        }
        setState(() {
          _resultado = _ResultadoIntento.ninguno;
          _mostrarFinVistaPrevia = false;
        });
        return;
      }
      if (next.locked && !previous.locked) {
        setState(() => _resultado = _ResultadoIntento.error);
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.errorSuave),
          );
        }
      } else if (next.paresEncontrados > previous.paresEncontrados) {
        setState(() => _resultado = _ResultadoIntento.acierto);
        // No acierto_1..5: pareja_encontrada ya es el sonido de acierto
        // propio de este juego.
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.parejaEncontrada),
          );
        }
      }
    });

    final (columnas, filas) = _grid(state.totalPares);
    const spacing = 12.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemoriaProgressIndicator(
            logrados: state.paresEncontrados,
            total: state.totalPares,
            etiquetaVisible:
                'Pares encontrados: ${state.paresEncontrados} de ${state.totalPares}',
            etiquetaAnuncio:
                'Par encontrado, ${state.paresEncontrados} de ${state.totalPares}',
          ),
          const SizedBox(height: 8),
          // Antes del primer volteo (sin intentos todavía) este espacio
          // nunca mostraba nada: se reusa esa misma franja para "Ver
          // cómo se juega", en vez de sumar una fila nueva al
          // presupuesto de alto que el tablero ya calcula al límite en
          // Avanzado. El Stack (no un SizedBox con una altura fija) se
          // dimensiona SIEMPRE al más alto entre: el piso de 48dp (área
          // táctil del botón) y el alto real de los 2 mensajes posibles
          // del banner — así nunca cambia entre estados (evitando el
          // salto de tamaño del tablero) y el banner no se recorta como
          // pasaba con la franja fija de 48dp ("Encontró la pareja" ya
          // necesita más).
          Stack(
            key: const ValueKey('memorice_clasico_banner_stack'),
            alignment: Alignment.center,
            children: [
              const SizedBox(height: 48),
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
              for (final texto in _mensajesVistaPreviaPosibles)
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
              // Referencia para el único momento en que se ven 2 cosas
              // juntas (el mensaje de fin de vista previa y el botón,
              // uno debajo del otro): sin esto, el Stack solo reservaría
              // el alto de cada uno por separado (nunca la suma), y el
              // tablero se encogería justo en esa ventana.
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ahora busque las parejas',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    SizedBox(height: 48),
                  ],
                ),
              ),
              // El botón y el mensaje de vista previa/transición son
              // independientes entre sí (no un if/else): justo al
              // terminar la vista previa y antes del primer volteo se
              // ven los dos juntos, uno debajo del otro.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isPreviewPhase)
                    _MensajeVistaPrevia(
                      textoVisible:
                          'Memorice las imágenes: '
                          '${_segundosRestantesVistaPrevia ?? memoricePreviewDuration(widget.run.nivel).inSeconds}',
                      anuncioAccesible: 'Memorice las imágenes',
                    )
                  else if (_mostrarFinVistaPrevia)
                    const _MensajeVistaPrevia(
                      textoVisible: 'Ahora busque las parejas',
                      anuncioAccesible: 'Ahora busque las parejas',
                    )
                  else if (_resultado != _ResultadoIntento.ninguno)
                    StatusBanner(
                      icon: _resultado == _ResultadoIntento.acierto
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      color: _resultado == _ResultadoIntento.acierto
                          ? AppColors.success
                          : AppColors.error,
                      text: _mensajeDe(_resultado),
                    ),
                  if (!state.isPreviewPhase && state.intentos == 0)
                    TextButton.icon(
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Expanded: el tablero recalcula el tamaño de carta con el alto
          // que quede DESPUÉS del indicador, para seguir cabiendo sin
          // scroll (incluido Avanzado, 10 pares / 20 cartas).
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth =
                    (constraints.maxWidth - spacing * (columnas - 1)) /
                    columnas;
                final cellHeight =
                    (constraints.maxHeight - spacing * (filas - 1)) / filas;
                final rawSize = cellWidth < cellHeight ? cellWidth : cellHeight;
                final size = rawSize.clamp(48.0, 110.0);

                return SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: size * columnas + spacing * (columnas - 1),
                      child: GridView.count(
                        crossAxisCount: columnas,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        children: [
                          for (var i = 0; i < state.cards.length; i++)
                            MemoriceCard(
                              cardNumber: i + 1,
                              face: memoriceFaces[state.cards[i].faceIndex],
                              isFaceUp: state.cards[i].isFaceUp,
                              isMatched: state.cards[i].isMatched,
                              onTap:
                                  state.locked ||
                                      state.isFinished ||
                                      state.isPreviewPhase
                                  ? null
                                  : () => controller.flipCard(i),
                            ),
                        ],
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

/// Mensaje de la vista previa o de su transición ("Memorice las
/// imágenes: N" / "Ahora busque las parejas"): sin ícono (no es un
/// acierto ni un error), y con un anuncio de accesibilidad que NO
/// cambia cada segundo. [anuncioAccesible] es lo que lee el lector de
/// pantalla (constante durante toda la cuenta regresiva); [textoVisible]
/// es lo que se ve en pantalla (con el número cambiando cada segundo).
class _MensajeVistaPrevia extends StatelessWidget {
  const _MensajeVistaPrevia({
    required this.textoVisible,
    required this.anuncioAccesible,
  });

  final String textoVisible;
  final String anuncioAccesible;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: anuncioAccesible,
      child: ExcludeSemantics(
        child: Text(
          textoVisible,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary,
        ),
      ),
    );
  }
}
