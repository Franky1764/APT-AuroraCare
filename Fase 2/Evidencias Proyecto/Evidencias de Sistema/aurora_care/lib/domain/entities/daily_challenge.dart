import 'cognitive_metrics.dart';
import 'session.dart';

enum ChallengeUnit { games, seconds, searches }

enum DailyChallenge {
  memorice('memorice_clasico', 'Complete 2 partidas de Memorice', 2),
  search(
    'buscar_en_lista',
    'Encuentre 3 elementos en Buscar en una lista',
    3,
    ChallengeUnit.searches,
  ),
  changes('que_cambio', 'Complete 1 partida de ¿Qué cambió?', 1),
  numberTime(
    'recuerde_numero',
    'Practique 3 minutos en Recuerde el número',
    180,
    ChallengeUnit.seconds,
  ),
  listGames('buscar_en_lista', 'Complete 2 partidas de Buscar en una lista', 2),
  connectTime(
    'conecta_puntos',
    'Practique 3 minutos en Conecta los puntos',
    180,
    ChallengeUnit.seconds,
  ),
  correctTouch('toca_correcto', 'Complete 2 partidas de Toca correcto', 2),
  memoryTime(
    'memorice_clasico',
    'Practique 3 minutos en Memorice',
    180,
    ChallengeUnit.seconds,
  ),
  trace('trazado_guiado', 'Complete 1 partida de Trazado guiado', 1),
  changesTime(
    'que_cambio',
    'Practique 2 minutos en ¿Qué cambió?',
    120,
    ChallengeUnit.seconds,
  ),
  zoom('ampliar_imagen', 'Complete 1 partida de Ampliar imagen', 1),
  sequenceTime(
    'memorice_secuencias',
    'Practique 3 minutos en Memorice de secuencias',
    180,
    ChallengeUnit.seconds,
  ),
  objectCount(
    'contador_objetos',
    'Complete 3 partidas de Contador de objetos',
    3,
  ),
  memoryLonger(
    'memorice_clasico',
    'Practique 4 minutos en Memorice',
    240,
    ChallengeUnit.seconds,
  );

  const DailyChallenge(
    this.gameType,
    this.title,
    this.goal, [
    this.unit = ChallengeUnit.games,
  ]);
  final String gameType;
  final String title;
  final int goal;
  final ChallengeUnit unit;

  static const _rotation = [
    changes,
    numberTime,
    listGames,
    connectTime,
    correctTouch,
    memoryTime,
    trace,
    changesTime,
    zoom,
    sequenceTime,
    objectCount,
    memoryLonger,
    memorice,
  ];

  static DailyChallenge forDay(DateTime day) {
    final calendarDay = DateTime.utc(day.year, day.month, day.day);
    final index = calendarDay.difference(DateTime.utc(2026, 11, 7)).inDays;
    // Mantiene las metas ya asignadas y evita reescribir rachas anteriores.
    if (index < 0) return index.isEven ? memorice : search;
    return _rotation[index % _rotation.length];
  }

  String progressLabel(int units) => switch (unit) {
    ChallengeUnit.games =>
      '$units de $goal ${goal == 1 ? 'partida' : 'partidas'}',
    ChallengeUnit.searches => '$units de $goal elementos encontrados',
    ChallengeUnit.seconds => '${_clock(units)} de ${_clock(goal)} min',
  };

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  int units(Session session) {
    if (session.gameType != gameType) return 0;
    return switch (unit) {
      ChallengeUnit.games => 1,
      ChallengeUnit.searches => switch (session.metrics) {
        PhoneListMetrics(:final completedSearches) => completedSearches,
        _ => 0,
      },
      ChallengeUnit.seconds => switch (session.metrics) {
        MemoriaMetrics(:final tiempoSegundos) => tiempoSegundos,
        PraxiasMetrics(
          :final tiempoSegundos,
          connectionVersion: 'connect-dots-v2',
        ) =>
          tiempoSegundos,
        _ => 0,
      },
    };
  }
}

class DailyChallengeProgress {
  const DailyChallengeProgress({
    required this.today,
    required this.unitsToday,
    required this.completedDates,
    required this.streak,
  });

  final DateTime today;
  final int unitsToday;
  final Set<DateTime> completedDates;
  final int streak;

  DailyChallenge get challenge => DailyChallenge.forDay(today);
  bool get completed => unitsToday >= challenge.goal;

  factory DailyChallengeProgress.fromSessions(
    Iterable<Session> sessions,
    DateTime now,
  ) {
    final today = _day(now);
    final totals = <DateTime, int>{};
    final counted = <String>{};
    for (final session in sessions) {
      if (session.endTime.isAfter(now) || !counted.add(session.sessionId)) {
        continue;
      }
      final date = _day(session.endTime);
      final units = DailyChallenge.forDay(date).units(session);
      if (units > 0) {
        totals.update(date, (total) => total + units, ifAbsent: () => units);
      }
    }
    final completed = {
      for (final entry in totals.entries)
        if (entry.value >= DailyChallenge.forDay(entry.key).goal) entry.key,
    };
    var day = completed.contains(today) ? today : _previousDay(today);
    var streak = 0;
    while (completed.contains(day)) {
      streak++;
      day = _previousDay(day);
    }
    return DailyChallengeProgress(
      today: today,
      unitsToday: (totals[today] ?? 0).clamp(
        0,
        DailyChallenge.forDay(today).goal,
      ),
      completedDates: Set.unmodifiable(completed),
      streak: streak,
    );
  }

  static DateTime _day(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _previousDay(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);
}
