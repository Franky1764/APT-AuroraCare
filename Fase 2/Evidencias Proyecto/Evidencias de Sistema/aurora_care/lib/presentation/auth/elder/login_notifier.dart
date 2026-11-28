// presentation/auth/elder/login_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/login_user.dart';
import '../../../domain/usecases/login_user.provider.dart';

class LoginNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false; // false = aún no se ha iniciado sesión

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    final loginUser = ref.read(loginUserProvider);
    state = await AsyncValue.guard(() async {
      await loginUser(LoginUserParams(email: email, password: password));
      return true; // true = login exitoso
    });
  }
}

final loginNotifierProvider = AsyncNotifierProvider<LoginNotifier, bool>(
  LoginNotifier.new,
);
