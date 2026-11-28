// lib/presentation/caregiver_dashboard/elder_caregiver_departure.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_account_provider.dart';
import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../data/sources/caregiver_alerts_platform.dart';
import '../../domain/entities/account_role.dart';

/// Aviso para el adulto mayor cuando SU CUIDADOR decide terminar el vínculo.
/// Devuelve null si no corresponde avisar:
/// - el vínculo sigue activo,
/// - lo terminó el propio adulto mayor (no trae revokedBy: 'caregiver'),
/// - ya se avisó por este mismo vínculo.
({String title, String message})? evaluateCaregiverDeparture({
  required String token,
  required Map<String, dynamic>? link,
  required String? alreadyNotifiedToken,
}) {
  if (link == null ||
      link['status'] != 'revoked' ||
      link['revokedBy'] != 'caregiver' ||
      alreadyNotifiedToken == token) {
    return null;
  }
  final raw = link['caregiverName'];
  final name = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  return (
    title: 'Su cuidador terminó el vínculo',
    message: name == null
        ? 'Su cuidador ya no verá su actividad de práctica. '
              'Si lo desea, puede invitar a otro familiar desde su perfil.'
        : '$name ya no verá su actividad de práctica. '
              'Si lo desea, puede invitar a otro familiar desde su perfil.',
  );
}

/// Aviso para el adulto mayor cuando un cuidador acaba de vincularse.
/// Solo si el vínculo es reciente (10 minutos) y ya trae el nombre, para no
/// avisar de vínculos antiguos al reinstalar la app.
({String title, String message})? evaluateCaregiverArrival({
  required String token,
  required Map<String, dynamic>? link,
  required String? alreadyNotifiedToken,
  required DateTime now,
}) {
  if (link == null ||
      link['status'] != 'active' ||
      alreadyNotifiedToken == token) {
    return null;
  }
  final linkedAt = link['linkedAt'];
  if (linkedAt is! Timestamp ||
      now.difference(linkedAt.toDate()).inMinutes.abs() > 10) {
    return null;
  }
  final raw = link['caregiverName'];
  if (raw is! String || raw.trim().isEmpty) return null;
  return (
    title: 'Un familiar lo acompaña',
    message: '${raw.trim()} ahora acompaña su práctica 💜',
  );
}

/// Escucha el vínculo del adulto mayor y avisa una sola vez cuando un
/// cuidador se vincula y cuando el cuidador se desvincula. Se activa desde main.dart con un ref.watch.
final elderCaregiverDepartureProvider = Provider.autoDispose<void>((ref) {
  final session = ref.watch(navigationSessionProvider).session;
  final uid = session?.uid;
  if (uid == null ||
      session?.role != AccountRole.elder ||
      ref.watch(authenticatedAccountIdProvider) != uid) {
    return;
  }
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final platform = ref.watch(caregiverAlertsPlatformProvider);
  final notifiedKey = 'elder_caregiver_left_$uid';
  final joinedKey = 'elder_caregiver_joined_$uid';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? linkSub;
  String? watchedToken;
  // includeMetadataChanges: sin esto, si la primera lectura viene de la
  // caché y el servidor no trae cambios, nunca llega una lectura «del
  // servidor» y el aviso no se mostraba (el vínculo no se escuchaba).
  final pointerSub = firestore
      .collection('caregiver_invite_state')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .listen((pointer) {
        if (pointer.metadata.isFromCache) return;
        final token = pointer.data()?['token'] as String?;
        if (token == watchedToken) return;
        watchedToken = token;
        linkSub?.cancel();
        linkSub = null;
        if (token == null) return;
        linkSub = firestore
            .collection('caregiver_links')
            .doc(token)
            .snapshots(includeMetadataChanges: true)
            .listen((link) {
              if (link.metadata.isFromCache) return;
              final arrival = evaluateCaregiverArrival(
                token: token,
                link: link.data(),
                alreadyNotifiedToken: prefs.getString(joinedKey),
                now: DateTime.now(),
              );
              if (arrival != null) {
                prefs.setString(joinedKey, token);
                unawaited(
                  platform.notifyElder(
                    title: arrival.title,
                    message: arrival.message,
                    kind: 'linked',
                  ),
                );
                return;
              }
              final notice = evaluateCaregiverDeparture(
                token: token,
                link: link.data(),
                alreadyNotifiedToken: prefs.getString(notifiedKey),
              );
              if (notice == null) return;
              prefs.setString(notifiedKey, token);
              unawaited(
                platform.notifyElder(
                  title: notice.title,
                  message: notice.message,
                ),
              );
              // El resumen compartido ya nadie lo puede leer: se borra.
              unawaited(
                firestore
                    .collection('caregiver_summaries')
                    .doc(token)
                    .delete()
                    .catchError((_) {}),
              );
            }, onError: (_) {});
      }, onError: (_) {});

  ref.onDispose(() {
    pointerSub.cancel();
    linkSub?.cancel();
  });
});
