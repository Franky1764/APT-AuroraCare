// domain/usecases/login_user.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import 'login_user.dart';

final loginUserProvider = Provider<LoginUser>((ref) {
  return LoginUser(ref.watch(authRepositoryProvider));
});