// lib/presentation/caregiver_dashboard/caregiver_report_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/game_level.dart';
import '../games/game_catalog.dart';
import '../../domain/entities/progress_report.dart';
import '../reports/report_providers.dart';
import '../reports/save_report_pdf_button.dart';
import 'caregiver_history.dart';
import 'caregiver_shared_report.dart';
import 'caregiver_navigation.dart';
import 'caregiver_overview.dart';
import 'caregiver_signal.dart';
import 'shared_practice_provider.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

/// Reporte de progreso del cuidador (SCRUM-32/33) con diseño propio.
///
/// Todo sale del resumen que comparte el adulto mayor por el vínculo
/// activo (sharedPracticeLinkProvider + sharedPracticeSummaryProvider).
/// Si no hay vínculo, no se muestra ningún dato. No muestra puntajes.

const _areas = [
  ('memoria', 'Memoria', Icons.psychology_outlined),
  ('atencion', 'Atención', Icons.center_focus_strong_outlined),
  ('praxias', 'Motricidad', Icons.back_hand_outlined),
];

DateTime? _date(Object? value) =>
    value is Timestamp ? value.toDate().toLocal() : null;

String _gameTitle(String? gameType) =>
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

String _shortDate(DateTime d) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

bool _isFresh(Map<String, dynamic> data) {
  final published = _date(data['publishedAt']);
  return published != null && DateTime.now().difference(published).inDays < 28;
}

/// Lo que se registró en la última práctica, en palabras simples.
List<(IconData, String)> _records(Map area) {
  final value = area['value'] as int? ?? 0;
  final observation = switch (area['metric']) {
    'accuracy' => 'Aciertos: $value %',
    'precision' => 'Precisión del recorrido: $value %',
    'response' when value > 0 =>
      value < 100
          ? 'Respondió en menos de 0,1 segundos en promedio'
          : 'Respondió en ${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} segundos en promedio',
    'completed' => 'Completó $value de ${area['total']} acciones',
    _ => null,
  };
  return [
    if (observation != null) (Icons.task_alt_rounded, observation),
    if (area['attempts'] case final int attempts)
      (Icons.replay_rounded, 'Intentos: $attempts'),
    if (area['errorsPct'] case final int errors)
      (Icons.touch_app_outlined, 'Toques equivocados: $errors %'),
    if (area['figures'] case final int figures)
      (Icons.category_outlined, 'Figuras completadas: $figures'),
    if (area['supports'] case final int supports)
      (Icons.support_outlined, 'Ayudas o demostraciones usadas: $supports'),
  ];
}

/// Sugerencia amable según la señal.
String _tip(CaregiverSignal signal) {
  if (signal == CaregiverSignal.mejora) {
    return 'Puede felicitarle y animarle a seguir practicando a su ritmo.';
  }
  if (signal == CaregiverSignal.estable) {
    return 'Mantener una práctica regular ayuda a sostener el hábito.';
  }
  if (signal == CaregiverSignal.atencion || signal == CaregiverSignal.revisar) {
    return 'Puede deberse al cansancio o a un mal día. Si se repite, puede '
        'conversarlo con un profesional de la salud.';
  }
  if (signal == CaregiverSignal.pendiente) {
    return 'El resumen se actualizará cuando su familiar vuelva a abrir '
        'AuroraCare.';
  }
  return 'Con algunas partidas más del mismo nivel podremos mostrar una '
      'tendencia.';
}

// ───────────────────────── Vínculo ─────────────────────────

/// Solo construye el contenido si hay un vínculo activo y un resumen
/// compartido. En otro caso muestra el estado correspondiente.
class _LinkedSummary extends ConsumerWidget {
  const _LinkedSummary({required this.builder});

  final Widget Function(BuildContext context, Map<String, dynamic> data)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final token = link.valueOrNull;
    final summary = token == null
        ? null
        : ref.watch(sharedPracticeSummaryProvider(token));
    final data = summary?.valueOrNull;

    if (link.hasError || summary?.hasError == true) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos consultar la actividad',
        text: 'Revise su conexión e inténtelo de nuevo.',
        action: 'Reintentar',
        onAction: () => ref.invalidate(sharedPracticeLinkProvider),
      );
    }
    if (link.isLoading || summary?.isLoading == true) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (token == null) {
      return _StateCard(
        icon: Icons.link_off_rounded,
        title: 'No hay un vínculo activo',
        text:
            'El reporte muestra solo lo que comparte su familiar. Para '
            'verlo, escanee el código QR desde su perfil.',
        action: 'Escanear código QR',
        onAction: () => CaregiverNavigation.openQrScanner(context),
      );
    }
    if (data == null) {
      return const _StateCard(
        icon: Icons.hourglass_empty_rounded,
        title: 'Aún no hay actividad compartida',
        text:
            'Cuando su familiar practique, verá aquí su resumen. Si se '
            'vincularon antes de esta función, generen un nuevo código '
            'desde el perfil de la persona mayor.',
      );
    }
    return builder(context, data);
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
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

// ───────────────────────── Reporte ─────────────────────────

class CaregiverReportScreen extends StatelessWidget {
  const CaregiverReportScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const CaregiverAppBar(),
    body: SafeArea(
      top: false,
      child: CaregiverSharedReport(
        narrativeBuilder: (data, fresh) =>
            _NarrativeCard(data: data, fresh: fresh),
      ),
    ),
  );
}

class _NarrativeCard extends ConsumerStatefulWidget {
  const _NarrativeCard({required this.data, required this.fresh});

  final Map<String, dynamic> data;
  final bool fresh;

  @override
  ConsumerState<_NarrativeCard> createState() => _NarrativeCardState();
}

class _NarrativeCardState extends ConsumerState<_NarrativeCard> {
  Future<ProgressReport>? _report;

  void _generate() {
    final areas = [
      for (final (domain, _, _) in _areas)
        if (widget.data[domain] case final Map area)
          ReportDomain(
            domain: domain,
            sessions: area['average'] == null
                ? area['count'] as int? ?? 0
                : area['comparable'] as int? ?? 0,
            level: area['level'] as int?,
            averageScore: (area['average'] as num?)?.toDouble(),
            signal: switch (area['trend']) {
              'improving' => 'mejora',
              'stable' => 'estable',
              'attention' => 'atencion',
              'review' => 'revisar',
              _ =>
                (area['count'] as int? ?? 0) > 0 && area['average'] == null
                    ? 'calibracion_pendiente'
                    : 'insuficiente',
            },
          ),
    ];
    setState(() {
      _report = ref.read(reportRepositoryProvider).generate(areas);
    });
  }

  String _exportText(ProgressReport? report) {
    final data = widget.data;
    final lines = <String>[
      'Reporte de progreso · AuroraCare',
      if (_date(data['publishedAt']) case final DateTime d)
        'Resumen actualizado: ${_shortDate(d)} ${d.year}',
      'Período: últimos 28 días.',
      '',
    ];
    for (final (key, label, _) in _areas) {
      final area = data[key];
      if (area is! Map || (area['count'] as int? ?? 0) == 0) continue;
      final signal = CaregiverSignal.fromSummary(
        area['trend'],
        fresh: widget.fresh,
      );
      lines.addAll([
        label,
        '${area['count']} prácticas registradas',
        if (area['practiceDays'] case final int days when days > 0)
          'En $days días distintos',
        [
          'Última práctica: ${_gameTitle(area['latestGame'] as String?)}',
          if (_levelLabel(area['latestLevel']) case final String l) 'Nivel $l',
          if (_date(area['latestAt']) case final DateTime d) _shortDate(d),
        ].join(' · '),
        for (final (_, text) in _records(area)) text,
        'Señal: ${signal.label}. ${signal.message}',
        '',
      ]);
    }
    if (report != null) lines.addAll(['Resumen redactado', report.text, '']);
    lines.add(reportDisclaimer);
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reportRepositoryProvider);
    return _Panel(
      child: FutureBuilder<ProgressReport>(
        future: _report,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.data == null && !loading && !snapshot.hasError)
                Text(
                  'Puede redactar un resumen en palabras simples para '
                  'guardarlo o compartirlo con un profesional de la salud.',
                  style: AppTextStyles.bodySecondary,
                ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (snapshot.hasError)
                Text(
                  'No pudimos redactar el informe. Inténtelo de nuevo.',
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
              if (snapshot.data case final ProgressReport report)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(report.text, style: AppTextStyles.body),
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: loading ? null : _generate,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(
                  snapshot.hasData ? 'Actualizar informe' : 'Redactar informe',
                ),
              ),
              const SizedBox(height: 10),
              SaveReportPdfButton(text: _exportText(snapshot.data)),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Detalle de un área ─────────────────────────

class CaregiverAreaDetailScreen extends StatelessWidget {
  const CaregiverAreaDetailScreen({
    super.key,
    required this.areaKey,
    required this.label,
    required this.icon,
  });

  final String areaKey;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CaregiverAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: _LinkedSummary(
            builder: (context, data) {
              final area = data[areaKey];
              if (area is! Map || (area['count'] as int? ?? 0) == 0) {
                return const _StateCard(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Sin prácticas en esta área',
                  text: 'Cuando su familiar practique, verá aquí el detalle.',
                );
              }
              final fresh = _isFresh(data);
              final signal = CaregiverSignal.fromSummary(
                area['trend'],
                fresh: fresh,
              );
              final count = area['count'] as int? ?? 0;
              final days = area['practiceDays'] as int? ?? 0;
              final level = _levelLabel(area['level']);
              final latestLevel = _levelLabel(area['latestLevel']);
              final at = _date(area['latestAt']);
              final records = _records(area);
              final comparable = area['comparable'] as int? ?? 0;
              final comparisonGame = area['comparisonGame'] as String?;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: _GradientHeader(
                      icon: icon,
                      title: label,
                      subtitle: 'Detalle compartido por su familiar',
                      pills: [(signal.icon, signal.label)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: signal.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(signal.icon, color: signal.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  signal.label,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    color: signal.color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(signal.message, style: AppTextStyles.body),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _tip(signal),
                                  style: AppTextStyles.bodySecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 2,
                    child: Row(
                      children: [
                        _StatTile(
                          icon: Icons.sports_esports_outlined,
                          value: '$count',
                          caption: count == 1 ? 'Práctica' : 'Prácticas',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.calendar_month_outlined,
                          value: days == 0 ? '—' : '$days',
                          caption: days == 1 ? 'Día' : 'Días distintos',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.signal_cellular_alt_rounded,
                          value: level ?? latestLevel ?? '—',
                          caption: 'Nivel',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const FadeSlideIn(
                    index: 3,
                    child: _SectionTitle(
                      icon: Icons.history_rounded,
                      title: 'Última práctica',
                      subtitle: 'Lo que registró el juego',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 4,
                    child: _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _gameTitle(area['latestGame'] as String?),
                            style: AppTextStyles.cardTitle.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            [
                              if (latestLevel != null) 'Nivel $latestLevel',
                              if (at != null)
                                practiceDateLabel(at, DateTime.now()),
                            ].join(' · '),
                            style: AppTextStyles.bodySecondary,
                          ),
                          if (records.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 4),
                            for (final (recordIcon, text) in records)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      recordIcon,
                                      size: 22,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        text,
                                        style: AppTextStyles.body,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Son datos del juego, no una evaluación médica.',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 5,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        caregiverPageRoute<void>(
                          CaregiverHistoryScreen(initialArea: areaKey),
                        ),
                      ),
                      icon: const Icon(Icons.timeline_rounded),
                      label: Text('Historial de $label'),
                    ),
                  ),
                  if (fresh &&
                      signal != CaregiverSignal.inicial &&
                      comparable > 0) ...[
                    const SizedBox(height: 24),
                    const FadeSlideIn(
                      index: 5,
                      child: _SectionTitle(
                        icon: Icons.compare_arrows_rounded,
                        title: '¿Cómo se obtuvo la señal?',
                        subtitle: 'Partidas comparables de los últimos 28 días',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 6,
                      child: _Panel(
                        child: Text(
                          'Se compararon $comparable '
                          '${comparable == 1 ? 'partida' : 'partidas'}'
                          '${level == null ? '' : ' de nivel $level'}'
                          '${comparisonGame == null ? '' : ' en ${_gameTitle(comparisonGame)}'}'
                          '${days > 0 ? ', jugadas en ${days == 1 ? 'un día' : '$days días distintos'}' : ''}.',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              caption,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTextStyles.tag.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Piezas comunes ─────────────────────────

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<(IconData, String)> pills;

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.textOnPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -44,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onPrimary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: onPrimary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: AppTextStyles.heading.copyWith(color: onPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: onPrimary.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final (pillIcon, text) in pills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: onPrimary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(pillIcon, size: 16, color: onPrimary),
                              const SizedBox(width: 6),
                              Text(
                                text,
                                style: AppTextStyles.tag.copyWith(
                                  color: onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(subtitle, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
