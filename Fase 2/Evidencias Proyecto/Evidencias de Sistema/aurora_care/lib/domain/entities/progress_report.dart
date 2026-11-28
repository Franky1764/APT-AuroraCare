/// El reporte solo recibe agregados; nunca identidad ni referencias del perfil.
class ReportDomain {
  const ReportDomain({
    required this.domain,
    required this.sessions,
    required this.signal,
    this.level,
    this.averageScore,
  });
  final String domain;
  final int sessions;
  final String signal;
  final int? level;
  final double? averageScore;
}

class ProgressReport {
  const ProgressReport({required this.text, required this.source});
  final String text;
  final String source;
}

const reportDisclaimer =
    'Este reporte no constituye un diagnóstico médico. '
    'Consulte a un profesional de la salud para una evaluación completa.';

ProgressReport localProgressReport(List<ReportDomain> domains) {
  final paragraphs = <String>['Resumen de los últimos 28 días.'];
  for (final domain in domains) {
    final label = switch (domain.domain) {
      'memoria' => 'Memoria',
      'atencion' => 'Atención',
      _ => 'Motricidad',
    };
    final details = domain.averageScore == null
        ? 'La práctica está registrada. Aún no hay una puntuación calibrada para comparar.'
        : 'Se incluyen ${domain.sessions} sesiones comparables de nivel ${domain.level}, '
              'con puntuación media ${domain.averageScore!.toStringAsFixed(1).replaceAll('.', ',')}/100. '
              'Consulte el detalle de seguimiento para conocer el contexto de la comparación.';
    paragraphs.add(
      domain.sessions == 0
          ? '$label: sin sesiones recientes.'
          : '$label: ${domain.sessions} ${domain.sessions == 1 ? 'sesión' : 'sesiones'}. $details',
    );
  }
  paragraphs.add(reportDisclaimer);
  return ProgressReport(text: paragraphs.join('\n\n'), source: 'dispositivo');
}
