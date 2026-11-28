// lib/presentation/caregiver_dashboard/caregiver_calendar.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../core/theme/app_text_styles.dart';
import 'shared_practice_provider.dart';

/// Calendario de actividad del panel del cuidador (SCRUM-32/33).
///
/// No cambia la información que comparte el adulto mayor: el teléfono del
/// cuidador guarda localmente cada día de práctica que aparece en el
/// resumen compartido (última práctica de cada área) con el color de su
/// estado. El historial empieza a llenarse desde que el cuidador abre el
/// panel con esta versión de la app.

/// Color de un día con práctica. El orden es la prioridad cuando el mismo
/// día hay prácticas en varias áreas.
enum DayActivity {
  practico('Practicó'),
  estable('Estable'),
  mejora('Mejora'),
  bajo('Resultados más bajos');

  const DayActivity(this.label);
  final String label;

  Color get color => switch (this) {
    practico => AppColors.primary,
    estable => AppColors.success,
    mejora => const Color(0xFF2F6FB3),
    bajo => const Color(0xFFC98A00),
  };

  static DayActivity fromTrend(Object? trend) => switch (trend) {
    'stable' => DayActivity.estable,
    'improving' => DayActivity.mejora,
    'attention' || 'review' => DayActivity.bajo,
    _ => DayActivity.practico,
  };

  DayActivity strongest(DayActivity other) =>
      other.index > index ? other : this;
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Agrega al historial los días de práctica del resumen. Función pura.
Map<String, DayActivity> mergeDayHistory(
  Map<String, DayActivity> history,
  Map<String, dynamic> summary,
) {
  final next = Map<String, DayActivity>.from(history);
  void add(Object? at, DayActivity activity) {
    if (at is! Timestamp) return;
    final key = dayKey(at.toDate().toLocal());
    next[key] = next[key]?.strongest(activity) ?? activity;
  }

  for (final area in ['memoria', 'atencion', 'praxias']) {
    final data = summary[area];
    if (data is Map && (data['count'] as int? ?? 0) > 0) {
      add(data['latestAt'], DayActivity.fromTrend(data['trend']));
    }
  }
  add(summary['lastPracticeAt'], DayActivity.practico);

  // Solo se conservan los últimos 120 días.
  final keys = next.keys.toList()..sort();
  for (final old in keys.take((keys.length - 120).clamp(0, keys.length))) {
    next.remove(old);
  }
  return next;
}

final caregiverDayHistoryProvider =
    Provider.autoDispose<Map<String, DayActivity>>((ref) {
      final uid = ref.watch(navigationSessionProvider).session?.uid;
      final token = ref.watch(sharedPracticeLinkProvider).valueOrNull;
      if (uid == null || token == null) return const {};
      final prefs = ref.watch(sharedPreferencesProvider);
      final key = 'caregiver_day_history_${uid}_$token';

      final saved = <String, DayActivity>{};
      final raw = prefs.getString(key);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((day, name) {
          final value = DayActivity.values
              .where((v) => v.name == name)
              .firstOrNull;
          if (value != null) saved[day] = value;
        });
      }

      final summary = ref
          .watch(sharedPracticeSummaryProvider(token))
          .valueOrNull;
      if (summary == null) return saved;
      final merged = mergeDayHistory(saved, summary);
      prefs.setString(
        key,
        jsonEncode(merged.map((day, value) => MapEntry(day, value.name))),
      );
      return merged;
    });

const _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
  'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class CaregiverActivityCalendar extends ConsumerStatefulWidget {
  const CaregiverActivityCalendar({super.key});

  @override
  ConsumerState<CaregiverActivityCalendar> createState() =>
      _CaregiverActivityCalendarState();
}

class _CaregiverActivityCalendarState
    extends ConsumerState<CaregiverActivityCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _month;

  /// Parpadeo suave y en bucle de los días con actividad.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(caregiverDayHistoryProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = _month.weekday - 1; // lunes = 0
    final activeDays = [
      for (var d = 1; d <= daysInMonth; d++)
        if (history.containsKey(dayKey(DateTime(_month.year, _month.month, d))))
          d,
    ].length;
    final isCurrentMonth =
        _month.year == today.year && _month.month == today.month;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Días con actividad',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Text(
              activeDays == 0
                  ? 'Sin actividad registrada este mes.'
                  : activeDays == 1
                  ? 'Practicó 1 día este mes.'
                  : 'Practicó $activeDays días este mes.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final letter in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Text(
                      letter,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tag.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (var d = 1; d <= daysInMonth; d++)
                  _DayCell(
                    day: d,
                    activity:
                        history[dayKey(DateTime(_month.year, _month.month, d))],
                    isToday:
                        isCurrentMonth && d == today.day,
                    pulse: _pulse,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final a in DayActivity.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: a.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(a.label, style: AppTextStyles.bodySecondary),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.activity,
    required this.isToday,
    required this.pulse,
  });

  final int day;
  final DayActivity? activity;
  final bool isToday;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final activity = this.activity;
    final label = Text(
      '$day',
      style: AppTextStyles.tag.copyWith(
        color: activity == null ? AppColors.textPrimary : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );

    if (activity == null) {
      return Semantics(
        label: 'Día $day, sin actividad',
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday ? AppColors.primary : AppColors.border,
              width: isToday ? 2 : 1.5,
            ),
          ),
          child: label,
        ),
      );
    }

    return Semantics(
      label: 'Día $day, ${activity.label}',
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(pulse.value);
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activity.color.withValues(alpha: 0.55 + 0.45 * t),
              boxShadow: [
                BoxShadow(
                  color: activity.color.withValues(alpha: 0.35 * t),
                  blurRadius: 4 + 6 * t,
                  spreadRadius: 1 * t,
                ),
              ],
              border: isToday
                  ? Border.all(color: AppColors.primaryDark, width: 2)
                  : null,
            ),
            child: child,
          );
        },
        child: label,
      ),
    );
  }
}
