import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant_model.dart';
import '../../data/repositories/tenant_repository.dart';

final tenantsProvider =
    AsyncNotifierProvider<TenantsController, List<TenantModel>>(
      TenantsController.new,
    );

final tenantDetailProvider = FutureProvider.family<TenantModel, String>((
  ref,
  tenantId,
) async {
  return ref.read(tenantRepositoryProvider).fetchTenant(tenantId);
});

final inactiveTenantsProvider = FutureProvider<List<TenantModel>>((ref) async {
  return ref.read(tenantRepositoryProvider).fetchTenants(active: false);
});

class TenantsController extends AsyncNotifier<List<TenantModel>> {
  @override
  Future<List<TenantModel>> build() {
    return ref.read(tenantRepositoryProvider).fetchTenants();
  }

  Future<void> refresh({bool silent = false}) async {
    final previous = state.asData?.value;

    try {
      final fresh = await ref.read(tenantRepositoryProvider).fetchTenants();
      state = AsyncData(fresh);
      ref.invalidate(inactiveTenantsProvider);
    } catch (error, stackTrace) {
      if (!silent || previous == null) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}
