// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../games/game_catalog.dart';

/// Pantalla principal del adulto mayor.
/// 100% visual: no depende de backend ni de estado de sesión.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.onGameSelected,
    required this.onViewProgress,
    required this.onAvatarTap,
    this.dailyChallenge,
    this.profilePortrait,
  });

  final String userName;

  /// Recibe el id de la tarjeta: 'memoria', 'atencion', 'praxias'
  /// (Motricidad) o 'respiracion'.
  final void Function(String gameId) onGameSelected;
  final VoidCallback onViewProgress;
  final VoidCallback onAvatarTap;
  final Widget? dailyChallenge;
  final Widget? profilePortrait;

  @override
  Widget build(BuildContext context) {
    final initial = userName.isEmpty ? '' : userName[0].toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.surface],
                  ),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Qué gusto verle', style: AppTextStyles.tag),
                          const SizedBox(height: 5),
                          Text(
                            'Hola, $userName 🌿',
                            style: AppTextStyles.greeting,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Un momento para usted, a su ritmo.',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Mi perfil',
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAvatarTap,
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child:
                                  profilePortrait ??
                                  Text(
                                    initial,
                                    style: AppTextStyles.cardTitle.copyWith(
                                      color: AppColors.textOnPrimary,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Elija su práctica', style: AppTextStyles.cardTitle),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    for (final domain in GameDomain.values)
                      _GameCard(
                        icon: domain.icon,
                        title: domain.label,
                        description: switch (domain) {
                          GameDomain.memoria => 'Recuerde y asocie',
                          GameDomain.atencion => 'Observe y responda',
                          GameDomain.praxias => 'Practique con sus manos',
                        },
                        onTap: () => onGameSelected(domain.homeId),
                      ),
                    _GameCard(
                      icon: Icons.self_improvement,
                      title: 'Respiración',
                      description: 'Haga una pausa',
                      onTap: () => onGameSelected('respiracion'),
                    ),
                  ];
                  if (constraints.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(16) >= 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          cards[i],
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i += 2) ...[
                        if (i > 0) const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: cards[i]),
                              const SizedBox(width: 12),
                              Expanded(child: cards[i + 1]),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              ?dailyChallenge,
              OutlinedButton.icon(
                onPressed: onViewProgress,
                icon: const Icon(Icons.show_chart),
                label: const Text('Ver mi progreso'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeShape =
        Theme.of(context).cardTheme.shape as RoundedRectangleBorder?;
    final borderRadius =
        (themeShape?.borderRadius as BorderRadius?) ??
        BorderRadius.circular(18);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(title, style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(description, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }
}
