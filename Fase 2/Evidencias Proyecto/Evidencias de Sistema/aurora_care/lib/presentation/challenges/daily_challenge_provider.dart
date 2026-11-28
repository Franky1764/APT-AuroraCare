import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_account_provider.dart';
import '../../core/router/navigation_session.dart';
import '../../data/sources/account_profile_store.provider.dart';
import '../../data/sources/local_session_store.dart';
import '../../domain/entities/account_role.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/session.dart';
import '../progress/progress_providers.dart';

final dailyChallengeSessionsProvider = Provider.autoDispose<List<Session>?>((
  ref,
) {
  final session = ref.watch(navigationSessionProvider).session;
  if (session?.role != AccountRole.elder) return null;
  ref.watch(authAccountChangesProvider);
  final store = ref.watch(accountProfileStoreProvider);
  if (store.currentAccount() != session?.uid) return null;
  // También prepara el perfil de una cuenta recién configurada.
  ref.watch(progressProvider);
  final profile = store.read(session!.uid);
  if (profile == null) return null;
  return LocalSessionStore(store.preferences)
      .all(profile.uuid)
      .map((model) => model.toEntity())
      .toList();
});

final dailyChallengeProvider = Provider.autoDispose<DailyChallengeProgress?>((
  ref,
) {
  final sessions = ref.watch(dailyChallengeSessionsProvider);
  if (sessions == null) return null;
  final now = ref.watch(progressClockProvider)().toLocal();
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextDay.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DailyChallengeProgress.fromSessions(sessions, now);
});
