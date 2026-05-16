import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/models/tenant_model.dart';
import 'tenants_provider.dart';
import 'widgets/tenant_card_widget.dart';

class TenantsListScreen extends ConsumerStatefulWidget {
  const TenantsListScreen({super.key});

  @override
  ConsumerState<TenantsListScreen> createState() => _TenantsListScreenState();
}

class _TenantsListScreenState extends ConsumerState<TenantsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTenants = ref.watch(tenantsProvider);
    final inactiveTenants = ref.watch(inactiveTenantsProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(tenantsProvider.notifier).refresh();
        },
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TENANTS',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Active and past residents',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      AppIconButtonCard(
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: () => context.push('/tenants/new'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search tenant, room, or phone',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Active'),
                        Tab(text: 'Past'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.66,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _TenantTab(
                          tenantsAsync: activeTenants,
                          query: query,
                          emptyTitle: 'No active tenants',
                          emptyMessage:
                              'Add the first tenant to start linking rooms and payments.',
                        ),
                        _TenantTab(
                          tenantsAsync: inactiveTenants,
                          query: query,
                          emptyTitle: 'No past tenants',
                          emptyMessage:
                              'When tenants are marked as left, their records stay here.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantTab extends StatelessWidget {
  const _TenantTab({
    required this.tenantsAsync,
    required this.query,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AsyncValue<List<TenantModel>> tenantsAsync;
  final String query;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return tenantsAsync.when(
      data: (items) {
        final filtered = items.where((tenant) {
          if (query.isEmpty) {
            return true;
          }

          final haystack =
              '${tenant.fullName} ${tenant.phone} ${tenant.room?.roomNumber ?? ''}'
                  .toLowerCase();
          return haystack.contains(query);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: AppEmptyState(
              title: emptyTitle,
              message: emptyMessage,
              icon: Icons.people_outline_rounded,
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final tenant = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TenantCardWidget(
                tenant: tenant,
                onTap: () => context.push('/tenants/${tenant.id}'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: AppEmptyState(
          title: 'Unable to load tenants',
          message: '$error',
          icon: Icons.cloud_off_rounded,
        ),
      ),
    );
  }
}
