import 'package:cloud_firestore/cloud_firestore.dart';

class CustomRoomIdModel {
  final String id;
  final String roomId; // Document ID of the room
  final String originalRoomId; // Original numeric ID
  final String customRoomId; // The new assigned short ID
  final String roomName;
  final String roomImageUrl;
  final DateTime assignedAt;
  final DateTime expiresAt;
  final bool isActive;

  CustomRoomIdModel({
    required this.id,
    required this.roomId,
    required this.originalRoomId,
    required this.customRoomId,
    required this.roomName,
    required this.roomImageUrl,
    required this.assignedAt,
    required this.expiresAt,
    this.isActive = true,
  });

  factory CustomRoomIdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomRoomIdModel(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      originalRoomId: data['originalRoomId'] ?? '',
      customRoomId: data['customId'] ?? data['customRoomId'] ?? '',
      roomName: data['roomName'] ?? '',
      roomImageUrl: data['roomImageUrl'] ?? '',
      assignedAt: data['assignedAt'] != null
          ? (data['assignedAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'originalRoomId': originalRoomId,
      'customId': customRoomId, // Matches PremiumRoomIdModel
      'customRoomId': customRoomId, // Fallback for any legacy admin panel queries
      'roomName': roomName,
      'roomImageUrl': roomImageUrl,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get styleCategory {
    final length = customRoomId.length;
    if (length == 1) return '1-Digit';
    if (length == 2) return '2-Digit';
    if (length >= 3 && length <= 4) return '3-4-Digit';
    if (length >= 5 && length <= 6) return '5-6-Digit';
    return 'Default';
  }
}
