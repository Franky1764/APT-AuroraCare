import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_history.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_week_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry practice(String area, int month, int day) =>
    HistoryEntry(area: area, at: DateTime(2026, month, day, 10));

Timestamp at(int month, int day) =>
    Timestamp.fromDate(DateTime(2026, month, day, 10));

void main() {
  // Sábado 21 de noviembre de 2026; la semana empieza el lunes 16.
  final now = DateTime(2026, 11, 21, 18);
  final weekStart = DateTime(2026, 11, 16);

  group('resumen semanal', () {
    test('cuenta días y prácticas reales de la semana', () {
      final week = weeklySummaryFromHistory([
        practice('memoria', 11, 16),
        practice('atencion', 11, 16),
        practice('memoria', 11, 18),
        practice('praxias', 11, 10), // semana anterior: no cuenta
      ], weekStart);
      expect(week.activeDays, [true, false, true, false, false, false, false]);
      expect(week.activeCount, 2);
      expect(week.practices, 3);
      expect(week.mostPracticedArea, 'Memoria');
    });

    test('sin prácticas no inventa datos', () {
      final week = weeklySummaryFromHistory([], weekStart);
      expect(week.activeCount, 0);
      expect(week.practices, 0);
      expect(week.mostPracticedArea, isNull);
      expect(week.message, 'No hay prácticas registradas esta semana.');
    });

    test('praxias se muestra como Motricidad', () {
      final week = weeklySummaryFromHistory(
        [practice('praxias', 11, 17)],
        weekStart,
      );
      expect(week.mostPracticedArea, 'Motricidad');
    });
  });

  group('avisos del panel', () {
    test('sin resumen compartido no hay avisos', () {
      expect(
        caregiverNoticesFrom(summary: null, history: const [], now: now),
        isEmpty,
      );
    });

    test('muestra la última práctica de cada área y abre su detalle', () {
      final notices = caregiverNoticesFrom(
        summary: {
          'publishedAt': at(11, 21),
          'lastPracticeAt': at(11, 21),
          'memoria': {
            'latestAt': at(11, 21),
            'latestGame': 'que_cambio',
            'latestLevel': 1,
            'trend': 'stable',
          },
          'atencion': {'latestAt': at(11, 10)}, // más de 7 días: no sale
        },
        history: [practice('memoria', 11, 21)],
        now: now,
      );
      final area = notices.first;
      expect(area.title, 'Practicó Memoria');
      expect(area.timeLabel, 'Hoy');
      expect(area.target, CaregiverNoticeTarget.area);
      expect(area.areaKey, 'memoria');
      expect(notices.where((n) => n.title == 'Practicó Atención'), isEmpty);
      expect(notices.last.target, CaregiverNoticeTarget.weeklySummary);
    });

    test('avisa cuando hace días que no practica', () {
      final notices = caregiverNoticesFrom(
        summary: {'publishedAt': at(11, 20), 'lastPracticeAt': at(11, 16)},
        history: const [],
        now: now,
      );
      expect(notices.single.title, 'Hace unos días que no practica');
    });

    test('los avisos no muestran puntajes ni palabras prohibidas', () {
      final notices = caregiverNoticesFrom(
        summary: {
          'publishedAt': at(11, 21),
          'memoria': {
            'latestAt': at(11, 21),
            'value': 87,
            'lastScore': 87,
            'trend': 'review',
          },
        },
        history: const [],
        now: now,
      );
      final text = notices.map((n) => '${n.title} ${n.body}').join(' ');
      expect(text, isNot(contains('87')));
      for (final word in ['deterioro', 'demencia', 'diagnóstico', 'problema']) {
        expect(text.toLowerCase(), isNot(contains(word)));
      }
    });
  });
}
