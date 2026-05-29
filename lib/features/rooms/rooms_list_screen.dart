import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/room_model.dart';
import 'rooms_provider.dart';
import 'widgets/room_card_widget.dart';

class RoomsListScreen extends ConsumerStatefulWidget {
  const RoomsListScreen({this.initialFilter, super.key});

  final String? initialFilter;

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
  void initState() {
    super.initState();
    _filter = _normalizeFilter(widget.initialFilter);
  }

  @override
  void didUpdateWidget(covariant RoomsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _filter = _normalizeFilter(widget.initialFilter);
    }
  }

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
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(letterSpacing: 0.9),
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
                  if (_isSpecialFilter(_filter))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_specialFilterLabel(_filter)),
                        selected: true,
                        onSelected: (_) {},
                        selectedColor: AppColors.primary,
                        labelStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
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
                        labelStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: _filter == item.$1 ? Colors.white : null,
                              fontWeight: FontWeight.w700,
                            ),
                        backgroundColor: Theme.of(
                          context,
                        ).inputDecorationTheme.fillColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
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
                final filtered =
                    items.where((room) {
                      final monthThreshold = _pendingMonthFilterThreshold(
                        _filter,
                      );
                      final matchesFilter = monthThreshold != null
                          ? _isPendingByMonthThreshold(room, monthThreshold)
                          : switch (_filter) {
                              'all' => true,
                              'pending' =>
                                room.currentMonthStatus == 'pending' ||
                                    room.currentMonthStatus == 'partial',
                              'two_month_pending' => _isPendingByMonthThreshold(
                                room,
                                2,
                              ),
                              'low_deposit' =>
                                room.isOccupied &&
                                    room.depositAmount < room.monthlyRent,
                              'oldest_tenant' => room.isOccupied,
                              'missing_documents' =>
                                room.isOccupied &&
                                    (room.currentTenant?.documents.isEmpty ??
                                        true),
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
                    }).toList()..sort((a, b) {
                      if (_filter != 'oldest_tenant') {
                        return 0;
                      }
                      final left = a.currentTenant?.joiningDate;
                      final right = b.currentTenant?.joiningDate;
                      if (left == null && right == null) {
                        return a.roomNumber.compareTo(b.roomNumber);
                      }
                      if (left == null) {
                        return 1;
                      }
                      if (right == null) {
                        return -1;
                      }
                      return left.compareTo(right);
                    });

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

  String _normalizeFilter(String? filter) {
    if (_pendingMonthFilterThreshold(filter ?? '') != null) {
      return filter!;
    }

    return switch (filter) {
      'occupied' ||
      'vacant' ||
      'pending' ||
      'two_month_pending' ||
      'low_deposit' ||
      'oldest_tenant' ||
      'missing_documents' => filter!,
      _ => 'all',
    };
  }

  int? _pendingMonthFilterThreshold(String filter) {
    final match = RegExp(r'^months_pending_(\d+)$').firstMatch(filter);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  bool _isPendingByMonthThreshold(RoomModel room, int monthThreshold) {
    if (!room.isOccupied) {
      return false;
    }
    final threshold = monthThreshold.clamp(1, 12);
    final payment = room.currentMonthPayment;
    final remaining = payment?.remainingAmount ?? 0;
    final carried = payment?.carriedForwardAmount ?? 0;
    final rent = room.monthlyRent <= 0 ? 1 : room.monthlyRent;
    return remaining >= rent * threshold || carried >= rent * threshold;
  }

  bool _isSpecialFilter(String filter) {
    if (_pendingMonthFilterThreshold(filter) != null) {
      return true;
    }

    return switch (filter) {
      'two_month_pending' ||
      'low_deposit' ||
      'oldest_tenant' ||
      'missing_documents' => true,
      _ => false,
    };
  }

  String _specialFilterLabel(String filter) {
    final monthThreshold = _pendingMonthFilterThreshold(filter);
    if (monthThreshold != null) {
      return '$monthThreshold+ Months Pending';
    }

    return switch (filter) {
      'two_month_pending' => '2+ Months Pending',
      'low_deposit' => 'Low Deposit',
      'oldest_tenant' => 'Oldest Tenants',
      'missing_documents' => 'Missing Documents',
      _ => 'Filtered',
    };
  }
}
