import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/data/sources/practice_feedback_platform.dart';
import 'package:aurora_care/domain/entities/account_role.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/presentation/caregiver_dashboard/caregiver_alerts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationPermission extends PracticeFeedbackPlatform {
  int requests = 0;
  bool granted = false;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    return granted;
  }
}

Timestamp at(int day, [int hour = 10]) =>
    Timestamp.fromDate(DateTime(2026, 11, day, hour));

Map<String, dynamic> summary({
  required Timestamp last,
  String trend = 'insufficient',
  Timestamp? memoriaAt,
}) => {
  'lastPracticeAt': last,
  'memoria': {'trend': trend, 'latestAt': memoriaAt ?? last},
};

void main() {
  testWidgets('los avisos requieren activación explícita y permiso', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final platform = _FakeNotificationPermission();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        practiceFeedbackPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(navigationSessionProvider.notifier)
        .restore(
          const SessionInfo(
            role: AccountRole.caregiver,
            uid: 'caregiver',
            email: '',
          ),
        );

    final toggle = container.read(
      caregiverNotificationsEnabledProvider.notifier,
    );
    expect(container.read(caregiverNotificationsEnabledProvider), isFalse);
    expect(container.read(caregiverDailyReminderProvider), isFalse);
    expect(platform.requests, 0);

    expect(await toggle.set(true), isFalse);
    expect(container.read(caregiverNotificationsEnabledProvider), isFalse);

    platform.granted = true;
    expect(await toggle.set(true), isTrue);
    expect(container.read(caregiverNotificationsEnabledProvider), isTrue);
    expect(prefs.getBool('caregiver_alerts_enabled_caregiver'), isTrue);
    expect(container.read(caregiverDailyReminderProvider), isFalse);

    expect(await toggle.set(false), isTrue);
    expect(container.read(caregiverNotificationsEnabledProvider), isFalse);
    expect(platform.requests, 2);
  });

  test('la primera lectura no avisa de prácticas antiguas', () {
    final r = evaluateCaregiverAlerts(null, summary(last: at(7)));
    expect(r.alerts, isEmpty);
  });

  test('una práctica nueva avisa «Nuevo progreso» una sola vez', () {
    final first = evaluateCaregiverAlerts(null, summary(last: at(7)));
    final second = evaluateCaregiverAlerts(first.state, summary(last: at(8)));
    expect(second.alerts.map((a) => a.kind), ['progress']);
    final again = evaluateCaregiverAlerts(second.state, summary(last: at(8)));
    expect(again.alerts, isEmpty);
  });

  test('un solo resultado «revisar» no avisa (SCORING §4.4)', () {
    final first = evaluateCaregiverAlerts(null, summary(last: at(6)));
    final r = evaluateCaregiverAlerts(
      first.state,
      summary(last: at(7), trend: 'review'),
    );
    expect(r.alerts.where((a) => a.kind == 'attention'), isEmpty);
  });

  test('«revisar» el mismo día dos veces no avisa', () {
    final s0 = evaluateCaregiverAlerts(null, summary(last: at(6)));
    final s1 = evaluateCaregiverAlerts(
      s0.state,
      summary(last: at(7, 9), trend: 'review'),
    );
    final s2 = evaluateCaregiverAlerts(
      s1.state,
      summary(last: at(7, 18), trend: 'review'),
    );
    expect(s2.alerts.where((a) => a.kind == 'attention'), isEmpty);
  });

  test('«revisar» en dos días distintos avisa una vez', () {
    final s0 = evaluateCaregiverAlerts(null, summary(last: at(5)));
    final s1 = evaluateCaregiverAlerts(
      s0.state,
      summary(last: at(6), trend: 'review'),
    );
    final s2 = evaluateCaregiverAlerts(
      s1.state,
      summary(last: at(7), trend: 'review'),
    );
    expect(s2.alerts.where((a) => a.kind == 'attention').length, 1);
    final s3 = evaluateCaregiverAlerts(
      s2.state,
      summary(last: at(8), trend: 'review'),
    );
    expect(s3.alerts.where((a) => a.kind == 'attention'), isEmpty);
  });

  test('los textos no usan palabras prohibidas ni números', () {
    const prohibidas = [
      'deterioro',
      'demencia',
      'alzheimer',
      'diagnóstico',
      'problema',
      'anormal',
      'patológico',
      'enfermedad',
    ];
    final s0 = evaluateCaregiverAlerts(null, summary(last: at(5)));
    final s1 = evaluateCaregiverAlerts(
      s0.state,
      summary(last: at(6), trend: 'review'),
    );
    final s2 = evaluateCaregiverAlerts(
      s1.state,
      summary(last: at(7), trend: 'review'),
    );
    for (final a in [...s1.alerts, ...s2.alerts]) {
      final text = '${a.title} ${a.message}'.toLowerCase();
      expect(text.contains(RegExp(r'\d')), isFalse);
      for (final p in prohibidas) {
        expect(text.contains(p), isFalse, reason: p);
      }
    }
  });

  test(
    'la primera práctica en un área nueva avisa en vez de «Nuevo progreso»',
    () {
      final s0 = evaluateCaregiverAlerts(null, summary(last: at(5)));
      final r = evaluateCaregiverAlerts(s0.state, {
        ...summary(last: at(6), memoriaAt: at(5)),
        'praxias': {'trend': 'insufficient', 'latestAt': at(6)},
      });
      expect(r.alerts.map((a) => a.kind), ['new_area']);
      expect(r.alerts.single.message, contains('Motricidad'));
    },
  );

  test('la primera lectura no avisa áreas nuevas', () {
    final r = evaluateCaregiverAlerts(null, {
      ...summary(last: at(6)),
      'praxias': {'trend': 'stable', 'latestAt': at(6)},
    });
    expect(r.alerts, isEmpty);
  });

  test('cambios del vínculo', () {
    expect(evaluateLinkChange(null, 'abc')?.kind, 'linked');
    expect(evaluateLinkChange('abc', 'abc'), isNull);
    expect(evaluateLinkChange('abc', null)?.kind, 'unlinked');
    expect(evaluateLinkChange(null, null), isNull);
    expect(evaluateLinkChange('abc', 'xyz')?.kind, 'linked');
  });

  group('racha de práctica', () {
    final now = DateTime(2026, 11, 10, 20);
    List<String> days(List<int> d) => [
      for (final n in d) '2026-11-${n.toString().padLeft(2, '0')}',
    ];

    test('cinco días seguidos hasta hoy avisa una sola vez', () {
      final r = evaluateStreakAlert(null, days([6, 7, 8, 9, 10]), now);
      expect(r.alert?.kind, 'streak');
      expect(r.notifiedStart, '2026-11-06');
      final again = evaluateStreakAlert(
        r.notifiedStart,
        days([6, 7, 8, 9, 10, 11]),
        DateTime(2026, 11, 11, 20),
      );
      expect(again.alert, isNull);
    });

    test('cuatro días o una racha cortada no avisan', () {
      expect(evaluateStreakAlert(null, days([7, 8, 9, 10]), now).alert, isNull);
      expect(
        evaluateStreakAlert(null, days([4, 5, 7, 8, 9, 10]), now).alert,
        isNull,
      );
    });

    test('una racha antigua no avisa', () {
      expect(
        evaluateStreakAlert(null, days([1, 2, 3, 4, 5]), now).alert,
        isNull,
      );
    });

    test('la racha puede terminar ayer', () {
      expect(
        evaluateStreakAlert(null, days([5, 6, 7, 8, 9]), now).alert?.kind,
        'streak',
      );
    });
  });

  test('los avisos nuevos no usan palabras prohibidas ni números', () {
    final s0 = evaluateCaregiverAlerts(null, summary(last: at(5)));
    final nueva = evaluateCaregiverAlerts(s0.state, {
      ...summary(last: at(6), memoriaAt: at(5)),
      'atencion': {'trend': 'stable', 'latestAt': at(6)},
    });
    final textos = [
      ...nueva.alerts,
      evaluateLinkChange(null, 'a')!,
      evaluateLinkChange('a', null)!,
      evaluateStreakAlert(null, [
        for (var d = 6; d <= 10; d++) '2026-11-${d.toString().padLeft(2, '0')}',
      ], DateTime(2026, 11, 10)).alert!,
    ];
    for (final a in textos) {
      final text = '${a.title} ${a.message}'.toLowerCase();
      expect(text.contains(RegExp(r'\d')), isFalse, reason: text);
      for (final p in [
        'deterioro',
        'demencia',
        'diagnóstico',
        'problema',
        'enfermedad',
      ]) {
        expect(text.contains(p), isFalse, reason: p);
      }
    }
  });
}
