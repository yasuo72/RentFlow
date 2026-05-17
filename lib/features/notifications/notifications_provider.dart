import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../dashboard/dashboard_provider.dart';

final notificationsProvider = Provider<List<InAppNotification>>((ref) {
  final bundle = ref.watch(dashboardProvider).asData?.value;
  if (bundle == null) {
    return const [];
  }

  final items = bundle.activity
      .map(InAppNotification.fromActivity)
      .toList(growable: false);

  items.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return items;
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final seenAt = ref.watch(notificationSeenAtProvider);
  final notifications = ref.watch(notificationsProvider);

  if (seenAt == null) {
    return notifications.length;
  }

  return notifications
      .where((notification) => notification.createdAt.isAfter(seenAt))
      .length;
});

final notificationSeenAtProvider =
    NotifierProvider<NotificationSeenAtController, DateTime?>(
      NotificationSeenAtController.new,
    );

class NotificationSeenAtController extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(AppStrings.notificationLastSeenKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markAllSeen() async {
    final seenAt = DateTime.now();
    state = seenAt;
    await ref
        .read(sharedPreferencesProvider)
        .setString(AppStrings.notificationLastSeenKey, seenAt.toIso8601String());
  }
}

enum InAppNotificationType {
  payment,
  tenant,
  room,
  expense,
  general,
}

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.actor,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String title;
  final String message;
  final String actor;
  final DateTime createdAt;
  final InAppNotificationType type;

  factory InAppNotification.fromActivity(ActivityLogItem item) {
    final action = item.action.toUpperCase();

    InAppNotificationType type;
    String title;

    if (action.contains('PAYMENT')) {
      type = InAppNotificationType.payment;
      title = 'Payment update';
    } else if (action.contains('TENANT')) {
      type = InAppNotificationType.tenant;
      title = 'Tenant update';
    } else if (action.contains('ROOM')) {
      type = InAppNotificationType.room;
      title = 'Room update';
    } else if (action.contains('EXPENSE')) {
      type = InAppNotificationType.expense;
      title = 'Expense update';
    } else {
      type = InAppNotificationType.general;
      title = 'Family update';
    }

    return InAppNotification(
      id: item.id,
      title: title,
      message: item.details.isNotEmpty ? item.details : _fallbackMessage(action),
      actor: item.userName,
      createdAt: item.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      type: type,
    );
  }

  IconData get icon {
    return switch (type) {
      InAppNotificationType.payment => Icons.payments_rounded,
      InAppNotificationType.tenant => Icons.people_alt_rounded,
      InAppNotificationType.room => Icons.home_work_rounded,
      InAppNotificationType.expense => Icons.receipt_long_rounded,
      InAppNotificationType.general => Icons.notifications_active_rounded,
    };
  }

  Color get color {
    return switch (type) {
      InAppNotificationType.payment => AppColors.accent,
      InAppNotificationType.tenant => AppColors.info,
      InAppNotificationType.room => AppColors.primary,
      InAppNotificationType.expense => AppColors.warning,
      InAppNotificationType.general => AppColors.primary,
    };
  }

  static String _fallbackMessage(String action) {
    return action
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0]}${segment.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
