import 'package:aurora_care/domain/entities/session.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/elder_caregiver_departure.dart';
import 'package:aurora_care/presentation/elder_alerts/elder_alerts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Solo se usan domain y endTime; el resto no importa para estas reglas.
Session played(String domain, DateTime at) => _FakeSession(domain, at);

class _FakeSession implements Session {
  _FakeSession(this.domain, this.endTime);
  @override
  final String domain;
  @override
  final DateTime endTime;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 11, 15, 16);

  group('sugerencia de área (16:00)', () {
    test('sin prácticas no sugiere área', () {
      expect(suggestArea([], now), isNull);
    });

    test('sugiere primero el área que nunca practicó', () {
      final area = suggestArea([
        played('memoria', DateTime(2026, 11, 15)),
        played('praxias', DateTime(2026, 11, 14)),
      ], now);
      expect(area, 'atencion');
    });

    test('sugiere la que no practica hace más tiempo (3 días o más)', () {
      final area = suggestArea([
        played('memoria', DateTime(2026, 11, 15)),
        played('atencion', DateTime(2026, 11, 10)),
        played('praxias', DateTime(2026, 11, 5)),
      ], now);
      expect(area, 'praxias');
    });

    test('si practicó todo hace poco no sugiere', () {
      final area = suggestArea([
        played('memoria', DateTime(2026, 11, 15)),
        played('atencion', DateTime(2026, 11, 14)),
        played('praxias', DateTime(2026, 11, 13)),
      ], now);
      expect(area, isNull);
    });

    test('praxias se muestra como Motricidad', () {
      expect(elderAreaNames['praxias'], 'Motricidad');
    });
  });

  group('constancia (20:00)', () {
    test('cuenta días seguidos que terminan hoy', () {
      final days = {'2026-11-13', '2026-11-14', '2026-11-15', '2026-11-10'};
      expect(currentStreak(days, now), 3);
      expect(currentStreak({'2026-11-14'}, now), 0);
    });

    test('solo felicita en los hitos', () {
      expect([1, 2, 3, 4, 5, 6, 7, 8, 14, 21].where(isStreakMilestone), [3, 5, 7, 14, 21]);
    });

    test('fecha en formato aaaa-mm-dd', () {
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('cuidador vinculado', () {
    test('avisa si el vínculo es reciente y trae nombre', () {
      final notice = evaluateCaregiverArrival(
        token: 't',
        link: {
          'status': 'active',
          'caregiverName': 'Ana',
          'linkedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 1))),
        },
        alreadyNotifiedToken: null,
        now: now,
      );
      expect(notice!.message, 'Ana ahora acompaña su práctica 💜');
    });

    test('no avisa vínculos antiguos ni repetidos', () {
      final old = {
        'status': 'active',
        'caregiverName': 'Ana',
        'linkedAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
      };
      expect(
        evaluateCaregiverArrival(token: 't', link: old, alreadyNotifiedToken: null, now: now),
        isNull,
      );
      final recent = {...old, 'linkedAt': Timestamp.fromDate(now)};
      expect(
        evaluateCaregiverArrival(token: 't', link: recent, alreadyNotifiedToken: 't', now: now),
        isNull,
      );
    });
  });
}
