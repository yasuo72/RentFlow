import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/room_model.dart';
import '../auth/auth_provider.dart';
import '../rooms/rooms_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/activity_feed_widget.dart';
import 'widgets/collection_chart_widget.dart';
import 'widgets/due_alerts_widget.dart';
import 'widgets/payment_calendar_widget.dart';
import '../payments/widgets/payment_qr_card.dart';
import 'widgets/stat_card_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboard = ref.watch(dashboardProvider);
    final auth = ref.watch(authControllerProvider);
    final rooms = ref.watch(roomsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardProvider.notifier).refresh();
        await ref.read(roomsProvider.notifier).refresh();
      },
      child: dashboard.when(
        data: (bundle) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            _DashboardHeader(
              userName: auth.user?.name ?? 'Family',
              onReportsTap: () => context.push('/reports'),
              onPeopleTap: () => context.push('/tenants'),
            ),
            const SizedBox(height: 18),
            _MonthlyOverviewCard(stats: bundle.stats),
            const SizedBox(height: 12),
            PaymentQrCard(
              compact: true,
              onOpen: () => context.push('/payment-qr'),
            ),
            const SizedBox(height: 12),
            _StatsGrid(stats: bundle.stats),
            const SizedBox(height: 20),
            CollectionChartWidget(points: bundle.chart),
            const SizedBox(height: 20),
            PaymentCalendarWidget(events: bundle.calendarEvents),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tr('roomStatus'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => StatefulNavigationShell.of(context).goBranch(1),
                  child: Text(l10n.tr('viewAll')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RoomsQuickRow(rooms: rooms),
            const SizedBox(height: 20),
            DueAlertsWidget(dues: bundle.dues),
            const SizedBox(height: 20),
            ActivityFeedWidget(items: bundle.activity),
          ],
        ),
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Shimmer.fromColors(
                baseColor: Theme.of(
                  context,
                ).cardColor.withValues(alpha: 0.6),
                highlightColor: Colors.white.withValues(alpha: 0.14),
                child: Container(
                  height: index == 0 ? 130 : 190,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            const SizedBox(height: 100),
            AppEmptyState(
              title: l10n.tr('unableToLoadDashboard'),
              message: '$error',
              icon: Icons.cloud_off_rounded,
              action: ElevatedButton(
                onPressed: () =>
                    ref.read(dashboardProvider.notifier).refresh(),
                child: Text(l10n.tr('retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatefulWidget {
  const _DashboardHeader({
    required this.userName,
    required this.onReportsTap,
    required this.onPeopleTap,
  });

  final String userName;
  final VoidCallback onReportsTap;
  final VoidCallback onPeopleTap;

  @override
  State<_DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<_DashboardHeader> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat(
      'EEEE, d MMMM',
      localeTag,
    ).format(_now);
    final timeLabel = DateFormat(
      'hh:mm a',
      localeTag,
    ).format(_now);
    final greeting = _greetingFor(
      hour: _now.hour,
      isHindi: l10n.isHindi,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dateLabel.toUpperCase()} · $timeLabel',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$greeting, ${widget.userName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr('latestRentOverview'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButtonCard(
              icon: Icons.bar_chart_rounded,
              onTap: widget.onReportsTap,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            AppIconButtonCard(
              icon: Icons.people_alt_rounded,
              onTap: widget.onPeopleTap,
            ),
          ],
        ),
      ],
    );
  }

  String _greetingFor({
    required int hour,
    required bool isHindi,
  }) {
    if (isHindi) {
      if (hour < 12) {
        return 'सुप्रभात';
      }
      if (hour < 17) {
        return 'नमस्कार';
      }
      return 'शुभ संध्या';
    }

    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class _MonthlyOverviewCard extends StatelessWidget {
  const _MonthlyOverviewCard({required this.stats});

  final DashboardStatsModel stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalDue = stats.totalCollected + stats.totalPending;
    final percent = totalDue == 0
        ? 0.0
        : (stats.totalCollected / totalDue).clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1535), Color(0xFF0F1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bgCardBorderStrongDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('totalCollected'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.54),
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.inr(stats.totalCollected),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tr(
                    'pendingThisMonth',
                    params: {
                      'amount': CurrencyFormatter.inr(stats.totalPending),
                    },
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _ProgressRing(value: percent),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStatsModel stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 1.18,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCardWidget(
          label: l10n.isHindi ? 'कुल कमरे' : 'Total rooms',
          value: stats.totalRooms,
          icon: Icons.home_work_rounded,
          color: AppColors.primary,
          badge: '${stats.occupied} occ',
        ),
        StatCardWidget(
          label: l10n.isHindi ? 'किरायेदार' : 'Tenants',
          value: stats.tenantCount,
          icon: Icons.people_alt_rounded,
          color: AppColors.accent,
        ),
        StatCardWidget(
          label: l10n.isHindi ? 'बकाया' : 'Pending due',
          value: stats.totalPending,
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          isCurrency: true,
        ),
        StatCardWidget(
          label: l10n.tr('expenses'),
          value: stats.totalExpenses,
          icon: Icons.receipt_long_rounded,
          color: AppColors.danger,
          isCurrency: true,
        ),
      ],
    );
  }
}

class _RoomsQuickRow extends StatelessWidget {
  const _RoomsQuickRow({required this.rooms});

  final AsyncValue<List<RoomModel>> rooms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 112,
      child: rooms.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(l10n.tr('noRoomsYet')),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final room = items[index];
              final statusColor = switch (room.currentMonthStatus) {
                'paid' => AppColors.accent,
                'partial' => AppColors.warning,
                'pending' => AppColors.danger,
                _ => Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
              };

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/rooms/${room.id}'),
                child: Container(
                  width: 94,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: room.currentMonthStatus == 'paid'
                          ? AppColors.bgCardBorderStrongDark
                          : statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        room.roomNumber,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.currentTenant?.fullName ?? l10n.tr('vacant'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '${l10n.tr('unableToLoadRooms')}\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
