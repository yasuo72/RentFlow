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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(tenantRepositoryProvider).fetchTenants(),
    );
    ref.invalidate(inactiveTenantsProvider);
  }
}
