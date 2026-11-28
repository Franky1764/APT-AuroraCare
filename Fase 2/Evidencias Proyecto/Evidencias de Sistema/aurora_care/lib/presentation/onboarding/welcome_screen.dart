// lib/presentation/onboarding/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

import '../../core/theme/app_text_styles.dart';

/// Pantalla de bienvenida de AuroraCare (F1 — onboarding).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/LogoAuroraFinal.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ejercicios simples para mantener la mente activa.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed:
                    onContinue ?? () => context.push(AppRoutes.roleSelection),
                child: const Text('Comenzar'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
