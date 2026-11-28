import '../entities/privacy_data.dart';

abstract class PrivacyRepository {
  Future<PrivacyData> readData();
  Future<void> correctName(String name);
  Future<void> withdrawConsent();
  Future<void> delete(PrivacyDeletion deletion, String password);
}
