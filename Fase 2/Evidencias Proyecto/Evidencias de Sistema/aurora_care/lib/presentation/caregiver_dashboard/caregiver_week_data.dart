// lib/presentation/caregiver_dashboard/caregiver_week_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/game_level.dart';
import '../games/game_catalog.dart';
import 'caregiver_dates.dart';
import 'caregiver_history.dart';
import 'caregiver_signal.dart';

/// Datos reales para el resumen semanal, el panel de avisos y el detalle de
/// actividad del cuidador (H67). Todo sale de `caregiver_summaries` a través
/// de sharedPracticeSummaryProvider y del historial que se arma con él
/// (caregiverAreaHistoryProvider). Reemplaza a CaregiverSampleData.
/// No muestra puntajes ni compara resultados entre áreas.

const caregiverWeekDayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// (clave, nombre, ícono) de cada área, igual que en el reporte.
const caregiverAreas = [
  ('memoria', 'Memoria', Icons.psychology_outlined),
  ('atencion', 'Atención', Icons.center_focus_strong_outlined),
  ('praxias', 'Motricidad', Icons.back_hand_outlined),
];

(String, String, IconData) caregiverArea(String key) => caregiverAreas
    .firstWhere((a) => a.$1 == key, orElse: () => caregiverAreas.first);

// ───────────────────────── Resumen semanal ─────────────────────────

class CaregiverWeeklySummary {
  const CaregiverWeeklySummary({
    required this.activeDays,
    required this.practices,
    required this.mostPracticedArea,
    required this.message,
  });

  /// Lunes a domingo: true si hubo al menos una práctica ese día.
  final List<bool> activeDays;

  /// Prácticas registradas en la semana (todas las áreas).
  final int practices;

  /// Nombre del área con más prácticas, o null si no hubo.
  final String? mostPracticedArea;
  final String message;

  int get activeCount => activeDays.where((day) => day).length;
}

CaregiverWeeklySummary weeklySummaryFromHistory(
  List<HistoryEntry> history,
  DateTime weekStart,
) {
  final start = CaregiverDates.dateOnly(weekStart);
  final week = [
    for (final e in history)
      if (_dayIndex(start, e.at) case final int i) (i, e),
  ];
  final activeDays = List<bool>.filled(7, false);
  final perArea = <String, int>{};
  for (final (i, e) in week) {
    activeDays[i] = true;
    perArea[e.area] = (perArea[e.area] ?? 0) + 1;
  }
  String? mostPracticed;
  if (perArea.isNotEmpty) {
    final top = perArea.entries.reduce((a, b) => b.value > a.value ? b : a);
    mostPracticed = caregiverArea(top.key).$2;
  }
  final days = activeDays.where((d) => d).length;
  final message = switch (days) {
    0 => 'No hay prácticas registradas esta semana.',
    >= 5 => 'Su familiar practicó casi todos los días esta semana.',
    >= 3 => 'Su familiar practicó con regularidad esta semana.',
    1 => 'Su familiar practicó 1 día esta semana. '
        'Un recordatorio amable puede ayudar.',
    _ => 'Su familiar practicó $days días esta semana. '
        'Un recordatorio amable puede ayudar.',
  };
  return CaregiverWeeklySummary(
    activeDays: activeDays,
    practices: week.length,
    mostPracticedArea: mostPracticed,
    message: message,
  );
}

int? _dayIndex(DateTime weekStart, DateTime at) {
  final diff = CaregiverDates.dateOnly(at).difference(weekStart).inDays;
  return diff >= 0 && diff < 7 ? diff : null;
}

// ───────────────────────── Avisos del panel ─────────────────────────

enum CaregiverNoticeTarget { none, area, weeklySummary }

class CaregiverNotice {
  const CaregiverNotice({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    required this.dotColor,
    required this.target,
    this.areaKey,
  });

  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color dotColor;
  final CaregiverNoticeTarget target;
  final String? areaKey;
}

String relativeDayLabel(DateTime at, DateTime now) {
  final days = CaregiverDates.dateOnly(now)
      .difference(CaregiverDates.dateOnly(at))
      .inDays;
  return switch (days) {
    <= 0 => 'Hoy',
    1 => 'Ayer',
    _ => 'Hace $days días',
  };
}

DateTime? _date(Object? value) =>
    value is Timestamp ? value.toDate().toLocal() : null;

String _gameTitle(Object? gameType) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == gameType)
        .firstOrNull
        ?.title ??
    'Ejercicio registrado';

String? _levelLabel(Object? value) {
  if (value is! int) return null;
  try {
    return GameLevel.fromValue(value).label;
  } on StateError {
    return null;
  }
}

/// Avisos que ve el cuidador en el panel, más recientes primero.
/// Sin vínculo o sin resumen publicado, la lista queda vacía.
List<CaregiverNotice> caregiverNoticesFrom({
  required Map<String, dynamic>? summary,
  required List<HistoryEntry> history,
  required DateTime now,
}) {
  if (summary == null) return const [];
  final published = _date(summary['publishedAt']);
  final fresh = published != null && now.difference(published).inDays < 28;
  final notices = <(DateTime, CaregiverNotice)>[];

  // Última práctica de cada área en los últimos 7 días.
  for (final (key, label, icon) in caregiverAreas) {
    final area = summary[key];
    if (area is! Map) continue;
    final at = _date(area['latestAt']);
    if (at == null || now.difference(at).inDays >= 7) continue;
    final level = _levelLabel(area['latestLevel']);
    final signal = CaregiverSignal.fromSummary(area['trend'], fresh: fresh);
    notices.add((
      at,
      CaregiverNotice(
        title: 'Practicó $label',
        body: [
          _gameTitle(area['latestGame']),
          if (level != null) 'nivel $level',
          signal.label,
        ].join(' · '),
        timeLabel: relativeDayLabel(at, now),
        icon: icon,
        dotColor: signal.color,
        target: CaregiverNoticeTarget.area,
        areaKey: key,
      ),
    ));
  }

  // Resumen de la semana en curso.
  final week = weeklySummaryFromHistory(
    history,
    CaregiverDates.startOfWeek(now),
  );
  if (week.activeCount > 0) {
    notices.add((
      DateTime(0),
      CaregiverNotice(
        title: 'Resumen de esta semana',
        body: week.activeCount == 1
            ? 'Practicó 1 día esta semana.'
            : 'Practicó ${week.activeCount} días esta semana.',
        timeLabel: 'Esta semana',
        icon: Icons.calendar_month_outlined,
        dotColor: AppColors.primary,
        target: CaregiverNoticeTarget.weeklySummary,
      ),
    ));
  }

  // Varios días sin prácticas nuevas.
  final last = _date(summary['lastPracticeAt']);
  if (last != null && now.difference(last).inDays >= 3) {
    notices.add((
      DateTime(1),
      CaregiverNotice(
        title: 'Hace unos días que no practica',
        body: 'La última práctica fue ${relativeDayLabel(last, now).toLowerCase()}. '
            'Si le viene bien, puede invitarle a jugar.',
        timeLabel: relativeDayLabel(last, now),
        icon: Icons.schedule,
        dotColor: AppColors.warning,
        target: CaregiverNoticeTarget.none,
      ),
    ));
  }

  if (!fresh) {
    notices.add((
      DateTime(2),
      CaregiverNotice(
        title: 'Resumen pendiente de actualización',
        body: 'Su familiar aún no comparte un resumen reciente.',
        timeLabel: published == null ? '' : relativeDayLabel(published, now),
        icon: Icons.update,
        dotColor: AppColors.textSecondary,
        target: CaregiverNoticeTarget.none,
      ),
    ));
  }

  notices.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, n) in notices) n];
}
