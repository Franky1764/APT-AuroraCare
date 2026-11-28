import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/reports/report_providers.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/domain/entities/game_level.dart';

void main() {
  test('all uncalibrated historical sessions are retained', () {
    final report = reportDomains(
      const ProgressSummary(
        hasProfile: true,
        domains: [
          DomainSummary(domain: 'memoria', sessions: 18, scoredSessions: 0),
          DomainSummary(domain: 'atencion', sessions: 12, scoredSessions: 0),
          DomainSummary(domain: 'praxias', sessions: 61, scoredSessions: 0),
        ],
      ),
    );
    expect(report.map((d) => d.sessions), [18, 12, 61]);
    expect(
      report.every(
        (d) => d.signal == 'calibracion_pendiente' && d.averageScore == null,
      ),
      isTrue,
    );
  });
  test('trend count includes only analyzed sessions of the selected level', () {
    final report = reportDomains(
      const ProgressSummary(
        hasProfile: true,
        domains: [
          DomainSummary(
            domain: 'memoria',
            sessions: 18,
            scoredSessions: 9,
            comparableSessions: 6,
            level: GameLevel.facil,
            averageScore: 65,
            trend: ProgressTrend.stable,
          ),
        ],
      ),
    ).single;
    expect(report.sessions, 6);
    expect(report.averageScore, 65);
    expect(report.signal, 'estable');
  });
}
