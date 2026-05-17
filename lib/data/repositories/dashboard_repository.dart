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

  DashboardBundle? readCachedDashboard() {
    final cached = _preferences.getString(AppStrings.dashboardCacheKey);
    if (cached == null || cached.isEmpty) {
      return null;
    }

    try {
      return DashboardBundle.decode(cached);
    } catch (_) {
      return null;
    }
  }

  Future<DashboardBundle> fetchDashboard() async {
    try {
      final responses = await Future.wait<Map<String, dynamic>>([
        _apiService.get('/dashboard/stats'),
        _apiService.get('/dashboard/monthly-chart'),
        _apiService.get('/dashboard/payment-calendar'),
        _apiService.get('/dashboard/recent-activity'),
        _apiService.get('/dashboard/upcoming-dues'),
      ]);

      final statsResponse = responses[0];
      final chartResponse = responses[1];
      final calendarResponse = responses[2];
      final activityResponse = responses[3];
      final dueResponse = responses[4];

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
      final cached = readCachedDashboard();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
