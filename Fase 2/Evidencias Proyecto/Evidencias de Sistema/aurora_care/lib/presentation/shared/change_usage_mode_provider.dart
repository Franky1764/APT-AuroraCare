import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/navigation_session.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import '../../domain/usecases/change_usage_mode.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';
import '../../domain/usecases/get_or_create_cognitive_profile.dart';
import '../../domain/usecases/get_or_create_cognitive_profile.provider.dart';
import '../games/shared/game_providers.dart';
import '../progress/progress_providers.dart';
import 'current_mode_provider.dart';
import 'usage_mode_exceptions.dart';
import '../profile/caregiver_link_notifier.dart';

final changeUsageModeProvider = Provider<Future<void> Function(int)>((ref) {
  final changeMode = ChangeUsageMode(ref.watch(authRepositoryProvider));
  return (mode) async {
    var stage = 'session';
    try {
      final session = ref.read(navigationSessionProvider).session;
      if (session == null) throw StateError('Se necesita una sesión activa');
      if (mode != 2 && mode != 3) throw ArgumentError.value(mode);
      final previousMode =
          session.currentMode ?? ref.read(currentModeProvider) ?? 0;
      var revoked = false;
      if (mode == 2 && previousMode != mode) {
        // Cancelar la invitación pendiente no toca el perfil ni sus sesiones.
        // Si falla, se conserva el modo; no se informa un cambio incompleto.
        final invitations = ref.read(caregiverInviteRepositoryProvider);
        stage = 'cancel-invitations';
        await invitations.cancelAllInvites();
        revoked = true;
        if (ref.read(navigationSessionProvider).session?.uid != session.uid) {
          throw StateError('La sesión cambió durante el guardado');
        }
      }
      try {
        if (previousMode != mode) {
          stage = 'save-mode';
          await changeMode(
            uid: session.uid,
            currentMode: previousMode,
            mode: mode,
          );
        }
      } catch (_) {
        if (revoked &&
            ref.read(navigationSessionProvider).session?.uid == session.uid) {
          throw const UsageModeSaveAfterRevocationFailed();
        }
        rethrow;
      } finally {
        // La revocación no se deshace si falla el guardado posterior.
        if (revoked &&
            ref.read(navigationSessionProvider).session?.uid == session.uid) {
          ref.invalidate(caregiverLinkProvider);
        }
      }
      // Una respuesta de otra cuenta nunca actualiza la sesión actual.
      if (ref.read(navigationSessionProvider).session?.uid != session.uid) {
        throw StateError('La sesión cambió durante el guardado');
      }
      // El servidor ya confirmó el modo; una falla del perfil no lo revierte.
      ref.read(currentModeProvider.notifier).state = mode;
      ref.read(navigationSessionProvider.notifier).selectMode(mode);
      // Mantiene el UUID existente y prepara el perfil cuando falta en este
      // dispositivo, igual que la selección inicial del modo.
      try {
        stage = 'prepare-profile';
        await ref.read(getOrCreateCognitiveProfileProvider)(
          GetOrCreateCognitiveProfileParams(activeMode: mode),
        );
      } catch (_) {
        if (ref.read(navigationSessionProvider).session?.uid != session.uid) {
          rethrow;
        }
        ref.invalidate(activeProfileProvider);
        ref.invalidate(progressProvider);
        throw UsageModeProfilePending(mode);
      }
      if (ref.read(navigationSessionProvider).session?.uid != session.uid) {
        throw StateError('La sesión cambió durante el guardado');
      }
      stage = 'refresh-state';
      ref.invalidate(caregiverLinkProvider);
      ref.invalidate(activeProfileProvider);
      ref.invalidate(progressProvider);
    } catch (error) {
      // Diagnóstico de desarrollo sin identidad, UUID, métricas ni texto del error.
      if (kDebugMode) {
        debugPrint(
          '[AuroraCare] usage-mode stage=$stage type=${error.runtimeType}',
        );
      }
      rethrow;
    }
  };
});
