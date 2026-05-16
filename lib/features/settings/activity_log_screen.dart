import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_provider.dart';

final activityUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.read(userRepositoryProvider).fetchUsers();
});

final activityLogProvider =
    FutureProvider.family<List<ActivityLogItem>, ({String? userId, String? action})>(
      (ref, filter) async {
        return ref.read(activityRepositoryProvider).fetchActivities(
          userId: filter.userId,
          action: filter.action,
          limit: 150,
        );
      },
    );

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String? _selectedUserId;
  String? _selectedAction;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isSuperAdmin = auth.user?.isSuperAdmin ?? false;
    final usersAsync = ref.watch(activityUsersProvider);
    final logsAsync = ref.watch(
      activityLogProvider((userId: _selectedUserId, action: _selectedAction)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activityUsersProvider);
          ref.invalidate(
            activityLogProvider((userId: _selectedUserId, action: _selectedAction)),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppHeaderPanel(
              title: 'Full family timeline',
              subtitle:
                  'Track edits, payments, tenant updates, and admin changes in one place.',
            ),
            const SizedBox(height: 18),
            usersAsync.when(
              data: (users) => AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: 'Filters',
                      subtitle: 'Narrow the timeline by person or action type.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(labelText: 'User'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All users'),
                        ),
                        ...users.map(
                          (user) => DropdownMenuItem<String?>(
                            value: user.id,
                            child: Text(user.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _selectedUserId = value),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedAction,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All actions'),
                        ),
                        DropdownMenuItem(value: 'PAYMENT_ADDED', child: Text('Payments')),
                        DropdownMenuItem(value: 'TENANT_ADDED', child: Text('Tenants')),
                        DropdownMenuItem(value: 'ROOM_UPDATED', child: Text('Rooms')),
                        DropdownMenuItem(value: 'USER_UPDATED', child: Text('Users')),
                        DropdownMenuItem(value: 'EXPENSE_ADDED', child: Text('Expenses')),
                      ],
                      onChanged: (value) => setState(() => _selectedAction = value),
                    ),
                    if (isSuperAdmin && _selectedUserId != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _clearSelectedTimeline(context, ref),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Delete selected person timeline'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Unable to load filters: $error'),
            ),
            const SizedBox(height: 18),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const AppEmptyState(
                    title: 'No activity found',
                    message:
                        'Try clearing the filters or record a few actions in rooms, payments, or expenses first.',
                    icon: Icons.timeline_outlined,
                  );
                }

                return Column(
                  children: logs
                      .map(
                        (log) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppSectionCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _actionColor(log.action).withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _actionIcon(log.action),
                                    color: _actionColor(log.action),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              log.userName,
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                          ),
                                          StatusBadge(
                                            label: log.action.replaceAll('_', ' '),
                                            color: _actionColor(log.action),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(log.details),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppDateUtils.formatDateTime(log.createdAt),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSuperAdmin)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteLogEntry(context, ref, log);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete this entry'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Text('Unable to load activity log.\n$error'),
            ),
          ],
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.contains('PAYMENT')) return AppColors.accent;
    if (action.contains('DELETE')) return AppColors.danger;
    if (action.contains('EXPENSE')) return AppColors.warning;
    return AppColors.primaryLight;
  }

  IconData _actionIcon(String action) {
    if (action.contains('PAYMENT')) return Icons.payments_rounded;
    if (action.contains('TENANT')) return Icons.person_rounded;
    if (action.contains('ROOM')) return Icons.meeting_room_rounded;
    if (action.contains('USER')) return Icons.manage_accounts_rounded;
    if (action.contains('EXPENSE')) return Icons.receipt_long_rounded;
    return Icons.history_rounded;
  }

  Future<void> _deleteLogEntry(
    BuildContext context,
    WidgetRef ref,
    ActivityLogItem log,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete timeline entry'),
        content: const Text(
          'This removes only this activity message from the timeline. This cannot be undone.',
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
      await ref.read(activityRepositoryProvider).deleteActivity(log.id);
      _refreshLogs(ref);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timeline entry deleted.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete entry: $error')),
      );
    }
  }

  Future<void> _clearSelectedTimeline(BuildContext context, WidgetRef ref) async {
    final userId = _selectedUserId;
    if (userId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected person timeline'),
        content: const Text(
          'This removes all activity messages for the selected person from the timeline. The related data itself stays untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final deletedCount = await ref
          .read(activityRepositoryProvider)
          .deleteActivitiesByUser(userId);
      _refreshLogs(ref);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$deletedCount timeline entries deleted.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to clear timeline: $error')),
      );
    }
  }

  void _refreshLogs(WidgetRef ref) {
    ref.invalidate(activityUsersProvider);
    ref.invalidate(
      activityLogProvider((userId: _selectedUserId, action: _selectedAction)),
    );
    ref.invalidate(dashboardProvider);
  }
}
