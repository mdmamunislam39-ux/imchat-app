import 'package:equatable/equatable.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

/// Emoji category model
class EmojiCategory extends Equatable {
  final String id;
  final String name;
  final String displayName;
  final String iconUrl;
  final int order;
  final bool isActive;

  const EmojiCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.iconUrl,
    required this.order,
    this.isActive = true,
  });

  factory EmojiCategory.fromJson(Map<String, dynamic> json) {
    return EmojiCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'iconUrl': iconUrl,
      'order': order,
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [id, name, displayName, iconUrl, order, isActive];
}

/// Individual emoji model
class EmojiItem extends Equatable {
  final String id;
  final String name;
  final String displayName;
  final String emojiUrl;
  final String categoryId;
  final int order;
  final bool isActive;
  final bool isAnimated;
  final String? soundUrl;

  const EmojiItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.emojiUrl,
    required this.categoryId,
    required this.order,
    this.isActive = true,
    this.isAnimated = false,
    this.soundUrl,
  });

  factory EmojiItem.fromJson(Map<String, dynamic> json) {
    return EmojiItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      emojiUrl: json['emojiUrl'] ?? json['emoji_url'] ?? '',
      categoryId: json['categoryId'] ?? '',
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
      isAnimated: json['isAnimated'] ?? false,
      soundUrl: json['soundUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'emojiUrl': emojiUrl,
      'categoryId': categoryId,
      'order': order,
      'isActive': isActive,
      'isAnimated': isAnimated,
      'soundUrl': soundUrl,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        displayName,
        emojiUrl,
        categoryId,
        order,
        isActive,
        isAnimated,
        soundUrl,
      ];
}

/// Emoji message type for chat
enum EmojiMessageType {
  text,
  emoji,
  mixed,
  join,
  leave,
  gift,
  announcement,
  vote,
  voteResult,
  rouletteResult,
}

/// Enhanced chat message with emoji support
class EmojiChatMessage extends Equatable {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String message;
  final EmojiMessageType messageType;
  final EmojiItem? emojiItem;
  final DateTime timestamp;
  final String roomId;
  final String? giftImageUrl;
  final int? giftCredits;
  final String? replyToMessageId;
  final String? replyToUsername;
  final String? replyToText;
  final String? senderLevelBadgeUrl;

  const EmojiChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.message,
    this.messageType = EmojiMessageType.text,
    this.emojiItem,
    required this.timestamp,
    required this.roomId,
    this.giftImageUrl,
    this.giftCredits,
    this.replyToMessageId,
    this.replyToUsername,
    this.replyToText,
    this.senderLevelBadgeUrl,
  });

  factory EmojiChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime timestamp;
    if (json['timestamp'] is DateTime) {
      timestamp = json['timestamp'] as DateTime;
    } else if (json['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
    } else {
      timestamp = DateTime.now(); // Fallback
    }

    return EmojiChatMessage(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      message: json['message'] ?? '',
      messageType: EmojiMessageType.values.firstWhere(
        (e) => e.name == json['messageType'],
        orElse: () => EmojiMessageType.text,
      ),
      emojiItem: json['emojiItem'] != null
          ? EmojiItem.fromJson(json['emojiItem'])
          : null,
      timestamp: timestamp,
      roomId: json['roomId'] ?? '',
      giftImageUrl: json['giftImageUrl'],
      giftCredits: json['giftCredits'],
      replyToMessageId: json['replyToMessageId'],
      replyToUsername: json['replyToUsername'],
      replyToText: json['replyToText'],
      senderLevelBadgeUrl: json['senderLevelBadgeUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'message': message,
      'messageType': messageType.name,
      'emojiItem': emojiItem?.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'roomId': roomId,
      'giftImageUrl': giftImageUrl,
      'giftCredits': giftCredits,
      'replyToMessageId': replyToMessageId,
      'replyToUsername': replyToUsername,
      'replyToText': replyToText,
      'senderLevelBadgeUrl': senderLevelBadgeUrl,
    };
  }

  /// Create from regular ChatMessage
  factory EmojiChatMessage.fromChatMessage(ChatMessage chatMessage) {
    return EmojiChatMessage(
      id: chatMessage.id,
      userId: chatMessage.userId,
      username: chatMessage.username,
      userAvatar: chatMessage.userAvatar,
      message: chatMessage.message,
      messageType: EmojiMessageType.text,
      timestamp: chatMessage.timestamp,
      roomId: chatMessage.roomId,
    );
  }

  /// Convert to regular ChatMessage for backward compatibility
  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id,
      userId: userId,
      username: username,
      userAvatar: userAvatar,
      message: message,
      timestamp: timestamp,
      roomId: roomId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        username,
        userAvatar,
        message,
        messageType,
        emojiItem,
        timestamp,
        roomId,
        giftImageUrl,
        giftCredits,
        replyToMessageId,
        replyToUsername,
        replyToText,
        senderLevelBadgeUrl,
      ];
}
