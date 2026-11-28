import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/progress_report.dart';
import '../../domain/repositories/report_repository.dart';

class ApiReportRepository implements ReportRepository {
  const ApiReportRepository(
    this.client,
    this.baseUrl, {
    this.timeout = const Duration(seconds: 10),
  });
  final http.Client client;
  final String baseUrl;
  final Duration timeout;

  @override
  Future<ProgressReport> generate(List<ReportDomain> domains) async {
    try {
      final base = Uri.tryParse(baseUrl);
      if (base == null ||
          !['https', 'http'].contains(base.scheme) ||
          base.host.isEmpty) {
        return localProgressReport(domains);
      }
      // Lista cerrada: no se serializan sesiones, fechas, UUID ni identidad.
      final response = await client
          .post(
            Uri.parse(
              '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/report/generate',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'periodo_dias': 28,
              'resumen_dominios': {
                for (final domain in domains)
                  domain.domain: {
                    'sesiones': domain.sessions,
                    'senal': domain.signal,
                    if (domain.level != null) 'nivel_senal': domain.level,
                    if (domain.averageScore != null)
                      'score_promedio': domain.averageScore,
                  },
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return localProgressReport(domains);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['reporte_texto'];
      final source = data['generado_con'];
      if (text is! String ||
          text.trim().isEmpty ||
          text.length > 5000 ||
          !text.contains(reportDisclaimer) ||
          !['openai', 'plantilla_local'].contains(source)) {
        return localProgressReport(domains);
      }
      return ProgressReport(text: text, source: source as String);
    } catch (_) {
      return localProgressReport(domains);
    }
  }
}
