import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 7, 18);

  test('fecha de la actividad: hoy, ayer o día y mes', () {
    expect(practiceDateLabel(DateTime(2026, 11, 7, 10, 15), now), 'Hoy, 10:15');
    expect(practiceDateLabel(DateTime(2026, 11, 6, 16, 30), now), 'Ayer, 16:30');
    expect(practiceDateLabel(DateTime(2026, 10, 24, 11, 20), now), '24 oct, 11:20');
  });

  test('última práctica en palabras', () {
    expect(lastPracticeLabel(DateTime(2026, 11, 7, 9), now), 'Practicó hoy');
    expect(lastPracticeLabel(DateTime(2026, 11, 6, 9), now), 'Practicó ayer');
    expect(lastPracticeLabel(DateTime(2026, 11, 3, 9), now), 'Practicó hace 4 días');
    expect(lastPracticeLabel(null, now), 'Aún no hay prácticas registradas');
  });
}
