import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense_model.dart';
import '../services/api_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiServiceProvider));
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
  ExpenseRepository(this._apiService);

  final ApiService _apiService;

  Future<List<ExpenseModel>> fetchExpenses() async {
    final response = await _apiService.get('/expenses');
    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ExpenseModel.fromJson)
        .toList();
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
