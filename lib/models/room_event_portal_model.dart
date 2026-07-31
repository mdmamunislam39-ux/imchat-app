import 'package:cloud_firestore/cloud_firestore.dart';

class RoomEventPortalModel {
  final String id;
  final String imageUrl;
  final String? eventId;
  final String? redirectUrl;
  final bool isActive;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomEventPortalModel({
    required this.id,
    required this.imageUrl,
    this.eventId,
    this.redirectUrl,
    this.isActive = true,
    this.orderIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomEventPortalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomEventPortalModel(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      eventId: data['eventId'],
      redirectUrl: data['redirectUrl'],
      isActive: data['isActive'] ?? true,
      orderIndex: data['orderIndex'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'eventId': eventId,
      'redirectUrl': redirectUrl,
      'isActive': isActive,
      'orderIndex': orderIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RoomEventPortalModel copyWith({
    String? id,
    String? imageUrl,
    String? eventId,
    String? redirectUrl,
    bool? isActive,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomEventPortalModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      eventId: eventId ?? this.eventId,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      isActive: isActive ?? this.isActive,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
