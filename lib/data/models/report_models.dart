import 'dashboard_stats_model.dart';
import '../repositories/expense_repository.dart';

class DueReportItem {
  const DueReportItem({
    required this.roomId,
    required this.roomNumber,
    required this.tenantName,
    required this.totalDue,
    required this.remainingAmount,
  });

  final String roomId;
  final String roomNumber;
  final String tenantName;
  final num totalDue;
  final num remainingAmount;

  factory DueReportItem.fromJson(Map<String, dynamic> json) {
    return DueReportItem(
      roomId: (json['roomId'] ?? '').toString(),
      roomNumber: (json['roomNumber'] ?? '-').toString(),
      tenantName: (json['tenantName'] ?? 'Unknown').toString(),
      totalDue: json['totalDue'] as num? ?? 0,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
    );
  }
}

class MonthlyCollectionSummary {
  const MonthlyCollectionSummary({
    required this.month,
    required this.year,
    required this.totalCollected,
    required this.totalPending,
    required this.partialPayments,
    required this.fullyPaidRooms,
  });

  final String month;
  final int year;
  final num totalCollected;
  final num totalPending;
  final int partialPayments;
  final int fullyPaidRooms;

  factory MonthlyCollectionSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyCollectionSummary(
      month: (json['month'] ?? '').toString(),
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      totalCollected: json['totalCollected'] as num? ?? 0,
      totalPending: json['totalPending'] as num? ?? 0,
      partialPayments: (json['partialPayments'] as num?)?.toInt() ?? 0,
      fullyPaidRooms: (json['fullyPaidRooms'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportsBundle {
  const ReportsBundle({
    required this.monthlySummary,
    required this.yearlyIncome,
    required this.dueReport,
    required this.expenseSummary,
  });

  final MonthlyCollectionSummary monthlySummary;
  final List<MonthlyCollectionPoint> yearlyIncome;
  final List<DueReportItem> dueReport;
  final List<ExpenseSummaryItem> expenseSummary;
}
