import 'package:cloud_firestore/cloud_firestore.dart';

class AudioRoomBanner {
  final String id;
  final String imageUrl;
  final String? clickUrl;
  final String? eventId;
  final DateTime createdAt;

  const AudioRoomBanner({
    required this.id,
    required this.imageUrl,
    this.clickUrl,
    this.eventId,
    required this.createdAt,
  });

  factory AudioRoomBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parsedDate;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedDate = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedDate = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else if (rawCreatedAt is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    } else {
      parsedDate = DateTime.now();
    }

    return AudioRoomBanner(
      id: doc.id,
      imageUrl: data['imageUrl']?.toString() ?? '',
      clickUrl: (data['clickUrl'] ?? data['redirectUrl'] ?? data['click_url'])?.toString(),
      eventId: data['eventId']?.toString(),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'clickUrl': clickUrl,
      'eventId': eventId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
