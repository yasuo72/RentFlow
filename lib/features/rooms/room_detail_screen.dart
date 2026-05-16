import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import 'rooms_provider.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomDetailProvider(roomId));

    return Scaffold(
      body: room.when(
        data: (item) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text('Room ${item.roomNumber}'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/rooms/new?roomId=${item.id}'),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Monthly rent: ${CurrencyFormatter.inr(item.monthlyRent)}',
                          ),
                          Text(
                            'Deposit: ${CurrencyFormatter.inr(item.depositAmount)}',
                          ),
                          Text('Floor: ${item.floor ?? '-'}'),
                          Text('Building: ${item.building ?? 'Main'}'),
                          Text('Meter: ${item.electricityMeterNumber ?? '-'}'),
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(item.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: Text(item.currentTenant?.fullName ?? 'Vacant'),
                      subtitle: Text(
                        item.currentTenant?.phone ?? 'No active tenant',
                      ),
                      trailing: item.currentTenant != null
                          ? const Icon(Icons.chevron_right_rounded)
                          : null,
                      onTap: item.currentTenant == null
                          ? null
                          : () => context.push(
                              '/tenants/${item.currentTenant!.id}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "This month's payment",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Paid: ${CurrencyFormatter.inr(item.currentMonthPayment?.amountPaid ?? 0)}',
                          ),
                          Text(
                            'Remaining: ${CurrencyFormatter.inr(item.currentMonthPayment?.remainingAmount ?? item.monthlyRent)}',
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: item.currentTenant == null
                                  ? null
                                  : () => context.push(
                                      '/payments/add?roomId=${item.id}&tenantId=${item.currentTenant!.id}',
                                    ),
                              child: const Text('Record payment'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment history',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          if (item.paymentHistory.isEmpty)
                            const Text('No payments recorded yet.')
                          else
                            ...item.paymentHistory.map(
                              (history) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(history.month),
                                subtitle: Text(
                                  'Paid ${CurrencyFormatter.inr(history.amountPaid)} · Remaining ${CurrencyFormatter.inr(history.remainingAmount)}',
                                ),
                                trailing: Text(history.recordedByName ?? '-'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Synced live with all family members · ${AppDateUtils.currentMonthLabel()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load room\n$error')),
      ),
    );
  }
}
