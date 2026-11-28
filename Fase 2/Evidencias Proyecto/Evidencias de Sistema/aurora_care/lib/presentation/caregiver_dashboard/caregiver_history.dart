// lib/presentation/caregiver_dashboard/caregiver_history.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/account_role.dart';
import '../../domain/entities/game_level.dart';
import '../games/game_catalog.dart';
import 'caregiver_navigation.dart';
import 'caregiver_overview.dart';
import 'caregiver_signal.dart';
import 'shared_practice_provider.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

/// Historial de resultados del cuidador (SCRUM-33, HU-35).
///
/// Criterios: historial de 28 días por área y sin acceso si no hay vínculo.
/// No cambia la información que comparte el adulto mayor: cada vez que el
/// resumen compartido trae una práctica nueva de un área, el teléfono del
/// cuidador la guarda (juego, nivel, fecha y señal). Se conservan solo los
/// últimos 28 días y nunca se guardan puntajes.

const historyDays = 28;

const _areas = [
  ('memoria', 'Memoria', Icons.psychology_outlined),
  ('atencion', 'Atención', Icons.center_focus_strong_outlined),
  ('praxias', 'Motricidad', Icons.back_hand_outlined),
];

class HistoryEntry {
  const HistoryEntry({
    required this.area,
    required this.at,
    this.game,
    this.level,
    this.trend,
  });

  final String area;
  final DateTime at;
  final String? game;
  final int? level;
  final String? trend;

  Map<String, dynamic> toJson() => {
    'area': area,
    'at': at.millisecondsSinceEpoch,
    'game': game,
    'level': level,
    'trend': trend,
  };

  static HistoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final area = json['area'];
    final at = json['at'];
    if (area is! String || at is! int) return null;
    return HistoryEntry(
      area: area,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      game: json['game'] as String?,
      level: json['level'] as int?,
      trend: json['trend'] as String?,
    );
  }
}

/// Agrega al historial la última práctica de cada área del resumen y quita
/// lo anterior a 28 días. Función pura; el resultado va de lo más reciente
/// a lo más antiguo.
List<HistoryEntry> mergeAreaHistory(
  List<HistoryEntry> history,
  Map<String, dynamic> summary,
  DateTime now,
) {
  final limit = DateUtils.dateOnly(now).subtract(
    const Duration(days: historyDays - 1),
  );
  final next = [...history];
  for (final (key, _, _) in _areas) {
    final area = summary[key];
    if (area is! Map || (area['count'] as int? ?? 0) == 0) continue;
    final at = area['latestAt'];
    if (at is! Timestamp) continue;
    final date = at.toDate().toLocal();
    final exists = next.any(
      (e) => e.area == key && e.at.millisecondsSinceEpoch == date.millisecondsSinceEpoch,
    );
    if (exists) continue;
    next.add(
      HistoryEntry(
        area: key,
        at: date,
        game: area['latestGame'] as String?,
        level: area['latestLevel'] as int?,
        trend: area['trend'] as String?,
      ),
    );
  }
  next.removeWhere((e) => e.at.isBefore(limit));
  next.sort((a, b) => b.at.compareTo(a.at));
  return next;
}

/// Días (0 = hace 27 días … 27 = hoy) con práctica en un área.
List<bool> practicedDays(List<HistoryEntry> history, String area, DateTime now) {
  final today = DateUtils.dateOnly(now);
  final days = List<bool>.filled(historyDays, false);
  for (final e in history.where((e) => e.area == area)) {
    final diff = today.difference(DateUtils.dateOnly(e.at)).inDays;
    if (diff >= 0 && diff < historyDays) days[historyDays - 1 - diff] = true;
  }
  return days;
}

/// «Esta semana», «La semana pasada» o «Hace N semanas».
String weekLabel(DateTime at, DateTime now) {
  final weeks = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(at)).inDays ~/ 7;
  return switch (weeks) {
    0 => 'Últimos 7 días',
    1 => 'Hace una semana',
    _ => 'Hace $weeks semanas',
  };
}

final caregiverAreaHistoryProvider =
    Provider.autoDispose<List<HistoryEntry>>((ref) {
      final session = ref.watch(navigationSessionProvider).session;
      final uid = session?.role == AccountRole.caregiver ? session?.uid : null;
      final token = ref.watch(sharedPracticeLinkProvider).valueOrNull;
      if (uid == null || token == null) return const [];
      final prefs = ref.watch(sharedPreferencesProvider);
      final key = 'caregiver_area_history_${uid}_$token';

      var saved = <HistoryEntry>[];
      final raw = prefs.getString(key);
      if (raw != null) {
        try {
          saved = [
            for (final item in jsonDecode(raw) as List)
              if (HistoryEntry.fromJson(item) case final HistoryEntry e) e,
          ];
        } on FormatException {
          saved = [];
        }
      }

      final summary = ref
          .watch(sharedPracticeSummaryProvider(token))
          .valueOrNull;
      if (summary == null) {
        return mergeAreaHistory(saved, const {}, DateTime.now());
      }
      final merged = mergeAreaHistory(saved, summary, DateTime.now());
      prefs.setString(key, jsonEncode([for (final e in merged) e.toJson()]));
      return merged;
    });

String _gameTitle(String? gameType) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == gameType)
        .firstOrNull
        ?.title ??
    'Ejercicio registrado';

String? _levelLabel(int? value) {
  if (value == null) return null;
  try {
    return GameLevel.fromValue(value).label;
  } on StateError {
    return null;
  }
}

// ───────────────────────── Pantalla ─────────────────────────

class CaregiverHistoryScreen extends ConsumerStatefulWidget {
  const CaregiverHistoryScreen({super.key, this.initialArea});

  /// 'memoria', 'atencion' o 'praxias'; null = todas.
  final String? initialArea;

  @override
  ConsumerState<CaregiverHistoryScreen> createState() =>
      _CaregiverHistoryScreenState();
}

class _CaregiverHistoryScreenState
    extends ConsumerState<CaregiverHistoryScreen> {
  late String? _area = widget.initialArea;

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final token = link.valueOrNull;
    final summary = token == null
        ? null
        : ref.watch(sharedPracticeSummaryProvider(token));

    final Widget content;
    if (link.hasError || summary?.hasError == true) {
      content = _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos consultar el historial',
        text: 'Revise su conexión e inténtelo de nuevo.',
        action: 'Reintentar',
        onAction: () => ref.invalidate(sharedPracticeLinkProvider),
      );
    } else if (link.isLoading || summary?.isLoading == true) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (token == null) {
      // Criterio de aceptación: sin vínculo no hay acceso al historial.
      content = _StateCard(
        icon: Icons.link_off_rounded,
        title: 'No hay un vínculo activo',
        text:
            'El historial muestra solo lo que comparte su familiar. Para '
            'verlo, escanee el código QR desde su perfil.',
        action: 'Escanear código QR',
        onAction: () => CaregiverNavigation.openQrScanner(context),
      );
    } else {
      content = _HistoryBody(
        history: ref.watch(caregiverAreaHistoryProvider),
        area: _area,
        onArea: (area) => setState(() => _area = area),
      );
    }

    return Scaffold(
      appBar: const CaregiverAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: content,
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.history,
    required this.area,
    required this.onArea,
  });

  final List<HistoryEntry> history;
  final String? area;
  final ValueChanged<String?> onArea;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = [
      for (final e in history)
        if (area == null || e.area == area) e,
    ];
    final groups = <String, List<HistoryEntry>>{};
    for (final e in visible) {
      groups.putIfAbsent(weekLabel(e.at, now), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: _Header(total: history.length),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 1,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AreaChip(
                label: 'Todas',
                selected: area == null,
                onTap: () => onArea(null),
              ),
              for (final (key, label, icon) in _areas)
                _AreaChip(
                  label: label,
                  icon: icon,
                  selected: area == key,
                  onTap: () => onArea(key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 2,
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Días con práctica',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Cada punto es un día; a la derecha, hoy.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 12),
                for (final (key, label, icon) in _areas)
                  if (area == null || area == key)
                    _AreaStrip(
                      label: label,
                      icon: icon,
                      days: practicedDays(history, key, now),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Prácticas registradas',
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _Panel(
            child: Text(
              'Aún no hay prácticas en estos 28 días. El historial se llena '
              'a medida que su familiar practica y usted abre el panel.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        for (final MapEntry(key: label, value: entries) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.tag.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final e in entries) ...[
            _EntryTile(entry: e),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text(
          'El historial se guarda en este teléfono desde que usó el panel '
          'con esta versión. No muestra puntajes: solo cuándo practicó, '
          'qué juego y la señal de ese momento.',
          style: AppTextStyles.bodySecondary,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.textOnPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: onPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.timeline_rounded, color: onPrimary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial',
                    style: AppTextStyles.heading.copyWith(color: onPrimary),
                  ),
                  Text(
                    total == 0
                        ? 'Últimos 28 días'
                        : total == 1
                        ? 'Últimos 28 días · 1 práctica'
                        : 'Últimos 28 días · $total prácticas',
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected ? AppColors.textOnPrimary : AppColors.primary,
            ),
      showCheckmark: false,
      label: Text(label),
      labelStyle: AppTextStyles.tag.copyWith(
        color: selected ? AppColors.textOnPrimary : AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primaryLight,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// 28 puntos, uno por día; los días con práctica van en color.
class _AreaStrip extends StatelessWidget {
  const _AreaStrip({
    required this.label,
    required this.icon,
    required this.days,
  });

  final String label;
  final IconData icon;
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final count = days.where((d) => d).length;
    return Semantics(
      label: '$label: practicó $count de los últimos 28 días',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    count == 1 ? '1 día' : '$count días',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Container(
                        height: 14,
                        margin: EdgeInsets.only(
                          right: i == days.length - 1 ? 0 : 2,
                          left: i > 0 && i % 7 == 0 ? 3 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: days[i]
                              ? AppColors.primary
                              : AppColors.border.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final (_, areaLabel, icon) = _areas.firstWhere(
      (a) => a.$1 == entry.area,
      orElse: () => _areas.first,
    );
    // Cada entrada muestra la señal que tenía el área en ese momento.
    final signal = CaregiverSignal.fromSummary(entry.trend, fresh: true);
    final level = _levelLabel(entry.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gameTitle(entry.game),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    areaLabel,
                    if (level != null) 'Nivel $level',
                    practiceDateLabel(entry.at, DateTime.now()),
                  ].join(' · '),
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: signal.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(signal.icon, size: 14, color: signal.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          signal.label,
                          style: AppTextStyles.tag.copyWith(
                            color: signal.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
