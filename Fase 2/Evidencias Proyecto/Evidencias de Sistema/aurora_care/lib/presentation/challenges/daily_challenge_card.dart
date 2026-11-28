import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_feedback.dart';
import '../shared/detail_dialog.dart';
import '../games/game_catalog.dart';
import '../games/shared/game_level_screen.dart';
import 'daily_challenge_provider.dart';

class DailyChallengeCard extends ConsumerWidget {
  const DailyChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(dailyChallengeProvider);
    if (progress == null) return const SizedBox.shrink();
    final challenge = progress.challenge;
    return Card(
      color: AppColors.primaryLight,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  progress.completed ? Icons.emoji_events : Icons.flag_outlined,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Desafío del día',
                    style: AppTextStyles.cardTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(challenge.title, style: AppTextStyles.body),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.unitsToday / challenge.goal,
              semanticsLabel:
                  'Progreso del desafío: ${challenge.progressLabel(progress.unitsToday)}',
              minHeight: 12,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(height: 8),
            Text(
              progress.completed
                  ? '¡Completó su desafío de hoy!'
                  : challenge.progressLabel(progress.unitsToday),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            if (!progress.completed)
              FilledButton(
                onPressed: () {
                  final game = gameCatalog.values
                      .expand((games) => games)
                      .firstWhere(
                        (game) => game.gameType == challenge.gameType,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GameLevelScreen(definition: game),
                    ),
                  );
                },
                child: Text(
                  progress.unitsToday == 0
                      ? 'Empezar desafío'
                      : 'Continuar desafío',
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PracticeCalendar(),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Ver calendario de racha'),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

class PracticeCalendar extends ConsumerStatefulWidget {
  const PracticeCalendar({super.key, this.showChallenges = true});

  final bool showChallenges;

  @override
  ConsumerState<PracticeCalendar> createState() => _ChallengeCalendarState();
}

class _ChallengeCalendarState extends ConsumerState<PracticeCalendar> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(dailyChallengeProvider);
    final title = widget.showChallenges
        ? 'Racha de desafíos'
        : 'Progreso por día';
    if (progress == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Text('No pudimos consultar las prácticas de este perfil.'),
        ),
      );
    }
    final today = progress.today;
    final month = DateTime(today.year, today.month + _monthOffset);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((month.weekday - 1 + count + 6) ~/ 7) * 7;
    final sessions =
        ref.watch(dailyChallengeSessionsProvider) ?? const <Session>[];
    final oldest = sessions.fold(today, (date, session) {
      final played = session.endTime.toLocal();
      return played.isBefore(date) ? played : date;
    });
    final canGoBack = month.isAfter(DateTime(oldest.year, oldest.month));
    final markedDates = widget.showChallenges
        ? progress.completedDates
        : {
            for (final session in sessions)
              DateUtils.dateOnly(session.endTime.toLocal()),
          };
    final completedThisMonth = markedDates
        .where((day) => day.year == month.year && day.month == month.month)
        .length;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.showChallenges) ...[
              _StreakHeader(progress: progress),
              const SizedBox(height: 20),
            ],
            Card(
              color: AppColors.surface,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Mes anterior',
                          onPressed: canGoBack
                              ? () => setState(() => _monthOffset--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${_months[month.month - 1]} de ${month.year}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mes siguiente',
                          onPressed: _monthOffset < 0
                              ? () => setState(() => _monthOffset++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Text(
                      widget.showChallenges
                          ? (completedThisMonth == 1
                                ? '1 desafío completado este mes'
                                : '$completedThisMonth desafíos completados este mes')
                          : (completedThisMonth == 1
                                ? '1 día con prácticas este mes'
                                : '$completedThisMonth días con prácticas este mes'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque un día para ver sus prácticas.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Table(
                      children: [
                        TableRow(
                          children: [
                            for (final day in const [
                              'L',
                              'M',
                              'X',
                              'J',
                              'V',
                              'S',
                              'D',
                            ])
                              Center(child: Text(day)),
                          ],
                        ),
                        for (var row = 0; row < cells; row += 7)
                          TableRow(
                            children: [
                              for (var column = 0; column < 7; column++)
                                _CalendarDay(
                                  date: DateTime(
                                    month.year,
                                    month.month,
                                    row + column - month.weekday + 2,
                                  ),
                                  month: month.month,
                                  today: today,
                                  markedDates: markedDates,
                                  showChallenges: widget.showChallenges,
                                  onSelected: (date) => _showDay(
                                    context,
                                    date,
                                    sessions,
                                    showChallenge: widget.showChallenges,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _CalendarLegend(
                          icon: Icons.check,
                          label: widget.showChallenges
                              ? 'Completado'
                              : 'Día con prácticas',
                        ),
                        const _CalendarLegend(icon: Icons.circle, label: 'Hoy'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                widget.showChallenges
                    ? 'Volver al desafío'
                    : 'Volver a Mi progreso',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDay(
  BuildContext context,
  DateTime date,
  List<Session> sessions, {
  required bool showChallenge,
}) {
  final practices =
      sessions
          .where(
            (session) => DateUtils.isSameDay(session.endTime.toLocal(), date),
          )
          .toList()
        ..sort((a, b) => b.endTime.compareTo(a.endTime));
  final byGame = <String, List<Session>>{};
  for (final practice in practices) {
    byGame.putIfAbsent(practice.gameType, () => []).add(practice);
  }
  final end = DateTime(
    date.year,
    date.month,
    date.day + 1,
  ).subtract(const Duration(microseconds: 1));
  final day = DailyChallengeProgress.fromSessions(practices, end);
  showDetailDialog(
    context: context,
    title: '${date.day} de ${_months[date.month - 1]} de ${date.year}',
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showChallenge) ...[
          Text('Desafío del día', style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(day.challenge.title, style: AppTextStyles.body),
          const SizedBox(height: 6),
          Text(
            day.completed
                ? '¡Desafío completado!'
                : day.challenge.progressLabel(day.unitsToday),
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          practices.length == 1
              ? '1 práctica registrada'
              : '${practices.length} prácticas registradas',
          style: AppTextStyles.cardTitle,
        ),
        if (practices.isEmpty)
          const Text('No hay prácticas registradas para este día.'),
        if (byGame.isNotEmpty)
          Text(
            'Toque un juego para ver sus resultados.',
            style: AppTextStyles.bodySecondary,
          ),
        for (final entry in byGame.entries) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.primaryLight,
            child: ListTile(
              title: Text(_gameName(entry.key), style: AppTextStyles.cardTitle),
              subtitle: Text(
                entry.value.length == 1
                    ? '1 partida'
                    : '${entry.value.length} partidas',
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
              ),
              onTap: () => _showGamePractices(context, entry.value),
            ),
          ),
        ],
      ],
    ),
  );
}

String _gameName(String type) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == type)
        .firstOrNull
        ?.title ??
    'Práctica registrada';

void _showGamePractices(BuildContext context, List<Session> sessions) {
  var index = 0;
  showDetailDialog(
    context: context,
    title: _gameName(sessions.first.gameType),
    content: StatefulBuilder(
      builder: (context, setState) {
        final session = sessions[index];
        final time = MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(session.endTime.toLocal()));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Partida ${index + 1} de ${sessions.length}',
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 4),
            Text(
              'Nivel ${session.nivel.label} · $time',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 10),
            for (final item in SessionFeedback.fromMetrics(
              session.metrics,
              gameType: session.gameType,
            ).items.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.key}: ${item.value}',
                  style: AppTextStyles.body,
                ),
              ),
            if (sessions.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: index > 0 ? () => setState(() => index--) : null,
                    child: const Text('Anterior'),
                  ),
                  TextButton(
                    onPressed: index + 1 < sessions.length
                        ? () => setState(() => index++)
                        : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.progress});
  final DailyChallengeProgress progress;

  @override
  Widget build(BuildContext context) {
    final streak = progress.streak;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                streak == 0 ? Icons.flag_rounded : Icons.emoji_events_rounded,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              switch (streak) {
                0 => 'Su racha empieza aquí',
                1 => '1 día de racha',
                _ => '$streak días de racha',
              },
              style: AppTextStyles.heading.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress.completed
                  ? '¡Completó el desafío de hoy!'
                  : streak == 0
                  ? 'Complete su primer desafío a su ritmo y marque el primer día.'
                  : 'El desafío de hoy le espera cuando quiera continuar.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.primaryDark),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.tag),
    ],
  );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.month,
    required this.today,
    required this.markedDates,
    required this.showChallenges,
    required this.onSelected,
  });
  final DateTime date;
  final int month;
  final DateTime today;
  final Set<DateTime> markedDates;
  final bool showChallenges;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    if (date.month != month) return const SizedBox.shrink();
    final completed = markedDates.contains(date);
    final isToday = date == today;
    final onTap = date.isAfter(today) ? null : () => onSelected(date);
    return Semantics(
      button: onTap != null,
      onTap: onTap,
      label:
          '${date.day}${isToday ? ', hoy' : ''}${completed ? (showChallenges ? ', desafío completado' : ', día con prácticas') : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          borderRadius: BorderRadius.circular(8),
          color: completed
              ? AppColors.warningBackground
              : isToday
              ? AppColors.primaryLight
              : AppColors.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Text('${date.day}', style: AppTextStyles.tag),
                  SizedBox(
                    height: 14,
                    child: completed
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.primaryDark,
                          )
                        : isToday
                        ? Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.primary,
                          )
                        : null,
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
