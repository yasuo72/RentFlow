import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant_model.dart';
import '../services/api_service.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository(ref.watch(apiServiceProvider));
});

class TenantRepository {
  TenantRepository(this._apiService);

  final ApiService _apiService;

  Future<List<TenantModel>> fetchTenants({bool active = true}) async {
    final response = await _apiService.get(
      active ? '/tenants' : '/tenants/inactive',
    );
    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TenantModel.fromJson)
        .toList();
  }

  Future<TenantModel> fetchTenant(String id) async {
    final response = await _apiService.get('/tenants/$id');
    return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<TenantModel> createTenant(
    Map<String, dynamic> data, {
    String? profilePhotoPath,
    List<({String path, String type})> documents = const [],
  }) async {
    final formData = await _buildTenantFormData(
      data,
      profilePhotoPath: profilePhotoPath,
      documents: documents,
    );
    final response = await _apiService.postMultipart(
      '/tenants',
      data: formData,
    );
    return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<TenantModel> updateTenant(
    String id,
    Map<String, dynamic> data, {
    String? profilePhotoPath,
    List<({String path, String type})> documents = const [],
  }) async {
    final formData = await _buildTenantFormData(
      data,
      profilePhotoPath: profilePhotoPath,
      documents: documents,
    );
    final response = await _apiService.putMultipart(
      '/tenants/$id',
      data: formData,
    );
    return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> markTenantLeft(String id, {DateTime? leavingDate}) async {
    await _apiService.delete(
      '/tenants/$id',
      data: {
        if (leavingDate != null) 'leavingDate': leavingDate.toIso8601String(),
      },
    );
  }

  Future<void> purgeTenant(String id) async {
    await _apiService.delete('/tenants/$id/permanent');
  }

  Future<TenantModel> uploadTenantDocuments(
    String id,
    List<({String path, String type})> documents,
  ) async {
    final formData = FormData();

    for (final document in documents) {
      formData.files.add(
        MapEntry(
          'documents',
          await MultipartFile.fromFile(
            document.path,
            filename: _fileName(document.path),
          ),
        ),
      );
      formData.fields.add(MapEntry('types', document.type));
    }

    final response = await _apiService.postMultipart(
      '/tenants/$id/documents',
      data: formData,
    );
    return TenantModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<FormData> _buildTenantFormData(
    Map<String, dynamic> data, {
    String? profilePhotoPath,
    List<({String path, String type})> documents = const [],
  }) async {
    final formData = FormData();

    data.forEach((key, value) {
      if (value == null) {
        return;
      }

      if (value is DateTime) {
        formData.fields.add(MapEntry(key, value.toIso8601String()));
        return;
      }

      formData.fields.add(MapEntry(key, value.toString()));
    });

    if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'profilePhoto',
          await MultipartFile.fromFile(
            profilePhotoPath,
            filename: _fileName(profilePhotoPath),
          ),
        ),
      );
    }

    for (final document in documents) {
      formData.files.add(
        MapEntry(
          'documents',
          await MultipartFile.fromFile(
            document.path,
            filename: _fileName(document.path),
          ),
        ),
      );
      formData.fields.add(MapEntry('documentTypes', document.type));
    }

    return formData;
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? 'upload' : segments.last;
  }
}
