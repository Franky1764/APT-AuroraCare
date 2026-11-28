import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/practice_feedback_platform.dart';
import '../profile/help_support_screen.dart';
import 'caregiver_alerts.dart';
import 'caregiver_connection_provider.dart';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/theme/app_text_styles.dart';
import 'caregiver_navigation.dart';
import 'caregiver_profile_screen.dart';
import 'caregiver_theme_screen.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

class CaregiverSettingsScreen extends ConsumerStatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  ConsumerState<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState
    extends ConsumerState<CaregiverSettingsScreen> {
  Future<void> _setAlerts(Future<bool> change) async {
    final allowed = await change;
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Si desea recibir avisos, permita las notificaciones de AuroraCare en Ajustes.',
          ),
          action: SnackBarAction(
            label: 'Abrir Ajustes',
            onPressed: () =>
                ref.read(practiceFeedbackPlatformProvider).openSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLinked =
        ref.watch(caregiverConnectionProvider).valueOrNull ?? false;

    final options = <Widget>[
      _SettingsTile(
        label: 'Mi perfil',
        onTap: () => Navigator.of(
          context,
        ).push(caregiverPageRoute<void>(const CaregiverProfileScreen())),
      ),
      if (isLinked)
        _SettingsTile(
          leading: Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
          ),
          label: 'Familiar vinculado',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La cuenta ya tiene un familiar vinculado. Aún no hay un resumen compartido.',
              ),
            ),
          ),
        )
      else
        _SettingsTile(
          leading: Icon(Icons.qr_code_scanner, color: AppColors.primary),
          label: 'Vincular a un familiar',
          onTap: () => CaregiverNavigation.openQrScanner(context),
        ),
      _SwitchTile(
        label: 'Notificaciones',
        value: ref.watch(caregiverNotificationsEnabledProvider),
        onChanged: (value) => _setAlerts(
          ref.read(caregiverNotificationsEnabledProvider.notifier).set(value),
        ),
      ),
      _SwitchTile(
        label: 'Recordatorios diarios',
        value: ref.watch(caregiverDailyReminderProvider),
        onChanged: (value) => _setAlerts(
          ref.read(caregiverDailyReminderProvider.notifier).set(value),
        ),
      ),
      // Mismos temas que el adulto mayor, con pantalla propia del cuidador.
      // El tema se guarda en este teléfono: no se comparte con el familiar.
      // El nombre del tema va debajo del título: «Accesible para
      // daltonismo» no cabe a la derecha y aplastaba el título (H71).
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => Navigator.of(
            context,
          ).push(caregiverPageRoute<void>(const CaregiverThemeScreen())),
          leading: Icon(Icons.palette_outlined, color: AppColors.primary),
          title: Text('Tema de colores', style: AppTextStyles.body),
          subtitle: Text(
            ref.watch(themeProvider).nombre,
            style: AppTextStyles.bodySecondary,
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
      ),
      _SettingsTile(
        label: 'Ayuda y soporte',
        onTap: () => Navigator.of(context).push(
          caregiverPageRoute<void>(const HelpSupportScreen(isCaregiver: true)),
        ),
      ),
    ];

    return Scaffold(
      appBar: const CaregiverAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text('Configuración', style: AppTextStyles.heading),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < options.length; i++)
                FadeSlideIn(index: 1 + i, child: options[i]),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 1 + options.length,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.errorBackground,
                    side: BorderSide(color: AppColors.error, width: 2),
                  ),
                  onPressed: () => CaregiverNavigation.confirmLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(label, style: AppTextStyles.body),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        title: Text(label, style: AppTextStyles.body),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
