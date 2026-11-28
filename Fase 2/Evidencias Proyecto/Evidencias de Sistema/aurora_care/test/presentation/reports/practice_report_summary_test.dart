import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/presentation/progress/progress_providers.dart';
import 'package:aurora_care/presentation/reports/practice_report_summary.dart';

void main() {
  final now = DateTime(2026, 11, 27, 12);
  Session practice(
    String id,
    double accuracy, {
    GameLevel level = GameLevel.facil,
    String uuid = 'profile',
  }) => Session(
    sessionId: id,
    uuid: uuid,
    domain: 'memoria',
    gameType: 'memorice_clasico',
    nivel: level,
    startTime: now.subtract(const Duration(hours: 1)),
    endTime: now,
    metrics: MemoriaMetrics(
      errores: 1,
      intentos: 5,
      tiempoSegundos: 60,
      tasaAciertoPct: accuracy,
    ),
  );
  test('first unscored practice produces an exportable factual summary', () {
    final summary = summarizeProgress(
      [practice('1', 80)],
      uuid: 'profile',
      now: now,
    );
    final report = PracticeReportSummary(summary, now);
    expect(report.days, 1);
    expect(report.count, 1);
    expect(report.pdfText(), contains('80,0 %'));
    expect(report.pdfText(), contains('Registro inicial'));
    expect(report.pdfText(), isNot(contains('puntuación calibrada')));
    expect(
      report.pdfText(observations: 'Estaba cansada'),
      contains('Estaba cansada'),
    );
  });
  test(
    'averages same game and level, excluding other accounts and invalid values',
    () {
      final summary = summarizeProgress(
        [
          practice('1', 80),
          practice('2', 60),
          practice('3', 20, level: GameLevel.avanzado),
          practice('4', 0, uuid: 'other'),
          practice('5', double.nan),
        ],
        uuid: 'profile',
        now: now,
      );
      final groups = PracticeReportSummary(
        summary,
        now,
      ).groupsFor(summary.domains.first);
      expect(groups.length, 2);
      expect(groups.first.results.join(), contains('70,0 % (2 registros)'));
      expect(groups.last.results.join(), contains('20,0 %'));
    },
  );
  test(
    'structured tables retain levels, results and optional observations',
    () {
      final summary = summarizeProgress(
        [
          practice('advanced', 60, level: GameLevel.avanzado),
          practice('easy', 80),
        ],
        uuid: 'profile',
        now: now,
      );
      final sections = PracticeReportSummary(
        summary,
        now,
      ).pdfSections(observations: 'Una pregunta');
      expect(sections.first['observations'], 'Una pregunta');
      final memory = sections.firstWhere((s) => s['title'] == 'Memoria');
      final rows = memory['rows'] as List;
      expect(rows.map((row) => row['level']), ['Fácil', 'Avanzado']);
      expect(rows.first['results'], contains('80,0 %'));
      expect(rows.last['results'], contains('60,0 %'));
    },
  );
  test('empty period has no fabricated result', () {
    final summary = summarizeProgress([], uuid: 'profile', now: now);
    final report = PracticeReportSummary(summary, now);
    expect(report.count, 0);
    expect(report.days, 0);
    expect(report.overview, contains('primera práctica'));
    expect(report.pdfText(), isNot(contains('NaN')));
  });
}
