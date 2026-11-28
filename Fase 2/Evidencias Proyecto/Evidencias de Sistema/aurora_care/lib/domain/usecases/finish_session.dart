// lib/domain/usecases/finish_session.dart
import '../entities/session.dart';
import '../entities/cognitive_metrics.dart';
import '../entities/session_analysis.dart';
import '../repositories/session_analyzer.dart';
import '../repositories/session_repository.dart';
import 'usecase.dart';

import 'dart:developer' as developer;

class FinishSession implements UseCase<SessionResult, FinishSessionParams> {
  final SessionRepository repository;
  final SessionAnalyzer analyzer;

  const FinishSession(this.repository, this.analyzer);

  static const _espera = Duration(seconds: 8);

  @override
  Future<SessionResult> call(FinishSessionParams params) async {
    final session = params.session;

    // Sin conexión, Firestore deja la escritura en cola y su Future no termina
    // hasta reconectar. No esperamos: la sesión queda guardada localmente.
    await repository.saveSession(session).timeout(_espera, onTimeout: () {});

    // La práctica de uso del teléfono conserva observaciones propias y no
    // se envía al scoring de atención o trazado sin una calibración específica.
    if (session.metrics is PhonePracticeMetrics) {
      return const SessionResult(null);
    }

    try {
      final window = await repository
          .getSessionsInWindow(session.uuid, domain: session.domain)
          .timeout(_espera);
      final history = window
          .where(
            (s) =>
                s.sessionId != session.sessionId &&
                s.gameType == session.gameType &&
                s.scoreSesion != null &&
                s.scoringVersion == 'scoring-v1.1-memorice-1',
          )
          .toList();

      final analysis = await analyzer
          .analyze(session, history)
          .timeout(_espera);

      // Solo se persisten resultados trazables; nunca se reemplazan por un score fijo.
      final version = analysis.scoringVersion;
      if (version == null || version != 'scoring-v1.1-memorice-1') {
        throw StateError('Versión de scoring no reconocida');
      }

      await repository
          .updateSessionScore(
            session.uuid,
            session.sessionId,
            analysis.scoreSesion,
            scoringVersion: version,
          )
          .timeout(_espera, onTimeout: () {});

      return SessionResult(analysis);
    } catch (e) {
      // Sin conexión o servicio caído: la sesión queda sin score.
      developer.log('FinishSession: sesión sin analizar. Motivo: $e');
      return const SessionResult(null);
    }
  }
}

class FinishSessionParams {
  final Session session;
  const FinishSessionParams(this.session);
}
