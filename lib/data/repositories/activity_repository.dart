import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_stats_model.dart';
import '../services/api_service.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(apiServiceProvider));
});

class ActivityRepository {
  ActivityRepository(this._apiService);

  final ApiService _apiService;

  Future<List<ActivityLogItem>> fetchActivities({
    String? userId,
    String? action,
    int limit = 100,
  }) async {
    final response = await _apiService.get(
      '/dashboard/recent-activity',
      queryParameters: {
        'limit': limit,
        if (userId != null && userId.isNotEmpty) 'user': userId,
        if (action != null && action.isNotEmpty) 'action': action,
      },
    );

    return (response['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityLogItem.fromJson)
        .toList();
  }

  Future<void> deleteActivity(String id) async {
    await _apiService.delete('/dashboard/recent-activity/$id');
  }

  Future<int> deleteActivitiesByUser(String userId) async {
    final response = await _apiService.delete(
      '/dashboard/recent-activity/by-user/$userId',
    );

    return (response['data']?['deletedCount'] as num?)?.toInt() ?? 0;
  }
}
