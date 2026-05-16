import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/tenant_model.dart';

class TenantCardWidget extends StatelessWidget {
  const TenantCardWidget({
    required this.tenant,
    required this.onTap,
    super.key,
  });

  final TenantModel tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paid = tenant.currentMonthPayment?.amountPaid ?? 0;
    final remaining = tenant.currentMonthPayment?.remainingAmount ?? 0;
    final hasPayment = paid > 0 || remaining > 0;
    final statusColor = remaining > 0
        ? (paid > 0 ? AppColors.warning : AppColors.danger)
        : AppColors.accent;
    final statusText = !hasPayment
        ? 'No payment yet'
        : remaining > 0
        ? '${CurrencyFormatter.inr(remaining)} due'
        : 'Paid';
    final initials = tenant.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TenantAvatar(
                imageUrl: tenant.profilePhoto,
                initials: initials.isEmpty ? 'T' : initials,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tenant.phone,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge(
                          label: 'Room ${tenant.room?.roomNumber ?? '-'}',
                          color: AppColors.primary,
                        ),
                        StatusBadge(
                          label: 'Since ${tenant.joiningDate.year}',
                          color: AppColors.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
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

class _TenantAvatar extends StatelessWidget {
  const _TenantAvatar({
    required this.imageUrl,
    required this.initials,
  });

  final String? imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _InitialBox(initials: initials),
        ),
      );
    }

    return _InitialBox(initials: initials);
  }
}

class _InitialBox extends StatelessWidget {
  const _InitialBox({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryDim,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }
}
