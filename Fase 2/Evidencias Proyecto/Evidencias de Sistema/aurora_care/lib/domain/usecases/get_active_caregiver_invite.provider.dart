// domain/usecases/get_active_caregiver_invite.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/caregiver_invite_repository.provider.dart';
import 'get_active_caregiver_invite.dart';

final getActiveCaregiverInviteProvider =
    Provider<GetActiveCaregiverInvite>((ref) {
      return GetActiveCaregiverInvite(
        ref.watch(caregiverInviteRepositoryProvider),
      );
    });
