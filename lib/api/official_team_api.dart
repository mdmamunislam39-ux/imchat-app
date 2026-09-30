import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OfficialTeamApi {
  static const String officialTeamId = 'official_team';
  static final _firestore = FirebaseFirestore.instance;

  /// Send an official system message to a specific user
  static Future<void> sendOfficialMessage({
    required String receiverId,
    required String receiverDeviceToken,
    required String messageText,
    Map<String, dynamic>? call,
  }) async {
    try {
      final Message message = Message(
        msgId: AppHelper.generateID,
        senderId: officialTeamId,
        type: MessageType.text,
        textMsg: messageText,
        sentAt: DateTime.now(),
      );

      // Save message in receiver's chat
      await _firestore
          .collection('Users/$receiverId/Chats/$officialTeamId/Messages')
          .doc(message.msgId)
          .set(message.toMap(isGroup: false));

      // Save message in dedicated official_notifications subcollection with server timestamp
      final Map<String, dynamic> msgMap = message.toMap(isGroup: false);
      msgMap['sentAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('Users/$receiverId/official_notifications')
          .doc(message.msgId)
          .set(msgMap);

      // Update the Chat Node for the receiver
      final chat = Chat(
        senderId: officialTeamId,
        msgType: MessageType.text,
        lastMsg: message.textMsg,
        msgId: message.msgId,
      );

      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set(chat.toMap(true), SetOptions(merge: true));

      // Centralized Audit Log
      await _firestore.collection('official_notification_logs').doc(message.msgId).set({
        'msgId': message.msgId,
        'senderId': officialTeamId,
        'receiverId': receiverId,
        'textMsg': messageText,
        'sentAt': Timestamp.fromDate(message.sentAt ?? DateTime.now()),
      });

      if (receiverDeviceToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat Official team',
          body: messageText,
          deviceToken: receiverDeviceToken,
          call: call,
        );
      }

      debugPrint('sendOfficialMessage() -> success');
    } catch (e) {
      debugPrint('sendOfficialMessage() -> error: $e');
    }
  }

  /// Broadcast an official message to ALL users in the database
  static Future<void> broadcastOfficialMessage(String messageText) async {
    try {
      final String msgId = AppHelper.generateID;

      // 1. Save to centralized official_broadcasts collection so EVERY user sees it instantly
      await _firestore.collection('official_broadcasts').doc(msgId).set({
        'msgId': msgId,
        'senderId': officialTeamId,
        'type': 'text',
        'textMsg': messageText,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // 2. Centralized Audit Log
      await _firestore.collection('official_notification_logs').doc(msgId).set({
        'msgId': msgId,
        'senderId': officialTeamId,
        'receiverId': 'Broadcast',
        'textMsg': messageText,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // 3. Push and individual copy for active users
      final usersSnapshot = await _firestore.collection('Users').get();
      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        final data = doc.data();
        final deviceToken = data['deviceToken'] ?? '';
        try {
          await sendOfficialMessage(
            receiverId: userId,
            receiverDeviceToken: deviceToken,
            messageText: messageText,
          );
        } catch (e) {
          debugPrint('❌ [OfficialTeam] Failed to send broadcast to user $userId: $e');
        }
      }
      debugPrint('📢 [OfficialTeam] Broadcasted to ${usersSnapshot.docs.length} users successfully.');
    } catch (e) {
      debugPrint('❌ [OfficialTeam] Failed to fetch users for broadcast: $e');
    }
  }

  // --- Pre-defined Triggers ---

  /// Trigger: When a user logs in for the first time.
  static Future<void> sendWelcomeMessage(User receiver) async {
    final msg = "🎉 Welcome ${receiver.fullname}! Enjoy your experience in our imChat app.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user’s mute is lifted.
  static Future<void> sendUnmuteMessage(User receiver) async {
    final msg = "✅ ${receiver.fullname} has been unmuted";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user’s ban is lifted.
  static Future<void> sendUnbanMessage(User receiver) async {
    final msg = "✅ ${receiver.fullname} is no longer banned from the room.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user successfully purchases diamonds.
  static Future<void> sendDiamondRechargeMessage(User receiver, int amount) async {
    final msg = "💎 ${receiver.fullname} has successfully recharged $amount diamonds.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user successfully purchases diamonds from a seller.
  static Future<void> sendDiamondSellerRechargeMessage(User receiver, User seller, int amount) async {
    final msg = "🎉 Congratulations! Reseller ${seller.fullname} has sent you a gift. $amount diamonds have been added to your wallet";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user receives a reward/achievement
  static Future<void> sendRewardMessage(User receiver, String rewardName, {bool isBadge = false}) async {
    final msg = isBadge
        ? "🏅 Congratulations ${receiver.fullname}! You received the $rewardName badge."
        : "✨ ${receiver.fullname} just claimed $rewardName from the store.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: Admin panel manual post
  static Future<void> sendAdminManualMessage(User receiver, String message) async {
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: "📢 $message",
    );
  }

  /// Trigger: When a user becomes Host
  static Future<void> sendHostCongratulation(User receiver) async {
    final msg = "🎉 Congratulations ${receiver.fullname}! You are now an official Host!";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user becomes Agency
  static Future<void> sendAgencyCongratulation(User receiver) async {
    final msg = "🏆 Well done ${receiver.fullname}! You have become an Agency member.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When a user becomes Diamond Reseller
  static Future<void> sendDiamondResellerCongratulation(User receiver) async {
    final msg = "💎 Well done ${receiver.fullname}! You have become a Diamond Reseller.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: Follow notification when followed user opens a voice room (Pure push notification only, does not create imChat Team chat message)
  static Future<void> sendFollowedUserOpenedRoomMessage(User receiver, String followedUserName, String roomId) async {
    if (receiver.deviceToken.isEmpty) return;
    await PushNotificationService.sendNotification(
      type: NotificationType.follower_room,
      title: "$followedUserName is on live!",
      body: "Let's have fun together!!🤘🤟",
      deviceToken: receiver.deviceToken,
      call: {
        'type': 'follower_room',
        'roomId': roomId,
      },
    );
  }

  /// Trigger: When an agency sends a host invitation — sends an interactive invitation card
  static Future<void> sendHostInvitationMessage({
    required String receiverId,
    required String receiverDeviceToken,
    required String receiverName,
    required String invitationId,
    required String agencyId,
    required String agencyName,
  }) async {
    try {
      final String msgId = AppHelper.generateID;

      final Map<String, dynamic> msgMap = {
        'msgId': msgId,
        'senderId': officialTeamId,
        'type': 'hostInvitation',
        'textMsg': '', // empty — handled by the custom card widget
        'fileUrl': '',
        'gifUrl': '',
        'location': null,
        'roomShare': null,
        'invitationId': invitationId,
        'invitationAgencyId': agencyId,
        'invitationAgencyName': agencyName,
        'videoThumbnail': '',
        'isRead': false,
        'isRecAudio': false,
        'isForwarded': false,
        'sentAt': FieldValue.serverTimestamp(),
        'replyMessage': null,
        'groupUpdate': null,
      };

      // Save to the receiver's chat with official_team
      await _firestore
          .collection('Users/$receiverId/Chats/$officialTeamId/Messages')
          .doc(msgId)
          .set(msgMap);

      // Save to official_notifications subcollection
      await _firestore
          .collection('Users/$receiverId/official_notifications')
          .doc(msgId)
          .set(msgMap);

      // Update the Chat Node for receiver
      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set({
        'senderId': officialTeamId,
        'msgType': 'hostInvitation',
        'lastMsg': '🏆 Agency invitation from $agencyName',
        'msgId': msgId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Audit log
      await _firestore.collection('official_notification_logs').doc(msgId).set({
        'msgId': msgId,
        'senderId': officialTeamId,
        'receiverId': receiverId,
        'textMsg': 'Agency invitation from $agencyName',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Push notification
      if (receiverDeviceToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat Official Team',
          body: '🏆 You have been invited to join $agencyName as a Host!',
          deviceToken: receiverDeviceToken,
        );
      }

      debugPrint('sendHostInvitationMessage() -> success');
    } catch (e) {
      debugPrint('sendHostInvitationMessage() -> error: $e');
    }
  }

  /// Trigger: When a user sends a relationship/intimacy invitation
  static Future<void> sendRelationshipInvitationMessage({
    required String receiverId,
    required String receiverDeviceToken,
    required String senderName,
    required String invitationId,
    required String relationshipType,
  }) async {
    try {
      final String msgId = AppHelper.generateID;

      final Map<String, dynamic> msgMap = {
        'msgId': msgId,
        'senderId': officialTeamId,
        'type': 'relationshipInvitation',
        'textMsg': '', // empty — handled by the custom card widget
        'fileUrl': '',
        'gifUrl': '',
        'location': null,
        'roomShare': null,
        'invitationId': invitationId,
        'invitationAgencyName': senderName, // reuse existing field for sender name
        'invitationAgencyId': relationshipType, // reuse existing field for type
        'videoThumbnail': '',
        'isRead': false,
        'isRecAudio': false,
        'isForwarded': false,
        'sentAt': FieldValue.serverTimestamp(),
        'replyMessage': null,
        'groupUpdate': null,
      };

      // Save to receiver's chat with official_team
      await _firestore
          .collection('Users/$receiverId/Chats/$officialTeamId/Messages')
          .doc(msgId)
          .set(msgMap);

      // Save to official_notifications subcollection
      await _firestore
          .collection('Users/$receiverId/official_notifications')
          .doc(msgId)
          .set(msgMap);

      // Update the Chat Node for receiver
      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set({
        'senderId': officialTeamId,
        'msgType': 'relationshipInvitation',
        'lastMsg': '❤️ Relationship request from $senderName',
        'msgId': msgId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Audit log
      await _firestore.collection('official_notification_logs').doc(msgId).set({
        'msgId': msgId,
        'senderId': officialTeamId,
        'receiverId': receiverId,
        'textMsg': 'Relationship request from $senderName',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Push notification
      String targetToken = receiverDeviceToken;
      if (targetToken.isEmpty) {
        final userDoc = await _firestore.collection('Users').doc(receiverId).get();
        if (userDoc.exists) {
          targetToken = userDoc.data()?['deviceToken'] ?? '';
        }
      }

      if (targetToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat Official Team',
          body: '❤️ You have received a $relationshipType request from $senderName!',
          deviceToken: targetToken,
        );
      }

      debugPrint('sendRelationshipInvitationMessage() -> success');
    } catch (e) {
      debugPrint('sendRelationshipInvitationMessage() -> error: $e');
    }
  }

  /// Trigger: When a user receives a follow / friend request
  static Future<void> sendFollowNotification({
    required String receiverId,
    required String senderName,
  }) async {
    try {
      final String msgId = AppHelper.generateID;

      final Map<String, dynamic> msgMap = {
        'msgId': msgId,
        'senderId': officialTeamId,
        'type': 'systemNotification',
        'textMsg': '👤 $senderName started following you!',
        'fileUrl': '',
        'gifUrl': '',
        'location': null,
        'roomShare': null,
        'videoThumbnail': '',
        'isRead': false,
        'isRecAudio': false,
        'isForwarded': false,
        'sentAt': FieldValue.serverTimestamp(),
        'replyMessage': null,
        'groupUpdate': null,
      };

      await _firestore
          .collection('Users/$receiverId/Chats/$officialTeamId/Messages')
          .doc(msgId)
          .set(msgMap);

      await _firestore
          .collection('Users/$receiverId/official_notifications')
          .doc(msgId)
          .set(msgMap);

      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set({
        'senderId': officialTeamId,
        'msgType': 'systemNotification',
        'lastMsg': '👤 $senderName started following you!',
        'msgId': msgId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userDoc = await _firestore.collection('Users').doc(receiverId).get();
      final targetToken = userDoc.data()?['deviceToken'] ?? '';

      if (targetToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat',
          body: '👤 $senderName started following you!',
          deviceToken: targetToken,
        );
      }
    } catch (e) {
      debugPrint('sendFollowNotification() -> error: $e');
    }
  }

  /// Trigger: When a host is removed/terminated from an agency
  static Future<void> sendHostTerminationNotice(User receiver, String agencyName) async {
    final msg =
        "📢 Notice: You have been removed from $agencyName. Your host status has been deactivated. Please contact support if you have any questions.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: msg,
    );
  }

  /// Trigger: When an official asset (frame, entry effect, theme, skin) is assigned or acquired by a user
  static Future<void> sendAssetAssignmentNotice({
    required String receiverId,
    required String receiverDeviceToken,
    required String assetName,
    required String assetCategory,
  }) async {
    final msg = "🎁 Congratulations! An official item \"$assetName\" ($assetCategory) has been assigned to your account. You can now select it from your profile/room customization settings.";
    await sendOfficialMessage(
      receiverId: receiverId,
      receiverDeviceToken: receiverDeviceToken,
      messageText: msg,
    );
  }
}
