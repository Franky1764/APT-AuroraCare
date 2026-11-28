import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/game_level.dart';
import '../games/game_catalog.dart';
import '../../domain/entities/progress_report.dart';
import '../reports/report_providers.dart';
import '../reports/save_report_pdf_button.dart';
import 'shared_practice_provider.dart';
import 'caregiver_signal.dart';

class SharedPracticeCard extends ConsumerWidget {
  const SharedPracticeCard({super.key, this.onOpenReport});

  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final token = link.asData?.value;
    final summary = token == null
        ? null
        : ref.watch(sharedPracticeSummaryProvider(token));
    final data = summary?.asData?.value;
    final now = DateTime.now();
    final latest = (data?['lastPracticeAt'] as Timestamp?)?.toDate().toLocal();
    final published = (data?['publishedAt'] as Timestamp?)?.toDate().toLocal();
    final today = latest != null && DateUtils.isSameDay(latest, now);
    final dateFormat = MaterialLocalizations.of(context);
    final status = link.hasError || summary?.hasError == true
        ? 'No pudimos consultar la actividad en este momento.'
        : link.isLoading || summary?.isLoading == true
        ? 'Consultando la actividad…'
        : token == null
        ? 'No hay un vínculo activo.'
        : data == null
        ? 'Aún no hay actividad disponible. Si se vincularon antes de esta función, generen un nuevo código desde el perfil de la persona mayor.'
        : today
        ? 'Practicó hoy.'
        : published != null && !DateUtils.isSameDay(published, now)
        ? 'El resumen aún no se ha actualizado hoy.'
        : latest != null
        ? 'No hay práctica registrada hoy. Última práctica: ${dateFormat.formatShortDate(latest)}.'
        : 'Aún no hay prácticas recientes registradas.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Actividad de práctica',
                    style: AppTextStyles.cardTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(status, style: AppTextStyles.body),
              ),
            ),
            if (data != null) ...[
              if (!today && DateUtils.isSameDay(published, now))
                const Text(
                  'Si le viene bien, puede invitarle a practicar a su ritmo.',
                ),
              if (published != null)
                Text(
                  'Resumen actualizado el ${dateFormat.formatShortDate(published)}.',
                ),
              for (final (key, label) in [
                ('memoria', 'Memoria'),
                ('atencion', 'Atención'),
                ('praxias', 'Motricidad'),
              ])
                if (data[key] case final Map area
                    when (area['count'] as int) > 0)
                  _PracticeArea(
                    label: label,
                    area: area,
                    showTrend:
                        published != null &&
                        now.difference(published).inDays < 28,
                  ),
              if (onOpenReport != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onOpenReport,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ver reporte'),
                ),
              ],
              if (onOpenReport == null &&
                  latest != null &&
                  published != null &&
                  now.difference(published).inDays < 28)
                _SharedNarrative(key: ValueKey(token), data: data),
            ],
          ],
        ),
      ),
    );
  }
}

class _PracticeArea extends StatelessWidget {
  const _PracticeArea({
    required this.label,
    required this.area,
    required this.showTrend,
  });
  final String label;
  final Map area;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final count = area['count'] as int;
    final latestAt = (area['latestAt'] as Timestamp?)?.toDate().toLocal();
    final latestLevel = area['latestLevel'] as int?;
    final contextParts = [
      if (area['latestGame'] case final String game) _gameTitle(game),
      if (latestLevel != null)
        'Nivel ${GameLevel.fromValue(latestLevel).label}',
      if (latestAt != null)
        MaterialLocalizations.of(context).formatShortDate(latestAt),
    ];
    final comparisonGame = area['comparisonGame'] as String?;
    final practiceDays = area['practiceDays'] as int?;
    final firstScore = area['firstScore'] as num?;
    final lastScore = area['lastScore'] as num?;
    final observation = _practiceObservation(area);
    final signal = CaregiverSignal.fromSummary(area['trend'], fresh: showTrend);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          Text(label, style: AppTextStyles.cardTitle),
          Text(
            count == 1
                ? '1 práctica registrada'
                : '$count prácticas registradas',
          ),
          if (contextParts.isNotEmpty) Text(contextParts.join(' · ')),
          if (observation != null) Text('Última práctica · $observation'),
          if (area['attempts'] case final int attempts)
            Text('Intentos registrados: $attempts'),
          if (area['errorsPct'] case final int errors)
            Text('Errores registrados: $errors %'),
          if (area['figures'] case final int figures)
            Text('Figuras completadas: $figures'),
          if (area['supports'] case final int supports)
            Text('Ayudas y demostraciones consultadas: $supports'),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: signal.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(signal.icon, color: signal.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signal.label,
                          style: AppTextStyles.tag.copyWith(
                            color: signal.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          signal.message,
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showTrend && signal != CaregiverSignal.inicial) ...[
            Text(
              '${area['comparable']} partidas de nivel ${area['level']}'
              '${comparisonGame == null ? '' : ' en ${_gameTitle(comparisonGame)}'}'
              '${practiceDays == null ? '' : ', en $practiceDays días distintos'}'
              ' dentro de los últimos 28 días del informe.',
            ),
            if (firstScore != null && lastScore != null)
              Text(
                'Puntaje del juego en la primera y última partida comparable: '
                '${firstScore.toStringAsFixed(1).replaceAll('.', ',')} y '
                '${lastScore.toStringAsFixed(1).replaceAll('.', ',')} de 100.',
              ),
          ],
        ],
      ),
    );
  }
}

String _gameTitle(String gameType) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == gameType)
        .firstOrNull
        ?.title ??
    'Ejercicio registrado';

String? _practiceObservation(Map area) {
  final value = area['value'] as int;
  return switch (area['metric']) {
    'accuracy' => 'Aciertos registrados: $value %',
    'precision' => 'Precisión del recorrido: $value %',
    'response' when value > 0 =>
      value < 100
          ? 'Tiempo promedio para responder: menos de 0,1 segundos'
          : 'Tiempo promedio para responder: ${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} segundos',
    'completed' => 'Acciones completadas: $value de ${area['total']}',
    _ => null,
  };
}

class _SharedNarrative extends ConsumerStatefulWidget {
  const _SharedNarrative({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  ConsumerState<_SharedNarrative> createState() => _SharedNarrativeState();
}

class _SharedNarrativeState extends ConsumerState<_SharedNarrative> {
  Future<ProgressReport>? _report;

  void _generate() {
    final areas = ['memoria', 'atencion', 'praxias'].map((domain) {
      final area = widget.data[domain] as Map;
      final average = (area['average'] as num?)?.toDouble();
      final count = area['count'] as int;
      return ReportDomain(
        domain: domain,
        sessions: average == null ? count : area['comparable'] as int,
        level: area['level'] as int?,
        averageScore: average,
        signal: switch (area['trend']) {
          'improving' => 'mejora',
          'stable' => 'estable',
          'attention' => 'atencion',
          'review' => 'revisar',
          _ =>
            count > 0 && average == null
                ? 'calibracion_pendiente'
                : 'insuficiente',
        },
      );
    }).toList();
    final repository = ref.read(reportRepositoryProvider);
    final report = repository.generate(areas);
    setState(() {
      _report = report;
    });
  }

  String _exportText(ProgressReport? report) {
    final dateFormat = MaterialLocalizations.of(context);
    return [
      if (widget.data['publishedAt'] case final Timestamp date)
        'Resumen actualizado: ${dateFormat.formatShortDate(date.toDate().toLocal())}',
      'Período de seguimiento: últimos 28 días.',
      '',
      for (final (key, label) in [
        ('memoria', 'Memoria'),
        ('atencion', 'Atención'),
        ('praxias', 'Motricidad'),
      ])
        if (widget.data[key] case final Map area) ...[
          label,
          '${area['count']} prácticas registradas',
          if (area['latestGame'] case final String game) _gameTitle(game),
          if (area['latestLevel'] case final int level)
            'Nivel ${GameLevel.fromValue(level).label}',
          if (area['latestAt'] case final Timestamp date)
            'Última práctica: ${dateFormat.formatShortDate(date.toDate().toLocal())}',
          if (_practiceObservation(area) case final String observation)
            observation,
          if (area['attempts'] case final int attempts)
            'Intentos registrados: $attempts',
          if (area['errorsPct'] case final int errors)
            'Errores registrados: $errors %',
          if (area['figures'] case final int figures)
            'Figuras completadas: $figures',
          if (area['supports'] case final int supports)
            'Ayudas y demostraciones: $supports',
          if (area['trend'] != 'insufficient' && area['firstScore'] != null)
            '${area['comparable']} partidas comparables. Puntaje inicial y final: ${area['firstScore']} y ${area['lastScore']} de 100.',
          '',
        ],
      if (report != null) ...['Resumen redactado', report.text, ''],
      reportDisclaimer,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reportRepositoryProvider);
    return FutureBuilder<ProgressReport>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.hasError)
              const Text('No pudimos redactar el informe.'),
            if (snapshot.hasData) SelectableText(snapshot.data!.text),
            const SizedBox(height: 16),
            SaveReportPdfButton(text: _exportText(snapshot.data)),
            TextButton(
              onPressed: _generate,
              child: Text(
                snapshot.hasData ? 'Actualizar informe' : 'Redactar informe',
              ),
            ),
          ],
        );
      },
    );
  }
}
