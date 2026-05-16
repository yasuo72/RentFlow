import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, DashboardBundle>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardBundle> {
  @override
  Future<DashboardBundle> build() {
    return ref.read(dashboardRepositoryProvider).fetchDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dashboardRepositoryProvider).fetchDashboard(),
    );
  }
}
