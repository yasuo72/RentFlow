import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(
    ref.watch(apiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

class RoomRepository {
  RoomRepository(this._apiService, this._preferences);

  final ApiService _apiService;
  final dynamic _preferences;

  Future<List<RoomModel>> fetchRooms() async {
    try {
      final response = await _apiService.get('/rooms');
      final rooms = (response['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoomModel.fromJson)
          .toList();
      await _preferences.setString(
        AppStrings.roomsCacheKey,
        jsonEncode(rooms.map((room) => room.toJson()).toList()),
      );
      return rooms;
    } on DioException {
      final cached = _preferences.getString(AppStrings.roomsCacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(RoomModel.fromJson)
            .toList();
      }
      rethrow;
    }
  }

  Future<RoomModel> fetchRoom(String id) async {
    final response = await _apiService.get('/rooms/$id');
    return RoomModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<RoomModel> createRoom(Map<String, dynamic> data) async {
    final response = await _apiService.post('/rooms', data: data);
    return RoomModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<RoomModel> updateRoom(String id, Map<String, dynamic> data) async {
    final response = await _apiService.put('/rooms/$id', data: data);
    return RoomModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteRoom(String id) async {
    await _apiService.delete('/rooms/$id');
  }

  Future<void> uploadRoomPhotos(String id, List<String> photoPaths) async {
    if (photoPaths.isEmpty) {
      return;
    }

    final formData = FormData();
    for (final path in photoPaths) {
      formData.files.add(
        MapEntry(
          'photos',
          await MultipartFile.fromFile(path, filename: _fileName(path)),
        ),
      );
    }

    await _apiService.postMultipart('/rooms/$id/photos', data: formData);
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? 'upload.jpg' : segments.last;
  }
}
