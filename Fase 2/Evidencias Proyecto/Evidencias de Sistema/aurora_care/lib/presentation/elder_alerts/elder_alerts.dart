// lib/presentation/elder_alerts/elder_alerts.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_account_provider.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../data/repositories/session_repository_impl.provider.dart';
import '../../data/sources/elder_alerts_platform.dart';
import '../../domain/entities/account_role.dart';
import '../../domain/entities/session.dart';
import '../games/shared/game_providers.dart';
import '../progress/progress_providers.dart';

/// Avisos del adulto mayor (además de los de las 09:00 y 20:00 que ya
/// existían en PracticeNotifications):
/// - 16:00 Sugerencia de área, solo si hoy no practicó.
/// - 20:00 Felicitación por constancia (3, 5, 7, 14, 21 y 28 días seguidos).
///   Solo si practicó hoy, así nunca coincide con «Un momento para usted».
/// - Domingo 18:00 Resumen de la semana (cuántos días practicó).
/// Sin puntajes ni palabras de SCORING §prohibidas.

const elderAreaNames = {
  'memoria': 'Memoria',
  'atencion': 'Atención',
  'praxias': 'Motricidad',
};

/// Día en formato aaaa-mm-dd (el mismo que lee Android).
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Área que conviene sugerir: la que no practica hace 3 días o más
/// (o nunca), eligiendo la más antigua. Null si practicó todas hace poco
/// o si aún no tiene ninguna práctica.
String? suggestArea(Iterable<Session> sessions, DateTime now) {
  if (sessions.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  String? best;
  DateTime? bestDate;
  for (final area in elderAreaNames.keys) {
    DateTime? last;
    for (final s in sessions.where((s) => s.domain == area)) {
      if (last == null || s.endTime.isAfter(last)) last = s.endTime;
    }
    if (last == null) return area; // nunca la practicó: va primero
    final lastDay = DateTime(last.year, last.month, last.day);
    if (today.difference(lastDay).inDays < 3) continue;
    if (bestDate == null || last.isBefore(bestDate)) {
      best = area;
      bestDate = last;
    }
  }
  return best;
}

/// Días seguidos con práctica que terminan hoy.
int currentStreak(Set<String> days, DateTime now) {
  var streak = 0;
  var day = DateTime(now.year, now.month, now.day);
  while (days.contains(isoDay(day))) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// La felicitación solo sale en estos hitos, para no repetirla cada día.
bool isStreakMilestone(int streak) =>
    streak == 3 || streak == 5 || (streak >= 7 && streak % 7 == 0);

/// Mantiene a Android al día: se recalcula al iniciar sesión, al cambiar el
/// interruptor de notificaciones y después de cada partida (progressProvider
/// se invalida al terminar un juego).
final elderAlertsSyncProvider = Provider.autoDispose<void>((ref) {
  final session = ref.watch(navigationSessionProvider).session;
  final platform = ref.watch(elderAlertsPlatformProvider);
  final uid = session?.uid;
  final isElder =
      uid != null &&
      session?.role == AccountRole.elder &&
      ref.watch(authenticatedAccountIdProvider) == uid;
  final enabled = ref.watch(notificationsEnabledProvider);
  if (!isElder || !enabled) {
    unawaited(platform.configure(account: isElder ? uid : null, enabled: false));
    return;
  }
  ref.watch(progressProvider); // se recalcula después de cada partida
  final profile = ref.watch(activeProfileProvider).valueOrNull;
  if (profile == null) {
    unawaited(platform.configure(account: uid, enabled: true));
    return;
  }
  final repository = ref.watch(sessionRepositoryProvider);
  unawaited(() async {
    try {
      final sessions = await repository.getSessionsInWindow(
        profile.uuid,
        days: 28,
      );
      final now = DateTime.now();
      final area = suggestArea(sessions, now);
      await platform.configure(
        account: uid,
        enabled: true,
        practiceDays: {for (final s in sessions) isoDay(s.endTime)}.toList(),
        suggestedArea: area == null ? null : elderAreaNames[area],
      );
    } catch (_) {
      // Sin datos locales no se programan sugerencias; los demás avisos siguen.
      await platform.configure(account: uid, enabled: true);
    }
  }());
});
