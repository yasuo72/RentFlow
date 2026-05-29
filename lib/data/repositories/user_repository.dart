import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiServiceProvider));
});

class UserRepository {
  UserRepository(this._apiService);

  final ApiService _apiService;

  Future<List<UserModel>> fetchUsers() async {
    final response = await _apiService.get('/users');
    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserModel.fromJson)
        .toList();
  }

  Future<UserModel> createUser(Map<String, dynamic> data) async {
    final response = await _apiService.post('/users', data: data);
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    final response = await _apiService.put('/users/$id', data: data);
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deactivateUser(String id) async {
    await _apiService.delete('/users/$id');
  }

  Future<void> deleteUserPermanently(String id) async {
    await _apiService.delete(
      '/users/$id',
      queryParameters: {'permanent': 'true'},
    );
  }
}
