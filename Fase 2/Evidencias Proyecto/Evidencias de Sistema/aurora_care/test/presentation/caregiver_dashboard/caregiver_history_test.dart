import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_history.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Timestamp at(int month, int day, [int hour = 10]) =>
    Timestamp.fromDate(DateTime(2026, month, day, hour));

Map<String, dynamic> summary({
  Timestamp? memoria,
  Timestamp? praxias,
  String trend = 'stable',
}) => {
  if (memoria != null)
    'memoria': {
      'count': 1,
      'latestAt': memoria,
      'latestGame': 'que_cambio',
      'latestLevel': 1,
      'trend': trend,
    },
  if (praxias != null)
    'praxias': {'count': 2, 'latestAt': praxias, 'trend': 'insufficient'},
  'atencion': {'count': 0, 'latestAt': null},
};

void main() {
  final now = DateTime(2026, 11, 14, 18);

  test('guarda la última práctica de cada área sin repetirla', () {
    final first = mergeAreaHistory(
      [],
      summary(memoria: at(11, 7), praxias: at(11, 12)),
      now,
    );
    expect(first.map((e) => e.area), ['praxias', 'memoria']);
    expect(first.last.game, 'que_cambio');
    expect(first.last.level, 1);

    final again = mergeAreaHistory(
      first,
      summary(memoria: at(11, 7), praxias: at(11, 12)),
      now,
    );
    expect(again.length, 2);
  });

  test('conserva prácticas anteriores del mismo área', () {
    final first = mergeAreaHistory([], summary(memoria: at(11, 7)), now);
    final second = mergeAreaHistory(first, summary(memoria: at(11, 13)), now);
    expect(second.where((e) => e.area == 'memoria').length, 2);
    expect(second.first.at, DateTime(2026, 11, 13, 10));
  });

  test('solo guarda los últimos 28 días', () {
    final old = mergeAreaHistory(
      [],
      summary(memoria: at(10, 10)),
      DateTime(2026, 10, 12),
    );
    expect(old.length, 1);
    expect(mergeAreaHistory(old, const {}, now), isEmpty);
    final limit = mergeAreaHistory([], summary(memoria: at(10, 18, 0)), now);
    expect(limit.length, 1, reason: 'hoy y los 27 días anteriores');
  });

  test('áreas sin prácticas no entran al historial', () {
    final h = mergeAreaHistory([], summary(), now);
    expect(h, isEmpty);
  });

  test('días con práctica: el último punto es hoy', () {
    final h = mergeAreaHistory(
      [],
      summary(memoria: at(11, 14), praxias: at(11, 1)),
      now,
    );
    final memoria = practicedDays(h, 'memoria', now);
    expect(memoria.length, 28);
    expect(memoria.last, isTrue);
    expect(memoria.where((d) => d).length, 1);
    final praxias = practicedDays(h, 'praxias', now);
    expect(praxias[27 - 13], isTrue);
  });

  test('agrupa por semanas', () {
    expect(weekLabel(DateTime(2026, 11, 12), now), 'Últimos 7 días');
    expect(weekLabel(DateTime(2026, 11, 5), now), 'Hace una semana');
    expect(weekLabel(DateTime(2026, 10, 20), now), 'Hace 3 semanas');
  });

  test('el historial no guarda puntajes', () {
    final h = mergeAreaHistory([], summary(memoria: at(11, 7)), now);
    expect(h.first.toJson().keys, isNot(contains('lastScore')));
    expect(h.first.toJson().keys, isNot(contains('value')));
  });

  test('ida y vuelta en JSON', () {
    final h = mergeAreaHistory([], summary(memoria: at(11, 7)), now);
    final back = HistoryEntry.fromJson(h.first.toJson())!;
    expect(back.at, h.first.at);
    expect(back.trend, 'stable');
    expect(HistoryEntry.fromJson('basura'), isNull);
  });
}
