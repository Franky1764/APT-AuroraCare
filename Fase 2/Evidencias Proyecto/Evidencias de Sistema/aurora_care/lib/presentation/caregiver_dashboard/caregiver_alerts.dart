// lib/presentation/caregiver_dashboard/caregiver_alerts.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_account_provider.dart';
import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../data/sources/caregiver_alerts_platform.dart';
import '../../data/sources/practice_feedback_platform.dart';
import '../../domain/entities/account_role.dart';
import 'caregiver_calendar.dart';
import 'shared_practice_provider.dart';

/// Avisos al cuidador (SCRUM-34). Usa el mismo resumen compartido que el
/// panel (shared_practice_provider.dart), sin cambiar cómo se entrega la
/// información del vínculo.
///
/// - Nuevo progreso: el adulto mayor registró una práctica nueva.
/// - Atención: un área queda en «revisar» en dos evaluaciones seguidas de
///   días distintos (SCORING §4.4). Una sola evaluación no avisa.
/// - Nueva área: la primera práctica en un área desde el vínculo.
/// - Vinculación lista / Vínculo finalizado: cambios en el vínculo.
/// - Racha: cinco días seguidos con práctica (según el calendario).
/// - En Android (CaregiverNotifications.kt), a las 19:00 y con la app
///   cerrada: recordatorio diario (opcional), «Hace unos días que no
///   practica» (tres días sin prácticas nuevas) y resumen semanal (domingo).
///
/// El permiso de notificaciones se pide la primera vez que el cuidador
/// entra al panel; los interruptores muestran el estado real del permiso.

class CaregiverAlert {
  const CaregiverAlert(this.kind, this.title, this.message);
  final String kind;
  final String title;
  final String message;
}

class CaregiverAlertsEvaluation {
  const CaregiverAlertsEvaluation(this.state, this.alerts);
  final Map<String, dynamic> state;
  final List<CaregiverAlert> alerts;
}

const _areaNames = {
  'memoria': 'Memoria',
  'atencion': 'Atención',
  'praxias': 'Motricidad',
};

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

int? _millis(Object? value) => switch (value) {
  Timestamp t => t.millisecondsSinceEpoch,
  DateTime d => d.millisecondsSinceEpoch,
  int ms => ms,
  _ => null,
};

/// Compara el resumen nuevo con lo que el cuidador ya vio y decide qué
/// avisos corresponden. Función pura para poder probarla.
CaregiverAlertsEvaluation evaluateCaregiverAlerts(
  Map<String, dynamic>? previous,
  Map<String, dynamic> summary,
) {
  final state = <String, dynamic>{
    'lastPractice': previous?['lastPractice'],
    'areas': Map<String, dynamic>.from(
      (previous?['areas'] as Map?) ?? const {},
    ),
  };
  final alerts = <CaregiverAlert>[];
  final firstTime = previous == null;

  final lastPractice = _millis(summary['lastPracticeAt']);
  final seen = state['lastPractice'] as int?;
  var newPractice = false;
  if (lastPractice != null && (seen == null || lastPractice > seen)) {
    newPractice = !firstTime && seen != null;
    state['lastPractice'] = lastPractice;
  }

  final areas = state['areas'] as Map<String, dynamic>;
  for (final entry in _areaNames.entries) {
    final area = summary[entry.key];
    if (area is! Map) continue;
    final latest = _millis(area['latestAt']);
    if (latest == null) continue;
    final before = Map<String, dynamic>.from(
      (areas[entry.key] as Map?) ?? const {},
    );
    if ((before['latest'] as int? ?? 0) >= latest) continue;

    if (before['latest'] == null && !firstTime) {
      alerts.add(
        CaregiverAlert(
          'new_area',
          'Practicó en una nueva área',
          'Su familiar practicó ${entry.value} por primera vez desde que '
              'están vinculados. Puede verlo en el panel.',
        ),
      );
    }

    final day = _dayKey(DateTime.fromMillisecondsSinceEpoch(latest));
    final review = area['trend'] == 'review';
    final sustained =
        review && before['review'] == true && before['day'] != day;
    final notified = review && (before['notified'] == true || sustained);

    if (sustained && before['notified'] != true && !firstTime) {
      alerts.add(
        CaregiverAlert(
          'attention',
          'Un aviso sobre ${entry.value}',
          'Las partidas recientes de ${entry.value} muestran resultados '
              'más bajos en dos días distintos. Si lo desea, puede '
              'conversarlo con un profesional de la salud.',
        ),
      );
    }
    areas[entry.key] = {
      'latest': latest,
      'day': day,
      'review': review,
      'notified': notified,
    };
  }
  // «Nueva área» ya cuenta la práctica nueva: no se envían dos avisos.
  if (newPractice && !alerts.any((a) => a.kind == 'new_area')) {
    alerts.insert(
      0,
      const CaregiverAlert(
        'progress',
        'Nuevo progreso de su familiar',
        'Registró una práctica nueva. Puede ver el resumen en el panel.',
      ),
    );
  }
  return CaregiverAlertsEvaluation(state, alerts);
}

/// Aviso cuando cambia el vínculo. [previous] es el último vínculo que vio
/// este teléfono y [current] el vínculo activo confirmado por el servidor.
CaregiverAlert? evaluateLinkChange(String? previous, String? current) {
  if (current != null && current != previous) {
    return const CaregiverAlert(
      'linked',
      'Vinculación lista',
      'Ya puede ver la actividad de práctica de su familiar en el panel.',
    );
  }
  if (previous != null && current == null) {
    return const CaregiverAlert(
      'unlinked',
      'Vínculo finalizado',
      'El vínculo con su familiar terminó y ya no verá su actividad. '
          'Si lo desea, puede vincularse de nuevo con un código QR.',
    );
  }
  return null;
}

/// Racha de práctica: avisa una vez cuando hay [streakDays] días seguidos
/// con práctica que terminan hoy o ayer. [notifiedStart] es el primer día
/// de la última racha avisada, para no repetir el aviso.
({CaregiverAlert? alert, String? notifiedStart}) evaluateStreakAlert(
  String? notifiedStart,
  Iterable<String> practiceDays,
  DateTime now,
) {
  const streakDays = 5;
  final days = practiceDays.toSet();
  DateTime before(DateTime d) => DateTime(d.year, d.month, d.day - 1);
  var end = DateTime(now.year, now.month, now.day);
  if (!days.contains(dayKey(end))) end = before(end);
  if (!days.contains(dayKey(end))) {
    return (alert: null, notifiedStart: notifiedStart);
  }
  var start = end;
  var length = 1;
  while (days.contains(dayKey(before(start)))) {
    start = before(start);
    length++;
  }
  final startKey = dayKey(start);
  if (length < streakDays || startKey == notifiedStart) {
    return (alert: null, notifiedStart: notifiedStart);
  }
  return (
    alert: const CaregiverAlert(
      'streak',
      '¡Varios días seguidos!',
      'Su familiar practicó cinco días seguidos. Es un buen momento para '
          'felicitarle.',
    ),
    notifiedStart: startKey,
  );
}

String? _caregiverUid(Ref ref) {
  final session = ref.watch(navigationSessionProvider).session;
  return session?.role == AccountRole.caregiver ? session?.uid : null;
}

class _CaregiverSwitch extends Notifier<bool> {
  _CaregiverSwitch(this.key);
  final String key;

  /// Solo queda activado si el cuidador lo eligió y Android permite las
  /// notificaciones. Por defecto queda desactivado hasta dar el permiso.
  @override
  bool build() {
    final uid = _caregiverUid(ref);
    if (uid == null) return false;
    final prefs = ref.watch(sharedPreferencesProvider);
    final platform = ref.watch(practiceFeedbackPlatformProvider);
    final name = '${key}_$uid';
    var disposed = false;

    // Revisa el permiso real al abrir y al volver de Ajustes.
    Future<void> check() async {
      await Future<void>.value(); // después de build
      final chosen = prefs.getBool(name) ?? false;
      final allowed = chosen && await platform.notificationsAllowed();
      if (!disposed && state != allowed) state = allowed;
    }

    final listener = AppLifecycleListener(onResume: check);
    ref.onDispose(() {
      disposed = true;
      listener.dispose();
    });
    check();
    return prefs.getBool(name) ?? false;
  }

  /// Devuelve false si el usuario no dio permiso de notificaciones.
  Future<bool> set(bool value) async {
    final uid = _caregiverUid(ref);
    if (uid == null) return false;
    final allowed =
        !value ||
        await ref.read(practiceFeedbackPlatformProvider).requestNotifications();
    if (_caregiverUid(ref) != uid) return false;
    final enabled = value && allowed;
    await ref.read(sharedPreferencesProvider).setBool('${key}_$uid', enabled);
    state = enabled;
    return allowed;
  }
}

final caregiverNotificationsEnabledProvider =
    NotifierProvider<_CaregiverSwitch, bool>(
      () => _CaregiverSwitch('caregiver_alerts_enabled'),
    );

final caregiverDailyReminderProvider = NotifierProvider<_CaregiverSwitch, bool>(
  () => _CaregiverSwitch('caregiver_daily_reminder'),
);

/// Configura Android y revisa los cambios del resumen mientras el panel
/// está abierto. El permiso se solicita al activar un interruptor.
final caregiverAlertsSyncProvider = Provider.autoDispose<void>((ref) {
  final uid = _caregiverUid(ref);
  final platform = ref.watch(caregiverAlertsPlatformProvider);
  final enabled = ref.watch(caregiverNotificationsEnabledProvider);
  final daily = ref.watch(caregiverDailyReminderProvider);
  if (uid == null) {
    platform.configure(account: null, enabled: false, dailyReminder: false);
    return;
  }
  // Mientras Firebase confirma la cuenta no se cambia nada.
  if (ref.watch(authenticatedAccountIdProvider) != uid) return;

  final prefs = ref.watch(sharedPreferencesProvider);
  final alerts = <CaregiverAlert>[];

  // Vinculación lista / Vínculo finalizado (vínculo confirmado por el
  // servidor, no desde la caché).
  final link = ref.watch(sharedPracticeLinkProvider);
  final token = link.valueOrNull;
  if (link is AsyncData<String?>) {
    final linkKey = 'caregiver_alerts_link_$uid';
    final change = evaluateLinkChange(prefs.getString(linkKey), token);
    if (change != null) alerts.add(change);
    token == null ? prefs.remove(linkKey) : prefs.setString(linkKey, token);
  }

  int? lastPractice;
  var practiceDays = const <String>[];
  if (token != null) {
    final key = 'caregiver_alerts_state_${uid}_$token';
    final raw = prefs.getString(key);
    var state = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    final summary = ref
        .watch(sharedPracticeSummaryProvider(token))
        .valueOrNull;
    if (summary != null) {
      final result = evaluateCaregiverAlerts(state, summary);
      state = result.state;
      prefs.setString(key, jsonEncode(result.state));
      alerts.addAll(result.alerts);
    }
    lastPractice = state?['lastPractice'] as int?;

    final history = ref.watch(caregiverDayHistoryProvider);
    final streakKey = 'caregiver_alerts_streak_${uid}_$token';
    final streak = evaluateStreakAlert(
      prefs.getString(streakKey),
      history.keys,
      DateTime.now(),
    );
    if (streak.alert != null) {
      alerts.add(streak.alert!);
      prefs.setString(streakKey, streak.notifiedStart!);
    }
    final since = dayKey(DateTime.now().subtract(const Duration(days: 14)));
    practiceDays = [
      for (final day in history.keys)
        if (day.compareTo(since) >= 0) day,
    ];
  }

  // Android usa la última práctica y los días con práctica para los avisos
  // de las 19:00 aunque la app esté cerrada.
  platform.configure(
    account: uid,
    enabled: enabled,
    dailyReminder: enabled && daily,
    lastPractice: lastPractice,
    practiceDays: practiceDays,
  );
  if (!enabled) return;
  for (final alert in alerts) {
    platform.notify(
      account: uid,
      kind: alert.kind,
      title: alert.title,
      message: alert.message,
    );
  }
});
