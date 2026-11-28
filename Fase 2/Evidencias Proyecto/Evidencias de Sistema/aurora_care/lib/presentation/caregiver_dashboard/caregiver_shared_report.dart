import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/game_level.dart';
import '../../domain/entities/progress_report.dart';
import '../games/game_catalog.dart';
import '../reports/practice_report_summary.dart';
import '../reports/save_report_pdf_button.dart';
import 'shared_practice_provider.dart';
import 'caregiver_signal.dart';

const _areas = ['memoria', 'atencion', 'praxias'];

String _game(Map area) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == area['latestGame'])
        .firstOrNull
        ?.title ??
    'Ejercicio registrado';
String _level(Map area) =>
    GameLevel.values
        .where((level) => level.value == area['latestLevel'])
        .firstOrNull
        ?.label ??
    'No informado';
int _count(Map area) =>
    area['count'] is int ? (area['count'] as int).clamp(0, 1000000) : 0;
String? _date(Object? value) =>
    value is Timestamp ? reportDate(value.toDate()) : null;
String _dateSuffix(Object? value) {
  final date = _date(value);
  return date == null ? '' : ': $date';
}

List<(String, String)> _results(Map area) {
  final value = area['value'];
  return [
    if (value is num && value.isFinite && value >= 0)
      switch (area['metric']) {
        'accuracy' => ('Respuestas correctas', '$value %'),
        'precision' => ('Precisión del recorrido', '$value %'),
        'response' when value > 0 => (
          'Tiempo para responder',
          value < 100
              ? 'Menos de 0,1 segundos'
              : '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} segundos',
        ),
        'completed' => ('Acciones logradas', '$value de ${area['total']}'),
        _ => ('', ''),
      },
    if (area['errorsPct'] case final num errors)
      ('Respuestas incorrectas', '$errors %'),
    if (area['figures'] case final int figures)
      ('Figuras completadas', '$figures'),
    if (area['supports'] case final int supports)
      ('Apoyos y demostraciones', '$supports'),
  ].where((item) => item.$1.isNotEmpty).toList();
}

/// Solo presenta el resumen recibido del vínculo; no accede al historial local del cuidador.
class CaregiverSharedReport extends ConsumerWidget {
  const CaregiverSharedReport({super.key, this.narrativeBuilder});
  final Widget Function(Map<String, dynamic> data, bool fresh)?
  narrativeBuilder;

  Widget _card(String title, List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final token = link.asData?.value;
    final shared = token == null
        ? null
        : ref.watch(sharedPracticeSummaryProvider(token));
    // Los errores y la carga se comprueban antes de usar datos anteriores del stream.
    if (link.hasError || shared?.hasError == true) {
      return Center(
        child: TextButton(
          onPressed: () {
            ref.invalidate(sharedPracticeLinkProvider);
            if (token != null) {
              ref.invalidate(sharedPracticeSummaryProvider(token));
            }
          },
          child: const Text('No pudimos cargar el reporte. Reintentar'),
        ),
      );
    }
    if (link.isLoading || shared?.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    if (token == null) {
      return const Center(
        child: Text('Vincule a su familiar para consultar su reporte.'),
      );
    }
    final data = shared?.asData?.value;
    if (data == null) {
      return const Center(
        child: Text('Aún no hay un resumen compartido disponible.'),
      );
    }
    final counts = {
      for (final domain in _areas)
        reportAreaName(domain): _count(
          data[domain] is Map ? data[domain] as Map : const {},
        ),
    };
    final total = counts.values.fold<int>(
      0,
      (accumulated, amount) => accumulated + amount,
    );
    final maximum = counts.values.fold<int>(
      1,
      (maximum, amount) => amount > maximum ? amount : maximum,
    );
    final published = _date(data['publishedAt']);
    final sections = <Map<String, Object>>[
      {
        'title': 'Resumen compartido',
        'body':
            '$total prácticas registradas en el período de 28 días del resumen.\n'
            '${published == null ? 'Fecha de actualización no disponible.' : 'Actualizado el $published.'}\n\n'
            'Los resultados de cada área corresponden solamente a su última práctica compartida. No son promedios del período.',
      },
      for (final domain in _areas)
        {
          'title': reportAreaName(domain),
          'body':
              '${counts[reportAreaName(domain)]} prácticas registradas en esta área.',
          'rows': [
            if (data[domain] case final Map area when _count(area) > 0)
              {
                'game': _game(area),
                'level': _level(area),
                'count': '1',
                'results': _results(area)
                    .map((result) => '${result.$1}: ${result.$2}')
                    .join('\n'),
              },
          ],
          'context': data[domain] is Map && _count(data[domain] as Map) > 0
              ? 'Última práctica compartida${_dateSuffix((data[domain] as Map)['latestAt'])}. Los resultados de esta fila corresponden a una sola práctica.'
              : 'Sin prácticas registradas en este período.',
        },
    ];
    final text = [
      for (final section in sections) ...[
        section['title'],
        section['body'],
        if (section['rows'] case final List rows)
          for (final row in rows) ...[
            '${(row as Map)['game']} · Nivel ${row['level']}',
            row['results'],
          ],
        if (section['context'] != null) section['context'],
        '',
      ],
      reportDisclaimer,
    ].join('\n');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Reporte de progreso', style: AppTextStyles.heading),
        const SizedBox(height: 16),
        SaveReportPdfButton(
          key: ValueKey(token),
          text: text,
          activity: counts,
          sections: sections,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$total prácticas',
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              Text(
                'Período de 28 días del resumen',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              if (published != null)
                Text(
                  'Actualizado el $published',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card('Actividad por área', [
          for (final entry in counts.entries) ...[
            Text('${entry.key} · ${entry.value}', style: AppTextStyles.body),
            const SizedBox(height: 6),
            Semantics(
              label: '${entry.key}: ${entry.value} prácticas',
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: entry.value / maximum,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ]),
        const SizedBox(height: 20),
        Text('Última práctica por área', style: AppTextStyles.cardTitle),
        const SizedBox(height: 8),
        Text(
          'Toque un área para ver su último resultado compartido.',
          style: AppTextStyles.bodySecondary,
        ),
        const SizedBox(height: 12),
        for (final domain in _areas) ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              title: Text(
                reportAreaName(domain),
                style: AppTextStyles.cardTitle,
              ),
              subtitle: Text(
                '${counts[reportAreaName(domain)]} prácticas · ${counts[reportAreaName(domain)] == 0 ? 'Sin actividad' : 'Ver última práctica'}',
                style: AppTextStyles.bodySecondary,
              ),
              trailing: counts[reportAreaName(domain)] == 0
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: counts[reportAreaName(domain)] == 0
                  ? null
                  : () => _openLatest(
                      context,
                      token,
                      domain,
                      data[domain] as Map,
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (narrativeBuilder != null) ...[
          Card(
            child: ExpansionTile(
              key: ValueKey((token, data['publishedAt'])),
              title: const Text('Resumen escrito opcional'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: narrativeBuilder!(
                    data,
                    data['publishedAt'] is Timestamp &&
                        DateTime.now()
                                .difference(
                                  (data['publishedAt'] as Timestamp).toDate(),
                                )
                                .inDays <
                            28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(reportDisclaimer, style: AppTextStyles.bodySecondary),
      ],
    );
  }

  void _openLatest(
    BuildContext context,
    String token,
    String domain,
    Map area,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LinkedLatest(token: token, domain: domain),
    );
  }
}

/// Si cambia el vínculo, el detalle deja de mostrar los datos de ese vínculo.
class _LinkedLatest extends ConsumerWidget {
  const _LinkedLatest({required this.token, required this.domain});
  final String token;
  final String domain;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final current = ref.watch(sharedPracticeSummaryProvider(token));
    if (link.asData?.value != token ||
        current.asData?.value == null ||
        link.hasError ||
        current.hasError) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Este resumen ya no está disponible.'),
        ),
      );
    }
    final latest = current.asData!.value![domain];
    if (latest is! Map) {
      return const SizedBox.shrink();
    }
    final published = current.asData!.value!['publishedAt'];
    final fresh =
        published is Timestamp &&
        DateTime.now().difference(published.toDate()).inDays < 28;
    final signal = CaregiverSignal.fromSummary(latest['trend'], fresh: fresh);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      reportAreaName(domain),
                      style: AppTextStyles.heading,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar resultados',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_game(latest), style: AppTextStyles.cardTitle),
                    Text(
                      'Nivel ${_level(latest)}',
                      style: AppTextStyles.bodySecondary,
                    ),
                    Text(
                      'Última práctica${_dateSuffix(latest['latestAt'])}',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    for (final result in _results(latest))
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.$1, style: AppTextStyles.body),
                            Text(result.$2, style: AppTextStyles.heading),
                          ],
                        ),
                      ),
                    ExpansionTile(
                      title: const Text('Evolución de las prácticas'),
                      subtitle: Text(signal.label),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            signal.message,
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                    if (_results(latest).isEmpty)
                      Text(
                        'No hay medidas disponibles para esta práctica.',
                        style: AppTextStyles.bodySecondary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
