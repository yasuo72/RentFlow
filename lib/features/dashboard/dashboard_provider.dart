import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard_stats_model.dart';
import '../../data/repositories/dashboard_repository.dart';

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, DashboardBundle>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardBundle> {
  @override
  Future<DashboardBundle> build() async {
    final repository = ref.read(dashboardRepositoryProvider);
    final cached = repository.readCachedDashboard();

    if (cached != null) {
      Future.microtask(() => refresh(silent: true));
      return cached;
    }

    return repository.fetchDashboard();
  }

  Future<void> refresh({bool silent = false}) async {
    final previous = state.asData?.value;

    try {
      final fresh = await ref.read(dashboardRepositoryProvider).fetchDashboard();
      state = AsyncData(fresh);
    } catch (error, stackTrace) {
      if (!silent || previous == null) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}
