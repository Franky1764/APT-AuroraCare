// lib/presentation/profile/caregiver_link_notifier.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/caregiver_invite.dart';
import '../../domain/repositories/caregiver_invite_repository.provider.dart';
import '../../domain/entities/invite_status.dart';
import '../../domain/usecases/cancel_caregiver_invite.dart';
import '../../domain/usecases/cancel_caregiver_invite.provider.dart';
import '../../domain/usecases/create_caregiver_invite.provider.dart';
import '../../domain/usecases/get_active_caregiver_invite.provider.dart';
import '../../domain/usecases/usecase.dart';
import '../../domain/usecases/watch_caregiver_invite.dart';
import '../../domain/usecases/watch_caregiver_invite.provider.dart';

/// Estado visible de la pantalla de vínculo con cuidador (F8). El
/// vencimiento y el uso único siempre los decide el servidor; esto solo
/// refleja lo que getActiveInvite/watchInvite ya informan.
enum CaregiverLinkViewStatus {
  /// Todavía no hay invitación (o se canceló/venció y no se generó otra).
  none,

  /// Invitación vigente: se muestra el QR y la cuenta regresiva.
  active,

  /// Pasó el vencimiento sin que nadie la usara.
  expired,

  /// Un cuidador la escaneó y se vinculó.
  redeemed,
}

class CaregiverLinkState {
  const CaregiverLinkState({required this.status, this.invite});

  final CaregiverLinkViewStatus status;

  /// La invitación que originó este estado. null en "none".
  final CaregiverInvite? invite;
}

class CaregiverLinkNotifier
    extends AutoDisposeAsyncNotifier<CaregiverLinkState> {
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;

  @override
  Future<CaregiverLinkState> build() async {
    _generation++;
    ref.onDispose(() {
      _generation++;
      _subscription?.cancel();
    });

    final repository = ref.watch(caregiverInviteRepositoryProvider);
    final getActiveInvite = ref.watch(getActiveCaregiverInviteProvider);
    final invite = await getActiveInvite(const NoParams());
    if (invite == null) {
      final connected = await repository.watchConnection().first;
      if (connected) _escucharVinculo(repository.watchConnection());
      return CaregiverLinkState(
        status: connected
            ? CaregiverLinkViewStatus.redeemed
            : CaregiverLinkViewStatus.none,
      );
    }

    // getActiveInvite() ya filtra las invitaciones vencidas (eso lo
    // decide el servidor, nunca el cliente): si llegó una invitación
    // no-nula, es porque todavía está vigente.
    _escuchar(invite.token);
    return CaregiverLinkState(
      status: CaregiverLinkViewStatus.active,
      invite: invite,
    );
  }

  void _escuchar(String token) {
    _subscription?.cancel();
    final generation = ++_generation;
    final watchInvite = ref.read(watchCaregiverInviteProvider);
    _subscription = watchInvite(WatchCaregiverInviteParams(token: token))
        .listen(
          (status) {
            if (generation != _generation) return;
            final invite = state.valueOrNull?.invite;
            final nuevoEstado = switch (status) {
              InviteStatus.active => CaregiverLinkViewStatus.active,
              InviteStatus.expired => CaregiverLinkViewStatus.expired,
              InviteStatus.redeemed => CaregiverLinkViewStatus.redeemed,
            };
            state = AsyncData(
              CaregiverLinkState(status: nuevoEstado, invite: invite),
            );
          },
          onError: (Object error, StackTrace stack) {
            if (generation != _generation) return;
            state = AsyncError(error, stack);
          },
        );
  }

  void _escucharVinculo(Stream<bool> connection) {
    _subscription?.cancel();
    final generation = ++_generation;
    _subscription = connection.listen(
      (connected) {
        if (generation != _generation) return;
        state = AsyncData(
          CaregiverLinkState(
            status: connected
                ? CaregiverLinkViewStatus.redeemed
                : CaregiverLinkViewStatus.none,
          ),
        );
      },
      onError: (Object error, StackTrace stack) {
        if (generation == _generation) state = AsyncError(error, stack);
      },
    );
  }

  /// Genera una invitación nueva. El consentimiento ya se pidió en la
  /// pantalla antes de llamar a esto.
  Future<void> generar() async {
    state = const AsyncLoading();
    final createInvite = ref.read(createCaregiverInviteProvider);
    state = await AsyncValue.guard(() async {
      final invite = await createInvite(const NoParams());
      _escuchar(invite.token);
      return CaregiverLinkState(
        status: CaregiverLinkViewStatus.active,
        invite: invite,
      );
    });
  }

  /// El adulto mayor cancela la invitación activa antes de que venza.
  Future<void> cancelar() async {
    final token = state.valueOrNull?.invite?.token;
    if (token == null) return;
    // Se deja de escuchar ANTES de pedirle al repositorio que cancele:
    // cancelInvite() dispara su propio evento "expired" en watchInvite
    // para quien siga mirando ese token, y eso pisaría el "none" que se
    // devuelve a continuación si todavía estuviéramos suscritos.
    _generation++;
    _subscription?.cancel();
    _subscription = null;

    state = const AsyncLoading();
    final cancelInvite = ref.read(cancelCaregiverInviteProvider);
    state = await AsyncValue.guard(() async {
      await cancelInvite(CancelCaregiverInviteParams(token: token));
      return const CaregiverLinkState(status: CaregiverLinkViewStatus.none);
    });
  }

  Future<void> desvincular() async {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(caregiverInviteRepositoryProvider).cancelAllInvites();
      return const CaregiverLinkState(status: CaregiverLinkViewStatus.none);
    });
  }
}

final caregiverLinkProvider =
    AsyncNotifierProvider.autoDispose<
      CaregiverLinkNotifier,
      CaregiverLinkState
    >(CaregiverLinkNotifier.new);
