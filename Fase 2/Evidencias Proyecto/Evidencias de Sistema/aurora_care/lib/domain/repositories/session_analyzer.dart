// lib/domain/repositories/session_analyzer.dart
import '../entities/session.dart';
import '../entities/session_analysis.dart';

abstract class SessionAnalyzer {
  /// [history]: sesiones del mismo dominio de los últimos 28 días, ya con
  /// score, sin incluir [session].
  Future<SessionAnalysis> analyze(Session session, List<Session> history);
}