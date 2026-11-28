// lib/presentation/games/shared/game_level_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/firebase_providers.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game_level.dart';
import '../../../domain/usecases/set_metrics_consent.dart';
import '../../../domain/usecases/set_metrics_consent.provider.dart';
import 'game_definition.dart';
import 'game_providers.dart';
import 'game_shell.dart';
import 'metrics_consent_providers.dart';
import 'metrics_consent_view.dart';

/// Pantalla previa de cada juego: consentimiento de métricas (si aún no lo
/// dio), instrucciones y elección de nivel. Es la entrada común de todos los
/// juegos, por eso el consentimiento se exige aquí.
class GameLevelScreen extends ConsumerStatefulWidget {
  const GameLevelScreen({super.key, required this.definition});

  final GameDefinition definition;

  @override
  ConsumerState<GameLevelScreen> createState() => _GameLevelScreenState();
}

class _GameLevelScreenState extends ConsumerState<GameLevelScreen> {
  late GameLevel _nivel;

  @override
  void initState() {
    super.initState();
    // El último nivel usado queda como predeterminado.
    _nivel = ref.read(levelPreferenceProvider).read(widget.definition.gameType);
  }

  Future<void> _start() async {
    await ref
        .read(levelPreferenceProvider)
        .write(widget.definition.gameType, _nivel);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameShell(definition: widget.definition, nivel: _nivel),
      ),
    );
  }

  Future<void> _acceptConsent(String uid) async {
    await ref
        .read(setMetricsConsentProvider)
        .call(SetMetricsConsentParams(uid: uid, given: true))
        .timeout(const Duration(seconds: 8));
    ref.invalidate(metricsConsentProvider(uid));
  }

  void _declineConsent() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Para jugar necesitamos guardar cómo le va. '
          'Puede aceptar cuando quiera.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      return const _BlockedScaffold(message: 'Inicie sesión para jugar.');
    }

    final consent = ref.watch(metricsConsentProvider(uid));
    return consent.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _BlockedScaffold(
        message:
            'No pudimos comprobar su autorización. '
            'Revise su conexión e intente de nuevo.',
        onRetry: () => ref.invalidate(metricsConsentProvider(uid)),
      ),
      data: (given) => given
          ? _buildLevelSelector(context)
          : MetricsConsentView(
              onAccept: () => _acceptConsent(uid),
              onDecline: _declineConsent,
            ),
    );
  }

  Widget _buildLevelSelector(BuildContext context) {
    final definition = widget.definition;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            definition.icon,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            definition.title,
                            style: AppTextStyles.heading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      definition.instructions,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      definition.levelPrompt,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 12),
                    for (final level in GameLevel.values) ...[
                      _LevelButton(
                        level: level,
                        label: definition.levelLabels[level],
                        selected: level == _nivel,
                        onTap: () => setState(() => _nivel = level),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _start,
                  child: const Text('Comenzar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de bloqueo: no se puede abrir el juego (sin sesión, o no se pudo
/// comprobar el consentimiento). Nunca se asume que el consentimiento existe.
class _BlockedScaffold extends StatelessWidget {
  const _BlockedScaffold({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const ValueKey('consent_retry'),
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
    required this.level,
    this.label,
    required this.selected,
    required this.onTap,
  });

  final GameLevel level;
  final String? label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? AppColors.primaryLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 3 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label ?? level.label,
                  style: AppTextStyles.cardTitle,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
