import '../../data/repositories/auth_repository_impl.provider.dart';
import '../../domain/entities/account_role.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/router/navigation_session.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/caregiver/caregiver_qr_scan_screen.dart';
import 'activity_detail_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'caregiver_settings_screen.dart';
import 'progress_report_screen.dart';
import 'weekly_summary_screen.dart';
import 'widgets/caregiver_animations.dart';

class CaregiverNavigation {
  CaregiverNavigation._();

  static const String homeRouteName = '/caregiver/home';

  static void startSession(BuildContext context) {
    final session = ProviderScope.containerOf(context)
        .read(navigationSessionProvider)
        .session;
    final router = GoRouter.maybeOf(context);
    if (session?.role != AccountRole.caregiver) {
      router?.go(AppRoutes.caregiverLogin);
      return;
    }
    if (router != null) {
      router.go(AppRoutes.caregiverHome);
      return;
    }
    Navigator.of(context)
        .pushAndRemoveUntil(_homeRoute(), (route) => route.isFirst);
  }

  static void goHome(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.caregiverHome);
      return;
    }
    Navigator.of(context).popUntil(ModalRoute.withName(homeRouteName));
  }

  static void openQrScanner(BuildContext context) {
    Navigator.of(context).push(
      caregiverPageRoute<void>(
        Builder(
          builder: (qrContext) => CaregiverQrScanScreen(
            onContinue: () {
              Navigator.of(qrContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Vinculación registrada. Puede consultar la actividad desde su panel.',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Detalle real de un área ('memoria', 'atencion' o 'praxias').
  static void openActivityDetail(BuildContext context, String areaKey) {
    _push(context, ActivityDetailScreen(areaKey: areaKey));
  }

  static void openProgressReport(BuildContext context) {
    _push(context, const ProgressReportScreen());
  }

  static void openWeeklySummary(BuildContext context) {
    _push(context, const WeeklySummaryScreen());
  }

  static void openSettings(BuildContext context) {
    _push(context, const CaregiverSettingsScreen());
  }

  static Future<void> confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Cerrar sesión?', style: AppTextStyles.heading),
        content: Text(
          'Tendrás que volver a ingresar con tu correo y contraseña.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cerrar sesión',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await logout(context);
    }
  }

  static Future<void> logout(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(authRepositoryProvider).logout();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cerrar la sesión. Intente de nuevo.'),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    container.read(navigationSessionProvider.notifier).clear();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.welcome);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature estará disponible pronto.',
            style: AppTextStyles.body.copyWith(color: AppColors.textOnPrimary),
          ),
        ),
      );
  }

  static Route<void> _homeRoute() {
    return caregiverPageRoute<void>(
      const CaregiverDashboardScreen(),
      settings: const RouteSettings(name: homeRouteName),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(caregiverPageRoute<void>(screen));
  }
}
