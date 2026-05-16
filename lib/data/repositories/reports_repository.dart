import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_stats_model.dart';
import '../models/report_models.dart';
import 'expense_repository.dart';
import '../services/api_service.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    ref.watch(apiServiceProvider),
    ref.watch(expenseRepositoryProvider),
  );
});

class ReportsRepository {
  ReportsRepository(this._apiService, this._expenseRepository);

  final ApiService _apiService;
  final ExpenseRepository _expenseRepository;

  Future<ReportsBundle> fetchReports({
    required DateTime monthDate,
    required int year,
  }) async {
    final monthLabel = _monthLabel(monthDate);
    final monthlySummaryResponse = await _apiService.get(
      '/payments/summary/month',
      queryParameters: {'label': monthLabel, 'year': year},
    );
    final yearlyIncomeResponse = await _apiService.get(
      '/reports/yearly-income',
      queryParameters: {'year': year},
    );
    final dueReportResponse = await _apiService.get('/reports/due-report');
    final expenseSummary = await _expenseRepository.fetchSummary(monthDate);

    return ReportsBundle(
      monthlySummary: MonthlyCollectionSummary.fromJson(
        monthlySummaryResponse['data'] as Map<String, dynamic>? ?? const {},
      ),
      yearlyIncome: (yearlyIncomeResponse['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MonthlyCollectionPoint.fromJson)
          .toList(),
      dueReport: ((dueReportResponse['data'] as Map<String, dynamic>?)?['dues'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DueReportItem.fromJson)
          .toList(),
      expenseSummary: expenseSummary,
    );
  }

  Future<Uint8List> downloadMonthlyCollectionPdf(DateTime monthDate) {
    final label = _monthLabel(monthDate);
    return _apiService.getBytes(
      '/reports/monthly-collection',
      queryParameters: {
        'month': DateTime(monthDate.year, monthDate.month).toIso8601String(),
        'label': label,
        'year': monthDate.year,
      },
    );
  }

  String _monthLabel(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[date.month - 1]} ${date.year}';
  }
}
