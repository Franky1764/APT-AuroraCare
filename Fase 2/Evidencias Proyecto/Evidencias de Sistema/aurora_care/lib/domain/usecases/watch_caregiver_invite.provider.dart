// domain/usecases/watch_caregiver_invite.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/caregiver_invite_repository.provider.dart';
import 'watch_caregiver_invite.dart';

final watchCaregiverInviteProvider = Provider<WatchCaregiverInvite>((ref) {
  return WatchCaregiverInvite(ref.watch(caregiverInviteRepositoryProvider));
});
