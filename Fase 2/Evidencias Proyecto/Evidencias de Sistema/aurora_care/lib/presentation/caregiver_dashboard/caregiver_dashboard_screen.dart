import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_alerts.dart';
import 'caregiver_connection_provider.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'caregiver_navigation.dart';
import 'caregiver_overview.dart';
import 'caregiver_report_screen.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key, this.caregiverName});

  final String? caregiverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avisos al cuidador (SCRUM-34): revisa cada resumen nuevo.
    ref.watch(caregiverAlertsSyncProvider);
    final name = caregiverGreetingName(caregiverName);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: CaregiverAppBar(
          showBackButton: false,
          // Sin campana: los avisos llegan como notificaciones del teléfono.
          showNotifications: false,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  child: CaregiverGreetingHeader(
                    name: name,
                    onOpenSettings: () =>
                        CaregiverNavigation.openSettings(context),
                  ),
                ),
                const SizedBox(height: 24),
                ref
                    .watch(caregiverConnectionProvider)
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'No pudimos consultar la vinculación.',
                              ),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(caregiverConnectionProvider),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (connected) => connected
                          ? CaregiverOverview(
                              onOpenReport: () => Navigator.of(context).push(
                                caregiverPageRoute<void>(
                                  const CaregiverReportScreen(),
                                ),
                              ),
                            )
                          : const FadeSlideIn(
                              index: 1,
                              child: _WaitingForLinkCard(),
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

class _WaitingForLinkCard extends StatelessWidget {
  const _WaitingForLinkCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GentlePulse(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.qr_code_2,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no tienes a nadie vinculado',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 12),
            Text(
              'Para vincularte con tu familiar, pídele que abra '
              'AuroraCare en su teléfono y te muestre su código QR.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => CaregiverNavigation.openQrScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear código QR'),
            ),
          ],
        ),
      ),
    );
  }
}
