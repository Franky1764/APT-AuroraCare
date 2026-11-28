import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/caregiver_invite.dart';
import '../../../domain/repositories/caregiver_invite_repository.provider.dart';

class CaregiverInviteScanController extends AutoDisposeAsyncNotifier<bool> {
  bool _disposed = false;
  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  Future<void> scan(String raw) async {
    if (state.isLoading || state.valueOrNull == true) return;
    final token = CaregiverInvite.parseQr(raw);
    if (token == null) {
      state = AsyncError(StateError('invalid-code'), StackTrace.current);
      return;
    }
    final repository = ref.read(caregiverInviteRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.redeemInvite(token);
      if (!_disposed) state = const AsyncData(true);
    } catch (error, stack) {
      if (!_disposed) state = AsyncError(error, stack);
    }
  }

  void retry() {
    if (!state.isLoading) state = const AsyncData(false);
  }
}

final caregiverInviteScanProvider =
    AsyncNotifierProvider.autoDispose<CaregiverInviteScanController, bool>(
      CaregiverInviteScanController.new,
    );
