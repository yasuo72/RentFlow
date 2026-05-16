import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import 'payments_provider.dart';
import 'widgets/payment_card_widget.dart';
import 'widgets/pending_payment_tile.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsProvider);
    final pending = ref.watch(pendingPaymentsProvider);
    final filter = ref.watch(paymentsFilterProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/payments/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentsProvider);
          ref.invalidate(pendingPaymentsProvider);
        },
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
                        'PAYMENTS',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collections and receipts',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                AppIconButtonCard(
                  icon: Icons.add_card_rounded,
                  onTap: () => context.push('/payments/add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const ['all', 'paid', 'partial'])
                  ChoiceChip(
                    label: Text(status.toUpperCase()),
                    selected: filter.status == status,
                    onSelected: (_) {
                      ref.read(paymentsFilterProvider.notifier).update(
                        status: status,
                        month: AppDateUtils.currentMonthLabel(),
                      );
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: filter.status == status ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const AppSectionTitle(
              eyebrow: 'Pending / partial',
              title: 'Rooms needing follow-up',
            ),
            const SizedBox(height: 10),
            pending.when(
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    title: 'No pending rooms',
                    message: 'All current rooms are settled or not yet due.',
                    icon: Icons.check_circle_outline_rounded,
                  );
                }

                return Column(
                  children: items
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PendingPaymentTile(item: item),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            const AppSectionTitle(
              eyebrow: 'History',
              title: 'Recorded payments',
            ),
            const SizedBox(height: 10),
            payments.when(
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    title: 'No payments yet',
                    message: 'Recorded rent payments will appear here.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return Column(
                  children: items
                      .map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PaymentCardWidget(
                            payment: payment,
                            onTap: () => context.push('/payments/${payment.id}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AppEmptyState(
                title: 'Unable to load payments',
                message: '$error',
                icon: Icons.cloud_off_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
