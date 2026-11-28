// presentation/auth/elder/register_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/register_user.dart';
import '../../../domain/usecases/register_user.provider.dart';

class RegisterNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false; // false = aún no se ha registrado

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final registerUser = ref.read(registerUserProvider);
    state = await AsyncValue.guard(() async {
      await registerUser(
        RegisterUserParams(
          displayName: displayName,
          email: email,
          password: password,
        ),
      );
      return true; // true = registro exitoso
    });
  }
}

final registerNotifierProvider = AsyncNotifierProvider<RegisterNotifier, bool>(
  RegisterNotifier.new,
);
