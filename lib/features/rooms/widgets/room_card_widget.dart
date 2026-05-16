import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/room_model.dart';

class RoomCardWidget extends StatelessWidget {
  const RoomCardWidget({
    required this.room,
    required this.onTap,
    required this.onRecordPayment,
    super.key,
  });

  final RoomModel room;
  final VoidCallback onTap;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final paymentStatusColor = switch (room.currentMonthStatus) {
      'paid' => AppColors.accent,
      'partial' => AppColors.warning,
      'pending' => AppColors.danger,
      _ => Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
    };
    final occupancyColor = room.isOccupied
        ? AppColors.accent
        : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final statusLabel = switch (room.currentMonthStatus) {
      'paid' => 'PAID',
      'partial' => 'PARTIAL',
      'pending' => 'PENDING',
      _ => 'VACANT',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: paymentStatusColor,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(22),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.titleLarge,
                                children: [
                                  const TextSpan(text: 'Room '),
                                  TextSpan(
                                    text: room.roomNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 24),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              room.currentTenant?.fullName ?? 'Vacant | Available',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (room.currentTenant?.phone case final phone?)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  phone,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(
                            label: room.isOccupied ? 'OCCUPIED' : 'VACANT',
                            color: occupancyColor,
                          ),
                          const SizedBox(height: 8),
                          StatusBadge(
                            label: statusLabel,
                            color: paymentStatusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((room.floor ?? '').isNotEmpty)
                        _MetaPill(label: 'Floor ${room.floor}'),
                      _MetaPill(label: room.building ?? 'Main'),
                      _MetaPill(
                        label: CurrencyFormatter.inr(room.monthlyRent),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyFormatter.inr(room.monthlyRent),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              room.currentMonthStatus == 'partial'
                                  ? '${CurrencyFormatter.inr(room.currentMonthPayment?.remainingAmount ?? 0)} remaining'
                                  : room.currentMonthStatus == 'pending'
                                  ? 'Full month pending'
                                  : room.currentMonthStatus == 'paid'
                                  ? 'Payment settled'
                                  : 'No active tenant in this room',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: paymentStatusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (room.isOccupied && room.currentMonthStatus != 'paid')
                        ElevatedButton(
                          onPressed: onRecordPayment,
                          child: Text(
                            room.currentMonthStatus == 'partial'
                                ? 'Pay more'
                                : 'Record',
                          ),
                        ),
                    ],
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: resolvedColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
