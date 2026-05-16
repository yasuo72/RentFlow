import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../models/dashboard_stats_model.dart';
import '../services/api_service.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(apiServiceProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

class DashboardRepository {
  DashboardRepository(this._apiService, this._preferences);

  final ApiService _apiService;
  final dynamic _preferences;

  Future<DashboardBundle> fetchDashboard() async {
    try {
      final statsResponse = await _apiService.get('/dashboard/stats');
      final chartResponse = await _apiService.get('/dashboard/monthly-chart');
      final calendarResponse = await _apiService.get('/dashboard/payment-calendar');
      final activityResponse = await _apiService.get(
        '/dashboard/recent-activity',
      );
      final dueResponse = await _apiService.get('/dashboard/upcoming-dues');

      final bundle = DashboardBundle(
        stats: DashboardStatsModel.fromJson(
          statsResponse['data'] as Map<String, dynamic>,
        ),
        chart: (chartResponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MonthlyCollectionPoint.fromJson)
            .toList(),
        calendarEvents:
            (calendarResponse['data'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(PaymentCalendarEvent.fromJson)
                .toList(),
        activity: (activityResponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActivityLogItem.fromJson)
            .toList(),
        dues: (dueResponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DueAlert.fromJson)
            .toList(),
      );

      await _preferences.setString(
        AppStrings.dashboardCacheKey,
        bundle.encode(),
      );

      return bundle;
    } on DioException {
      final cached = _preferences.getString(AppStrings.dashboardCacheKey);
      if (cached != null) {
        return DashboardBundle.decode(cached);
      }
      rethrow;
    }
  }
}
