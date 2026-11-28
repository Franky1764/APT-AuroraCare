// lib/presentation/shared/app_header_bar.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Header reutilizable con el logo de AuroraCare centrado y botón de volver
/// opcional a la izquierda. La campana se quitó porque no abría nada.
/// Mismo patrón visual que CaregiverAppBar (pantallas de cuidador de
/// Eduardo), adaptado para las pantallas del adulto mayor.
class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderBar({
    super.key,
    this.showBackButton = false,
    this.onLogoTap,
    this.onBellTap,
  });

  // Mismo ícono de logo que usa CaregiverAppBar (assets/images ya trae el
  // logo real del proyecto, no hace falta un placeholder).
  static const String _logoPath = 'assets/images/IconoAuroraLila.png';

  final bool showBackButton;
  final VoidCallback? onLogoTap;
  /// Ya no se usa (la campana se quitó). Se mantiene para no romper a
  /// las pantallas que todavía lo pasan.
  final VoidCallback? onBellTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      title: GestureDetector(
        onTap: onLogoTap,
        child: Image.asset(_logoPath, height: 32),
      ),
      centerTitle: true,
    );
  }
}
