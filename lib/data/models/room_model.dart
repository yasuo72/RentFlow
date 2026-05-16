class RoomReference {
  const RoomReference({
    required this.id,
    required this.roomNumber,
    this.monthlyRent,
  });

  final String id;
  final String roomNumber;
  final num? monthlyRent;

  factory RoomReference.fromJson(Map<String, dynamic> json) {
    return RoomReference(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      roomNumber: (json['roomNumber'] ?? '-') as String,
      monthlyRent: json['monthlyRent'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'roomNumber': roomNumber,
    'monthlyRent': monthlyRent,
  };
}

class TenantReference {
  const TenantReference({
    required this.id,
    required this.fullName,
    this.phone,
    this.profilePhoto,
    this.joiningDate,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? profilePhoto;
  final DateTime? joiningDate;

  factory TenantReference.fromJson(Map<String, dynamic> json) {
    return TenantReference(
      id: (json['_id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '') as String,
      phone: json['phone'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      joiningDate: json['joiningDate'] != null
          ? DateTime.tryParse(json['joiningDate'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fullName': fullName,
    'phone': phone,
    'profilePhoto': profilePhoto,
    'joiningDate': joiningDate?.toIso8601String(),
  };
}

class RoomPaymentSnapshot {
  const RoomPaymentSnapshot({
    this.amountPaid = 0,
    this.remainingAmount = 0,
    this.monthlyRentDue = 0,
    this.carriedForwardAmount = 0,
    this.totalDue = 0,
    this.paymentMethod,
    this.paymentDate,
    this.remark,
  });

  final num amountPaid;
  final num remainingAmount;
  final num monthlyRentDue;
  final num carriedForwardAmount;
  final num totalDue;
  final String? paymentMethod;
  final DateTime? paymentDate;
  final String? remark;

  factory RoomPaymentSnapshot.fromJson(Map<String, dynamic> json) {
    return RoomPaymentSnapshot(
      amountPaid: json['amountPaid'] as num? ?? 0,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
      monthlyRentDue: json['monthlyRentDue'] as num? ?? 0,
      carriedForwardAmount: json['carriedForwardAmount'] as num? ?? 0,
      totalDue:
          json['totalDue'] as num? ??
          ((json['amountPaid'] as num? ?? 0) +
              (json['remainingAmount'] as num? ?? 0)),
      paymentMethod: json['paymentMethod'] as String?,
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'amountPaid': amountPaid,
    'remainingAmount': remainingAmount,
    'monthlyRentDue': monthlyRentDue,
    'carriedForwardAmount': carriedForwardAmount,
    'totalDue': totalDue,
    'paymentMethod': paymentMethod,
    'paymentDate': paymentDate?.toIso8601String(),
    'remark': remark,
  };
}

class RoomPaymentHistoryItem {
  const RoomPaymentHistoryItem({
    required this.id,
    required this.month,
    required this.amountPaid,
    required this.remainingAmount,
    this.recordedByName,
  });

  final String id;
  final String month;
  final num amountPaid;
  final num remainingAmount;
  final String? recordedByName;

  factory RoomPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return RoomPaymentHistoryItem(
      id: (json['_id'] ?? '').toString(),
      month: (json['month'] ?? '-') as String,
      amountPaid: json['amountPaid'] as num? ?? 0,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
      recordedByName:
          (json['recordedBy'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'month': month,
    'amountPaid': amountPaid,
    'remainingAmount': remainingAmount,
    'recordedBy': recordedByName == null ? null : {'name': recordedByName},
  };
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.roomNumber,
    required this.monthlyRent,
    required this.status,
    this.floor,
    this.building,
    this.depositAmount = 0,
    this.electricityMeterNumber,
    this.notes,
    this.photos = const [],
    this.currentTenant,
    this.currentMonthStatus = 'vacant',
    this.currentMonthPayment,
    this.paymentHistory = const [],
  });

  final String id;
  final String roomNumber;
  final num monthlyRent;
  final String status;
  final String? floor;
  final String? building;
  final num depositAmount;
  final String? electricityMeterNumber;
  final String? notes;
  final List<String> photos;
  final TenantReference? currentTenant;
  final String currentMonthStatus;
  final RoomPaymentSnapshot? currentMonthPayment;
  final List<RoomPaymentHistoryItem> paymentHistory;

  bool get isOccupied => status == 'occupied';

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: (json['_id'] ?? '').toString(),
      roomNumber: (json['roomNumber'] ?? '-') as String,
      monthlyRent: json['monthlyRent'] as num? ?? 0,
      status: (json['status'] ?? 'vacant') as String,
      floor: json['floor'] as String?,
      building: json['building'] as String?,
      depositAmount: json['depositAmount'] as num? ?? 0,
      electricityMeterNumber: json['electricityMeterNumber'] as String?,
      notes: json['notes'] as String?,
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      currentTenant: json['currentTenant'] is Map<String, dynamic>
          ? TenantReference.fromJson(
              json['currentTenant'] as Map<String, dynamic>,
            )
          : null,
      currentMonthStatus: (json['currentMonthStatus'] ?? 'vacant') as String,
      currentMonthPayment: json['currentMonthPayment'] is Map<String, dynamic>
          ? RoomPaymentSnapshot.fromJson(
              json['currentMonthPayment'] as Map<String, dynamic>,
            )
          : null,
      paymentHistory: (json['paymentHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoomPaymentHistoryItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'roomNumber': roomNumber,
    'monthlyRent': monthlyRent,
    'status': status,
    'floor': floor,
    'building': building,
    'depositAmount': depositAmount,
    'electricityMeterNumber': electricityMeterNumber,
    'notes': notes,
    'photos': photos,
    'currentTenant': currentTenant?.toJson(),
    'currentMonthStatus': currentMonthStatus,
    'currentMonthPayment': currentMonthPayment?.toJson(),
    'paymentHistory': paymentHistory.map((item) => item.toJson()).toList(),
  };
}
