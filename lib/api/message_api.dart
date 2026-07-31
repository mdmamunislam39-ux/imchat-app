import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/group_api.dart';
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
    try {
      // Get current user instance
      final User currentUser = AuthController.instance.currentUser;

      // Save message for current user
      await _getCollectionRef(userId1: currentUser.userId, userId2: receiver.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false))
          .timeout(const Duration(seconds: 15));

      // Save message for another user
      await _getCollectionRef(userId1: receiver.userId, userId2: currentUser.userId)
          .doc(message.msgId)
          .set(message.toMap(isGroup: false))
          .timeout(const Duration(seconds: 15));

      // Save the last chat
      ChatApi.saveChat(
        userId1: currentUser.userId,
        userId2: receiver.userId,
        message: message,
      );

      // Send push notification to recevier
      PushNotificationService.sendNotification(
        type: NotificationType.message,
        title: currentUser.fullname,
        body: PushNotificationService.getMessageType(message),
        deviceToken: receiver.deviceToken,
      );

      // Debug
      debugPrint('saveMessage() -> success');
    } catch (e) {
      debugPrint('saveMessage() -> error: $e');
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
      return _firestore
          .collection('Users/${currentUser.userId}/official_notifications')
          .orderBy('sentAt', descending: true)
          .limit(100)
          .snapshots()
          .map((event) {
        return event.docs.map((doc) {
          return Message.fromMap(
              data: doc.data(), docRef: doc.reference, isGroup: false);
        }).toList();
      });
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
