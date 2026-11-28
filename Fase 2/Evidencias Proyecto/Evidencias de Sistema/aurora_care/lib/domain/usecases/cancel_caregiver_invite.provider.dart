// domain/usecases/cancel_caregiver_invite.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/caregiver_invite_repository.provider.dart';
import 'cancel_caregiver_invite.dart';

final cancelCaregiverInviteProvider = Provider<CancelCaregiverInvite>((ref) {
  return CancelCaregiverInvite(ref.watch(caregiverInviteRepositoryProvider));
});
