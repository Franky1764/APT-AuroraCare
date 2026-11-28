import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
// lib/presentation/caregiver_dashboard/caregiver_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/sources/practice_feedback_platform.dart';
import '../profile/profile_portrait.dart';
import 'caregiver_alerts.dart';
import 'caregiver_connection_provider.dart';
import 'caregiver_navigation.dart';
import 'caregiver_overview.dart';
import 'caregiver_unlink.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

/// «Mi perfil» del cuidador: foto o avatar, tamaño de texto, avisos y
/// vínculo, usando los mismos providers que el adulto mayor. El tema de
/// colores está en Configuración (CaregiverThemeScreen)
/// usando los mismos providers. Todo se guarda en este teléfono; nada se
/// comparte con el familiar.
class CaregiverProfileScreen extends ConsumerStatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  ConsumerState<CaregiverProfileScreen> createState() =>
      _CaregiverProfileScreenState();
}

enum _PortraitAction { photo, initial }

class _CaregiverProfileScreenState
    extends ConsumerState<CaregiverProfileScreen> {
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

  Future<void> _editPortrait() async {
    final account = ref.read(navigationSessionProvider).session?.uid;
    if (account == null) return;
    final selection = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Su foto de perfil', style: AppTextStyles.heading),
              const SizedBox(height: 6),
              Text(
                'Elija una imagen que le guste. Se guarda en este teléfono.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _PortraitAction.photo),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir una foto'),
              ),
              const SizedBox(height: 16),
              Text('O elija un avatar', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final avatar in ProfileAvatar.values)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () => Navigator.pop(context, avatar),
                      icon: Icon(avatar.icon),
                      label: Text(avatar.label),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _PortraitAction.initial),
                child: const Text('Usar mi inicial'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection == null ||
        !mounted ||
        ref.read(navigationSessionProvider).session?.uid != account) {
      return;
    }
    final portrait = ref.read(profilePortraitProvider.notifier);
    try {
      if (selection == _PortraitAction.photo) {
        final allowed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Abrir la galería?'),
            content: const Text(
              'AuroraCare solo podrá acceder a la foto que usted elija. '
              'Su foto de perfil se guardará en este teléfono.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir galería'),
              ),
            ],
          ),
        );
        if (allowed != true ||
            !mounted ||
            ref.read(navigationSessionProvider).session?.uid != account) {
          return;
        }
        await portrait.choosePhoto();
      } else {
        await portrait.chooseAvatar(
          selection is ProfileAvatar ? selection : null,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos cambiar su imagen. Inténtelo de nuevo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(navigationSessionProvider);
    final name = caregiverGreetingName(session.userName);
    final email = session.session?.email ?? '';
    final initial = name.isEmpty ? '' : name[0].toUpperCase();
    final isLargeText = ref.watch(textScaleProvider) > 1.0;
    final link = ref.watch(caregiverConnectionProvider);
    final isLinked = link.valueOrNull ?? false;
    final notifications = ref.watch(caregiverNotificationsEnabledProvider);
    final daily = ref.watch(caregiverDailyReminderProvider);

    final sections = <Widget>[
      _ProfileHeader(
        name: name.isEmpty ? 'Cuidador' : name,
        email: email,
        initial: initial,
        onEditPortrait: _editPortrait,
      ),
      _InfoRow(
        items: [
          _InfoItem(
            icon: isLinked ? Icons.favorite_rounded : Icons.link_off_rounded,
            title: isLinked ? 'Vinculado' : 'Sin vincular',
            caption: 'Familiar',
            color: isLinked ? AppColors.success : AppColors.textSecondary,
          ),
          _InfoItem(
            icon: notifications
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            title: notifications ? 'Activos' : 'Apagados',
            caption: 'Avisos',
            color: notifications ? AppColors.primary : AppColors.textSecondary,
          ),
          _InfoItem(
            icon: Icons.schedule_rounded,
            title: notifications && daily ? '19:00' : 'No',
            caption: 'Recordatorio',
            color: notifications && daily
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ],
      ),
      _Section(
        title: 'Lectura',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                _RoundIcon(Icons.text_fields_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tamaño de texto', style: AppTextStyles.body),
                      Text(
                        isLargeText ? 'Grande' : 'Normal',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                _SizeOption(
                  label: 'A',
                  selected: !isLargeText,
                  onTap: () => ref.read(textScaleProvider.notifier).set(1.0),
                ),
                const SizedBox(width: 8),
                _SizeOption(
                  label: 'A+',
                  selected: isLargeText,
                  onTap: () => ref.read(textScaleProvider.notifier).set(1.3),
                ),
              ],
            ),
          ),
        ],
      ),
      _Section(
        title: 'Avisos',
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            secondary: _RoundIcon(Icons.notifications_outlined),
            title: Text('Notificaciones', style: AppTextStyles.body),
            subtitle: const Text('Avisos sobre la práctica de su familiar.'),
            value: notifications,
            onChanged: (value) => _setAlerts(
              ref
                  .read(caregiverNotificationsEnabledProvider.notifier)
                  .set(value),
            ),
          ),
          Divider(height: 1, indent: 72, color: AppColors.border),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            secondary: _RoundIcon(Icons.schedule_rounded),
            title: Text('Recordatorio diario', style: AppTextStyles.body),
            subtitle: const Text('A las 19:00, para revisar el panel.'),
            value: daily,
            onChanged: (value) => _setAlerts(
              ref.read(caregiverDailyReminderProvider.notifier).set(value),
            ),
          ),
        ],
      ),
      _Section(
        title: 'Privacidad',
        children: [
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
            title: Text('Mis datos y privacidad', style: AppTextStyles.body),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.privacy),
          ),
        ],
      ),
      _Section(
        title: 'Vínculo',
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            leading: _RoundIcon(
              isLinked ? Icons.family_restroom_rounded : Icons.qr_code_scanner,
            ),
            title: Text(
              isLinked ? 'Familiar vinculado' : 'Vincular a un familiar',
              style: AppTextStyles.body,
            ),
            subtitle: Text(
              isLinked
                  ? 'Puede ver su actividad en el panel.'
                  : 'Escanee el código QR de su familiar.',
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
            onTap: isLinked
                ? () => CaregiverNavigation.goHome(context)
                : () => CaregiverNavigation.openQrScanner(context),
          ),
          if (isLinked) ...[
            Divider(height: 1, indent: 72, color: AppColors.border),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.errorBackground,
                child: Icon(Icons.link_off_rounded, color: AppColors.error),
              ),
              title: Text(
                'Dejar de ser cuidador',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              subtitle: const Text('Su familiar recibirá un aviso.'),
              onTap: () => confirmCaregiverUnlink(context, ref),
            ),
          ],
        ],
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
              for (var i = 0; i < sections.length; i++) ...[
                FadeSlideIn(index: i, child: sections[i]),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              FadeSlideIn(
                index: sections.length,
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

/// Encabezado con degradado del tema: foto o avatar, nombre y correo.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.initial,
    required this.onEditPortrait,
  });

  final String name;
  final String email;
  final String initial;
  final VoidCallback onEditPortrait;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Tooltip(
            message: 'Cambiar foto o avatar',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEditPortrait,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textOnPrimary,
                        width: 3,
                      ),
                    ),
                    child: ProfilePortrait(initial: initial, radius: 42),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.accent,
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.textOnPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: AppColors.textOnPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cuidador de su familiar',
                  style: AppTextStyles.tag.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.title,
    required this.caption,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String caption;
  final Color color;
}

/// Resumen rápido: vínculo, avisos y recordatorio.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(items[i].icon, color: items[i].color, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    items[i].title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.tag.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    items[i].caption,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.tag.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Grupo de opciones con título, en una sola tarjeta.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.tag.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'A' ? 'Texto normal' : 'Texto grande',
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: selected
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
