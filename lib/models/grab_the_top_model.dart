import 'package:cloud_firestore/cloud_firestore.dart';

class GrabTheTopRule {
  final String id;
  final String giftId;
  final String giftName;
  final String? giftImageUrl;
  final int minGiftCount;
  final int showingTimeSeconds;
  final bool isActive;
  final String bannerTitle;

  GrabTheTopRule({
    required this.id,
    required this.giftId,
    required this.giftName,
    this.giftImageUrl,
    required this.minGiftCount,
    required this.showingTimeSeconds,
    this.isActive = true,
    this.bannerTitle = '👑 {sender} sent {count}x {gift} to {receiver} and Grabbed the Top! 🪑',
  });

  factory GrabTheTopRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GrabTheTopRule(
      id: doc.id,
      giftId: data['giftId']?.toString() ?? '',
      giftName: data['giftName']?.toString() ?? '',
      giftImageUrl: data['giftImageUrl']?.toString(),
      minGiftCount: (data['minGiftCount'] ?? data['giftQuantity'] ?? 1) as int,
      showingTimeSeconds: (data['showingTimeSeconds'] ?? data['showingTime'] ?? 10) as int,
      isActive: data['isActive'] ?? true,
      bannerTitle: data['bannerTitle']?.toString() ?? '👑 {sender} sent {count}x {gift} to {receiver} and Grabbed the Top! 🪑',
    );
  }
}

class ActiveGrabTheTopEvent {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;
  final String giftId;
  final String giftName;
  final String? giftPngUrl;
  final int quantity;
  final String roomId;
  final int showingTimeSeconds;
  final DateTime expiresAt;
  final DateTime createdAt;

  ActiveGrabTheTopEvent({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
    required this.giftId,
    required this.giftName,
    this.giftPngUrl,
    required this.quantity,
    required this.roomId,
    required this.showingTimeSeconds,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  factory ActiveGrabTheTopEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ActiveGrabTheTopEvent(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Sender',
      senderImageUrl: data['senderImageUrl'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Receiver',
      receiverImageUrl: data['receiverImageUrl'],
      giftId: data['giftId'] ?? '',
      giftName: data['giftName'] ?? 'Gift',
      giftPngUrl: data['giftPngUrl'],
      quantity: (data['quantity'] ?? 1) as int,
      roomId: data['roomId'] ?? '',
      showingTimeSeconds: (data['showingTimeSeconds'] ?? 10) as int,
      expiresAt: parseDate(data['expiresAt']),
      createdAt: parseDate(data['createdAt']),
    );
  }
}
