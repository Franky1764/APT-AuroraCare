import '../entities/session_info.dart';

abstract class CaregiverAccountRepository {
  Future<SessionInfo> register({
    required String name,
    required String email,
    required String password,
  });
  Future<SessionInfo> login({required String email, required String password});
}
