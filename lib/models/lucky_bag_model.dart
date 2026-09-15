import 'package:cloud_firestore/cloud_firestore.dart';

class LuckyBagModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final int totalAmount;
  final int remainingAmount;
  final int maxWinners;
  final int claimedCount;
  final int entryFee;
  final String distributionType; // 'random' or 'equal'
  final bool isPublic;
  final String? message;
  final String status; // 'active', 'completed', 'expired'
  final DateTime createdAt;
  final DateTime unlocksAt;
  final DateTime expiresAt;

  LuckyBagModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.totalAmount,
    required this.remainingAmount,
    required this.maxWinners,
    required this.claimedCount,
    this.entryFee = 0,
    this.distributionType = 'random',
    this.isPublic = false,
    this.message,
    required this.status,
    required this.createdAt,
    required this.unlocksAt,
    required this.expiresAt,
  });

  factory LuckyBagModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    final created = parseDate(map['createdAt']);
    final unlocks = parseDate(map['unlocksAt'], created.add(const Duration(seconds: 60)));
    final expires = parseDate(map['expiresAt'], unlocks.add(const Duration(minutes: 10)));

    return LuckyBagModel(
      id: id,
      roomId: map['roomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Anonymous',
      senderAvatar: map['senderAvatar'],
      totalAmount: (map['totalAmount'] ?? 0) is double
          ? (map['totalAmount'] as double).toInt()
          : (map['totalAmount'] ?? 0),
      remainingAmount: (map['remainingAmount'] ?? 0) is double
          ? (map['remainingAmount'] as double).toInt()
          : (map['remainingAmount'] ?? 0),
      maxWinners: (map['maxWinners'] ?? 1) is double
          ? (map['maxWinners'] as double).toInt()
          : (map['maxWinners'] ?? 1),
      claimedCount: (map['claimedCount'] ?? 0) is double
          ? (map['claimedCount'] as double).toInt()
          : (map['claimedCount'] ?? 0),
      entryFee: (map['entryFee'] ?? 0) is double
          ? (map['entryFee'] as double).toInt()
          : (map['entryFee'] ?? 0),
      distributionType: map['distributionType'] ?? 'random',
      isPublic: map['isPublic'] ?? false,
      message: map['message'],
      status: map['status'] ?? 'active',
      createdAt: created,
      unlocksAt: unlocks,
      expiresAt: expires,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'maxWinners': maxWinners,
      'claimedCount': claimedCount,
      'entryFee': entryFee,
      'distributionType': distributionType,
      'isPublic': isPublic,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'unlocksAt': Timestamp.fromDate(unlocksAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isUnlocked => DateTime.now().isAfter(unlocksAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isFull => claimedCount >= maxWinners;
  bool get isActive => status == 'active' && !isExpired && !isFull;

  int get secondsUntilUnlock {
    final diff = unlocksAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

class LuckyBagClaimModel {
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rewardAmount;
  final bool isLuckyKing;
  final DateTime claimedAt;

  LuckyBagClaimModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rewardAmount,
    this.isLuckyKing = false,
    required this.claimedAt,
  });

  factory LuckyBagClaimModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return LuckyBagClaimModel(
      userId: map['userId'] ?? id,
      userName: map['userName'] ?? 'User',
      userAvatar: map['userAvatar'],
      rewardAmount: (map['rewardAmount'] ?? 0) is double
          ? (map['rewardAmount'] as double).toInt()
          : (map['rewardAmount'] ?? 0),
      isLuckyKing: map['isLuckyKing'] ?? false,
      claimedAt: parseDate(map['claimedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'rewardAmount': rewardAmount,
      'isLuckyKing': isLuckyKing,
      'claimedAt': Timestamp.fromDate(claimedAt),
    };
  }
}
