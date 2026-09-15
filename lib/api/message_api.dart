import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/group_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/group.dart';

import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/chat_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/push_notification_service.dart';

abstract class MessageApi {
  //
  // MessageApi - CRUD Operations
  //

  // Firestore instance
  static final _firestore = FirebaseFirestore.instance;
  static final _setOptions = SetOptions(merge: true);

  // Get Messages collection reference
  static CollectionReference<Map<String, dynamic>> _getCollectionRef({
    required String userId1,
    required String userId2,
  }) {
    return _firestore.collection('Users/$userId1/Chats/$userId2/Messages');
  }

  // <-- Send 1-to-1 message -->
  static Future<void> sendMessage({
    required Message message,
    required User receiver,
  }) async {
    final User currentUser = AuthController.instance.currentUser;

    // 1. Save message for current user (Sender)
    try {
      await _getCollectionRef(userId1: currentUser.userId, userId2: receiver.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false))
          .timeout(const Duration(seconds: 10));
      debugPrint('saveMessage() -> sender success');
    } catch (e) {
      debugPrint('saveMessage() -> sender error: $e');
    }

    // 2. Save message for another user (Receiver)
    try {
      await _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false))
          .timeout(const Duration(seconds: 10));
      debugPrint('saveMessage() -> receiver success');
    } catch (e) {
      debugPrint('saveMessage() -> receiver error: $e');
    }

    // 3. Save the last chat node for both users
    try {
      await ChatApi.saveChat(
        userId1: currentUser.userId,
        userId2: receiver.userId,
        message: message,
      );
      debugPrint('saveChat() -> success');
    } catch (e) {
      debugPrint('saveChat() -> error: $e');
    }

    // 4. Send push notification to receiver
    try {
      if (receiver.deviceToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: currentUser.fullname,
          body: PushNotificationService.getMessageType(message),
          deviceToken: receiver.deviceToken,
          call: {
            'messageId': message.msgId,
            'senderId': currentUser.userId,
          },
        );
      }
    } catch (e) {
      debugPrint('sendNotification() -> error: $e');
    }
  }

  static Future<void> forwardMessage({
    required Message message,
    required List contacts,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // Handle the contacts list
      final List<User> users = contacts.whereType<User>().toList();
      final List<Group> groups = contacts.whereType<Group>().toList();

      // Update message data
      message.isForwarded = true;
      message.senderId = currentUser.userId;
      message.msgId = AppHelper.generateID;

      // Forward message to selected users
      List<Future> usersMsgFutures = users.map<Future>((user) {
        return sendMessage(message: message, receiver: user);
      }).toList();

      // Send to users
      if (usersMsgFutures.isNotEmpty) {
        Future.wait(usersMsgFutures);
      }

      // Forward message to selected groups
      List<Future> groupsMsgFutures = groups.map<Future>((group) {
        return sendGroupMessage(group: group, message: message);
      }).toList();

      // Send to groups
      if (groupsMsgFutures.isNotEmpty) {
        Future.wait(groupsMsgFutures);
      }

      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'message_forwarded_successfully'.tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  static Future<void> updateUnreadList(Group group) async {
    Map<String, dynamic> updates = {};

    for (final member in group.members) {
      // Construct the update for each member
      updates['unreadList.${member.userId}'] = FieldValue.increment(1);
    }

    // Update all members at once
    await GroupApi.groupsRef.doc(group.groupId).update(updates).timeout(const Duration(seconds: 15));
  }

  static Future<void> saveGroupMessage(
    Group group, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // Create the new Group
      await Future.wait([
        // Update group info
        GroupApi.groupsRef
            .doc(group.groupId)
            .update(data ?? group.toUpdateMap())
            .timeout(const Duration(seconds: 15)),
        // Save the group message
        GroupApi.groupsRef
            .doc(group.groupId)
            .collection('Messages')
            .doc(group.lastMsg!.msgId)
            .set(group.lastMsg!.toMap(isGroup: true))
            .timeout(const Duration(seconds: 15)),
      ]);
      debugPrint('saveGroupMessage() -> success');
    } catch (e) {
      debugPrint('saveGroupMessage() -> error: $e');
    }
  }

  // <-- Send group message -->
  static Future<void> sendGroupMessage({
    required Group group,
    required Message message,
  }) async {
    try {
      // Get sender profile
      final User sender = group.getMemberProfile(message.senderId);

      // Update the last message
      group.lastMsg = message;
      // Save group message
      await saveGroupMessage(group);

      // Hold notify futures
      List<Future<void>> notifyFutures = [];

      // Notify active participants
      for (final member in group.participants) {
        // Remove the sender from the list and make sure the group is not muted.
        if (message.senderId != member.userId &&
            !member.mutedGroups.contains(group.groupId)) {
          // Add notification
          notifyFutures.add(
            PushNotificationService.sendNotification(
              type: NotificationType.group,
              title: group.name,
              body:
                  "${sender.fullname}: ${PushNotificationService.getMessageType(message)}",
              deviceToken: member.deviceToken,
            ),
          );
        }
      }

      // Send push notifications
      await Future.wait(notifyFutures);

      // Debug
      debugPrint('sendGroupMessage() -> success');
    } catch (e) {
      debugPrint('sendGroupMessage() -> error: $e');
    }
  }

  // <-- Send broadcast message -->
  static Future<void> sendBroadcastMessage({
    required Group group,
    required Message message,
  }) async {
    try {
      // Update the group info
      group.lastMsg = message;
      saveGroupMessage(group);

      // Notify the recipients
      List<Future<void>> messageFutures = [];

      // Notify recipients
      for (final receiver in group.recipients) {
        // Add message
        messageFutures.add(sendMessage(message: message, receiver: receiver));
      }

      // Send message
      await Future.wait(messageFutures);

      // Debug
      debugPrint('sendBroadcastMessage() -> success');
    } catch (e) {
      debugPrint('sendBroadcastMessage() -> error: $e');
    }
  }

  // Save call log message (canceled, rejected, missed, completed) for both users
  static Future<void> sendCallLogMessage({
    required bool isVideo,
    required User receiver,
    required String status,
    required int duration,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      final String callType = isVideo ? 'video' : 'audio';
      final String payload = 'call|$callType|$status|$duration';

      final Message message = Message(
        msgId: AppHelper.generateID,
        senderId: currentUser.userId,
        type: MessageType.text,
        textMsg: payload,
      );

      // Save to sender and receiver chat messages and update recent chats
      await MessageApi.sendMessage(
        message: message,
        receiver: receiver,
      );

      // If missed or canceled by caller before answer, notify receiver
      if (status == 'missed' || status == 'canceled') {
        final String notifBody = isVideo
            ? 'you_missed_a_video_call'.tr
            : 'you_missed_a_voice_call'.tr;

        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: currentUser.fullname,
          body: notifBody,
          deviceToken: receiver.deviceToken,
          call: {
            'messageId': message.msgId,
            'senderId': currentUser.userId,
          },
        );
      }

      debugPrint('sendCallLogMessage() -> success (status: $status, duration: $duration)');
    } catch (e) {
      debugPrint('sendCallLogMessage() -> error: $e');
    }
  }

  // Save missed call message for receiver
  static Future<void> sendMissedCallMessage({
    required bool isVideo,
    required User receiver,
  }) async {
    try {
      // Get current user instance
      final User currentUser = AuthController.instance.currentUser;

      // Get correct message
      final String body =
          isVideo ? 'you_missed_a_video_call'.tr : 'you_missed_a_voice_call'.tr;

      // Get Message instance
      final Message message = Message(
        msgId: AppHelper.generateID,
        senderId: currentUser.userId,
        type: MessageType.text,
        textMsg: body,
      );

      // Get chat instance
      final Chat chat = Chat(
        senderId: currentUser.userId,
        msgType: message.type,
        lastMsg: message.textMsg,
        msgId: message.msgId,
      );

      await Future.wait([
        // Save last chat for receiver
        _firestore
            .collection('Users/${receiver.userId}/Chats')
            .doc(currentUser.userId)
            .set(chat.toMap(true), _setOptions),

        // Save message for receiver
        _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
            .doc(message.msgId)
            .set(message.toMap(isGroup: false)),

        // Send push notification to recevier
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: currentUser.fullname,
          body: body,
          deviceToken: receiver.deviceToken,
          call: {
            'messageId': message.msgId,
            'senderId': currentUser.userId,
          },
        ),
      ]);

      // Debug
      debugPrint('saveMissedCallMessage() -> success');
    } catch (e) {
      debugPrint('saveMissedCallMessage() -> error: $e');
    }
  }

  // Get 1-to-1 messages
  static Stream<List<Message>> getMessages(User user) {
    // Get current user
    final User currentUser = AuthController.instance.currentUser;
    final String userId = user.userId;

    if (userId == 'official_team') {
      late StreamController<List<Message>> streamCtrl;
      StreamSubscription? subNotifs;
      StreamSubscription? subChats;
      StreamSubscription? subBroadcasts;

      final Map<String, Message> notifMap = {};
      final Map<String, Message> chatMap = {};
      final Map<String, Message> broadcastMap = {};
      bool hasEmitted = false;

      void emitMerged() {
        if (streamCtrl.isClosed) return;
        final all = <String, Message>{};
        all.addAll(broadcastMap);
        all.addAll(chatMap);
        all.addAll(notifMap);

        final list = all.values.toList();
        list.sort((a, b) {
          final tA = a.sentAt;
          final tB = b.sentAt;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        if (list.isEmpty) {
          final defaultMsg = Message(
            msgId: 'welcome_${currentUser.userId}',
            senderId: 'official_team',
            type: MessageType.text,
            textMsg: '🎉 Welcome ${currentUser.fullname}! Enjoy your experience in our imChat app. Here you will receive all official notices and updates.',
            sentAt: DateTime.now(),
            isRead: true,
          );
          streamCtrl.add([defaultMsg]);
          if (!hasEmitted) {
            OfficialTeamApi.sendWelcomeMessage(currentUser);
          }
        } else {
          streamCtrl.add(list);
        }
        hasEmitted = true;
      }

      streamCtrl = StreamController<List<Message>>(
        onListen: () {
          // 1. official_notifications subcollection
          subNotifs = _firestore
              .collection('Users/${currentUser.userId}/official_notifications')
              .limit(100)
              .snapshots()
              .listen((snapshot) {
            notifMap.clear();
            for (var doc in snapshot.docs) {
              try {
                final msg = Message.fromMap(
                  data: doc.data(),
                  docRef: doc.reference,
                  isGroup: false,
                );
                final id = msg.msgId.isNotEmpty ? msg.msgId : doc.id;
                notifMap[id] = msg;
              } catch (e) {
                debugPrint('Error parsing official_notification doc ${doc.id}: $e');
              }
            }
            emitMerged();
          }, onError: (e) {
            debugPrint('Error in official_notifications stream: $e');
            emitMerged();
          });

          // 2. Chats/official_team/Messages subcollection
          subChats = _firestore
              .collection('Users/${currentUser.userId}/Chats/official_team/Messages')
              .limit(100)
              .snapshots()
              .listen((snapshot) {
            chatMap.clear();
            for (var doc in snapshot.docs) {
              try {
                final msg = Message.fromMap(
                  data: doc.data(),
                  docRef: doc.reference,
                  isGroup: false,
                );
                final id = msg.msgId.isNotEmpty ? msg.msgId : doc.id;
                chatMap[id] = msg;
              } catch (e) {
                debugPrint('Error parsing official chat doc ${doc.id}: $e');
              }
            }
            emitMerged();
          }, onError: (e) {
            debugPrint('Error in official chat stream: $e');
            emitMerged();
          });

          // 3. Central official_broadcasts collection
          subBroadcasts = _firestore
              .collection('official_broadcasts')
              .limit(50)
              .snapshots()
              .listen((snapshot) {
            broadcastMap.clear();
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                DateTime? sentAt;
                if (data['sentAt'] is Timestamp) {
                  sentAt = (data['sentAt'] as Timestamp).toDate();
                } else if (data['sentAt'] is DateTime) {
                  sentAt = data['sentAt'] as DateTime;
                } else if (data['sentAt'] is String) {
                  sentAt = DateTime.tryParse(data['sentAt']);
                }
                final msg = Message(
                  msgId: doc.id,
                  senderId: 'official_team',
                  type: Message.getMsgType(data['type'] ?? 'text'),
                  textMsg: data['textMsg'] ?? '',
                  fileUrl: data['fileUrl'] ?? '',
                  sentAt: sentAt ?? DateTime.now(),
                  isRead: true,
                );
                broadcastMap[doc.id] = msg;
              } catch (e) {
                debugPrint('Error parsing official_broadcast doc ${doc.id}: $e');
              }
            }
            emitMerged();
          }, onError: (e) {
            debugPrint('Error in official_broadcasts stream: $e');
            emitMerged();
          });
        },
        onCancel: () {
          subNotifs?.cancel();
          subChats?.cancel();
          subBroadcasts?.cancel();
        },
      );

      return streamCtrl.stream;
    }

    if (user.userType == 'channel') {
      return _firestore
          .collection('channel_posts')
          .where('channelId', isEqualTo: userId)
          .limit(200)
          .snapshots()
          .map((event) {
        // Sort locally to bypass the need for a Firestore composite index
        final docs = event.docs.toList();
        docs.sort((a, b) {
          final tA = a.data()['createdAt'];
          final tB = b.data()['createdAt'];
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return (tB as Timestamp).compareTo(tA as Timestamp);
        });

        return docs.map((doc) {
          final data = doc.data();
          
          MessageType msgType = MessageType.text;
          if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
            msgType = MessageType.image;
          }
          
          String textMessage = data['textContent'] ?? '';
          if (data['voiceRoomId'] != null && data['voiceRoomId'].toString().isNotEmpty) {
            textMessage += "${textMessage.isEmpty ? '' : '\n\n'}🎤 Voice Room ID: ${data['voiceRoomId']}";
          }
          if (data['linkUrl'] != null && data['linkUrl'].toString().isNotEmpty) {
            textMessage += "${textMessage.isEmpty ? '' : '\n\n'}🔗 Link: ${data['linkUrl']}";
          }

          return Message(
            msgId: doc.id,
            senderId: userId,
            type: msgType,
            textMsg: textMessage.trim(),
            fileUrl: data['imageUrl'] ?? '',
            sentAt: data['createdAt'] is Timestamp 
                ? (data['createdAt'] as Timestamp).toDate() 
                : DateTime.now(),
            isRead: true,
          );
        }).toList();
      });
    }

    // Query messages
    return _getCollectionRef(userId1: currentUser.userId, userId2: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((event) {
      return event.docs.map((doc) {
        return Message.fromMap(
            data: doc.data(), docRef: doc.reference, isGroup: false);
      }).toList();
    });
  }

  // <-- Get Group Messages -->
  static Stream<List<Message>> getGroupMessages(String groupId) {
    return GroupApi.groupsRef
        .doc(groupId)
        .collection('Messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((event) {
      return event.docs.map((doc) {
        return Message.fromMap(
            data: doc.data(), docRef: doc.reference, isGroup: true);
      }).toList();
    });
  }

  // Read message receipt
  static Future<void> readMsgReceipt({
    required String receiverId,
    required String messageId,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      final docRef =
          _getCollectionRef(userId1: receiverId, userId2: currentUser.userId)
              .doc(messageId);

      // set with merge handles missing docs gracefully
      await docRef.set({'isRead': true}, SetOptions(merge: true));
      debugPrint('readMsgReceipt() -> success');
    } catch (e) {
      debugPrint('readMsgReceipt() -> error: $e');
    }
  }

  // Delete message for me: 1-to-1 chat
  static Future<void> deleteMsgForMe({
    required Message message,
    required String receiverId,
    required Message? replaceMsg,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // Get the Chat node
      final Chat chat = ChatController.instance.getChat(receiverId);

      // Check the last message id to update the current user chat node
      if (chat.msgId == message.msgId) {
        ChatApi.softDeleteChat(
          userId1: currentUser.userId,
          userId2: receiverId,
          msgId: message.msgId,
        );
      }

      // Soft delete message for me
      await _getCollectionRef(userId1: currentUser.userId, userId2: receiverId)
          .doc(message.msgId)
          .set(message.toDeletedMap(), _setOptions);
      // Show feedback
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'message_deleted_successfully'.tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  // Soft delete message for everyone 1-to-1 or for Group
  static Future<void> softDeleteForEveryone({
    required bool isGroup,
    required Message message,
    String? receiverId,
    Group? group,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // Soft delete group message
      if (isGroup) {
        // Check the last msg group id to update the group info
        if (group?.lastMsg?.msgId == message.msgId) {
          // Replace the last msg
          group!.lastMsg = message;
          GroupApi.groupsRef
              .doc(group.groupId)
              .set(group.toUpdateMap(isDeleted: true), _setOptions);
        }

        // Soft delete the group message
        GroupApi.groupsRef
            .doc(group!.groupId)
            .collection('Messages')
            .doc(message.msgId)
            .set(message.toDeletedMap());

        // Delete group message files
        MessageApi.deleteMessageFiles([message]);

        // Show feedback
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'message_deleted_successfully'.tr);
        return;
      }

      // Get the Chat node
      final Chat chat = ChatController.instance.getChat(receiverId!);

      // Check the last message id to update the chat node
      if (chat.msgId == message.msgId) {
        Future.wait([
          ChatApi.softDeleteChat(
            userId1: currentUser.userId,
            userId2: receiverId,
            msgId: message.msgId,
          ),
          // Update for another user
          ChatApi.softDeleteChat(
            userId1: receiverId,
            userId2: currentUser.userId,
            msgId: message.msgId,
          ),
        ]);
      }

      await Future.wait([
        // Soft delete for me
        _getCollectionRef(userId1: currentUser.userId, userId2: receiverId)
            .doc(message.msgId)
            .set(message.toDeletedMap(), _setOptions),
        // Soft delete for another user
        _getCollectionRef(userId1: receiverId, userId2: currentUser.userId)
            .doc(message.msgId)
            .set(message.toDeletedMap(), _setOptions),
      ]);

      // Delete message files
      MessageApi.deleteMessageFiles([message]);

      // Show feedback
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'message_deleted_successfully'.tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  static Future<void> deleteMessageForever({
    required bool isGroup,
    required Message message,
    Group? group,
    String? receiverId,
    Message? replaceMsg,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      void successMessage() {
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'message_deleted_successfully'.tr);
      }

      // Delete Group Message
      if (isGroup) {
        await deleteGroupMessageForever(
          msgId: message.msgId,
          group: group!,
          replaceMsg: replaceMsg,
        );
        return;
      }

      // Update the current user chat node
      if (replaceMsg != null) {
        // Get chat instance
        final Chat chat = Chat(
          senderId: currentUser.userId,
          msgType: replaceMsg.type,
          lastMsg: replaceMsg.textMsg,
          msgId: replaceMsg.msgId,
        );

        // Update chat node.
        _firestore
            .collection('Users/${currentUser.userId}/Chats')
            .doc(receiverId)
            .set(chat.toMap(false), _setOptions);
      } else {
        ChatApi.resetChat(
          userId1: currentUser.userId,
          userId2: receiverId!,
        );
      }

      // Delete forever
      await _getCollectionRef(userId1: currentUser.userId, userId2: receiverId!)
          .doc(message.msgId)
          .delete();

      // Delete message files
      MessageApi.deleteMessageFiles([message]);

      // Show feedback
      successMessage();
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  static Future<void> deleteGroupMessageForever({
    required String msgId,
    required Group group,
    required Message? replaceMsg,
  }) async {
    //return;

    // Check last message replace the last msg
    if (replaceMsg != null) {
      group.lastMsg = replaceMsg;
      // Check deleted
      if (replaceMsg.isDeleted) {
        GroupApi.groupsRef
            .doc(group.groupId)
            .set(group.toUpdateMap(isDeleted: true), _setOptions);
      } else {
        GroupApi.groupsRef.doc(group.groupId).update(group.toUpdateMap());
      }
    } else {
      // Reset the last message
      group.lastMsg = null;
      GroupApi.groupsRef
          .doc(group.groupId)
          .set(group.toUpdateMap(), _setOptions);
    }

    // Delete the group msg forever
    GroupApi.groupsRef
        .doc(group.groupId)
        .collection('Messages')
        .doc(msgId)
        .delete();
  }

  static Future<void> deleteMessageFiles(List<Message> messages) async {
    try {
      // Delete group messages
      List<Future> fileFutures = [];

      for (final msg in messages) {
        if (msg.fileUrl.isNotEmpty) {
          fileFutures.add(AppHelper.deleteFile(msg.fileUrl));
          if (msg.type == MessageType.video && msg.videoThumbnail.isNotEmpty) {
            fileFutures.add(AppHelper.deleteFile(msg.videoThumbnail));
          }
        }
      }

      // Check the list
      if (fileFutures.isNotEmpty) {
        await Future.wait(fileFutures);
      }
      debugPrint(
          'deleteMessageFiles() -> success, files: ${fileFutures.length}');
    } catch (e) {
      debugPrint('deleteMessageFiles() -> error: $e');
    }
  }

  // Save outgoing or incoming call message for receiver & sender
  static Future<void> sendOutgoingorIncomingCallMessage({
    required bool isVideo,
    required User receiver,
    int? durationSeconds,
  }) async {
    try {
      // Get current user instance
      final User currentUser = AuthController.instance.currentUser;

      // Get correct message
      String body = isVideo ? 'Video call' : 'Audio call';
      if (durationSeconds != null && durationSeconds > 0) {
        body = '$body|$durationSeconds';
      }

      // Get Message instance
      final Message message = Message(
        msgId: AppHelper.generateID,
        senderId: currentUser.userId,
        type: MessageType.text,
        textMsg: body,
      );

      // Get chat instance
      final Chat chat = Chat(
        senderId: currentUser.userId,
        msgType: message.type,
        lastMsg: body.contains('|') ? body.split('|')[0] : body,
        msgId: message.msgId,
      );

      await Future.wait([
        // Save last chat for receiver
        _firestore
            .collection('Users/${receiver.userId}/Chats')
            .doc(currentUser.userId)
            .set(chat.toMap(true), _setOptions),

        // Save last chat for sender
        _firestore
            .collection('Users/${currentUser.userId}/Chats')
            .doc(receiver.userId)
            .set(chat.toMap(false), _setOptions),

        // Save message for receiver & sender
        _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
            .doc(message.msgId)
            .set(message.toMap(isGroup: false)),

        // Send push notification to receiver
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: currentUser.fullname,
          body: isVideo ? 'Video call' : 'Audio call',
          deviceToken: receiver.deviceToken,
          call: {
            'messageId': message.msgId,
            'senderId': currentUser.userId,
          },
        ),
      ]);

      // Debug
      debugPrint('sendOutgoingorIncomingCallMessage() -> success');
    } catch (e) {
      debugPrint('sendOutgoingorIncomingCallMessage() -> error: $e');
    }
  }
  ///////////
}
