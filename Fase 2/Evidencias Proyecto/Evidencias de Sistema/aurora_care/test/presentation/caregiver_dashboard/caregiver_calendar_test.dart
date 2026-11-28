import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_calendar.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_overview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Timestamp at(int day) => Timestamp.fromDate(DateTime(2026, 11, day, 10));

void main() {
  test('cada área practicada marca su día con el color de su estado', () {
    final history = mergeDayHistory({}, {
      'lastPracticeAt': at(7),
      'memoria': {'count': 1, 'trend': 'stable', 'latestAt': at(7)},
      'praxias': {'count': 2, 'trend': 'insufficient', 'latestAt': at(5)},
      'atencion': {'count': 0, 'trend': 'review', 'latestAt': at(3)},
    });
    expect(history['2026-11-07'], DayActivity.estable);
    expect(history['2026-11-05'], DayActivity.practico);
    expect(history.containsKey('2026-11-03'), isFalse);
  });

  test('se conserva el historial anterior y gana el estado más importante', () {
    final first = mergeDayHistory({}, {
      'memoria': {'count': 1, 'trend': 'improving', 'latestAt': at(6)},
    });
    final second = mergeDayHistory(first, {
      'atencion': {'count': 1, 'trend': 'review', 'latestAt': at(6)},
      'memoria': {'count': 2, 'trend': 'stable', 'latestAt': at(8)},
    });
    expect(second['2026-11-06'], DayActivity.bajo);
    expect(second['2026-11-08'], DayActivity.estable);
  });

  test('el saludo usa el nombre y no el correo', () {
    expect(caregiverGreetingName('Pruebascuidador@gmail.com'), 'Pruebascuidador');
    expect(caregiverGreetingName('carla'), 'Carla');
    expect(caregiverGreetingName(null), '');
  });
}
