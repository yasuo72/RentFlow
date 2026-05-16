import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/dashboard_stats_model.dart';

class CollectionChartWidget extends StatelessWidget {
  const CollectionChartWidget({required this.points, super.key});

  final List<MonthlyCollectionPoint> points;

  @override
  Widget build(BuildContext context) {
    final chartPoints = points.length > 6
        ? points.sublist(points.length - 6)
        : points;

    if (chartPoints.isEmpty) {
      return const AppEmptyState(
        title: 'No collection history yet',
        message: 'Monthly collections will start appearing here once payments are recorded.',
        icon: Icons.insights_rounded,
      );
    }

    final maxY = chartPoints.fold<num>(
      0,
      (maxValue, point) => math.max(
        maxValue,
        math.max(point.collected, point.pending),
      ),
    );

    return AppSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            eyebrow: 'Collection trend',
            title: 'Collected vs pending',
            subtitle: 'Last 6 months',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 188,
            child: BarChart(
              BarChartData(
                maxY: (maxY <= 0 ? 1 : maxY).toDouble() * 1.18,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartPoints.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            chartPoints[index].month,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(chartPoints.length, (index) {
                  final point = chartPoints[index];

                  return BarChartGroupData(
                    x: index,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: point.collected.toDouble(),
                        width: 10,
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, Color(0x6600D9A3)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      BarChartRodData(
                        toY: point.pending.toDouble(),
                        width: 10,
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [AppColors.warning, Color(0x66FFB800)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _LegendChip(
                label: 'Collected',
                color: AppColors.accent,
              ),
              _LegendChip(
                label: 'Pending',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
