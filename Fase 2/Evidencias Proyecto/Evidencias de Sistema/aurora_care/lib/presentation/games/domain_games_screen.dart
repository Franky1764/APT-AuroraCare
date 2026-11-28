// lib/presentation/games/domain_games_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/firebase_providers.dart';
import '../../core/theme/app_text_styles.dart';
import 'game_catalog.dart';
import 'memoria/mis_recuerdos/mis_recuerdos_entry_screen.dart';
import 'shared/game_definition.dart';
import 'shared/game_level_screen.dart';

enum MotorPracticeGroup { general, phone }

/// Lista los juegos de un dominio. Cada juego abre GameLevelScreen, que es la
/// entrada común (consentimiento de métricas, instrucciones y nivel).
///
/// En Memoria se agrega además una tarjeta especial "Mis recuerdos": NO es
/// un GameDefinition (no tiene puntaje, no pasa por GameShell/FinishSession,
/// igual que Respiración guiada) — abre su propia pantalla directo. Esta
/// pantalla resuelve el uid UNA sola vez (ConsumerWidget) y lo pasa como
/// parámetro simple hacia abajo, para que mis_recuerdos/ no dependa de
/// FirebaseAuth directamente (así sus widgets se testean sin mockear
/// Firebase).
class DomainGamesScreen extends ConsumerWidget {
  const DomainGamesScreen({
    super.key,
    required this.domain,
    this.motorPracticeGroup,
  });

  final GameDomain domain;
  final MotorPracticeGroup? motorPracticeGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juegos = juegosDeDominio(domain).where(
      (game) =>
          domain != GameDomain.praxias ||
          game.phonePractice ==
              (motorPracticeGroup == MotorPracticeGroup.phone),
    );
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    if (domain == GameDomain.praxias && motorPracticeGroup == null) {
      void open(MotorPracticeGroup group) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              DomainGamesScreen(domain: domain, motorPracticeGroup: group),
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Motricidad'), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('¿Qué quiere practicar?', style: AppTextStyles.heading),
              const SizedBox(height: 12),
              Text(
                'Elija cómo quiere ejercitar sus movimientos hoy.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 24),
              _EntradaEspecialCard(
                titulo: 'Ejercitar mis movimientos',
                icono: Icons.gesture_rounded,
                onTap: () => open(MotorPracticeGroup.general),
              ),
              const SizedBox(height: 8),
              Text(
                'Recorrer figuras, conectar puntos y colorear.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 24),
              _EntradaEspecialCard(
                titulo: 'Practicar con mi teléfono',
                icono: Icons.touch_app_outlined,
                onTap: () => open(MotorPracticeGroup.phone),
              ),
              const SizedBox(height: 8),
              Text(
                'Practicar los gestos y la navegación del teléfono, a su ritmo.',
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          domain == GameDomain.praxias
              ? motorPracticeGroup == MotorPracticeGroup.phone
                    ? 'Practicar con mi teléfono'
                    : 'Ejercitar mis movimientos'
              : domain.label,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            Text('Elija un ejercicio', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 16),
            for (final juego in juegos) ...[
              _JuegoCard(
                definition: juego,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameLevelScreen(definition: juego),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (domain == GameDomain.memoria)
              _EntradaEspecialCard(
                titulo: 'Mis recuerdos',
                icono: Icons.favorite_border,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MisRecuerdosEntryScreen(uid: uid),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una entrada que NO es un GameDefinition (no pasa por
/// GameLevelScreen). Mismo estilo visual que _JuegoCard, para que no se
/// note la diferencia arquitectónica desde la interfaz.
class _EntradaEspecialCard extends StatelessWidget {
  const _EntradaEspecialCard({
    required this.titulo,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final IconData icono;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icono, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(titulo, style: AppTextStyles.cardTitle)),
                Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JuegoCard extends StatelessWidget {
  const _JuegoCard({required this.definition, required this.onTap});

  final GameDefinition definition;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(definition.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(definition.title, style: AppTextStyles.cardTitle),
                ),
                Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
