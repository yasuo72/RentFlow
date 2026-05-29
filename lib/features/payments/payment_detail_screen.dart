import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/repositories/payment_repository.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../rooms/rooms_provider.dart';
import '../tenants/tenants_provider.dart';
import 'payment_share_service.dart';
import 'payments_provider.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin =
        ref.watch(authControllerProvider).user?.isSuperAdmin ?? false;
    final payment = ref.watch(paymentDetailProvider(paymentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Detail'),
        actions: [
          if (isSuperAdmin)
            IconButton(
              onPressed: () => _deletePayment(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: payment.when(
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.receiptNumber,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Room',
                    value: 'Room ${item.room?.roomNumber ?? '-'}',
                  ),
                  _DetailRow(
                    label: 'Tenant',
                    value: item.tenant?.fullName ?? '-',
                  ),
                  _DetailRow(label: 'Month', value: item.month),
                  _DetailRow(
                    label: 'Carried forward',
                    value: CurrencyFormatter.inr(item.carriedForwardAmount),
                  ),
                  _DetailRow(
                    label: 'Manual extra due',
                    value: CurrencyFormatter.inr(item.manualDueAmount),
                  ),
                  if ((item.manualDueRemark ?? '').isNotEmpty)
                    _DetailRow(
                      label: 'Manual due reason',
                      value: item.manualDueRemark!,
                    ),
                  _DetailRow(
                    label: 'Total due',
                    value: CurrencyFormatter.inr(item.totalDue),
                  ),
                  _DetailRow(
                    label: 'Paid so far',
                    value: CurrencyFormatter.inr(item.amountPaid),
                  ),
                  _DetailRow(
                    label: 'Remaining',
                    value: CurrencyFormatter.inr(item.remainingAmount),
                  ),
                  _DetailRow(
                    label: 'Advance / extra paid',
                    value: CurrencyFormatter.inr(item.advanceAmount),
                  ),
                  _DetailRow(
                    label: 'Latest method',
                    value: item.paymentMethod.toUpperCase(),
                  ),
                  _DetailRow(
                    label: 'Latest date',
                    value: AppDateUtils.formatDateTime(item.paymentDate),
                  ),
                  _DetailRow(
                    label: 'Recorded by',
                    value: item.recordedBy?.name ?? '-',
                  ),
                  if (item.remark != null && item.remark!.isNotEmpty)
                    _DetailRow(label: 'Remark', value: item.remark!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    eyebrow: 'WhatsApp sharing',
                    title: 'Receipt and payment QR',
                    subtitle:
                        'Send a formatted rent receipt, or share the receipt with the QR image/PDF.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _shareSafely(
                      context,
                      () => PaymentShareService.shareWhatsAppText(item),
                    ),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp receipt'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _shareSafely(
                      context,
                      () => PaymentShareService.shareReceiptWithQr(item),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Share receipt + QR image'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _shareSafely(
                      context,
                      () => PaymentShareService.shareReceiptPdfWithQr(
                        payment: item,
                        loadPdf: () => ref
                            .read(paymentRepositoryProvider)
                            .downloadReceipt(item.id),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Share PDF receipt + QR'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionTitle(
                    title: 'Installments',
                    subtitle:
                        'Every partial payment recorded under this month stays here.',
                  ),
                  const SizedBox(height: 14),
                  if (item.entries.isEmpty)
                    const Text('No installment history available.')
                  else
                    ...item.entries.asMap().entries.map((entry) {
                      final installment = entry.value;

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: entry.key == item.entries.length - 1 ? 0 : 12,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${entry.key + 1}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    CurrencyFormatter.inr(
                                      installment.amountPaid,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${installment.paymentMethod.toUpperCase()} | ${installment.recordedBy?.name ?? '-'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppDateUtils.formatDateTime(
                                      installment.paymentDate,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if ((installment.remark ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      installment.remark!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load payment\n$error')),
      ),
    );
  }

  Future<void> _shareSafely(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share receipt: $error')),
      );
    }
  }

  Future<void> _deletePayment(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment'),
        content: const Text(
          'This permanently removes the payment and its timeline record. This cannot be undone.',
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
      await ref.read(paymentRepositoryProvider).deletePayment(paymentId);
      ref.invalidate(paymentsProvider);
      ref.invalidate(paymentDetailProvider(paymentId));
      ref.invalidate(pendingPaymentsProvider);
      ref.invalidate(roomsProvider);
      ref.invalidate(tenantsProvider);
      ref.invalidate(dashboardProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted permanently.')),
      );
      context.pop();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete payment: $error')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
