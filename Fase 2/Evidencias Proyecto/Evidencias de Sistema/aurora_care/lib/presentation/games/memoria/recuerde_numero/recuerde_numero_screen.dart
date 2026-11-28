// lib/presentation/games/memoria/recuerde_numero/recuerde_numero_screen.dart
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
import '../memoria_progress_indicator.dart';
import '../shared/memoria_help_dialog.dart';
import 'recuerde_numero_controller.dart';
import 'recuerde_numero_demo.dart';
import 'recuerde_numero_keypad.dart';

/// Pantalla de Recuerde el número. El cascarón (GameShell) ya resolvió
/// consentimiento, nivel y tiempo transcurrido; este widget solo juega la
/// partida y llama a run.finish() al terminar.
///
/// El encabezado (indicador de rondas + mensaje + casilleros) tiene
/// siempre la misma altura, en las 3 fases, para que la zona inferior
/// (número grande o teclado) no cambie de tamaño al cambiar de fase.
class RecuerdeNumeroScreen extends ConsumerStatefulWidget {
  const RecuerdeNumeroScreen({super.key, required this.run});

  final GameRun run;

  @override
  ConsumerState<RecuerdeNumeroScreen> createState() =>
      _RecuerdeNumeroScreenState();
}

class _RecuerdeNumeroScreenState extends ConsumerState<RecuerdeNumeroScreen> {
  /// Aciertos consecutivos, para elegir SoundEffect.acierto(_racha). Se
  /// reinicia a 0 en cada error y empieza en 0 al abrir la partida.
  int _racha = 0;

  // Reserva espacio en las fases cortas y permite crecer al ampliar el texto.
  static const double _mensajeAlturaMinima = 52;
  static const double _casilleroAncho = 44.0;
  static const double _casilleroAlto = 56.0;
  static const double _casilleroSpacing = 8.0;

  /// Franja para "Ver cómo se juega", reservada con esta altura desde
  /// el primer frame y durante toda la partida (no solo mientras el
  /// botón está visible): si cambiara de alto, el número grande o el
  /// teclado de abajo se moverían justo cuando el botón desaparece —
  /// lo que el comentario de la clase ya evita para las 3 fases.
  static const double _tutorialAltura = 48.0;

  /// Solo en la ronda 1, antes de resolverla (state.rondasJugadas ==
  /// 0). El controlador pausa la medición de tiempo Y el Timer que
  /// esconde el número mientras el diálogo está abierto (si no, el
  /// número se escondería de fondo y la ronda se podría perder sin
  /// llegar a verlo completo), y reanuda siempre al cerrar, sea con
  /// "Volver al juego", el botón atrás o tocando fuera del diálogo (el
  /// Future de showDialog se resuelve en los 3 casos).
  Future<void> _verComoSeJuega(
    BuildContext context,
    RecuerdeNumeroController controller,
  ) async {
    controller.pausar();
    try {
      await showMemoriaHelpDialog(
        context: context,
        run: widget.run,
        title: 'Cómo jugar',
        badgeIcon: Icons.play_circle_outline_rounded,
        puntos: const [
          'Memorice el número antes de que desaparezca.',
          'Luego escríbalo con el teclado.',
          'Toque "Listo" cuando termine.',
        ],
        illustration: const Center(child: RecuerdeNumeroDemo()),
      );
    } finally {
      if (context.mounted) controller.reanudar();
    }
  }

  String _mensajePrincipal(RecuerdeNumeroState state) {
    switch (state.fase) {
      case RecuerdeNumeroFase.mostrando:
        return 'Memorice el número';
      case RecuerdeNumeroFase.esperandoRespuesta:
        return 'Escriba el número (${state.respuesta.length} de '
            '${state.digitos})';
      case RecuerdeNumeroFase.retroalimentacion:
        if (state.ultimaRondaCorrecta == true) return '¡Correcto!';
        if (state.isFinished) return 'Completó las rondas de hoy.';
        return 'No importa, siga intentando. El número era ${state.numero}.';
    }
  }

  /// Etiqueta de accesibilidad: en "mostrando" anuncia el número dígito
  /// por dígito; en "esperandoRespuesta" anuncia cada dígito escrito.
  String _mensajeAnuncio(RecuerdeNumeroState state, String mensaje) {
    switch (state.fase) {
      case RecuerdeNumeroFase.mostrando:
        final digitosSeparados = state.numero.split('').join(', ');
        return 'El número es $digitosSeparados';
      case RecuerdeNumeroFase.esperandoRespuesta:
        if (state.respuesta.isEmpty) return mensaje;
        final ultimo = state.respuesta[state.respuesta.length - 1];
        return 'Escribió $ultimo, ${state.respuesta.length} de '
            '${state.digitos}';
      case RecuerdeNumeroFase.retroalimentacion:
        return mensaje;
    }
  }

  Widget _buildMensaje(RecuerdeNumeroState state) {
    final mensaje = _mensajePrincipal(state);
    final anuncio = _mensajeAnuncio(state, mensaje);

    // "mostrando" y "esperandoRespuesta": fases de espera, sin ícono de
    // éxito ni de error (igual que antes).
    if (state.fase != RecuerdeNumeroFase.retroalimentacion) {
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
            key: const ValueKey('recuerde_numero_mensaje'),
            height: _mensajeAlturaMinima,
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: texto),
            ),
          ),
        ),
      );
    }

    // "retroalimentacion": ícono solo cuando el intento tiene un
    // veredicto claro (acierto o error). El cierre sin acierto final
    // (se acabaron las rondas) queda neutro, sin ícono — la app nunca
    // presenta esto como un fracaso.
    final correct = state.ultimaRondaCorrecta == true;
    return ConstrainedBox(
      key: const ValueKey('recuerde_numero_mensaje'),
      constraints: const BoxConstraints(minHeight: _mensajeAlturaMinima),
      child: correct || !state.isFinished
          ? StatusBanner(
              icon: correct
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: correct ? AppColors.success : AppColors.error,
              text: mensaje,
            )
          : Semantics(
              liveRegion: true,
              label: anuncio,
              child: ExcludeSemantics(
                child: Center(
                  child: Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCasilleros(RecuerdeNumeroState state) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: _casilleroSpacing,
      runSpacing: _casilleroSpacing,
      children: [
        for (var i = 0; i < state.digitos; i++)
          SizedBox(
            width: _casilleroAncho,
            height: _casilleroAlto,
            child: _DigitoBox(
              orden: i + 1,
              digito: i < state.respuesta.length ? state.respuesta[i] : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = recuerdeNumeroControllerProvider(widget.run.nivel);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (next.metrics != null && previous?.metrics == null) {
        widget.run.finish(next.metrics!);
      }
      // Solo entra acá cuando una ronda de verdad se resolvió (al
      // confirmar la respuesta completa, ver confirmar()/_terminarRonda
      // en el controller) — nunca por escribir/borrar un dígito, ni por
      // el Timer que oculta el número, ni por "Ver cómo se juega"
      // (pausar/reanudar no tocan este estado).
      if (previous != null && next.rondasJugadas > previous.rondasJugadas) {
        if (next.ultimaRondaCorrecta == true) {
          _racha++;
          if (ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
            );
          }
        } else {
          _racha = 0;
          if (ref.read(soundsEnabledProvider)) {
            unawaited(
              ref.read(soundServiceProvider).play(SoundEffect.errorSuave),
            );
          }
        }
      }
    });

    final mostrandoNumero = state.fase == RecuerdeNumeroFase.mostrando;
    final puedeResponder = state.fase == RecuerdeNumeroFase.esperandoRespuesta;
    final listoHabilitado = state.respuesta.length == state.digitos;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemoriaProgressIndicator(
            logrados: state.rondasCorrectas,
            total: recuerdeNumeroRondasCorrectasParaGanar,
            etiquetaVisible:
                'Rondas logradas: ${state.rondasCorrectas} de '
                '$recuerdeNumeroRondasCorrectasParaGanar',
            etiquetaAnuncio:
                'Ronda lograda, ${state.rondasCorrectas} de '
                '$recuerdeNumeroRondasCorrectasParaGanar',
          ),
          const SizedBox(height: 6),
          _buildMensaje(state),
          const SizedBox(height: 6),
          _buildCasilleros(state),
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
          Expanded(
            child: mostrandoNumero
                ? ExcludeSemantics(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          state.numero.split('').join(' '),
                          style: AppTextStyles.greeting.copyWith(
                            fontSize: 96,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                : RecuerdeNumeroKeypad(
                    bloqueado: !puedeResponder,
                    listoHabilitado: listoHabilitado,
                    onDigito: controller.tocarDigito,
                    onBorrar: controller.borrar,
                    onListo: controller.confirmar,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Un casillero que muestra un dígito ya escrito, o vacío. 100%
/// presentación.
class _DigitoBox extends StatelessWidget {
  const _DigitoBox({required this.orden, required this.digito});

  final int orden;
  final String? digito;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    final lleno = digito != null;

    return Semantics(
      label: lleno ? 'Casillero $orden: $digito' : 'Casillero $orden, vacío',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: lleno ? AppColors.primaryLight : AppColors.surface,
            borderRadius: radius,
            border: Border.all(
              color: lleno ? AppColors.primary : AppColors.border,
              width: lleno ? 2 : 1,
            ),
          ),
          child: Center(
            child: FittedBox(
              child: Text(
                digito ?? '',
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
