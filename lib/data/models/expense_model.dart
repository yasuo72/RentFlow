import 'room_model.dart';
import 'user_model.dart';

class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.room,
    this.billPhoto,
    this.recordedBy,
  });

  final String id;
  final String category;
  final num amount;
  final DateTime date;
  final String? description;
  final RoomReference? room;
  final String? billPhoto;
  final UserModel? recordedBy;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: (json['_id'] ?? '').toString(),
      category: (json['category'] ?? 'other') as String,
      amount: json['amount'] as num? ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      description: json['description'] as String?,
      room: json['room'] is Map<String, dynamic>
          ? RoomReference.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      billPhoto: json['billPhoto'] as String?,
      recordedBy: json['recordedBy'] is Map<String, dynamic>
          ? UserModel.fromJson(json['recordedBy'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'room': room?.toJson(),
    'billPhoto': billPhoto,
    'recordedBy': recordedBy?.toJson(),
  };
}
