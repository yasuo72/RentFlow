import 'room_model.dart';

class EmergencyContact {
  const EmergencyContact({
    this.name,
    this.phone,
    this.relation,
  });

  final String? name;
  final String? phone;
  final String? relation;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      relation: json['relation'] as String?,
    );
  }
}

class TenantDocument {
  const TenantDocument({
    required this.type,
    required this.url,
    required this.name,
  });

  final String type;
  final String url;
  final String name;

  factory TenantDocument.fromJson(Map<String, dynamic> json) {
    return TenantDocument(
      type: (json['type'] ?? 'other') as String,
      url: (json['url'] ?? '') as String,
      name: (json['name'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'url': url, 'name': name};
}

class TenantPaymentHistoryItem {
  const TenantPaymentHistoryItem({
    required this.id,
    required this.month,
    required this.amountPaid,
    required this.remainingAmount,
    this.remark,
    this.recordedByName,
    this.paymentDate,
    this.receiptNumber,
  });

  final String id;
  final String month;
  final num amountPaid;
  final num remainingAmount;
  final String? remark;
  final String? recordedByName;
  final DateTime? paymentDate;
  final String? receiptNumber;

  factory TenantPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return TenantPaymentHistoryItem(
      id: (json['_id'] ?? '').toString(),
      month: (json['month'] ?? '-') as String,
      amountPaid: json['amountPaid'] as num? ?? 0,
      remainingAmount: json['remainingAmount'] as num? ?? 0,
      remark: json['remark'] as String?,
      recordedByName:
          (json['recordedBy'] as Map<String, dynamic>?)?['name'] as String?,
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      receiptNumber: json['receiptNumber'] as String?,
    );
  }
}

class TenantModel {
  const TenantModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.joiningDate,
    this.alternatePhone,
    this.idNumber,
    this.occupation,
    this.familyMembers = 1,
    this.permanentAddress,
    this.profilePhoto,
    this.room,
    this.currentMonthPayment,
    this.documents = const [],
    this.paymentHistory = const [],
    this.notes,
    this.emergencyContact,
    this.isActive = true,
    this.leavingDate,
  });

  final String id;
  final String fullName;
  final String phone;
  final DateTime joiningDate;
  final String? alternatePhone;
  final String? idNumber;
  final String? occupation;
  final int familyMembers;
  final String? permanentAddress;
  final String? profilePhoto;
  final RoomReference? room;
  final RoomPaymentSnapshot? currentMonthPayment;
  final List<TenantDocument> documents;
  final List<TenantPaymentHistoryItem> paymentHistory;
  final String? notes;
  final EmergencyContact? emergencyContact;
  final bool isActive;
  final DateTime? leavingDate;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: (json['_id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      joiningDate:
          DateTime.tryParse(json['joiningDate']?.toString() ?? '') ??
          DateTime.now(),
      alternatePhone: json['alternatePhone'] as String?,
      idNumber: json['idNumber'] as String?,
      occupation: json['occupation'] as String?,
      familyMembers: (json['familyMembers'] as num?)?.toInt() ?? 1,
      permanentAddress: json['permanentAddress'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      room: json['room'] is Map<String, dynamic>
          ? RoomReference.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      currentMonthPayment: json['currentMonthPayment'] is Map<String, dynamic>
          ? RoomPaymentSnapshot.fromJson(
              json['currentMonthPayment'] as Map<String, dynamic>,
            )
          : null,
      documents: (json['documents'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TenantDocument.fromJson)
          .toList(),
      paymentHistory: (json['paymentHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TenantPaymentHistoryItem.fromJson)
          .toList(),
      notes: json['notes'] as String?,
      emergencyContact: json['emergencyContact'] is Map<String, dynamic>
          ? EmergencyContact.fromJson(
              json['emergencyContact'] as Map<String, dynamic>,
            )
          : null,
      isActive: json['isActive'] as bool? ?? true,
      leavingDate: json['leavingDate'] != null
          ? DateTime.tryParse(json['leavingDate'].toString())
          : null,
    );
  }
}
