import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aurora_care/data/repositories/api_report_repository.dart';
import 'package:aurora_care/domain/entities/progress_report.dart';

void main() {
  const domains = [
    ReportDomain(
      domain: 'praxias',
      sessions: 61,
      signal: 'calibracion_pendiente',
    ),
  ];
  test(
    'sends only allowlisted aggregates and accepts server template',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/report/generate');
        expect(jsonDecode(request.body), {
          'periodo_dias': 28,
          'resumen_dominios': {
            'praxias': {'sesiones': 61, 'senal': 'calibracion_pendiente'},
          },
        });
        return http.Response(
          jsonEncode({
            'reporte_texto': 'Práctica registrada. $reportDisclaimer',
            'generado_con': 'plantilla_local',
          }),
          200,
        );
      });
      final result = await ApiReportRepository(
        client,
        'https://example.test',
      ).generate(domains);
      expect(result.source, 'plantilla_local');
    },
  );
  test(
    'offline, malformed and missing disclaimer fall back to real counts',
    () async {
      for (final response in [
        http.Response('error', 503),
        http.Response('{}', 200),
        http.Response(
          jsonEncode({'reporte_texto': 'sin aviso', 'generado_con': 'openai'}),
          200,
        ),
      ]) {
        final result = await ApiReportRepository(
          MockClient((_) async => response),
          'https://example.test',
        ).generate(domains);
        expect(result.source, 'dispositivo');
        expect(result.text, contains('61 sesiones'));
        expect(result.text, contains(reportDisclaimer));
        expect(result.text, isNot(contains('mejora')));
      }
    },
  );
  test('timeout does not leave the report loading indefinitely', () async {
    final pending = Completer<http.Response>();
    final result = await ApiReportRepository(
      MockClient((_) => pending.future),
      'https://example.test',
      timeout: const Duration(milliseconds: 10),
    ).generate(domains);
    expect(result.source, 'dispositivo');
    pending.complete(http.Response('{}', 200));
  });
  test('unconfigured endpoint does not send data', () async {
    final result = await ApiReportRepository(
      MockClient((_) async {
        fail('No endpoint configured');
      }),
      '',
    ).generate(domains);
    expect(result.source, 'dispositivo');
  });
}
