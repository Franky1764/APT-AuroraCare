import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/progress_report.dart';
import '../challenges/daily_challenge_card.dart';
import '../progress/progress_providers.dart';
import 'practice_report_summary.dart';
import 'report_area_details.dart';
import 'report_providers.dart';
import 'save_report_pdf_button.dart';

class ProgressReportScreen extends ConsumerStatefulWidget {
  const ProgressReportScreen({super.key});
  @override
  ConsumerState<ProgressReportScreen> createState() =>
      _ProgressReportScreenState();
}

class _ProgressReportScreenState extends ConsumerState<ProgressReportScreen> {
  final _observations = TextEditingController();
  @override
  void dispose() {
    _observations.dispose();
    super.dispose();
  }

  Widget _section(String title, List<Widget> children) => Card(
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
  Widget build(BuildContext context) {
    final state = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de mi progreso')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(progressProvider),
              child: const Text('No pudimos cargar sus prácticas. Reintentar'),
            ),
          ),
          data: (summary) {
            if (!summary.hasProfile) {
              return const Center(
                child: Text(
                  'Seleccione su perfil para consultar sus prácticas.',
                ),
              );
            }
            final report = PracticeReportSummary(
              summary,
              ref.read(progressClockProvider)(),
            );
            // Conserva la notificación de informe disponible y la redacción opcional.
            final narrative = ref.watch(progressReportProvider).asData?.value;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SaveReportPdfButton(
                    text: report.pdfText(
                      observations: _observations.text,
                      narrative: narrative,
                    ),
                    sections: report.pdfSections(
                      observations: _observations.text,
                      narrative: narrative,
                    ),
                    activity: {
                      for (final area in summary.domains)
                        reportAreaName(area.domain): area.sessions,
                    },
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const PracticeCalendar(showChallenges: false),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  color: AppColors.textOnPrimary,
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textOnPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Su práctica, en un vistazo',
                              style: AppTextStyles.heading.copyWith(
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Últimos 28 días · ${reportDate(report.now.subtract(const Duration(days: 28)))} al ${reportDate(report.now)}',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 20,
                              runSpacing: 8,
                              children: [
                                Text(
                                  '${report.count} prácticas',
                                  style: AppTextStyles.cardTitle.copyWith(
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                                Text(
                                  '${report.days} días con actividad',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section('Resumen general', [
                    SelectableText(report.overview, style: AppTextStyles.body),
                  ]),
                  const SizedBox(height: 16),
                  _section('Actividad por área', [
                    Text(
                      'Cantidad de prácticas registradas. Las barras representan actividad.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 16),
                    for (final area in summary.domains) ...[
                      Text(
                        '${reportAreaName(area.domain)} · ${area.sessions}',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        label:
                            '${reportAreaName(area.domain)}: ${area.sessions} prácticas',
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: report.count == 0
                                ? 0
                                : area.sessions /
                                      summary.domains
                                          .map((a) => a.sessions)
                                          .reduce((a, b) => a > b ? a : b),
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
                  const SizedBox(height: 16),
                  Text('Resultados por área', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 8),
                  for (final area in summary.domains) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        title: Text(
                          reportAreaName(area.domain),
                          style: AppTextStyles.cardTitle,
                        ),
                        subtitle: Text(
                          '${area.sessions} ${area.sessions == 1 ? 'práctica' : 'prácticas'} · ${area.sessions == 0 ? 'Sin actividad' : 'Ver resultados'}',
                          style: AppTextStyles.bodySecondary,
                        ),
                        trailing: area.sessions == 0
                            ? null
                            : Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primary,
                              ),
                        onTap: area.sessions == 0
                            ? null
                            : () =>
                                  showReportAreaDetails(context, report, area),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (narrative != null &&
                      narrative.source != 'dispositivo') ...[
                    const SizedBox(height: 16),
                    _section('Resumen complementario', [
                      Text(
                        narrative.source == 'openai'
                            ? 'Redactado con asistencia de IA'
                            : 'Preparado con plantilla',
                        style: AppTextStyles.tag,
                      ),
                      Text(
                        narrative.text.replaceAll(reportDisclaimer, '').trim(),
                        style: AppTextStyles.body,
                        textAlign: TextAlign.justify,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  _section('Sus observaciones para la consulta', [
                    Text(
                      'Opcional. Puede anotar cómo se sintió o qué desea preguntar. Se incluirá en el PDF; no se envía para redactar el resumen.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _observations,
                      maxLength: 600,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Por ejemplo: ese día estaba cansada.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Text(
                      'Estas notas se conservan solo mientras esta pantalla esté abierta.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  Text(
                    reportDisclaimer,
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
