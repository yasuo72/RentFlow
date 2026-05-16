import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_strings.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

class SecureStorageService {
  const SecureStorageService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveToken(String token) {
    return _storage.write(key: AppStrings.authTokenKey, value: token);
  }

  Future<String?> readToken() {
    return _storage.read(key: AppStrings.authTokenKey);
  }

  Future<void> clearToken() {
    return _storage.delete(key: AppStrings.authTokenKey);
  }
}
