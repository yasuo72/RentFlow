import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../dashboard/dashboard_provider.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      () => ref.read(notificationSeenAtProvider.notifier).markAllSeen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final lastSeen = ref.watch(notificationSeenAtProvider);
    final dues = ref.watch(dashboardProvider).asData?.value.dues ?? const [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(dashboardProvider.notifier).refresh();
          await ref.read(notificationSeenAtProvider.notifier).markAllSeen();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Row(
              children: [
                AppIconButtonCard(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('notifications').toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tr('notificationsTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppHeaderPanel(
              title: unreadCount == 0
                  ? l10n.tr('allCaughtUp')
                  : l10n.tr(
                      'notificationsUnreadCount',
                      params: {'count': unreadCount.toString()},
                    ),
              subtitle: lastSeen == null
                  ? l10n.tr('notificationsSubtitle')
                  : l10n.tr(
                      'notificationsSeenAt',
                      params: {
                        'time': AppDateUtils.formatDateTime(lastSeen),
                      },
                    ),
              trailing: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (dues.isNotEmpty) ...[
              const SizedBox(height: 18),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionTitle(
                      eyebrow: l10n.tr('dueAttention'),
                      title: l10n.tr('roomsNeedAttention'),
                      subtitle: l10n.tr(
                        'notificationsDueSubtitle',
                        params: {'count': dues.length.toString()},
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...dues.take(3).map(
                      (due) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.warningDim,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Room ${due.roomNumber}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    due.tenantName,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              CurrencyFormatter.inr(due.pendingAmount),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.warning),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppSectionTitle(
              eyebrow: l10n.tr('recentAlerts'),
              title: l10n.tr('notificationsTitle'),
              subtitle: l10n.tr('notificationsListSubtitle'),
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              AppEmptyState(
                title: l10n.tr('noNotificationsYet'),
                message: l10n.tr('noNotificationsSubtitle'),
                icon: Icons.notifications_none_rounded,
              )
            else
              ...notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationTile(
                    notification: notification,
                    unread: lastSeen == null ||
                        notification.createdAt.isAfter(lastSeen),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.unread,
  });

  final InAppNotification notification;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AppSectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${notification.actor} - ${AppDateUtils.timeAgo(notification.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
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
