import 'dart:convert';

class DashboardStatsModel {
  const DashboardStatsModel({
    required this.totalRooms,
    required this.occupied,
    required this.vacant,
    required this.totalCollected,
    required this.totalPending,
    required this.totalExpenses,
    required this.tenantCount,
  });

  final int totalRooms;
  final int occupied;
  final int vacant;
  final num totalCollected;
  final num totalPending;
  final num totalExpenses;
  final int tenantCount;

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      occupied: (json['occupied'] as num?)?.toInt() ?? 0,
      vacant: (json['vacant'] as num?)?.toInt() ?? 0,
      totalCollected: json['totalCollected'] as num? ?? 0,
      totalPending: json['totalPending'] as num? ?? 0,
      totalExpenses: json['totalExpenses'] as num? ?? 0,
      tenantCount: (json['tenantCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalRooms': totalRooms,
    'occupied': occupied,
    'vacant': vacant,
    'totalCollected': totalCollected,
    'totalPending': totalPending,
    'totalExpenses': totalExpenses,
    'tenantCount': tenantCount,
  };
}

class MonthlyCollectionPoint {
  const MonthlyCollectionPoint({
    required this.month,
    required this.fullMonth,
    required this.collected,
    required this.pending,
  });

  final String month;
  final String fullMonth;
  final num collected;
  final num pending;

  factory MonthlyCollectionPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyCollectionPoint(
      month: (json['month'] ?? '') as String,
      fullMonth: (json['fullMonth'] ?? json['month'] ?? '') as String,
      collected: json['collected'] as num? ?? 0,
      pending: json['pending'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'month': month,
    'fullMonth': fullMonth,
    'collected': collected,
    'pending': pending,
  };
}

class ActivityLogItem {
  const ActivityLogItem({
    required this.id,
    required this.action,
    required this.details,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String details;
  final String userName;
  final DateTime? createdAt;

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) {
    return ActivityLogItem(
      id: (json['_id'] ?? '').toString(),
      action: (json['action'] ?? '') as String,
      details: (json['details'] ?? '') as String,
      userName: (json['userName'] ?? 'Family') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'action': action,
    'details': details,
    'userName': userName,
    'createdAt': createdAt?.toIso8601String(),
  };
}

class DueAlert {
  const DueAlert({
    required this.roomNumber,
    required this.tenantName,
    required this.pendingAmount,
    this.daysUntilDue,
  });

  final String roomNumber;
  final String tenantName;
  final num pendingAmount;
  final int? daysUntilDue;

  factory DueAlert.fromJson(Map<String, dynamic> json) {
    return DueAlert(
      roomNumber: (json['roomNumber'] ?? '-') as String,
      tenantName: (json['tenantName'] ?? 'Unknown') as String,
      pendingAmount:
          json['pendingAmount'] as num? ?? json['remainingAmount'] as num? ?? 0,
      daysUntilDue: (json['daysUntilDue'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'roomNumber': roomNumber,
    'tenantName': tenantName,
    'pendingAmount': pendingAmount,
    'daysUntilDue': daysUntilDue,
  };
}

class PaymentCalendarEvent {
  const PaymentCalendarEvent({
    required this.id,
    required this.paymentId,
    required this.date,
    required this.roomNumber,
    required this.tenantName,
    required this.amountPaid,
    required this.paymentMethod,
    required this.recordedByName,
    required this.remainingAmount,
    this.remark,
  });

  final String id;
  final String paymentId;
  final DateTime date;
  final String roomNumber;
  final String tenantName;
  final num amountPaid;
  final String paymentMethod;
  final String recordedByName;
  final num remainingAmount;
  final String? remark;

  factory PaymentCalendarEvent.fromJson(Map<String, dynamic> json) {
    return PaymentCalendarEvent(
      id: (json['id'] ?? '').toString(),
      paymentId: (json['paymentId'] ?? '').toString(),
      date:
          DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      roomNumber: (json['roomNumber'] ?? '-') as String,
      tenantName: (json['tenantName'] ?? 'Unknown') as String,
      amountPaid: json['amountPaid'] as num? ?? 0,
      paymentMethod: (json['paymentMethod'] ?? 'cash') as String,
      recordedByName: (json['recordedByName'] ?? 'Family') as String,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'paymentId': paymentId,
    'date': date.toIso8601String(),
    'roomNumber': roomNumber,
    'tenantName': tenantName,
    'amountPaid': amountPaid,
    'paymentMethod': paymentMethod,
    'recordedByName': recordedByName,
    'remainingAmount': remainingAmount,
    'remark': remark,
  };
}

class DashboardBundle {
  const DashboardBundle({
    required this.stats,
    required this.chart,
    required this.activity,
    required this.dues,
    required this.calendarEvents,
  });

  final DashboardStatsModel stats;
  final List<MonthlyCollectionPoint> chart;
  final List<ActivityLogItem> activity;
  final List<DueAlert> dues;
  final List<PaymentCalendarEvent> calendarEvents;

  factory DashboardBundle.fromJson(Map<String, dynamic> json) {
    return DashboardBundle(
      stats: DashboardStatsModel.fromJson(
        json['stats'] as Map<String, dynamic>,
      ),
      chart: (json['chart'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MonthlyCollectionPoint.fromJson)
          .toList(),
      activity: (json['activity'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ActivityLogItem.fromJson)
          .toList(),
      dues: (json['dues'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DueAlert.fromJson)
          .toList(),
      calendarEvents: (json['calendarEvents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentCalendarEvent.fromJson)
          .toList(),
    );
  }

  String encode() => jsonEncode({
    'stats': stats.toJson(),
    'chart': chart.map((item) => item.toJson()).toList(),
    'activity': activity.map((item) => item.toJson()).toList(),
    'dues': dues.map((item) => item.toJson()).toList(),
    'calendarEvents': calendarEvents.map((item) => item.toJson()).toList(),
  });

  factory DashboardBundle.decode(String source) {
    return DashboardBundle.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}
