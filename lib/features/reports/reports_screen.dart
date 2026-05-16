import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/reports_repository.dart';

final reportsBundleProvider =
    FutureProvider.family<ReportsBundle, ({DateTime month, int year})>((
      ref,
      filter,
    ) async {
      return ref.read(reportsRepositoryProvider).fetchReports(
        monthDate: filter.month,
        year: filter.year,
      );
    });

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late int _selectedYear = DateTime.now().year;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bundleAsync = ref.watch(
      reportsBundleProvider((month: _selectedMonth, year: _selectedYear)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('reports'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            reportsBundleProvider((month: _selectedMonth, year: _selectedYear)),
          );
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            AppHeaderPanel(
              title: l10n.tr('reportsAndExports'),
              subtitle: l10n.tr('reportsOverview'),
              trailing: TextButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.white,
                ),
                label: Text(
                  AppDateUtils.monthLabel(_selectedMonth),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionTitle(
                    title: l10n.tr('filters'),
                    subtitle: l10n.tr('filtersSubtitle'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(4, (index) => DateTime.now().year - index)
                        .map(
                          (year) => ChoiceChip(
                            label: Text('$year'),
                            selected: _selectedYear == year,
                            onSelected: (_) => setState(() => _selectedYear = year),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            bundleAsync.when(
              data: (bundle) => Column(
                children: [
                  _MonthlyCollectionHero(
                    bundle: bundle,
                    exporting: _exporting,
                    onExport: _exportMonthlyReport,
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionTitle(
                          title: l10n.tr('yearlyIncomeSummary'),
                          subtitle: l10n.tr(
                            'collectedVsPending',
                            params: {'year': '$_selectedYear'},
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InsightRow(
                          items: [
                            _InsightItem(
                              label: l10n.tr('yearTotal'),
                              value: CurrencyFormatter.inr(
                                bundle.yearlyIncome.fold<num>(
                                  0,
                                  (sum, point) => sum + point.collected,
                                ),
                              ),
                              color: AppColors.accent,
                            ),
                            _InsightItem(
                              label: l10n.tr('bestMonth'),
                              value: _bestMonthLabel(bundle.yearlyIncome),
                              color: AppColors.primary,
                            ),
                            _InsightItem(
                              label: l10n.tr('pendingLoad'),
                              value: CurrencyFormatter.inr(
                                bundle.yearlyIncome.fold<num>(
                                  0,
                                  (sum, point) => sum + point.pending,
                                ),
                              ),
                              color: AppColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).inputDecorationTheme.fillColor,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tr('monthlyPerformance'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.tr('monthlyPerformanceSubtitle'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 280,
                                child: _YearlyIncomeChart(points: bundle.yearlyIncome),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionTitle(
                          title: l10n.tr('dueReport'),
                          subtitle: l10n.tr('dueReportSubtitle'),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.warningDim,
                                AppColors.dangerDim.withValues(alpha: 0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('roomsNeedAttention'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.tr(
                                        'roomsNeedAttentionSubtitle',
                                        params: {
                                          'count': '${bundle.dueReport.length}',
                                        },
                                      ),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.inr(
                                      bundle.dueReport.fold<num>(
                                        0,
                                        (sum, item) => sum + item.remainingAmount,
                                      ),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: AppColors.warning),
                                  ),
                                  Text(
                                    l10n.isHindi ? 'कुल बकाया' : 'Total pending',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (bundle.dueReport.isEmpty)
                          AppEmptyState(
                            title: l10n.tr('noOutstandingDues'),
                            message: l10n.tr('allSettled'),
                            icon: Icons.verified_rounded,
                          )
                        else
                          ...bundle.dueReport.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DueTile(item: item),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionTitle(
                          title: l10n.tr('expenseReport'),
                          subtitle: l10n.tr(
                            'expenseReportSubtitle',
                            params: {
                              'month': AppDateUtils.monthLabel(_selectedMonth),
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (bundle.expenseSummary.isEmpty)
                          AppEmptyState(
                            title: l10n.tr('noExpenses'),
                            message: l10n.tr('noExpensesSubtitle'),
                            icon: Icons.receipt_long_outlined,
                          )
                        else ...[
                          _ExpenseOverview(summary: bundle.expenseSummary),
                          const SizedBox(height: 16),
                          ...bundle.expenseSummary.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _categoryLabel(item.category),
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.inr(item.totalAmount),
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    minHeight: 8,
                                    value: _expenseProgress(
                                      item.totalAmount,
                                      bundle.expenseSummary,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.tr(
                                      'entriesCount',
                                      params: {'count': '${item.count}'},
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: AppEmptyState(
                  title: l10n.tr('loadReportsFailed'),
                  message: '$error',
                  icon: Icons.analytics_outlined,
                  action: ElevatedButton(
                    onPressed: () => ref.invalidate(
                      reportsBundleProvider(
                        (month: _selectedMonth, year: _selectedYear),
                      ),
                    ),
                    child: Text(l10n.tr('retry')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (selected != null) {
      setState(() {
        _selectedMonth = DateTime(selected.year, selected.month);
      });
    }
  }

  Future<void> _exportMonthlyReport() async {
    setState(() => _exporting = true);
    final shareText = context.l10n.tr(
      'shareReportText',
      params: {'month': AppDateUtils.monthLabel(_selectedMonth)},
    );

    try {
      final bytes = await ref
          .read(reportsRepositoryProvider)
          .downloadMonthlyCollectionPdf(_selectedMonth);
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'rentflow-${AppDateUtils.monthLabel(_selectedMonth)}.pdf',
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('exportFailed', params: {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  double _expenseProgress(num amount, List<ExpenseSummaryItem> summary) {
    final total = summary.fold<num>(0, (sum, item) => sum + item.totalAmount);
    if (total == 0) {
      return 0;
    }
    return amount / total;
  }
}

class _MonthlyCollectionHero extends StatelessWidget {
  const _MonthlyCollectionHero({
    required this.bundle,
    required this.exporting,
    required this.onExport,
  });

  final ReportsBundle bundle;
  final bool exporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = bundle.monthlySummary;
    final totalDue = summary.totalCollected + summary.totalPending;
    final rate = totalDue == 0 ? 0.0 : summary.totalCollected / totalDue;

    return Container(
      width: double.infinity,
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
                    Text(
                      l10n.tr('monthlyCollection'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.month,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.tr('exportPdf')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.inr(summary.totalCollected),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${(rate * 100).round()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  label: l10n.tr('collected'),
                  value: CurrencyFormatter.inr(summary.totalCollected),
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportMetric(
                  label: l10n.tr('pending'),
                  value: CurrencyFormatter.inr(summary.totalPending),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  label: l10n.tr('partialRooms'),
                  value: '${summary.partialPayments}',
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportMetric(
                  label: l10n.tr('fullyPaidRooms'),
                  value: '${summary.fullyPaidRooms}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InsightItem {
  const _InsightItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.items});

  final List<_InsightItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: items[index].color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[index].label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    items[index].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: items[index].color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _YearlyIncomeChart extends StatelessWidget {
  const _YearlyIncomeChart({required this.points});

  final List<MonthlyCollectionPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return AppEmptyState(
        title: context.l10n.tr('noYearlyData'),
        message: context.l10n.tr('noYearlyDataSubtitle'),
        icon: Icons.bar_chart_outlined,
      );
    }

    final maxValue = points.fold<num>(
      0,
      (max, point) =>
          [max, point.collected, point.pending].reduce((a, b) => a > b ? a : b),
    );
    final maxY = maxValue == 0 ? 100 : maxValue * 1.25;
    final chartWidth = points.length * 54.0;

    return Column(
      children: [
        Row(
          children: [
            _LegendDot(color: AppColors.accent, label: context.l10n.tr('collected')),
            const SizedBox(width: 14),
            _LegendDot(color: AppColors.warning, label: context.l10n.tr('pending')),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth < 360 ? 360 : chartWidth,
              child: BarChart(
                BarChartData(
                  maxY: maxY.toDouble(),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).dividerColor,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(14),
                      getTooltipColor: (_) => Theme.of(context).cardColor,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _compactInr(value),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              points[index].month,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 6,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].collected.toDouble(),
                            width: 12,
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          BarChartRodData(
                            toY: points[i].pending.toDouble(),
                            width: 12,
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.item});

  final DueReportItem item;

  @override
  Widget build(BuildContext context) {
    final ratio = item.totalDue == 0 ? 0.0 : item.remainingAmount / item.totalDue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.warning.withValues(alpha: 0.16),
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
                      'Room ${item.roomNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.tenantName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.inr(item.remainingAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  Text(
                    'of ${CurrencyFormatter.inr(item.totalDue)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio.clamp(0, 1).toDouble(),
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseOverview extends StatelessWidget {
  const _ExpenseOverview({required this.summary});

  final List<ExpenseSummaryItem> summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.fold<num>(0, (sum, item) => sum + item.totalAmount);
    final top = [...summary]..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: [
                    for (var i = 0; i < summary.length; i++)
                      PieChartSectionData(
                        value: summary[i].totalAmount.toDouble(),
                        color: _expenseColor(i),
                        showTitle: false,
                        radius: 22,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tr('expenseMix'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.tr('expenseMixSubtitle'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyFormatter.inr(total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < top.length && i < 4; i++) ...[
                  _LegendDot(
                    color: _expenseColor(i),
                    label:
                        '${_categoryLabel(top[i].category)} · ${CurrencyFormatter.inr(top[i].totalAmount)}',
                  ),
                  if (i != 3 && i != top.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _bestMonthLabel(List<MonthlyCollectionPoint> points) {
  if (points.isEmpty) {
    return '-';
  }

  final sorted = [...points]
    ..sort((a, b) => b.collected.compareTo(a.collected));

  return sorted.first.month;
}

String _compactInr(num value) {
  final locale = Intl.getCurrentLocale().isEmpty
      ? 'en_IN'
      : Intl.getCurrentLocale();
  return NumberFormat.compactCurrency(
    locale: locale,
    symbol: '₹',
    decimalDigits: 0,
  ).format(value);
}

String _categoryLabel(String category) {
  final words = category.split('_').map((word) {
    if (word.isEmpty) {
      return word;
    }
    return '${word[0].toUpperCase()}${word.substring(1)}';
  });

  return words.join(' ');
}

Color _expenseColor(int index) {
  const palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.warning,
    AppColors.info,
    AppColors.danger,
  ];

  return palette[index % palette.length];
}
