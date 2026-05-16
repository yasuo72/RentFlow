import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiServiceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

class AuthRepository {
  AuthRepository(this._apiService, this._storage);

  final ApiService _apiService;
  final SecureStorageService _storage;

  Future<({String token, UserModel user})> login({
    required String phone,
    required String password,
  }) async {
    final response = await _apiService.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'].toString();
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveToken(token);
    return (token: token, user: user);
  }

  Future<UserModel> getMe() async {
    final response = await _apiService.get('/auth/me');
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateFcmToken(String? token) async {
    await _apiService.put('/auth/me/fcm-token', data: {'fcmToken': token});
  }

  Future<void> logout() async {
    await _apiService.post('/auth/logout');
    await _storage.clearToken();
  }

  Future<String?> readSavedToken() => _storage.readToken();
}
