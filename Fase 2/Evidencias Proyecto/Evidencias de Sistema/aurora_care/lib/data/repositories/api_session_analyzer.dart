import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/cognitive_metrics.dart';
import '../../domain/entities/game_level.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_analysis.dart';
import '../../domain/repositories/session_analyzer.dart';

/// Envía solo métricas e historial numérico al calculador determinístico.
/// No envía identidad, UUID del perfil, identificador de sesión ni recuerdos.
class ApiSessionAnalyzer implements SessionAnalyzer {
  const ApiSessionAnalyzer(this.client, this.baseUrl);

  final http.Client client;
  final String baseUrl;
  static const scoringVersion = 'scoring-v1.1-memorice-1';

  @override
  Future<SessionAnalysis> analyze(
    Session session,
    List<Session> history,
  ) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme)) {
      throw StateError('Configure AURORACARE_API_BASE_URL');
    }
    final since = session.startTime.subtract(const Duration(days: 28));
    final validHistory = history.where(
      (s) =>
          s.uuid == session.uuid &&
          s.domain == session.domain &&
          s.sessionId != session.sessionId &&
          s.scoreSesion != null &&
          s.scoringVersion == scoringVersion &&
          !s.startTime.isBefore(since) &&
          !s.startTime.isAfter(session.startTime),
    );
    final response = await client
        .post(
          Uri.parse(
            '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/session/analyze',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'game_type': session.gameType,
            'nivel': session.nivel.value,
            'timestamp': session.startTime.toUtc().toIso8601String(),
            'metricas': _metrics(session.metrics),
            'historial_28d': [
              for (final previous in validHistory)
                {
                  'timestamp': previous.startTime.toUtc().toIso8601String(),
                  'nivel': previous.nivel.value,
                  'score': previous.scoreSesion,
                  'game_type': previous.gameType,
                  if (previous.metrics is MemoriaMetrics)
                    'tasa_acierto_pct':
                        (previous.metrics as MemoriaMetrics).tasaAciertoPct,
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 7));
    if (response.statusCode != 200) {
      // No se registra el cuerpo, porque contiene información de la sesión.
      throw StateError('Análisis pendiente (HTTP ${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final trend = data['tendencia'] as Map<String, dynamic>;
    final score = (data['score_sesion'] as num).toDouble();
    final variation = (trend['variacion_pct'] as num?)?.toDouble();
    final count = data['sesiones_en_ventana'] as int;
    if (!score.isFinite ||
        score < 0 ||
        score > 100 ||
        (variation != null && !variation.isFinite) ||
        count < 1 ||
        data['nivel_jugado'] != session.nivel.value ||
        data['scoring_version'] != scoringVersion) {
      throw const FormatException('Respuesta de scoring inválida');
    }
    return SessionAnalysis(
      scoreSesion: score,
      nivelJugado: session.nivel,
      sugerirAvance: data['sugerir_avance'] as bool,
      sesionesEnVentana: count,
      senal: TrendSignal.values.byName(trend['senal'] as String),
      variacionPct: variation,
      nivelSenal: trend['nivel_senal'] == null
          ? null
          : GameLevel.fromValue(trend['nivel_senal'] as int),
      scoringVersion: scoringVersion,
    );
  }

  Map<String, num> _metrics(CognitiveMetrics metrics) => switch (metrics) {
    MemoriaMetrics m => {
      'errores': m.errores,
      'intentos': m.intentos,
      'tiempo_total_seg': m.tiempoSegundos,
      'tasa_acierto_pct': m.tasaAciertoPct,
    },
    AtencionMetrics m => {
      'tiempo_respuesta_ms': m.tiempoRespuestaMs,
      'tasa_error_pct': m.tasaErrorPct,
      'alcance': m.alcance,
    },
    PraxiasMetrics m => {
      'precision_pct': m.precisionPct,
      'correcciones': m.correcciones,
      'tiempo_seg': m.tiempoSegundos,
    },
    _ => throw ArgumentError('Métricas no compatibles'),
  };
}
