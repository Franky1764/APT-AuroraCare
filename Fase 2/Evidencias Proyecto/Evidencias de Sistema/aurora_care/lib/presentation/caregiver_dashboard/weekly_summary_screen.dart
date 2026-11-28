import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'caregiver_dates.dart';
import 'caregiver_history.dart';
import 'caregiver_week_data.dart';
import 'shared_practice_provider.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';
import 'widgets/week_picker_sheet.dart';

/// Resumen semanal del cuidador (H67): lee las prácticas que comparte el
/// adulto mayor en `caregiver_summaries` (historial de 28 días).
class WeeklySummaryScreen extends ConsumerStatefulWidget {
  const WeeklySummaryScreen({super.key, this.initialWeek});

  final DateTime? initialWeek;

  @override
  ConsumerState<WeeklySummaryScreen> createState() =>
      _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends ConsumerState<WeeklySummaryScreen> {
  late DateTime _weekStart = CaregiverDates.startOfWeek(
    widget.initialWeek ?? DateTime.now(),
  );
  int _direction = 1;

  bool get _canGoBack => _weekStart.isAfter(CaregiverDates.oldestWeekStart);

  bool get _canGoForward => _weekStart.isBefore(CaregiverDates.currentWeekStart);

  void _showWeek(DateTime weekStart) {
    if (CaregiverDates.isSameDay(weekStart, _weekStart)) return;
    setState(() {
      _direction = weekStart.isAfter(_weekStart) ? 1 : -1;
      _weekStart = weekStart;
    });
  }

  Future<void> _openCalendar() async {
    final picked = await showWeekPickerSheet(
      context,
      selectedWeek: _weekStart,
    );
    if (picked != null && mounted) _showWeek(picked);
  }

  @override
  Widget build(BuildContext context) {
    final linked = ref.watch(sharedPracticeLinkProvider).valueOrNull != null;
    final summary = weeklySummaryFromHistory(
      ref.watch(caregiverAreaHistoryProvider),
      _weekStart,
    );

    return Scaffold(
      appBar: const CaregiverAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text('Resumen semanal', style: AppTextStyles.heading),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 1,
                child: _WeekSelector(
                  weekStart: _weekStart,
                  canGoBack: _canGoBack,
                  canGoForward: _canGoForward,
                  onPrevious: () =>
                      _showWeek(CaregiverDates.addDays(_weekStart, -7)),
                  onNext: () => _showWeek(CaregiverDates.addDays(_weekStart, 7)),
                  onOpenCalendar: _openCalendar,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey(_weekStart);
                  final dx = (isIncoming ? 0.12 : -0.12) * _direction;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                child: linked
                    ? _WeekContent(
                        key: ValueKey(_weekStart),
                        weekStart: _weekStart,
                        summary: summary,
                      )
                    : Container(
                        key: ValueKey(_weekStart),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Cuando se vincule con su familiar, aquí verá los '
                          'días en que practicó.',
                          style: AppTextStyles.body,
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

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.weekStart,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCalendar,
  });

  final DateTime weekStart;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final isCurrent = CaregiverDates.isCurrentWeek(weekStart);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: canGoBack ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onOpenCalendar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                isCurrent
                                    ? 'Esta semana'
                                    : CaregiverDates.monthYear(weekStart),
                                key: ValueKey(weekStart),
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          CaregiverDates.weekLabel(weekStart),
                          key: ValueKey(weekStart),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Semana siguiente',
              onPressed: canGoForward ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekContent extends StatelessWidget {
  const _WeekContent({
    super.key,
    required this.weekStart,
    required this.summary,
  });

  final DateTime weekStart;
  final CaregiverWeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final today = CaregiverDates.dateOnly(DateTime.now());
    final activeDays = summary.activeDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Días con práctica: ${summary.activeCount} de ${activeDays.length}',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < activeDays.length; i++)
                      PopIn(
                        index: i,
                        child: _DayCircle(
                          letter: caregiverWeekDayLetters[i],
                          active: activeDays[i],
                          future: CaregiverDates.addDays(weekStart, i)
                              .isAfter(today),
                        ),
                      ),
                  ],
                ),
                Divider(height: 32, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Prácticas registradas:',
                        style: AppTextStyles.body,
                      ),
                    ),
                    CountUpText(
                      value: summary.practices,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (summary.mostPracticedArea case final String area) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Área más practicada:',
                          style: AppTextStyles.body,
                        ),
                      ),
                      Text(
                        area,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(summary.message, style: AppTextStyles.body),
        ),
      ],
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.letter,
    required this.active,
    this.future = false,
  });

  final String letter;
  final bool active;
  final bool future;

  @override
  Widget build(BuildContext context) {
    final String description;
    if (future) {
      description = '$letter: aún no llega';
    } else if (active) {
      description = '$letter: practicó';
    } else {
      description = '$letter: no practicó';
    }

    return Semantics(
      label: description,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? AppColors.primary
                : AppColors.border.withValues(alpha: future ? 0.5 : 1),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            letter,
            style: AppTextStyles.tag.copyWith(
              color: active
                  ? AppColors.textOnPrimary
                  : AppColors.textPrimary.withValues(alpha: future ? 0.35 : 1),
            ),
          ),
        ),
      ),
    );
  }
}
