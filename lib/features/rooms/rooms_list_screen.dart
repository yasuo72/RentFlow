import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import 'rooms_provider.dart';
import 'widgets/room_card_widget.dart';

class RoomsListScreen extends ConsumerStatefulWidget {
  const RoomsListScreen({super.key});

  @override
  ConsumerState<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends ConsumerState<RoomsListScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rooms = ref.watch(roomsProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/rooms/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(roomsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROOMS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Occupancy and payment status',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                AppIconButtonCard(
                  icon: Icons.add_business_rounded,
                  onTap: () => context.push('/rooms/new'),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search room, tenant, or phone',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in const [
                    ('all', 'All'),
                    ('occupied', 'Occupied'),
                    ('vacant', 'Vacant'),
                    ('pending', 'Pending Due'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: _filter == item.$1,
                        onSelected: (_) => setState(() => _filter = item.$1),
                        selectedColor: AppColors.primary,
                        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _filter == item.$1 ? Colors.white : null,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Theme
                            .of(context)
                            .inputDecorationTheme
                            .fillColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        side: BorderSide(
                          color: _filter == item.$1
                              ? Colors.transparent
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            rooms.when(
              data: (items) {
                final filtered = items.where((room) {
                  final matchesFilter = switch (_filter) {
                    'all' => true,
                    'pending' =>
                      room.currentMonthStatus == 'pending' ||
                          room.currentMonthStatus == 'partial',
                    _ => room.status == _filter,
                  };

                  if (!matchesFilter) {
                    return false;
                  }

                  if (query.isEmpty) {
                    return true;
                  }

                  final haystack =
                      '${room.roomNumber} ${room.currentTenant?.fullName ?? ''} ${room.currentTenant?.phone ?? ''}'
                          .toLowerCase();

                  return haystack.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    title: 'No matching rooms',
                    message: 'Try another filter or add a new room.',
                    icon: Icons.meeting_room_outlined,
                  );
                }

                return Column(
                  children: filtered
                      .map(
                        (room) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RoomCardWidget(
                            room: room,
                            onTap: () => context.push('/rooms/${room.id}'),
                            onRecordPayment: () => context.push(
                              '/payments/add?roomId=${room.id}&tenantId=${room.currentTenant?.id ?? ''}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AppEmptyState(
                title: 'Unable to load rooms',
                message: '$error',
                icon: Icons.cloud_off_rounded,
                action: ElevatedButton(
                  onPressed: () => ref.read(roomsProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
