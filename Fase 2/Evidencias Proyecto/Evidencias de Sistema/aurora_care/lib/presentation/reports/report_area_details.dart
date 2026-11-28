import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../progress/progress_providers.dart';
import 'practice_report_summary.dart';

Future<void> showReportAreaDetails(
  BuildContext context,
  PracticeReportSummary report,
  DomainSummary area,
) {
  final groups = report.groupsFor(area);
  final games = groups.map((group) => group.title).toSet().toList();
  var game = games.firstOrNull;
  var selected = groups.firstOrNull;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final levels = groups.where((group) => group.title == game).toList();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reportAreaName(area.domain),
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
                        if (games.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: game,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ejercicio',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final name in games)
                                DropdownMenuItem(
                                  value: name,
                                  child: Text(name, maxLines: 2),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              game = value;
                              selected = groups.firstWhere(
                                (group) => group.title == value,
                              );
                            }),
                          ),
                        const SizedBox(height: 16),
                        Text('Nivel de la práctica', style: AppTextStyles.tag),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final group in levels)
                              ChoiceChip(
                                label: Text(group.first.nivel.label),
                                selected: identical(selected, group),
                                onSelected: (_) =>
                                    setState(() => selected = group),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (selected case final group?) ...[
                          Text(
                            '${group.sessions.length} ${group.sessions.length == 1 ? 'práctica en este nivel' : 'prácticas en este nivel'}',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const SizedBox(height: 12),
                          for (final result in group.results)
                            _ResultCard(result: result),
                          const SizedBox(height: 8),
                          Text(
                            'Los resultados describen sus ejercicios. Cada nivel se muestra por separado.',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ] else
                          Text(
                            'No hay resultados disponibles para este período.',
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
      },
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final String result;
  @override
  Widget build(BuildContext context) {
    final separator = result.indexOf(': ');
    final rawLabel = separator < 0 ? '' : result.substring(0, separator);
    const labels = {
      'Aciertos promedio por partida': 'Respuestas correctas',
      'Tiempo promedio por partida para responder': 'Tiempo para responder',
      'Errores promedio por partida': 'Respuestas incorrectas',
      'Acciones completadas': 'Acciones logradas',
      'Acciones con apoyo': 'Veces que usó el apoyo',
      'Precisión promedio del recorrido por partida': 'Precisión del recorrido',
    };
    final value = separator < 0 ? result : result.substring(separator + 2);
    final count = RegExp(r'\((\d+) registros?\)').firstMatch(value)?.group(1);
    final display = value
        .replaceAll(RegExp(r'\s*\(\d+ registros?\)\.?'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rawLabel.isNotEmpty)
            Text(labels[rawLabel] ?? rawLabel, style: AppTextStyles.body),
          const SizedBox(height: 6),
          Text(display, style: AppTextStyles.heading),
          if (count != null) ...[
            const SizedBox(height: 6),
            Text(
              count == '1'
                  ? 'Resultado de una práctica'
                  : 'Promedio de $count prácticas con datos',
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ],
      ),
    );
  }
}
