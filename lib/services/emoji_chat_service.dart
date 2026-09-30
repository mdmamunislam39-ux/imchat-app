import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/ban_service.dart';
import 'package:chat_messenger/services/backend_engine_manager.dart';
import 'package:get/get.dart';

/// Service for sending emoji messages in audio rooms
class EmojiChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, List<EmojiChatMessage>> _vpsRoomMessages = {};
  static final StreamController<String> _vpsRoomUpdateNotifier = StreamController<String>.broadcast();
  static bool _socketListenerAttached = false;

  static void _ensureVpsSocketListener() {
    if (_socketListenerAttached) return;
    _socketListenerAttached = true;
    final vpsSocket = BackendEngineManager.instance.socketService;
    vpsSocket.roomMessageStream.listen((data) {
      try {
        final incomingRoomId = data['roomId']?.toString().trim() ?? data['room_id']?.toString().trim() ?? '';
        if (incomingRoomId.isEmpty) return;

        final roomMessages = _vpsRoomMessages.putIfAbsent(incomingRoomId, () => []);
        final extra = (data['extraData'] is Map)
            ? Map<String, dynamic>.from(data['extraData'])
            : ((data['extra_data'] is Map) ? Map<String, dynamic>.from(data['extra_data']) : {});
        final msgId = data['id']?.toString() ?? extra['id']?.toString() ?? '';
        if (msgId.isNotEmpty && roomMessages.any((m) => m.id == msgId)) {
          return;
        }

        final msgTypeStr = data['messageType']?.toString() ?? data['message_type']?.toString() ?? 'text';
        final msgType = EmojiMessageType.values.firstWhere(
          (e) => e.name == msgTypeStr,
          orElse: () => EmojiMessageType.text,
        );

        final timestamp = data['createdAt'] != null || data['created_at'] != null
            ? (DateTime.tryParse((data['createdAt'] ?? data['created_at']).toString())?.toLocal() ?? DateTime.now())
            : DateTime.now();

        final emojiUrl = extra['emojiUrl']?.toString() ?? extra['emoji_url']?.toString();
        final emojiName = extra['emojiName']?.toString() ?? extra['emoji_name']?.toString() ?? 'emoji';

        final emojiItem = (emojiUrl != null && emojiUrl.isNotEmpty)
            ? EmojiItem(
                id: emojiName,
                name: emojiName,
                displayName: data['content']?.toString() ?? '',
                emojiUrl: emojiUrl,
                categoryId: 'general',
                order: 0,
              )
            : null;

        final msg = EmojiChatMessage(
          id: msgId,
          userId: data['senderId']?.toString() ?? data['sender_id']?.toString() ?? '',
          username: extra['username']?.toString() ?? extra['userName']?.toString() ?? extra['user_name']?.toString() ?? 'User',
          userAvatar: extra['userAvatar']?.toString() ?? extra['user_avatar']?.toString(),
          message: data['content']?.toString() ?? '',
          messageType: msgType,
          emojiItem: emojiItem,
          timestamp: timestamp,
          roomId: incomingRoomId,
          giftImageUrl: extra['giftImageUrl']?.toString() ?? extra['gift_image_url']?.toString(),
          giftCredits: (extra['giftCredits'] is num)
              ? (extra['giftCredits'] as num).toInt()
              : ((extra['gift_credits'] is num) ? (extra['gift_credits'] as num).toInt() : null),
          replyToMessageId: extra['replyToMessageId']?.toString() ?? extra['reply_to_message_id']?.toString(),
          replyToUsername: extra['replyToUsername']?.toString() ?? extra['reply_to_username']?.toString(),
          replyToText: extra['replyToText']?.toString() ?? extra['reply_to_text']?.toString(),
          senderLevelBadgeUrl: extra['senderLevelBadgeUrl']?.toString() ?? extra['sender_level_badge_url']?.toString(),
        );

        roomMessages.add(msg);
        if (roomMessages.length > 100) roomMessages.removeAt(0);
        _vpsRoomUpdateNotifier.add(incomingRoomId);
      } catch (e) {
        debugPrint('[EmojiChatService] Error processing VPS room message: $e');
      }
    });
  }

  static void _addLocalVpsMessage(String roomId, EmojiChatMessage msg) {
    _ensureVpsSocketListener();
    final list = _vpsRoomMessages.putIfAbsent(roomId, () => []);
    if (!list.any((m) => m.id == msg.id)) {
      list.add(msg);
      if (list.length > 100) list.removeAt(0);
      _vpsRoomUpdateNotifier.add(roomId);
    }
  }

  /// Send an emoji message to a room
  static Future<void> sendEmojiMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required EmojiItem emoji,
    bool updateParticipantStatus = true,
    String? senderLevelBadgeUrl,
  }) async {
    try {
      if (BanService.isChatBanned(AuthController.instance.currentUser)) {
        Get.snackbar('Chat Banned', 'You are temporarily banned from sending messages.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      debugPrint('🎭 [EmojiChatService] Sending emoji message: ${emoji.name}');

      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final emojiMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: emoji.displayName,
        messageType: EmojiMessageType.emoji,
        emojiItem: emoji,
        timestamp: DateTime.now(),
        roomId: roomId,
        senderLevelBadgeUrl: senderLevelBadgeUrl,
      );

      if (BackendEngineManager.isVps) {
        _addLocalVpsMessage(roomId, emojiMessage);
        BackendEngineManager.instance.socketService.sendRoomMessage(
          roomId: roomId,
          content: emoji.displayName,
          messageType: 'emoji',
          extraData: {
            'id': messageId,
            'emojiUrl': emoji.emojiUrl,
            'emojiName': emoji.name,
            'username': username,
            'userAvatar': userAvatar,
            'senderLevelBadgeUrl': senderLevelBadgeUrl,
          },
        );
      }

      // Universal cloud sync to Firestore
      _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(emojiMessage.toJson())
          .catchError((e) => debugPrint('[EmojiChatService] Firestore sync non-fatal error: $e'));

      // Update participant's active emoji status if requested
      if (updateParticipantStatus) {
        await _updateParticipantEmoji(roomId, userId, emoji.emojiUrl);
      }

      debugPrint('🎭 [EmojiChatService] Emoji message sent successfully');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending emoji message: $e');
      throw Exception('Failed to send emoji message: $e');
    }
  }

  /// Send a text message to a room
  static Future<void> sendTextMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required String message,
    String? senderLevelBadgeUrl,
    String? replyToMessageId,
    String? replyToUsername,
    String? replyToText,
  }) async {
    try {
      if (BanService.isChatBanned(AuthController.instance.currentUser)) {
        Get.snackbar('Chat Banned', 'You are temporarily banned from sending messages.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      debugPrint('💬 [EmojiChatService] Sending text message');

      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final textMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: message,
        messageType: EmojiMessageType.text,
        timestamp: DateTime.now(),
        roomId: roomId,
        senderLevelBadgeUrl: senderLevelBadgeUrl,
        replyToMessageId: replyToMessageId,
        replyToUsername: replyToUsername,
        replyToText: replyToText,
      );

      if (BackendEngineManager.isVps) {
        _addLocalVpsMessage(roomId, textMessage);
        BackendEngineManager.instance.socketService.sendRoomMessage(
          roomId: roomId,
          content: message,
          messageType: 'text',
          extraData: {
            'id': messageId,
            'username': username,
            'userAvatar': userAvatar,
            'senderLevelBadgeUrl': senderLevelBadgeUrl,
            'replyToMessageId': replyToMessageId,
            'replyToUsername': replyToUsername,
            'replyToText': replyToText,
          },
        );
      }

      // Universal cloud sync to Firestore
      _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(textMessage.toJson())
          .catchError((e) => debugPrint('[EmojiChatService] Firestore sync non-fatal error: $e'));

      debugPrint('💬 [EmojiChatService] Text message sent successfully');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending text message: $e');
      throw Exception('Failed to send text message: $e');
    }
  }

  /// Send a dice roll message to a room and trigger the dice animation
  static Future<void> sendDiceMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required int rolledNumber,
    String? senderLevelBadgeUrl,
    String diceStyle = 'classic',
  }) async {
    try {
      if (BanService.isChatBanned(AuthController.instance.currentUser)) {
        Get.snackbar('Chat Banned', 'You are temporarily banned from sending messages.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      debugPrint('🎲 [EmojiChatService] Sending dice message ($diceStyle)');

      final bool isBlue = diceStyle == 'blue';
      final diceEmoji = EmojiItem(
        id: isBlue ? 'local_blue_dice_action' : 'local_dice_action',
        name: isBlue ? 'blue_dice_$rolledNumber' : 'dice_$rolledNumber',
        displayName: isBlue ? 'Blue Dice $rolledNumber' : 'Dice $rolledNumber',
        emojiUrl: isBlue ? 'local_blue_dice:$rolledNumber' : 'local_dice:$rolledNumber',
        categoryId: 'activity',
        order: 0,
      );

      await sendEmojiMessage(
        roomId: roomId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        emoji: diceEmoji,
        updateParticipantStatus: true,
        senderLevelBadgeUrl: senderLevelBadgeUrl,
      );
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending dice message: $e');
      throw Exception('Failed to send dice message: $e');
    }
  }

  /// Send a presence message (join/leave)
  static Future<void> sendPresenceMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required bool isJoin,
  }) async {
    try {
      debugPrint(
          '🚪 [EmojiChatService] Sending presence message: ${isJoin ? 'JOIN' : 'LEAVE'}');

      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final presenceMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: isJoin ? 'joined' : 'left',
        messageType: isJoin ? EmojiMessageType.join : EmojiMessageType.leave,
        timestamp: DateTime.now(),
        roomId: roomId,
      );

      if (BackendEngineManager.isVps) {
        _addLocalVpsMessage(roomId, presenceMessage);
        BackendEngineManager.instance.socketService.sendRoomMessage(
          roomId: roomId,
          content: isJoin ? 'joined' : 'left',
          messageType: isJoin ? 'join' : 'leave',
          extraData: {
            'id': messageId,
            'username': username,
            'userAvatar': userAvatar,
          },
        );
        return;
      }

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(presenceMessage.toJson());
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending presence message: $e');
    }
  }

  /// Send a gift message notification to chat
  static Future<void> sendGiftMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required String giftName,
    required String giftImageUrl,
    String? receiverName,
    int? giftCredits,
    String? senderLevelBadgeUrl,
  }) async {
    try {
      debugPrint('🎁 [EmojiChatService] Sending gift message: $giftName to $receiverName');

      final String message = '$giftName|||${receiverName ?? ''}';

      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final giftMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: message,
        messageType: EmojiMessageType.gift,
        timestamp: DateTime.now(),
        roomId: roomId,
        giftImageUrl: giftImageUrl,
        giftCredits: giftCredits,
        senderLevelBadgeUrl: senderLevelBadgeUrl,
      );

      if (BackendEngineManager.isVps) {
        _addLocalVpsMessage(roomId, giftMessage);
        BackendEngineManager.instance.socketService.sendRoomMessage(
          roomId: roomId,
          content: message,
          messageType: 'gift',
          extraData: {
            'id': messageId,
            'username': username,
            'userAvatar': userAvatar,
            'giftImageUrl': giftImageUrl,
            'giftCredits': giftCredits,
            'senderLevelBadgeUrl': senderLevelBadgeUrl,
            'receiverName': receiverName,
          },
        );
        return;
      }

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(giftMessage.toJson());
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending gift message: $e');
    }
  }

  /// Send a lucky win notification to chat
  static Future<void> sendLuckyWinMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required String giftName,
    required int multiplier,
    required int wonDiamonds,
    String? giftImageUrl,
  }) async {
    try {
      debugPrint('🎉 [EmojiChatService] Sending Lucky Win message: $username won ${multiplier}x ($wonDiamonds diamonds)');

      final message = '🎉 $username opened $giftName and WON ${multiplier}x Multiplier! (+$wonDiamonds 💎)';

      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final luckyMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: message,
        messageType: EmojiMessageType.rouletteResult,
        timestamp: DateTime.now(),
        roomId: roomId,
        giftImageUrl: giftImageUrl,
        giftCredits: wonDiamonds,
      );

      if (BackendEngineManager.isVps) {
        _addLocalVpsMessage(roomId, luckyMessage);
        BackendEngineManager.instance.socketService.sendRoomMessage(
          roomId: roomId,
          content: message,
          messageType: 'rouletteResult',
          extraData: {
            'id': messageId,
            'username': username,
            'userAvatar': userAvatar,
            'giftImageUrl': giftImageUrl,
            'giftCredits': wonDiamonds,
          },
        );
        return;
      }

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(luckyMessage.toJson());
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending lucky win message: $e');
    }
  }

  /// Get enhanced chat messages stream with emoji support
  static Stream<List<EmojiChatMessage>> getEmojiChatMessagesStream(
      String roomId) {
    _ensureVpsSocketListener();
    if (BackendEngineManager.isVps) {
      final vpsSocket = BackendEngineManager.instance.socketService;
      vpsSocket.joinRoom(roomId);
    }

    final roomMessages = _vpsRoomMessages.putIfAbsent(roomId, () => []);

    late StreamController<List<EmojiChatMessage>> controller;
    StreamSubscription? updateSub;
    StreamSubscription? fsSub;

    controller = StreamController<List<EmojiChatMessage>>.broadcast(
      onListen: () {
        // 1. Immediately emit current in-memory messages
        if (roomMessages.isNotEmpty) {
          controller.add(List<EmojiChatMessage>.from(roomMessages));
        }

        // 2. Listen to VPS Socket updates (0ms real-time)
        updateSub = _vpsRoomUpdateNotifier.stream.listen((updatedRoomId) {
          if (updatedRoomId == roomId || updatedRoomId.isEmpty) {
            if (!controller.isClosed) {
              final sorted = List<EmojiChatMessage>.from(roomMessages);
              sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              controller.add(sorted);
            }
          }
        });

        // 3. Listen to Firestore collection in real-time as universal cloud stream
        fsSub = _firestore
            .collection('audio_rooms_v2')
            .doc(roomId)
            .collection('chat')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots()
            .listen((snapshot) {
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              if (data['timestamp'] is Timestamp) {
                data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is int) {
                data['timestamp'] =
                    DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
              } else if (data['timestamp'] is! DateTime) {
                data['timestamp'] = DateTime.now();
              }
              final msg = EmojiChatMessage.fromJson(data);
              if (!roomMessages.any((m) => m.id == msg.id)) {
                roomMessages.add(msg);
              }
            } catch (e) {
              debugPrint('[EmojiChatService] Error parsing snapshot message: $e');
            }
          }
          if (roomMessages.length > 100) {
            roomMessages.removeRange(0, roomMessages.length - 100);
          }
          if (!controller.isClosed) {
            final sorted = List<EmojiChatMessage>.from(roomMessages);
            sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(sorted);
          }
        }, onError: (e) {
          debugPrint('[EmojiChatService] Firestore room chat listener error: $e');
        });
      },
      onCancel: () {
        updateSub?.cancel();
        fsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Get regular chat messages stream (for backward compatibility)
  static Stream<List<ChatMessage>> getChatMessagesStream(String roomId) {
    if (BackendEngineManager.isVps) {
      return getEmojiChatMessagesStream(roomId).map((emojiMessages) {
        return emojiMessages.map((e) => e.toChatMessage()).toList();
      });
    }

    return _firestore
        .collection('audio_rooms_v2')
        .doc(roomId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              // Handle different timestamp formats
              if (data['timestamp'] is Timestamp) {
                data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is int) {
                data['timestamp'] =
                    DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
              } else if (data['timestamp'] is DateTime) {
                // Already correct format
              } else {
                // Fallback to current time
                data['timestamp'] = DateTime.now();
              }
              // Convert EmojiChatMessage to ChatMessage if needed
              if (data.containsKey('messageType')) {
                final emojiMessage = EmojiChatMessage.fromJson(data);
                return emojiMessage.toChatMessage();
              } else {
                return ChatMessage.fromJson(data);
              }
            } catch (e) {
              debugPrint(
                  '💬 [EmojiChatService] Error parsing chat message: $e');
              return null;
            }
          })
          .where((message) => message != null)
          .cast<ChatMessage>()
          .toList();
    });
  }

  /// Delete a chat message
  static Future<void> deleteMessage(String roomId, String messageId) async {
    try {
      debugPrint('🗑️ [EmojiChatService] Deleting message: $messageId');

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .delete();

      debugPrint('🗑️ [EmojiChatService] Message deleted successfully');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error deleting message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Report a chat message
  static Future<void> reportMessage({
    required String roomId,
    required String messageId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      debugPrint('🚨 [EmojiChatService] Reporting message: $messageId');

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .update({
        'reportedBy': reporterId,
        'reportReason': reason,
        'reportedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🚨 [EmojiChatService] Message reported successfully');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error reporting message: $e');
      throw Exception('Failed to report message: $e');
    }
  }

  /// Update participant's active emoji in Firestore and clear it after delay
  static Future<void> _updateParticipantEmoji(
      String roomId, String userId, String emojiUrl) async {
    try {
      final roomRef = _firestore.collection('audio_rooms_v2').doc(roomId);
      final roomDoc = await roomRef.get().timeout(const Duration(seconds: 15));

      if (!roomDoc.exists) return;

      final data = roomDoc.data() as Map<String, dynamic>;
      final participants =
          List<Map<String, dynamic>>.from(data['participants'] ?? []);

      final index = participants.indexWhere((p) => p['userId'] == userId);
      if (index == -1) return;

      // Update emoji
      debugPrint(
          '🎭 [EmojiChatService] Updating participant $userId with emoji $emojiUrl');
      participants[index]['activeEmojiUrl'] = emojiUrl;

      await roomRef.update({'participants': participants});
      debugPrint(
          '🎭 [EmojiChatService] Participant emoji updated in Firestore');

      // Clear after 3 seconds
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          debugPrint('🎭 [EmojiChatService] Clearing emoji for $userId');
          final currentDoc = await roomRef.get().timeout(const Duration(seconds: 15));
          if (!currentDoc.exists) return;

          final currentData = currentDoc.data() as Map<String, dynamic>;
          final currentParticipants = List<Map<String, dynamic>>.from(
              currentData['participants'] ?? []);

          final currentIndex =
              currentParticipants.indexWhere((p) => p['userId'] == userId);
          if (currentIndex == -1) return;

          // Only clear if it's still the same emoji (to avoid clearing a more recent emoji)
          if (currentParticipants[currentIndex]['activeEmojiUrl'] == emojiUrl) {
            currentParticipants[currentIndex]['activeEmojiUrl'] = null;
            await roomRef.update({'participants': currentParticipants});
            debugPrint(
                '🎭 [EmojiChatService] Participant emoji cleared in Firestore');
          } else {
            debugPrint(
                '🎭 [EmojiChatService] Skip clearing: emoji already changed or cleared');
          }
        } catch (e) {
          debugPrint(
              '❌ [EmojiChatService] Error clearing participant emoji: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error updating participant emoji: $e');
    }
  }

  /// Delete messages older than 30 minutes
  static Future<void> cleanupOldMessages(String roomId) async {
    try {
      debugPrint(
          '🧹 [EmojiChatService] Cleaning up old messages for room: $roomId');

      // Calculate timestamp 30 minutes ago
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 30));

      final snapshot = await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .where('timestamp', isLessThan: cutoffTime)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('🧹 [EmojiChatService] No old messages found to delete');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
          '🧹 [EmojiChatService] Deleted ${snapshot.docs.length} old messages');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error cleaning up messages: $e');
    }
  }

  /// Delete ALL messages in the room (Clear Chat)
  static Future<void> clearAllMessages(String roomId) async {
    try {
      debugPrint(
          '🧹 [EmojiChatService] Clearing ALL messages for room: $roomId');

      // Get all messages
      // Note: Firestore batch limit is 500. If more than 500, we need loop.
      // For simplicity/performance, we'll do batches of 500.
      bool hasMore = true;
      while (hasMore) {
        final snapshot = await _firestore
            .collection('audio_rooms_v2')
            .doc(roomId)
            .collection('chat')
            .limit(500)
            .get();

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        debugPrint(
            '🧹 [EmojiChatService] Cleared batch of ${snapshot.docs.length} messages');
      }

      debugPrint('🧹 [EmojiChatService] All messages cleared successfully');
    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error clearing all messages: $e');
      throw Exception('Failed to clear messages: $e');
    }
  }
  /// Send a vote message (e.g. "Voted for 1 yes >")
  static Future<void> sendVoteMessage({
    required String roomId,
    required String userId,
    required String username,
    String? userAvatar,
    required int optionIndex,
    required String optionText,
  }) async {
    try {
      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final voteMessage = EmojiChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: 'Voted for ${optionIndex + 1} $optionText',
        messageType: EmojiMessageType.vote,
        timestamp: DateTime.now(),
        roomId: roomId,
      );

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(voteMessage.toJson());

    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending vote message: $e');
    }
  }

  /// Send a voting result/summary message
  static Future<void> sendVoteResultMessage({
    required String roomId,
    required String message,
  }) async {
    try {
      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final voteResultMessage = EmojiChatMessage(
        id: messageId,
        userId: 'system',
        username: 'System',
        message: message,
        messageType: EmojiMessageType.voteResult,
        timestamp: DateTime.now(),
        roomId: roomId,
      );

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(voteResultMessage.toJson());

    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending vote result message: $e');
    }
  }

  /// Send a roulette result message
  static Future<void> sendRouletteResultMessage(String roomId, String result) async {
    try {
      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final rouletteMessage = EmojiChatMessage(
        id: messageId,
        userId: 'system',
        username: 'System',
        message: 'Game Result: $result',
        messageType: EmojiMessageType.rouletteResult,
        timestamp: DateTime.now(),
        roomId: roomId,
      );

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(rouletteMessage.toJson());

    } catch (e) {
      debugPrint('❌ [EmojiChatService] Error sending roulette result message: $e');
    }
  }
}
