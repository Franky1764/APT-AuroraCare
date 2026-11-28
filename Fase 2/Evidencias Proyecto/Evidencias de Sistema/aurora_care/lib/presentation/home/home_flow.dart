// lib/presentation/home/home_flow.dart

import 'package:flutter/material.dart';

import '../../core/audio/music_route_scope.dart';
import '../../core/audio/sound_effect.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../breathing/breathing_duration_screen.dart';
import '../challenges/daily_challenge_card.dart';
import '../games/domain_games_screen.dart';
import '../games/game_catalog.dart';
import '../profile/profile_screen.dart';
import '../profile/profile_portrait.dart';
import '../progress/progress_screen.dart';
import 'home_screen.dart';

/// HomeScreen con todos sus callbacks ya conectados (perfil, progreso,
/// juegos). Única versión de Inicio: se usa tanto en el flujo normal
/// (tras elegir modo, en welcome_flow.dart) como en AuthGate (sesión
/// guardada), para que ambos caminos tengan el mismo comportamiento.
///
/// No toma BuildContext como parámetro: usa el context del propio
/// HomeScreen (vía Builder), igual que buildWelcomeFlow() en
/// welcome_flow.dart.
///
/// Las tarjetas del Home son por dominio (Memoria, Atención, Motricidad):
/// cada una abre DomainGamesScreen con los juegos de game_catalog.dart.
/// Respiración queda fuera del catálogo y abre su propia pantalla.
Widget buildHomeScreen(String userName) {
  return Builder(
    builder: (context) => MusicRouteScope(
      track: MusicTrack.menu,
      child: HomeScreen(
        userName: userName,
        dailyChallenge: const DailyChallengeCard(),
        profilePortrait: ProfilePortrait(
          initial: userName.isEmpty ? '' : userName[0].toUpperCase(),
          radius: 24,
        ),
        onGameSelected: (gameId) {
          if (gameId == 'respiracion') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreathingDurationScreen(userName: userName),
              ),
            );
            return;
          }
          final domain = dominioPorHomeId(gameId);
          if (domain != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DomainGamesScreen(domain: domain),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Próximamente podrás jugar a este ejercicio.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        onViewProgress: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProgressScreen(userName: userName),
            ),
          );
        },
        onAvatarTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userName: userName),
            ),
          );
        },
      ),
    ),
  );
}
