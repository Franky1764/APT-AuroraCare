// lib/presentation/breathing/breathing_complete_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Cierre de la respiración guiada (F5). Sin puntajes ni estadísticas.
class BreathingCompleteScreen extends StatelessWidget {
  const BreathingCompleteScreen({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.self_improvement,
                          color: AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '¡Muy bien, $userName!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Terminó su momento de calma.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
