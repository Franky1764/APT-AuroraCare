// domain/usecases/create_caregiver_invite.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/caregiver_invite_repository.provider.dart';
import 'create_caregiver_invite.dart';

final createCaregiverInviteProvider = Provider<CreateCaregiverInvite>((ref) {
  return CreateCaregiverInvite(ref.watch(caregiverInviteRepositoryProvider));
});
