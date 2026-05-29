import 'room_model.dart';
import 'user_model.dart';

class PaymentEntryModel {
  const PaymentEntryModel({
    required this.amountPaid,
    required this.paymentMethod,
    this.paymentDate,
    this.remark,
    this.recordedBy,
  });

  final num amountPaid;
  final String paymentMethod;
  final DateTime? paymentDate;
  final String? remark;
  final UserModel? recordedBy;

  factory PaymentEntryModel.fromJson(Map<String, dynamic> json) {
    return PaymentEntryModel(
      amountPaid: json['amountPaid'] as num? ?? 0,
      paymentMethod: (json['paymentMethod'] ?? 'cash') as String,
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      remark: json['remark'] as String?,
      recordedBy: json['recordedBy'] is Map<String, dynamic>
          ? UserModel.fromJson(json['recordedBy'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'amountPaid': amountPaid,
    'paymentMethod': paymentMethod,
    'paymentDate': paymentDate?.toIso8601String(),
    'remark': remark,
    'recordedBy': recordedBy?.toJson(),
  };
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.month,
    required this.year,
    required this.monthlyRentDue,
    required this.amountPaid,
    required this.remainingAmount,
    required this.paymentMethod,
    required this.receiptNumber,
    this.room,
    this.tenant,
    this.recordedBy,
    this.remark,
    this.paymentDate,
    this.isPartialPayment = false,
    this.carriedForwardAmount = 0,
    this.manualDueAmount = 0,
    this.manualDueRemark,
    this.advanceAmount = 0,
    this.entries = const [],
  });

  final String id;
  final String month;
  final int year;
  final num monthlyRentDue;
  final num amountPaid;
  final num remainingAmount;
  final String paymentMethod;
  final String receiptNumber;
  final RoomReference? room;
  final TenantReference? tenant;
  final UserModel? recordedBy;
  final String? remark;
  final DateTime? paymentDate;
  final bool isPartialPayment;
  final num carriedForwardAmount;
  final num manualDueAmount;
  final String? manualDueRemark;
  final num advanceAmount;
  final List<PaymentEntryModel> entries;

  num get totalDue => monthlyRentDue + carriedForwardAmount + manualDueAmount;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final parsedEntries = (json['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentEntryModel.fromJson)
        .toList();

    return PaymentModel(
      id: (json['_id'] ?? '').toString(),
      month: (json['month'] ?? '-') as String,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      monthlyRentDue: json['monthlyRentDue'] as num? ?? 0,
      amountPaid: json['amountPaid'] as num? ?? 0,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
      paymentMethod: (json['paymentMethod'] ?? 'cash') as String,
      receiptNumber: (json['receiptNumber'] ?? '') as String,
      room: json['room'] is Map<String, dynamic>
          ? RoomReference.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      tenant: json['tenant'] is Map<String, dynamic>
          ? TenantReference.fromJson(json['tenant'] as Map<String, dynamic>)
          : null,
      recordedBy: json['recordedBy'] is Map<String, dynamic>
          ? UserModel.fromJson(json['recordedBy'] as Map<String, dynamic>)
          : null,
      remark: json['remark'] as String?,
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      isPartialPayment: json['isPartialPayment'] as bool? ?? false,
      carriedForwardAmount: json['carriedForwardAmount'] as num? ?? 0,
      manualDueAmount: json['manualDueAmount'] as num? ?? 0,
      manualDueRemark: json['manualDueRemark'] as String?,
      advanceAmount: json['advanceAmount'] as num? ?? 0,
      entries: parsedEntries.isNotEmpty
          ? parsedEntries
          : [
              PaymentEntryModel(
                amountPaid: json['amountPaid'] as num? ?? 0,
                paymentMethod: (json['paymentMethod'] ?? 'cash') as String,
                paymentDate: json['paymentDate'] != null
                    ? DateTime.tryParse(json['paymentDate'].toString())
                    : null,
                remark: json['remark'] as String?,
                recordedBy: json['recordedBy'] is Map<String, dynamic>
                    ? UserModel.fromJson(
                        json['recordedBy'] as Map<String, dynamic>,
                      )
                    : null,
              ),
            ],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'month': month,
    'year': year,
    'monthlyRentDue': monthlyRentDue,
    'amountPaid': amountPaid,
    'remainingAmount': remainingAmount,
    'paymentMethod': paymentMethod,
    'receiptNumber': receiptNumber,
    'room': room?.toJson(),
    'tenant': tenant?.toJson(),
    'recordedBy': recordedBy?.toJson(),
    'remark': remark,
    'paymentDate': paymentDate?.toIso8601String(),
    'isPartialPayment': isPartialPayment,
    'carriedForwardAmount': carriedForwardAmount,
    'manualDueAmount': manualDueAmount,
    'manualDueRemark': manualDueRemark,
    'advanceAmount': advanceAmount,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };
}
