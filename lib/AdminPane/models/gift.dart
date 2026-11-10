import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Gift model for Firebase storage
class Gift extends Equatable {
  final String id;
  final String name;
  final String category;
  final int credits;
  final String? pngUrl; // PNG file URL for display
  final String? svgaUrl; // SVGA file URL for animation
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int? showingTimeSeconds;

  const Gift({
    required this.id,
    required this.name,
    required this.category,
    required this.credits,
    this.pngUrl,
    this.svgaUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.showingTimeSeconds,
  });

  /// Create from JSON
  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      credits: json['credits'] is int ? json['credits'] : int.tryParse(json['credits']?.toString() ?? '0') ?? 0,
      pngUrl: json['pngUrl']?.toString() ?? json['imageUrl']?.toString(),
      svgaUrl: json['svgaUrl']?.toString(),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      showingTimeSeconds: json['showingTimeSeconds'] is int
          ? json['showingTimeSeconds']
          : int.tryParse(json['showingTimeSeconds']?.toString() ?? json['showingTime']?.toString() ?? ''),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'credits': credits,
      'pngUrl': pngUrl,
      'svgaUrl': svgaUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      if (showingTimeSeconds != null) 'showingTimeSeconds': showingTimeSeconds,
    };
  }

  /// Create a copy with updated fields
  Gift copyWith({
    String? id,
    String? name,
    String? category,
    int? credits,
    String? pngUrl,
    String? svgaUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? showingTimeSeconds,
  }) {
    return Gift(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      credits: credits ?? this.credits,
      pngUrl: pngUrl ?? this.pngUrl,
      svgaUrl: svgaUrl ?? this.svgaUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      showingTimeSeconds: showingTimeSeconds ?? this.showingTimeSeconds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        credits,
        pngUrl,
        svgaUrl,
        createdAt,
        updatedAt,
        isActive,
        showingTimeSeconds,
      ];
}

/// Gift transaction model for tracking sent gifts
class GiftTransaction extends Equatable {
  final String id;
  final String giftId;
  final String giftName;
  final String giftPngUrl;
  final String? giftSvgaUrl;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;
  final String roomId;
  final int credits;
  final int quantity;
  final int beansToReceiver;
  final bool isComboHit;
  final DateTime timestamp;
  final int? showingTimeSeconds;

  const GiftTransaction({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.giftPngUrl,
    this.giftSvgaUrl,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
    required this.roomId,
    required this.credits,
    this.quantity = 1,
    this.beansToReceiver = 0,
    this.isComboHit = false,
    required this.timestamp,
    this.showingTimeSeconds,
  });

  /// Create from JSON
  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    final int credits = json['credits'] is int
        ? json['credits']
        : int.tryParse(json['credits']?.toString() ?? '0') ?? 0;
    final int quantity = json['quantity'] is int
        ? json['quantity']
        : int.tryParse(json['quantity']?.toString() ??
                json['count']?.toString() ??
                '1') ??
            1;
    final int beans = json['beansToReceiver'] is int
        ? json['beansToReceiver']
        : int.tryParse(json['beansToReceiver']?.toString() ?? '') ??
            (credits * quantity);

    return GiftTransaction(
      id: json['id'] ?? '',
      giftId: json['giftId'] ?? '',
      giftName: json['giftName'] ?? '',
      giftPngUrl: json['giftPngUrl'] ?? '',
      giftSvgaUrl: json['giftSvgaUrl'],
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderImageUrl: json['senderImageUrl'],
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverImageUrl: json['receiverImageUrl'],
      roomId: json['roomId'] ?? '',
      credits: credits,
      quantity: quantity,
      beansToReceiver: beans,
      isComboHit: json['isComboHit'] == true,
      timestamp: Gift._parseTimestamp(json['timestamp']),
      showingTimeSeconds: json['showingTimeSeconds'] is int
          ? json['showingTimeSeconds']
          : int.tryParse(json['showingTimeSeconds']?.toString() ?? json['showingTime']?.toString() ?? ''),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giftId': giftId,
      'giftName': giftName,
      'giftPngUrl': giftPngUrl,
      'giftSvgaUrl': giftSvgaUrl,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImageUrl': receiverImageUrl,
      'roomId': roomId,
      'credits': credits,
      'quantity': quantity,
      'beansToReceiver': beansToReceiver,
      'isComboHit': isComboHit,
      'timestamp': Timestamp.fromDate(timestamp),
      if (showingTimeSeconds != null) 'showingTimeSeconds': showingTimeSeconds,
    };
  }

  @override
  List<Object?> get props => [
        id,
        giftId,
        giftName,
        giftPngUrl,
        giftSvgaUrl,
        senderId,
        senderName,
        senderImageUrl,
        receiverId,
        receiverName,
        receiverImageUrl,
        roomId,
        credits,
        quantity,
        beansToReceiver,
        isComboHit,
        timestamp,
        showingTimeSeconds,
      ];
}
