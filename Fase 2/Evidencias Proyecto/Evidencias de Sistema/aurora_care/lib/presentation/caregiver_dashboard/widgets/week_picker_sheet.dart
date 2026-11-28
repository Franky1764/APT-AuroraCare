import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../caregiver_dates.dart';
import '../caregiver_week_data.dart';

Future<DateTime?> showWeekPickerSheet(
  BuildContext context, {
  required DateTime selectedWeek,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WeekPickerSheet(selectedWeek: selectedWeek),
  );
}

class _WeekPickerSheet extends StatefulWidget {
  const _WeekPickerSheet({required this.selectedWeek});

  final DateTime selectedWeek;

  @override
  State<_WeekPickerSheet> createState() => _WeekPickerSheetState();
}

class _WeekPickerSheetState extends State<_WeekPickerSheet> {
  late DateTime _visibleMonth = DateTime(
    widget.selectedWeek.year,
    widget.selectedWeek.month,
  );
  late DateTime _selectedWeek = widget.selectedWeek;
  int _direction = 1;

  int _monthIndex(DateTime date) => date.year * 12 + date.month;

  bool get _canGoToPreviousMonth =>
      _monthIndex(_visibleMonth) >
      _monthIndex(CaregiverDates.oldestWeekStart);

  bool get _canGoToNextMonth =>
      _monthIndex(_visibleMonth) < _monthIndex(DateTime.now());

  bool _isSelectable(DateTime weekStart) =>
      !weekStart.isAfter(CaregiverDates.currentWeekStart) &&
      !weekStart.isBefore(CaregiverDates.oldestWeekStart);

  void _changeMonth(int delta) {
    setState(() {
      _direction = delta;
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<DateTime> _weeksOfVisibleMonth() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lastDay = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final weeks = <DateTime>[];
    var week = CaregiverDates.startOfWeek(firstDay);
    while (!week.isAfter(lastDay)) {
      weeks.add(week);
      week = CaregiverDates.addDays(week, 7);
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentSelected = CaregiverDates.isCurrentWeek(_selectedWeek);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elige una semana', style: AppTextStyles.heading),
            const SizedBox(height: 4),
            Text(
              'Toca cualquier día para seleccionar su semana.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed:
                      _canGoToPreviousMonth ? () => _changeMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      CaregiverDates.monthYear(_visibleMonth),
                      key: ValueKey(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: _canGoToNextMonth ? () => _changeMonth(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final letter in caregiverWeekDayLetters)
                  Expanded(
                    child: Center(
                      child: Text(
                        letter,
                        style: AppTextStyles.tag.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey(_visibleMonth);
                final begin = Offset(
                  (isIncoming ? 0.15 : -0.15) * _direction,
                  0,
                );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(_visibleMonth),
                children: [
                  for (final week in _weeksOfVisibleMonth())
                    _WeekRow(
                      weekStart: week,
                      visibleMonth: _visibleMonth.month,
                      selected: CaregiverDates.isSameDay(week, _selectedWeek),
                      enabled: _isSelectable(week),
                      onTap: () => setState(() => _selectedWeek = week),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                CaregiverDates.weekLabel(_selectedWeek),
                key: ValueKey(_selectedWeek),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selectedWeek),
              child: const Text('Ver esta semana'),
            ),
            if (!isCurrentSelected) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(CaregiverDates.currentWeekStart),
                child: Text(
                  'Ir a la semana actual',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.weekStart,
    required this.visibleMonth,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime weekStart;
  final int visibleMonth;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayCell(
                      date: CaregiverDates.addDays(weekStart, i),
                      inVisibleMonth:
                          CaregiverDates.addDays(weekStart, i).month ==
                              visibleMonth,
                      isToday: CaregiverDates.isSameDay(
                        CaregiverDates.addDays(weekStart, i),
                        today,
                      ),
                      selected: selected,
                      enabled: enabled,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inVisibleMonth,
    required this.isToday,
    required this.selected,
    required this.enabled,
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool isToday;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (selected) {
      color = AppColors.textOnPrimary;
    } else if (!enabled) {
      color = AppColors.textSecondary.withValues(alpha: 0.35);
    } else if (!inVisibleMonth) {
      color = AppColors.textSecondary.withValues(alpha: 0.6);
    } else {
      color = AppColors.textPrimary;
    }

    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: isToday
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.textOnPrimary : AppColors.accent,
                  width: 2,
                ),
              )
            : null,
        child: Text(
          '${date.day}',
          style: AppTextStyles.body.copyWith(
            color: color,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
