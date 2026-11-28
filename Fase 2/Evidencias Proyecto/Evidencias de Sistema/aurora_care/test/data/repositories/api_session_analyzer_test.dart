import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aurora_care/data/repositories/api_session_analyzer.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';

Session sample({
  String id = 'current',
  String uuid = 'private-profile',
  String domain = 'memoria',
  double? score,
  String? version,
  DateTime? date,
  CognitiveMetrics? metrics,
}) => Session(
  sessionId: id,
  uuid: uuid,
  domain: domain,
  gameType: 'memorice_clasico',
  nivel: GameLevel.facil,
  startTime: date ?? DateTime.utc(2026, 10, 28),
  endTime: DateTime.utc(2026, 10, 28, 0, 3),
  metrics:
      metrics ??
      const MemoriaMetrics(
        errores: 4,
        intentos: 20,
        tiempoSegundos: 180,
        tasaAciertoPct: 60,
      ),
  scoreSesion: score,
  scoringVersion: version,
);

Map<String, dynamic> result() => {
  'score_sesion': 55.8,
  'nivel_jugado': 1,
  'sugerir_avance': false,
  'sesiones_en_ventana': 2,
  'scoring_version': ApiSessionAnalyzer.scoringVersion,
  'tendencia': {
    'senal': 'insuficiente',
    'variacion_pct': null,
    'nivel_senal': 1,
  },
};

void main() {
  test(
    'sends real metrics without identity and excludes untrusted history',
    () async {
      final analyzer = ApiSessionAnalyzer(
        MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.example.test/session/analyze',
          );
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['metricas'], {
            'errores': 4,
            'intentos': 20,
            'tiempo_total_seg': 180,
            'tasa_acierto_pct': 60.0,
          });
          expect(request.body, isNot(contains('private-profile')));
          expect(request.body, isNot(contains('session_uuid')));
          expect(payload['historial_28d'], hasLength(1));
          return http.Response(jsonEncode(result()), 200);
        }),
        'https://api.example.test/',
      );
      final analysis = await analyzer.analyze(sample(), [
        sample(
          id: 'valid',
          score: 55,
          version: ApiSessionAnalyzer.scoringVersion,
        ),
        sample(id: 'fake', score: 70),
        sample(
          id: 'other',
          uuid: 'another',
          score: 70,
          version: ApiSessionAnalyzer.scoringVersion,
        ),
        sample(
          id: 'old',
          date: DateTime.utc(2026, 9, 1),
          score: 60,
          version: ApiSessionAnalyzer.scoringVersion,
        ),
        sample(
          id: 'future',
          date: DateTime.utc(2026, 11, 1),
          score: 60,
          version: ApiSessionAnalyzer.scoringVersion,
        ),
      ]);
      expect(analysis.scoreSesion, 55.8);
      expect(analysis.scoringVersion, ApiSessionAnalyzer.scoringVersion);
    },
  );

  test('translates attention and motor metrics', () async {
    for (final entry in <CognitiveMetrics, Map<String, num>>{
      const AtencionMetrics(
        tiempoRespuestaMs: 800,
        tasaErrorPct: 20,
        alcance: 4,
      ): {
        'tiempo_respuesta_ms': 800,
        'tasa_error_pct': 20,
        'alcance': 4,
      },
      const PraxiasMetrics(
        precisionPct: 85,
        correcciones: 3,
        tiempoSegundos: 60,
      ): {
        'precision_pct': 85,
        'correcciones': 3,
        'tiempo_seg': 60,
      },
    }.entries) {
      final analyzer = ApiSessionAnalyzer(
        MockClient((request) async {
          expect(jsonDecode(request.body)['metricas'], entry.value);
          return http.Response(jsonEncode(result()), 200);
        }),
        'https://api.example.test',
      );
      await analyzer.analyze(sample(metrics: entry.key), []);
    }
  });

  test('missing configuration does not send data', () async {
    final analyzer = ApiSessionAnalyzer(
      MockClient((_) async => throw StateError('must not send')),
      '',
    );
    await expectLater(analyzer.analyze(sample(), []), throwsStateError);
  });

  test('server errors never become a fabricated score', () async {
    for (final status in [422, 500, 503]) {
      final analyzer = ApiSessionAnalyzer(
        MockClient((_) async => http.Response('{}', status)),
        'https://api.example.test',
      );
      await expectLater(analyzer.analyze(sample(), []), throwsStateError);
    }
  });

  test('rejects invalid scores and missing provenance', () async {
    for (final invalid in [
      {...result(), 'score_sesion': 101},
      {...result(), 'scoring_version': null},
      {...result(), 'nivel_jugado': 2},
    ]) {
      final analyzer = ApiSessionAnalyzer(
        MockClient((_) async => http.Response(jsonEncode(invalid), 200)),
        'https://api.example.test',
      );
      await expectLater(analyzer.analyze(sample(), []), throwsFormatException);
    }
  });
}
