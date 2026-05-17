import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/dashboard_stats_model.dart';

class ActivityFeedWidget extends StatelessWidget {
  const ActivityFeedWidget({required this.items, super.key});

  final List<ActivityLogItem> items;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            eyebrow: 'Recent activity',
            title: 'Family updates',
            subtitle: 'Latest rent, tenant, and room actions',
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('No activity yet.')
          else
            ...items.take(8).map((item) {
              final initial = item.userName.trim().isEmpty
                  ? 'F'
                  : item.userName.trim().characters.first.toUpperCase();

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDim,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.details.isNotEmpty
                                ? item.details
                                : item.action,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.35),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.userName} - ${AppDateUtils.timeAgo(item.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
