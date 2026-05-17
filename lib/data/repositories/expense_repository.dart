import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../models/expense_model.dart';
import '../services/api_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(apiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

class ExpenseSummaryItem {
  const ExpenseSummaryItem({
    required this.category,
    required this.totalAmount,
    required this.count,
  });

  final String category;
  final num totalAmount;
  final int count;

  factory ExpenseSummaryItem.fromJson(Map<String, dynamic> json) {
    return ExpenseSummaryItem(
      category: (json['_id'] ?? 'other').toString(),
      totalAmount: json['totalAmount'] as num? ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExpenseRepository {
  ExpenseRepository(this._apiService, this._preferences);

  final ApiService _apiService;
  final dynamic _preferences;

  List<ExpenseModel>? readCachedExpenses() {
    final cached = _preferences.getString(AppStrings.expensesCacheKey);
    if (cached == null || cached.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ExpenseModel.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<ExpenseModel>> fetchExpenses() async {
    try {
      final response = await _apiService.get('/expenses');
      final expenses = (response['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExpenseModel.fromJson)
          .toList();
      await _preferences.setString(
        AppStrings.expensesCacheKey,
        jsonEncode(expenses.map((expense) => expense.toJson()).toList()),
      );
      return expenses;
    } on DioException {
      final cached = readCachedExpenses();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<ExpenseSummaryItem>> fetchSummary(DateTime month) async {
    final response = await _apiService.get(
      '/expenses/summary',
      queryParameters: {'month': DateTime(month.year, month.month).toIso8601String()},
    );

    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ExpenseSummaryItem.fromJson)
        .toList();
  }

  Future<ExpenseModel> addExpense(
    Map<String, dynamic> data, {
    String? billPhotoPath,
  }) async {
    final response = await _apiService.postMultipart(
      '/expenses',
      data: await _buildExpenseFormData(data, billPhotoPath: billPhotoPath),
    );
    return ExpenseModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<ExpenseModel> updateExpense(
    String id,
    Map<String, dynamic> data, {
    String? billPhotoPath,
  }) async {
    final response = await _apiService.putMultipart(
      '/expenses/$id',
      data: await _buildExpenseFormData(data, billPhotoPath: billPhotoPath),
    );
    return ExpenseModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String id) async {
    await _apiService.delete('/expenses/$id');
  }

  Future<FormData> _buildExpenseFormData(
    Map<String, dynamic> data, {
    String? billPhotoPath,
  }) async {
    final formData = FormData();

    data.forEach((key, value) {
      if (value == null) {
        return;
      }

      if (value is DateTime) {
        formData.fields.add(MapEntry(key, value.toIso8601String()));
      } else {
        formData.fields.add(MapEntry(key, value.toString()));
      }
    });

    if (billPhotoPath != null && billPhotoPath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'billPhoto',
          await MultipartFile.fromFile(
            billPhotoPath,
            filename: _fileName(billPhotoPath),
          ),
        ),
      );
    }

    return formData;
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? 'upload' : segments.last;
  }
}
