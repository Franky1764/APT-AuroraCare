// lib/presentation/onboarding/splash_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Pantalla de carga mientras AuthGate resuelve si hay una sesión
/// guardada. Solo el logo (ya incluye el nombre "AuroraCare"), sin
/// botones ni otros elementos.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width * 0.75).clamp(0.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset(
          'assets/images/LogoAuroraFinal.png',
          width: width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
