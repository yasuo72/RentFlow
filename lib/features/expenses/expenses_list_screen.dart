import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../auth/auth_provider.dart';
import 'expenses_provider.dart';

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isSuperAdmin =
        ref.watch(authControllerProvider).user?.isSuperAdmin ?? false;
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expenses/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expensesProvider),
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
                        'EXPENSES',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track outgoing property costs',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                AppIconButtonCard(
                  icon: Icons.add_chart_rounded,
                  onTap: () => context.push('/expenses/add'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            expenses.when(
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    title: 'No expenses yet',
                    message: 'Electricity, repairs, and maintenance costs will show here.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return Column(
                  children: items.map((expense) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSectionCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.dangerDim,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.category.toUpperCase(),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppDateUtils.formatDate(expense.date),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if ((expense.description ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        expense.description!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.inr(expense.amount),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (isSuperAdmin)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteExpense(context, ref, expense.id);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AppEmptyState(
                title: 'Unable to load expenses',
                message: '$error',
                icon: Icons.cloud_off_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    String expenseId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense'),
        content: const Text(
          'This permanently removes the expense and its timeline entry. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(expensesProvider.notifier).deleteExpense(expenseId);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted permanently.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete expense: $error')),
      );
    }
  }
}
