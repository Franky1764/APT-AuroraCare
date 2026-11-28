import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
// lib/presentation/profile/caregiver_link_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/caregiver_invite.dart';
import 'caregiver_link_notifier.dart';

/// Pantalla de vínculo con cuidador vía código QR (F8). Solo disponible
/// en Modo 3 (el llamador ya filtra eso). El código y su vencimiento
/// los controla el servidor; esta pantalla solo los muestra.
class CaregiverLinkScreen extends ConsumerStatefulWidget {
  const CaregiverLinkScreen({super.key});

  @override
  ConsumerState<CaregiverLinkScreen> createState() =>
      _CaregiverLinkScreenState();
}

class _CaregiverLinkScreenState extends ConsumerState<CaregiverLinkScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresca la pantalla cada segundo para que la cuenta regresiva se
    // vea avanzar. El valor mostrado SIEMPRE se recalcula desde
    // expiresAt - ahora (nunca desde un contador propio), así que esto
    // es puramente visual.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<bool> _confirmarConsentimiento() async {
    final acepto = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Antes de generar el código', style: AppTextStyles.heading),
        // Un Text por punto, con espacio entre ellos: un solo párrafo
        // corrido se leía muy junto. SingleChildScrollView es respaldo
        // para textScale alto en pantallas chicas (punto 4 del pedido).
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Al generar este código, quien lo escanee quedará '
                'vinculado como su cuidador.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'Su cuidador podrá ver cuándo practicó, sus resultados y su reporte de progreso.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'El código sirve una sola vez y vence en 10 minutos.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Text(
                'Puede desvincularlo cuando quiera. Generar otro código sustituye la invitación o vinculación anterior.',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aceptar y generar', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
    return acepto ?? false;
  }

  Future<void> _generar() async {
    final acepto = await _confirmarConsentimiento();
    if (!acepto || !mounted) return;
    await ref.read(caregiverLinkProvider.notifier).generar();
  }

  Future<void> _cancelar() =>
      ref.read(caregiverLinkProvider.notifier).cancelar();

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(caregiverLinkProvider);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    switch (error) {
                      TimeoutException() ||
                      FirebaseException(
                        code: 'unavailable' || 'deadline-exceeded',
                      ) => 'No pudimos confirmar el vínculo. Compruebe su conexión e inténtelo de nuevo.',
                      FirebaseException(code: 'permission-denied') => 'No hay permiso para consultar el vínculo en este momento.',
                      _ =>
                        'No pudimos consultar el vínculo. Inténtelo de nuevo.',
                    },
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(caregiverLinkProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          data: (state) => _Contenido(
            state: state,
            onGenerar: _generar,
            onCancelar: _cancelar,
            onDesvincular: () =>
                ref.read(caregiverLinkProvider.notifier).desvincular(),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.state,
    required this.onGenerar,
    required this.onCancelar,
    required this.onDesvincular,
  });

  final CaregiverLinkState state;
  final VoidCallback onGenerar;
  final VoidCallback onCancelar;
  final VoidCallback onDesvincular;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (state.status) {
              CaregiverLinkViewStatus.none => _vistaSinInvitacion(onGenerar),
              CaregiverLinkViewStatus.active => _vistaActiva(
                state.invite!,
                onCancelar,
              ),
              CaregiverLinkViewStatus.expired => _vistaVencida(onGenerar),
              CaregiverLinkViewStatus.redeemed => _vistaVinculada(
                context,
                onDesvincular,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Envuelve [titulo] y [mensaje] en un solo anuncio de accesibilidad:
/// cada cambio de estado se lee una vez, completo, no cada segundo.
Widget _mensajeDeEstado({
  required IconData icono,
  required Color colorIcono,
  required String titulo,
  required String mensaje,
}) {
  return Semantics(
    liveRegion: true,
    label: '$titulo. $mensaje',
    child: ExcludeSemantics(
      child: Column(
        children: [
          Icon(icono, size: 64, color: colorIcono),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    ),
  );
}

List<Widget> _vistaSinInvitacion(VoidCallback onGenerar) {
  return [
    Text(
      'Vincular con un cuidador',
      textAlign: TextAlign.center,
      style: AppTextStyles.heading,
    ),
    const SizedBox(height: 12),
    Text(
      'Genere un código para que su cuidador lo escanee y quede '
      'vinculado.',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySecondary,
    ),
    const SizedBox(height: 32),
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: onGenerar,
      child: const Text('Generar código', textAlign: TextAlign.center),
    ),
  ];
}

List<Widget> _vistaActiva(CaregiverInvite invite, VoidCallback onCancelar) {
  return [
    Text(
      'Pida a su cuidador que escanee este código',
      textAlign: TextAlign.center,
      style: AppTextStyles.heading,
    ),
    const SizedBox(height: 24),
    Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: QrImageView(
          data: invite.qrPayload,
          size: 190,
          eyeStyle: QrEyeStyle(color: AppColors.primary),
          dataModuleStyle: QrDataModuleStyle(color: AppColors.primary),
        ),
      ),
    ),
    const SizedBox(height: 20),
    _CuentaRegresiva(expiresAt: invite.expiresAt),
    const SizedBox(height: 24),
    OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: onCancelar,
      child: const Text('Cancelar invitación', textAlign: TextAlign.center),
    ),
  ];
}

List<Widget> _vistaVencida(VoidCallback onGenerar) {
  return [
    _mensajeDeEstado(
      icono: Icons.timer_off_outlined,
      colorIcono: AppColors.textSecondary,
      titulo: 'El código venció',
      mensaje: 'Genere uno nuevo para vincular a su cuidador.',
    ),
    const SizedBox(height: 32),
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: onGenerar,
      child: const Text('Generar uno nuevo', textAlign: TextAlign.center),
    ),
  ];
}

List<Widget> _vistaVinculada(BuildContext context, VoidCallback onDesvincular) {
  return [
    _mensajeDeEstado(
      icono: Icons.check_circle,
      colorIcono: AppColors.success,
      titulo: '¡Listo!',
      mensaje: 'Su cuidador podrá consultar su actividad y los resultados de sus prácticas.',
    ),
    const SizedBox(height: 32),
    OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Volver', textAlign: TextAlign.center),
    ),
    TextButton(
      onPressed: onDesvincular,
      child: const Text('Desvincular cuidador'),
    ),
  ];
}

/// Cuenta regresiva: se recalcula en cada build desde
/// expiresAt - DateTime.now(). El widget padre (CaregiverLinkScreen) la
/// reconstruye una vez por segundo; este widget nunca guarda su propio
/// contador.
class _CuentaRegresiva extends StatelessWidget {
  const _CuentaRegresiva({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final restante = expiresAt.difference(DateTime.now());
    final segundos = restante.isNegative ? 0 : restante.inSeconds;
    final minutos = segundos ~/ 60;
    final segundosResto = segundos % 60;
    final textoVisible =
        'Vence en ${minutos.toString().padLeft(2, '0')}:'
        '${segundosResto.toString().padLeft(2, '0')}';

    // El anuncio de accesibilidad redondea a minutos: así no se repite
    // cada segundo, solo cuando cambia el minuto.
    final minutosRedondeados = (segundos / 60).ceil();
    final textoAnunciado = minutosRedondeados <= 0
        ? 'El código está por vencer'
        : minutosRedondeados == 1
        ? 'Código vence en 1 minuto'
        : 'Código vence en $minutosRedondeados minutos';

    return Semantics(
      liveRegion: true,
      label: textoAnunciado,
      child: ExcludeSemantics(
        child: Text(
          textoVisible,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading,
        ),
      ),
    );
  }
}
