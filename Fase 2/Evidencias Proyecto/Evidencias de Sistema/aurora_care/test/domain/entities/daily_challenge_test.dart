import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/daily_challenge.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/domain/entities/session.dart';
import 'package:flutter_test/flutter_test.dart';

Session practice(
  String id,
  DateTime date,
  DailyChallenge challenge,
  CognitiveMetrics metrics,
) => Session(
  sessionId: id,
  uuid: 'profile',
  domain: 'memoria',
  gameType: challenge.gameType,
  nivel: GameLevel.facil,
  startTime: date,
  endTime: date,
  metrics: metrics,
);

void main() {
  test('la rotación mezcla juegos y mantiene metas breves', () {
    final month = [
      for (var day = 7; day < 37; day++)
        DailyChallenge.forDay(DateTime(2026, 11, day)),
    ];
    expect(month.toSet().length, greaterThan(10));
    expect(month.map((goal) => goal.gameType).toSet().length, greaterThan(5));
    for (final goal in month) {
      switch (goal.unit) {
        case ChallengeUnit.games:
          expect(goal.goal, inInclusiveRange(1, 3));
        case ChallengeUnit.seconds:
          expect(goal.goal, inInclusiveRange(1, 600));
        case ChallengeUnit.searches:
          fail('La nueva rotación usa partidas o minutos.');
      }
    }
  });

  test('una meta de tiempo suma solo la práctica del juego indicado', () {
    final date = DateTime(2026, 11, 8, 10);
    const metrics = MemoriaMetrics(
      errores: 0,
      intentos: 3,
      tiempoSegundos: 95,
      tasaAciertoPct: 100,
    );
    final sessions = [
      practice('one', date, DailyChallenge.numberTime, metrics),
      practice('other', date, DailyChallenge.memorice, metrics),
    ];
    final partial = DailyChallengeProgress.fromSessions(sessions, date);
    expect(partial.unitsToday, 95);
    expect(
      partial.challenge.progressLabel(partial.unitsToday),
      '1:35 de 3:00 min',
    );
    expect(partial.completed, isFalse);
    final done = DailyChallengeProgress.fromSessions([
      ...sessions,
      practice('two', date, DailyChallenge.numberTime, metrics),
    ], date);
    expect(done.unitsToday, 180);
    expect(done.completed, isTrue);
  });

  test('el avance cuenta partidas únicas y la racha solo días completados', () {
    final yesterday = DateTime(2026, 11, 5, 10);
    final today = DateTime(2026, 11, 6, 10);
    const memory = MemoriaMetrics(
      errores: 1,
      intentos: 3,
      tiempoSegundos: 10,
      tasaAciertoPct: 66,
    );
    const twoSearches = PhoneListMetrics(
      completedSearches: 2,
      totalSearches: 3,
      selectionAttempts: 3,
      otherSelections: 1,
      scrollGestures: 4,
      revealRequests: 0,
      searchesWithHelp: 0,
      listLength: 12,
    );
    final first = practice('first', yesterday, DailyChallenge.memorice, memory);
    final search = practice(
      'search',
      today,
      DailyChallenge.search,
      twoSearches,
    );
    final partial = DailyChallengeProgress.fromSessions([
      first,
      first,
      search,
    ], today);
    expect(partial.unitsToday, 2);
    expect(partial.streak, 0);
    expect(partial.completedDates, isEmpty);

    final second = practice(
      'second',
      yesterday,
      DailyChallenge.memorice,
      memory,
    );
    final later = practice('later', today, DailyChallenge.search, twoSearches);
    final done = DailyChallengeProgress.fromSessions([
      first,
      second,
      search,
      later,
    ], today);
    expect(done.unitsToday, 3);
    expect(done.streak, 2);
    expect(done.completedDates, {DateTime(2026, 11, 5), DateTime(2026, 11, 6)});
  });
}
