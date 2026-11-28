// domain/repositories/caregiver_invite_repository.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_invite_repository.dart';

/// Placeholder de inyección de dependencias: la implementación real
/// (Firestore) se agrega en data/ en un paso posterior y sobreescribe
/// este provider. Mismo patrón que sharedPreferencesProvider en
/// core/firebase_providers.dart — mientras no se sobreescriba, resolverlo
/// lanza un error claro en vez de fallar en silencio.
final caregiverInviteRepositoryProvider =
    Provider<CaregiverInviteRepository>((ref) {
      throw UnimplementedError(
        'caregiverInviteRepositoryProvider debe sobreescribirse con la '
        'implementación real (data/) — todavía no existe.',
      );
    });
