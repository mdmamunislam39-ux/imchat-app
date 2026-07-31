import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumRoomIdModel {
  final String roomId;
  final String customId;
  final DateTime? expiresAt;

  PremiumRoomIdModel({
    required this.roomId,
    required this.customId,
    this.expiresAt,
  });

  factory PremiumRoomIdModel.fromMap(Map<String, dynamic> map, String docId) {
    return PremiumRoomIdModel(
      roomId: docId,
      customId: map['customId'] ?? '',
      expiresAt: map['expiresAt'] != null 
          ? (map['expiresAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customId': customId,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
