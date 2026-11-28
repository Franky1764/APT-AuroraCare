import '../challenges/daily_challenge_card.dart';
import '../caregiver_dashboard/shared_practice_provider.dart';
// lib/presentation/progress/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'progress_providers.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/session_feedback.dart';
import '../games/shared/session_feedback_card.dart';
import '../games/shared/game_providers.dart';
import '../games/game_catalog.dart';
import '../shared/detail_dialog.dart';

class DomainProgress {
  const DomainProgress({
    required this.domain,
    required this.icon,
    required this.color,
    this.filledDots = 0,
    required this.statusText,
    this.sessions,
  });

  final String domain;
  final IconData icon;
  final Color color;

  // Compatibilidad con datos inyectados de pruebas; no se muestran puntos.
  final int filledDots;

  final int? sessions;
  final String statusText;
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({
    super.key,
    required this.userName,
    this.memory,
    this.attention,
    this.motorSkills,
    this.onGenerateReport,
  });

  final String userName;
  final DomainProgress? memory;
  final DomainProgress? attention;
  final DomainProgress? motorSkills;

  final VoidCallback? onGenerateReport;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String? _latestSummary(DomainSummary domain) {
    final session = domain.latestSession;
    if (session == null) return null;
    final items = SessionFeedback.fromMetrics(
      session.metrics,
      gameType: session.gameType,
    ).items;
    if (items.isEmpty) return null;
    final item = items.entries.first;
    return 'Última partida · ${item.key}: ${item.value}';
  }

  Widget _latestFeedback(DomainSummary domain) {
    final session = domain.latestSession!;
    final date = session.startTime.toLocal();
    var gameName = 'Ejercicio registrado';
    var levelName = 'Nivel ${session.nivel.label}';
    for (final game in gameCatalog.values.expand((games) => games)) {
      if (game.gameType == session.gameType) {
        gameName = game.title;
        levelName = game.levelLabels[session.nivel] ?? levelName;
        break;
      }
    }
    return SessionFeedbackCard(
      title: 'Última partida',
      subtitle:
          '$gameName · ${date.day}/${date.month}/${date.year} · $levelName',
      feedback: SessionFeedback.fromMetrics(
        session.metrics,
        gameType: session.gameType,
      ),
      compact: false,
    );
  }

  void _handleGenerateReport() {
    if (widget.onGenerateReport != null) {
      widget.onGenerateReport!();
      return;
    }
    context.push(AppRoutes.progressReport);
  }

  List<Widget> _buildProgress() {
    final injected = [widget.memory, widget.attention, widget.motorSkills];
    if (injected.every((item) => item != null)) {
      return [
        for (final item in injected) ...[
          _ProgressCard(progress: item!),
          const SizedBox(height: 16),
        ],
      ];
    }
    ref.watch(syncSharedPracticeProvider);
    return ref
        .watch(progressProvider)
        .when(
          loading: () => [
            const Center(child: CircularProgressIndicator()),
            const Text('Cargando tu progreso…'),
          ],
          error: (error, stack) => [
            const Text('No pudimos cargar tu progreso.'),
            TextButton(
              onPressed: () {
                ref.invalidate(activeProfileProvider);
                ref.invalidate(progressProvider);
              },
              child: const Text('Reintentar'),
            ),
          ],
          data: (summary) {
            if (!summary.hasProfile) {
              return [
                const Text(
                  'No hay un perfil activo para consultar el progreso.',
                ),
              ];
            }
            return [
              _PracticeOverview(summary: summary),
              const SizedBox(height: 20),
              Text('Detalle por área', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              if (summary.domains.every((domain) => domain.sessions == 0))
                const Text(
                  'No hay sesiones registradas en los últimos 28 días.',
                ),
              for (final domain in summary.domains) ...[
                _ProgressCard(
                  summary: _latestSummary(domain),
                  onTap: () => showDetailDialog(
                    context: context,
                    title: switch (domain.domain) {
                      'memoria' => 'Seguimiento de memoria',
                      'atencion' => 'Seguimiento de atención',
                      _ => 'Seguimiento de motricidad',
                    },
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          domain.contextText,
                          style: AppTextStyles.bodySecondary,
                        ),
                        if (domain.latestSession != null) ...[
                          const SizedBox(height: 16),
                          _latestFeedback(domain),
                        ],
                      ],
                    ),
                  ),
                  progress: DomainProgress(
                    domain: switch (domain.domain) {
                      'memoria' => 'Memoria',
                      'atencion' => 'Atención',
                      _ => 'Motricidad',
                    },
                    icon: switch (domain.domain) {
                      'memoria' => Icons.spa,
                      'atencion' => Icons.track_changes,
                      _ => Icons.back_hand,
                    },
                    color: AppColors.primary,
                    sessions: domain.sessions,
                    statusText:
                        '${domain.statusText}${domain.level == null ? '' : ' · Nivel ${domain.level!.label}'}',
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ];
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildProgress(),
              const SizedBox(height: 8),
              Card(
                color: AppColors.primaryLight,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Mi informe', style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text(
                        'Reúna sus resultados para guardarlos o compartirlos.',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _handleGenerateReport,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Generar reporte de mi progreso'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeOverview extends StatelessWidget {
  const _PracticeOverview({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final count = summary.domains.fold(
      0,
      (total, area) => total + area.sessions,
    );
    final now = DateTime.now();
    final practicedToday = summary.domains.any(
      (area) => DateUtils.isSameDay(area.latestSession?.endTime.toLocal(), now),
    );
    const radius = BorderRadius.all(Radius.circular(24));
    return Material(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
        ),
        child: Semantics(
          hint: 'Ver progreso por día',
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PracticeCalendar(showChallenges: false),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textOnPrimary,
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textOnPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Últimos 28 días',
                    style: AppTextStyles.tag.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    switch (count) {
                      0 => 'Su práctica empieza aquí',
                      1 => '1 práctica registrada',
                      _ => '$count prácticas registradas',
                    },
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    practicedToday
                        ? 'Hoy ya practicó. ¡Un momento para usted!'
                        : 'Cada práctica cuenta, a su ritmo.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, this.onTap, this.summary});

  final DomainProgress progress;
  final VoidCallback? onTap;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(progress.icon, size: 22, color: progress.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      progress.domain,
                      style: AppTextStyles.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (progress.sessions != null)
                Text(
                  progress.sessions == 1
                      ? '1 sesión registrada'
                      : '${progress.sessions} sesiones registradas',
                ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    progress.statusText,
                    style: AppTextStyles.tag.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(summary!, style: AppTextStyles.body),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ver detalle',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
