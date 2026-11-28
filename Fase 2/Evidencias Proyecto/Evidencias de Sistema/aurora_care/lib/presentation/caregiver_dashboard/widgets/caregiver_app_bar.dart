import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../caregiver_navigation.dart';
import 'caregiver_notifications_panel.dart';

class CaregiverAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CaregiverAppBar({
    super.key,
    this.showBackButton = true,
    this.showNotifications = false,
    this.dark = false,
  });

  static const String logoFullPath = 'assets/images/LogoAuroraFinal.png';
  static const String logoIconPath = 'assets/images/IconoAuroraLila.png';

  final bool showBackButton;
  final bool showNotifications;

  final bool dark;

  static const double _height = kToolbarHeight + 8;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: _height,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: showBackButton
          ? Center(
              child: _RoundIconButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: 'Volver',
                dark: dark,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      title: Tooltip(
        message: 'Ir al inicio',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => CaregiverNavigation.goHome(context),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              logoIconPath,
              height: 44,
              fit: BoxFit.contain,
              semanticLabel: 'AuroraCare, ir al inicio',
            ),
          ),
        ),
      ),
      actions: [
        if (showNotifications)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notificaciones',
              dark: dark,
              showBadge: false,
              onPressed: () => showCaregiverNotifications(context),
            ),
          )
        else
          const SizedBox(width: 56),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.dark = false,
    this.showBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool dark;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: dark
            ? AppColors.textOnPrimary.withValues(alpha: 0.12)
            : AppColors.primaryLight,
        foregroundColor: dark ? AppColors.textOnPrimary : AppColors.primary,
        fixedSize: const Size(44, 44),
      ),
      icon: Badge(
        isLabelVisible: showBadge,
        smallSize: 10,
        backgroundColor: AppColors.error,
        child: Icon(icon, size: 22),
      ),
    );
  }
}
