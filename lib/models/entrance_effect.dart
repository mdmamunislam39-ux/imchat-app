import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for entrance effect animations
class EntranceEffect {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String effectId;
  final String effectUrl;
  final DateTime timestamp;
  final String type; // 'entryEffect' or 'roomEntry'

  EntranceEffect({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.effectId,
    required this.effectUrl,
    required this.timestamp,
    required this.type,
  });

  factory EntranceEffect.fromJson(Map<String, dynamic> json) {
    return EntranceEffect(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatar: json['userAvatar'],
      effectId: json['effectId'] ?? '',
      effectUrl: json['effectUrl'] ?? '',
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(
              json['timestamp'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'entryEffect',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'effectId': effectId,
      'effectUrl': effectUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }
}
