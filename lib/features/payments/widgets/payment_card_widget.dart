import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/payment_model.dart';

class PaymentCardWidget extends StatelessWidget {
  const PaymentCardWidget({
    required this.payment,
    required this.onTap,
    super.key,
  });

  final PaymentModel payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAdvance = payment.advanceAmount > 0;
    final statusColor = hasAdvance
        ? AppColors.info
        : payment.remainingAmount == 0
        ? AppColors.accent
        : AppColors.warning;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  payment.room?.roomNumber ?? '-',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: statusColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.tenant?.fullName ?? 'Tenant',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${payment.month} | ${AppDateUtils.formatDate(payment.paymentDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge(
                          label: payment.paymentMethod
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          color: AppColors.info,
                        ),
                        StatusBadge(
                          label: hasAdvance
                              ? 'ADV ${CurrencyFormatter.inr(payment.advanceAmount)}'
                              : payment.remainingAmount == 0
                              ? 'PAID'
                              : 'REM ${CurrencyFormatter.inr(payment.remainingAmount)}',
                          color: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.inr(payment.amountPaid),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    payment.recordedBy?.name ?? '-',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
