import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';

import 'package:chat_messenger/services/backend_engine_manager.dart';

abstract class ChatApi {
  //
  // ChatApi - CRUD Operations
  //

  // Firestore instance
  static final _firestore = FirebaseFirestore.instance;

  // Save chat for both users
  static Future<void> saveChat({
    required String userId1,
    required String userId2,
    required Message message,
  }) async {
    try {
      // Get chat instance
      final Chat chat = Chat(
        senderId: userId1,
        msgType: message.type,
        lastMsg: message.textMsg,
        msgId: message.msgId,
      );

      await Future.wait([
        // Save chat in current user collection
        _firestore
            .collection('Users/$userId1/Chats')
            .doc(userId2)
            .set(chat.toMap(false), SetOptions(merge: true)),

        // Save inverse chat copy for another user
        _firestore
            .collection('Users/$userId2/Chats')
            .doc(userId1)
            .set(chat.toMap(true), SetOptions(merge: true)),
      ]);

      // Debug
      debugPrint('saveChat() -> success');
    } catch (e) {
      debugPrint('saveChat() -> error: $e');
    }
  }

  static Stream<List<Chat>> getChats() {
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      late StreamController<List<Chat>> controller;
      StreamSubscription? sub;
      StreamSubscription? fsSub;
      Timer? debounceTimer;
      bool isFetching = false;
      late void Function() scheduleFetch;

      Future<void> fetchAndEmit() async {
        if (isFetching) return;
        isFetching = true;
        try {
          final chatsData = await vpsApi.getDirectChats();
          final List<Chat> chats = [];
          for (var item in chatsData) {
            final otherUserId = item['other_user_id']?.toString() ?? '';
            if (otherUserId.isEmpty) continue;

            // Fast lookup in memory cache first, or build from SQL fields directly (0ms, 0 network blocking!)
            User? receiver = UserApi.getCachedUser(otherUserId);
            if (receiver == null) {
              receiver = User(
                userId: otherUserId,
                fullname: item['other_user_name'] ?? 'User',
                photoUrl: item['other_user_avatar'] ?? '',
                isOnline: item['other_user_online'] == true,
              );
              UserApi.cacheUser(receiver);
            } else if (item['other_user_online'] != null) {
              receiver.isOnline = item['other_user_online'] == true;
            }

            final lastMsg = item['last_message_text'] ?? '';
            final msgTypeStr = item['last_message_type'] ?? 'text';
            final sentAtStr = item['last_message_at'];
            final DateTime? sentAt = sentAtStr != null ? DateTime.tryParse(sentAtStr.toString())?.toLocal() : null;
            chats.add(Chat(
              senderId: item['last_message_sender_id'] ?? '',
              receiver: receiver,
              lastMsg: lastMsg,
              msgType: Message.getMsgType(msgTypeStr),
              sentAt: sentAt,
              unread: (item['unread_count'] is num) ? (item['unread_count'] as num).toInt() : 0,
            ));
          }

          // Merge with previous Firestore chat nodes so all past conversations remain visible
          final User currentUser = AuthController.instance.currentUser;
          if (currentUser.userId.isNotEmpty) {
            try {
              final existingOtherUserIds = chats.map((c) => c.receiver?.userId).toSet();
              final fsSnap = await _firestore
                  .collection('Users/${currentUser.userId}/Chats')
                  .orderBy('sentAt', descending: true)
                  .limit(30)
                  .get();

              final List<Future<void>> missingUserFetches = [];

              for (var doc in fsSnap.docs) {
                final otherId = doc.id;
                if (!existingOtherUserIds.contains(otherId)) {
                  User? receiver = UserApi.getCachedUser(otherId);
                  if (receiver == null) {
                    receiver = User(userId: otherId, fullname: 'User');
                    missingUserFetches.add(
                      UserApi.getUser(otherId).then((u) {
                        if (u != null) UserApi.cacheUser(u);
                      }).catchError((_) => null),
                    );
                  }
                  chats.add(Chat.fromMap(doc.data(), doc: doc, receiver: receiver));
                  existingOtherUserIds.add(otherId);
                }
              }

              if (missingUserFetches.isNotEmpty) {
                Future.wait(missingUserFetches).then((_) {
                  if (!controller.isClosed) {
                    scheduleFetch();
                  }
                });
              }

              chats.sort((a, b) {
                final tA = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final tB = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return tB.compareTo(tA);
              });
            } catch (_) {}
          }

          if (!controller.isClosed) {
            controller.add(chats);
          }
        } catch (e) {
          debugPrint('[ChatApi] VPS getChats notice: $e');
        } finally {
          isFetching = false;
        }
      }

      scheduleFetch = () {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 150), () {
          fetchAndEmit();
        });
      };

      controller = StreamController<List<Chat>>.broadcast(
        onListen: () {
          fetchAndEmit();
          sub = vpsSocket.directMessageStream.listen((_) => scheduleFetch());

          final User currentUser = AuthController.instance.currentUser;
          if (currentUser.userId.isNotEmpty) {
            fsSub = _firestore
                .collection('Users/${currentUser.userId}/Chats')
                .orderBy('sentAt', descending: true)
                .snapshots()
                .listen((_) => scheduleFetch(), onError: (_) {});
          }
        },
        onCancel: () {
          debounceTimer?.cancel();
          sub?.cancel();
          fsSub?.cancel();
        },
      );

      return controller.stream;
    }

    // Default Firebase Mode - Non-blocking, instant 0ms cached stream
    final User currentUer = AuthController.instance.currentUser;

    return _firestore
        .collection('Users/${currentUer.userId}/Chats')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .asyncMap((event) async {
          final List<Chat> chats = [];
          final List<Future<void>> missingFetches = [];

          for (var doc in event.docs) {
            try {
              final data = doc.data();
              User? user = UserApi.getCachedUser(doc.id);
              if (user == null) {
                user = User(userId: doc.id, fullname: 'User');
                missingFetches.add(
                  UserApi.getUser(doc.id).then((u) {
                    if (u != null) UserApi.cacheUser(u);
                  }).catchError((_) => null),
                );
              }
              chats.add(Chat.fromMap(data, doc: doc, receiver: user));
            } catch (e) {
              debugPrint('Error mapping chat doc ${doc.id}: $e');
            }
          }

          if (missingFetches.isNotEmpty) {
            Future.wait(missingFetches).then((_) {});
          }

          return chats;
        });
  }

  // Update Chat Node
  static Future<void> updateChatNode({
    required String userId1,
    required String userId2,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection('Users')
          .doc(userId1)
          .collection('Chats')
          .doc(userId2)
          .set(data, SetOptions(merge: true));
      debugPrint('updateChatNode() -> success');
    } catch (e) {
      debugPrint('updateChatNode() -> error: $e');
    }
  }

  // Update Chat typing status
  static Future<void> updateChatTypingStatus(
    bool isTyping,
    String receiverId,
  ) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateChatNode(
        userId1: receiverId,
        userId2: currentUer.userId,
        data: {'isTyping': isTyping, 'isRecording': false},
      );
      debugPrint('updateChatTypingStatus() -> success');
    } catch (e) {
      debugPrint('updateChatTypingStatus() -> error: $e');
    }
  }

  // Update Chat recording status
  static Future<void> updateChatRecordingStatus(
    bool isRecording,
    String receiverId,
  ) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateChatNode(
        userId1: receiverId,
        userId2: currentUer.userId,
        data: {'isRecording': isRecording, 'isTyping': false},
      );
      debugPrint('updateChatRecordingStatus() -> success');
    } catch (e) {
      debugPrint('updateChatRecordingStatus() -> error: $e');
    }
  }

  // Update the Chat Node
  static Future<void> leaveChat(String receiverId) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await Future.wait([
        UserApi.closeTypingOrRecordingStatus(),
        updateChatNode(
          userId1: receiverId,
          userId2: currentUer.userId,
          data: {'isTyping': false, 'isRecording': false, 'unread': 0},
        ),
      ]);
      debugPrint('updateTypingAndRecordingStatus() -> success');
    } catch (e) {
      debugPrint('updateTypingAndRecordingStatus() -> error: $e');
    }
  }

  // Soft delete chat.
  static Future<void> softDeleteChat({
    required String userId1,
    required String userId2,
    required String msgId,
  }) async {
    final User currentUer = AuthController.instance.currentUser;

    // Get Chat instance
    final Chat chat = Chat(
      senderId: currentUer.userId,
      msgType: MessageType.text,
      lastMsg: 'deleted',
      msgId: msgId,
    );
    _firestore
        .collection('Users/$userId1/Chats')
        .doc(userId2)
        .set(chat.toDeletedMap(), SetOptions(merge: true));
  }

  // Reset the last message in chat node.
  static Future<void> resetChat({
    required String userId1,
    required String userId2,
  }) async {
    _firestore.collection('Users/$userId1/Chats').doc(userId2).set({
      'msgType': 'text',
      'lastMsg': null,
      'sentAt': null,
    });
  }

  static Future<void> clearChat({
    required List<Message> messages,
    required String receiverId,
    bool showMessage = true,
  }) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      // Reset the last message in my chat node.
      resetChat(userId1: currentUer.userId, userId2: receiverId);

      // Loop the message futures
      final List<Future<void>> messageFutures = messages
          .map((msg) => msg.docRef!.delete())
          .toList();

      if (messageFutures.isNotEmpty) {
        Future.wait(messageFutures);
      }
      // Debug
      debugPrint("clearChat() -> success");
    } catch (e) {
      // Debug
      debugPrint("clearChat() -> error: $e");
    }
  }

  static Future<void> muteChat({
    required bool isMuted,
    required String receiverId,
  }) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(currentUer.userId)
          .set({'isMuted': isMuted}, SetOptions(merge: true));
      // Debug
      debugPrint("muteChat() -> $isMuted");
    } catch (e) {
      // Debug
      debugPrint("muteChat() -> error: $e");
    }
  }

  static Future<bool> checkMuteStatus(String receiverId) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      final chatDoc = await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(currentUer.userId)
          .get();
      return chatDoc.data()?['isMuted'] ?? false;
    } catch (e) {
      // Debug
      debugPrint("getMuteStatus() -> error: $e");
      return false;
    }
  }

  static Future<void> deleteChat({required String userId}) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      final reference = _firestore.collection(
        'Users/${currentUer.userId}/Chats',
      );

      // Delete messages
      final results = await reference.doc(userId).collection('Messages').get();
      final futures = results.docs.map((e) => e.reference.delete()).toList();
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      // Delete the chat node
      await reference.doc(userId).delete();

      debugPrint('saveChat() -> success');
    } catch (e) {
      debugPrint('saveChat() -> error: $e');
    }
  }
}
