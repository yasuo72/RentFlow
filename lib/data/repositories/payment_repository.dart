import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../models/payment_model.dart';
import '../services/api_service.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    ref.watch(apiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

class PaymentRepository {
  PaymentRepository(this._apiService, this._preferences);

  final ApiService _apiService;
  final dynamic _preferences;

  List<PaymentModel>? readCachedPayments({
    String? month,
    String? status,
    String? roomId,
  }) {
    final cacheKey = _cacheKeyFor(
      month: month,
      status: status,
      roomId: roomId,
    );
    final cached = _preferences.getString(cacheKey);
    if (cached == null || cached.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<PaymentModel>> fetchPayments({
    String? month,
    String? status,
    String? roomId,
  }) async {
    try {
      final response = await _apiService.get(
        '/payments',
        queryParameters: {
          if (month != null) 'month': month,
          if (status != null && status != 'all') 'status': status,
          if (roomId != null && roomId.isNotEmpty) 'room': roomId,
        },
      );
      final payments = (response['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
      final cacheKey = _cacheKeyFor(
        month: month,
        status: status,
        roomId: roomId,
      );
      await _preferences.setString(
        cacheKey,
        jsonEncode(payments.map((payment) => payment.toJson()).toList()),
      );
      return payments;
    } on DioException {
      final cached = readCachedPayments(
        month: month,
        status: status,
        roomId: roomId,
      );
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingPayments() async {
    final response = await _apiService.get('/payments/pending');
    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<PaymentModel> fetchPayment(String id) async {
    final response = await _apiService.get('/payments/$id');
    return PaymentModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<PaymentModel> recordPayment(Map<String, dynamic> data) async {
    final response = await _apiService.post('/payments', data: data);
    return PaymentModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<PaymentModel> updatePayment(String id, Map<String, dynamic> data) async {
    final response = await _apiService.put('/payments/$id', data: data);
    return PaymentModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deletePayment(String id) async {
    await _apiService.delete('/payments/$id');
  }

  Future<Map<String, dynamic>> fetchMonthlySummary({
    required String month,
    required int year,
  }) async {
    final response = await _apiService.get(
      '/payments/summary/month',
      queryParameters: {'label': month, 'year': year},
    );
    return response['data'] as Map<String, dynamic>? ?? const {};
  }

  Future<Uint8List> downloadReceipt(String id) {
    return _apiService.getBytes('/payments/$id/receipt');
  }

  String _cacheKeyFor({
    String? month,
    String? status,
    String? roomId,
  }) {
    final safeMonth = (month ?? 'all_months').replaceAll(' ', '_');
    final safeStatus = (status == null || status.isEmpty) ? 'all' : status;
    final safeRoom = (roomId == null || roomId.isEmpty) ? 'all_rooms' : roomId;
    return '${AppStrings.paymentsCacheKey}|$safeMonth|$safeStatus|$safeRoom';
  }
}
