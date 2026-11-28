import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_invite_scan_controller.dart';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../caregiver_dashboard/widgets/caregiver_animations.dart';
import '../../caregiver_dashboard/widgets/caregiver_app_bar.dart';

class CaregiverQrScanScreen extends ConsumerWidget {
  const CaregiverQrScanScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  static const Color _scannerBackground = Color(0xFF1A162B);
  static const double _viewfinderSize = 220;

  // El visor es siempre oscuro, sin importar el tema (como la pantalla de
  // una cámara). El borde y la línea de escaneo tampoco dependen del tema:
  // AppColors.primary/accent cambian de valor según la paleta activa y
  // varias combinaciones quedaban por debajo de 3:1 sobre este fondo fijo
  // (incluida Aurora: su primary actual da solo 2,61:1 aquí). Estos 2
  // colores fijos sí cumplen 3:1 contra _scannerBackground en cualquier
  // tema. _scannerAccent usa el mismo dorado que ya tenía Aurora, así que
  // la línea de escaneo no cambia para quien ya usa Aurora.
  static const Color _scannerBorder = Color(0xFF7B6AD1);
  static const Color _scannerAccent = Color(0xFFE8B33C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(caregiverInviteScanProvider);
    ref.listen(caregiverInviteScanProvider, (_, next) {
      if (next.valueOrNull == true) onContinue?.call();
    });
    return Scaffold(
      backgroundColor: _scannerBackground,
      appBar: const CaregiverAppBar(dark: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              FadeSlideIn(
                child: Text(
                  'Escanea el código QR',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: PopIn(
                  child: Container(
                    width: _viewfinderSize,
                    height: _viewfinderSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: _scannerBorder, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            onDetect: (capture) {
                              if (scan.isLoading ||
                                  scan.hasError ||
                                  scan.valueOrNull == true) {
                                return;
                              }
                              for (final barcode in capture.barcodes) {
                                final value = barcode.rawValue;
                                if (value != null) {
                                  ref
                                      .read(
                                        caregiverInviteScanProvider.notifier,
                                      )
                                      .scan(value);
                                  break;
                                }
                              }
                            },
                          ),
                          const _ScanLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (scan.hasError)
                Text(
                  'No pudimos usar este código. Puede estar vencido, cancelado o ya utilizado. Pida uno nuevo e intente otra vez.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 2,
                child: ElevatedButton(
                  onPressed: scan.hasError
                      ? () => ref
                            .read(caregiverInviteScanProvider.notifier)
                            .retry()
                      : null,
                  child: Text(
                    scan.hasError
                        ? 'Volver a escanear'
                        : scan.isLoading
                        ? 'Comprobando código…'
                        : 'Apunte al código de AuroraCare',
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Align(
            alignment: Alignment(0, -0.9 + 1.8 * t),
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CaregiverQrScanScreen._scannerAccent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: CaregiverQrScanScreen._scannerAccent.withValues(
                      alpha: 0.6,
                    ),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
