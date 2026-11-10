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

      // Update the Chat Node for the receiver with unread increment and server timestamp
      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set({
        'senderId': officialTeamId,
        'msgType': 'text',
        'lastMsg': message.textMsg,
        'msgId': message.msgId,
        'unread': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Centralized Audit Log
      await _firestore.collection('official_notification_logs').doc(message.msgId).set({
        'msgId': message.msgId,
        'senderId': officialTeamId,
        'receiverId': receiverId,
        'textMsg': messageText,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Token fallback lookup
      String targetToken = receiverDeviceToken;
      if (targetToken.isEmpty) {
        try {
          final userDoc = await _firestore.collection('Users').doc(receiverId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            targetToken = data?['deviceToken'] ?? data?['fcm_token'] ?? data?['fcmToken'] ?? '';
          }
        } catch (_) {}
      }

      if (targetToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat Official Team',
          body: messageText,
          deviceToken: targetToken,
          call: {
            'senderId': officialTeamId,
            'msgId': message.msgId,
            ...?call,
          },
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

      // 3. Push and individual copy for active users with same msgId for deduplication
      final usersSnapshot = await _firestore.collection('Users').get();
      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        final data = doc.data();
        final deviceToken = data['deviceToken'] ?? data['fcm_token'] ?? data['fcmToken'] ?? '';
        try {
          // Direct write with consistent msgId
          final msgMap = {
            'msgId': msgId,
            'senderId': officialTeamId,
            'type': 'text',
            'textMsg': messageText,
            'isRead': false,
            'sentAt': FieldValue.serverTimestamp(),
          };

          await _firestore
              .collection('Users/$userId/Chats/$officialTeamId/Messages')
              .doc(msgId)
              .set(msgMap);

          await _firestore
              .collection('Users/$userId/official_notifications')
              .doc(msgId)
              .set(msgMap);

          await _firestore
              .collection('Users/$userId/Chats')
              .doc(officialTeamId)
              .set({
            'senderId': officialTeamId,
            'msgType': 'text',
            'lastMsg': messageText,
            'msgId': msgId,
            'unread': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (deviceToken.isNotEmpty) {
            PushNotificationService.sendNotification(
              type: NotificationType.message,
              title: 'imChat Official Team',
              body: messageText,
              deviceToken: deviceToken,
              call: {
                'senderId': officialTeamId,
                'msgId': msgId,
              },
            );
          }
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

  /// Trigger: When a user successfully purchases diamonds from a seller (Sales notification for both Buyer and Seller).
  static Future<void> sendDiamondSellerRechargeMessage(User receiver, User seller, int amount) async {
    // 1. Send Congratulations to buyer/receiver
    final buyerMsg = "🎉 Congratulations! Reseller ${seller.fullname} has sent you $amount diamonds. They have been added to your wallet.";
    await sendOfficialMessage(
      receiverId: receiver.userId,
      receiverDeviceToken: receiver.deviceToken,
      messageText: buyerMsg,
    );

    // 2. Send Sales Confirmation receipt to reseller
    if (seller.userId.isNotEmpty && seller.userId != receiver.userId) {
      final sellerMsg = "💎 Sales Confirmation: You have successfully transferred $amount diamonds to ${receiver.fullname} (ID: ${receiver.searchId}).";
      await sendOfficialMessage(
        receiverId: seller.userId,
        receiverDeviceToken: seller.deviceToken,
        messageText: sellerMsg,
      );
    }
  }

  /// Trigger: Position notification when any user is granted or revoked a position (Host, Agency, Seller, BD, Direct Seller, Official, etc.)
  static Future<void> sendPositionNotification({
    required String userId,
    required String positionName,
    required bool isAssigned,
    String? note,
  }) async {
    final msg = isAssigned
        ? "🎉 Congratulations! You have been granted the $positionName position.${note != null && note.isNotEmpty ? ' Note: $note' : ''}"
        : "📢 Position Update: Your $positionName position has been deactivated.${note != null && note.isNotEmpty ? ' Note: $note' : ''}";
    await sendOfficialMessage(
      receiverId: userId,
      receiverDeviceToken: '',
      messageText: msg,
    );
  }

  /// Trigger: When Admin directly credits balance (diamonds/coins/beans) to user account
  static Future<void> sendAdminBalanceCreditNotification({
    required String userId,
    required int amount,
    String currency = 'Diamonds',
    String? note,
  }) async {
    final msg = "💎 Balance Added: Admin has directly credited $amount $currency to your account.${note != null && note.isNotEmpty ? ' Note: $note' : ''}";
    await sendOfficialMessage(
      receiverId: userId,
      receiverDeviceToken: '',
      messageText: msg,
    );
  }

  /// Trigger: When Seller account balance is credited (by Direct Seller or Admin)
  static Future<void> sendSellerBalanceNotification({
    required String sellerUserId,
    required int amount,
    required String creditedBy,
    String? note,
    String? directSellerUserId,
  }) async {
    // 1. Notify the seller who received the balance
    final sellerMsg = "💎 Seller Balance Credited: You received $amount Diamonds in your Seller balance from $creditedBy.${note != null && note.isNotEmpty ? ' Note: $note' : ''}";
    await sendOfficialMessage(
      receiverId: sellerUserId,
      receiverDeviceToken: '',
      messageText: sellerMsg,
    );

    // 2. If transferred by a Direct Seller, also send a confirmation receipt to the Direct Seller
    if (directSellerUserId != null && directSellerUserId.isNotEmpty && directSellerUserId != sellerUserId) {
      final dsMsg = "💎 Transfer Confirmation: You successfully transferred $amount Diamonds to Seller balance.${note != null && note.isNotEmpty ? ' Note: $note' : ''}";
      await sendOfficialMessage(
        receiverId: directSellerUserId,
        receiverDeviceToken: '',
        messageText: dsMsg,
      );
    }
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
      final String invitationSummary = '🏆 Agency invitation from $agencyName';

      final Map<String, dynamic> msgMap = {
        'msgId': msgId,
        'senderId': officialTeamId,
        'type': 'hostInvitation',
        'textMsg': invitationSummary,
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

      // Update the Chat Node for receiver with unread increment
      await _firestore
          .collection('Users/$receiverId/Chats')
          .doc(officialTeamId)
          .set({
        'senderId': officialTeamId,
        'msgType': 'hostInvitation',
        'lastMsg': invitationSummary,
        'msgId': msgId,
        'unread': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Audit log
      await _firestore.collection('official_notification_logs').doc(msgId).set({
        'msgId': msgId,
        'senderId': officialTeamId,
        'receiverId': receiverId,
        'textMsg': invitationSummary,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Push notification with auto token lookup
      String targetToken = receiverDeviceToken;
      if (targetToken.isEmpty) {
        try {
          final userDoc = await _firestore.collection('Users').doc(receiverId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            targetToken = data?['deviceToken'] ?? data?['fcm_token'] ?? data?['fcmToken'] ?? '';
          }
        } catch (_) {}
      }

      if (targetToken.isNotEmpty) {
        PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'imChat Official Team',
          body: '🏆 You have been invited to join $agencyName as a Host!',
          deviceToken: targetToken,
          call: {
            'senderId': officialTeamId,
            'msgId': msgId,
            'type': 'hostInvitation',
            'invitationId': invitationId,
            'agencyId': agencyId,
            'agencyName': agencyName,
          },
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

  /// Broadcast by an authorized app user with "App Notification Permission"
  static Future<int> broadcastByPermittedUser({
    required String senderUserId,
    required String senderName,
    required String messageText,
    required String targetGroup, // 'all', 'host', 'agency', 'seller', 'new_user', 'custom'
    List<String>? customRecipients,
    String? imageUrl,
    String? audioUrl,
    Map<String, dynamic>? roomShare,
    String? linkUrl,
  }) async {
    try {
      final String msgId = AppHelper.generateID;
      final sentAt = FieldValue.serverTimestamp();

      String messageType = 'text';
      if (audioUrl != null && audioUrl.isNotEmpty) {
        messageType = 'audio';
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        messageType = 'image';
      } else if (roomShare != null && roomShare.isNotEmpty) {
        messageType = 'roomShare';
      }

      String previewText = messageText;
      if (previewText.isEmpty) {
        if (messageType == 'image') {
          previewText = '📷 Photo';
        } else if (messageType == 'audio') {
          previewText = '🎙️ Voice Message';
        } else if (messageType == 'roomShare') {
          previewText = '🎙️ Voice Room Shared';
        } else if (linkUrl != null && linkUrl.isNotEmpty) {
          previewText = '🔗 Link Shared';
        }
      }

      // 1. If broadcast is for ALL, write to central official_broadcasts for INSTANT real-time sync
      if (targetGroup == 'all') {
        await _firestore.collection('official_broadcasts').doc(msgId).set({
          'msgId': msgId,
          'senderId': officialTeamId,
          'type': messageType,
          'textMsg': messageText,
          'fileUrl': audioUrl ?? imageUrl ?? '',
          'roomShare': roomShare,
          'linkUrl': linkUrl ?? '',
          'sentAt': sentAt,
          'senderUserId': senderUserId,
        });
      }

      // 2. Central audit log (guarded so log failure never blocks broadcast)
      try {
        await _firestore.collection('official_notification_logs').doc(msgId).set({
          'msgId': msgId,
          'senderId': officialTeamId,
          'senderUserId': senderUserId,
          'senderName': senderName,
          'targetGroup': targetGroup,
          'textMsg': messageText,
          'sentAt': sentAt,
          'source': 'app_permitted_user',
        });
      } catch (e) {
        debugPrint('Audit log write error: $e');
      }

      // 3. Resolve target users
      List<DocumentSnapshot> targetDocs = [];
      final usersColl = _firestore.collection('Users');

      if (targetGroup == 'all') {
        final snap = await usersColl.get();
        targetDocs = snap.docs;
      } else if (targetGroup == 'host') {
        final s1 = await usersColl.where('isHost', isEqualTo: true).get();
        final s2 = await usersColl.where('userType', isEqualTo: 'host').get();
        final map = <String, DocumentSnapshot>{};
        for (var d in s1.docs) {
          map[d.id] = d;
        }
        for (var d in s2.docs) {
          map[d.id] = d;
        }
        targetDocs = map.values.toList();
      } else if (targetGroup == 'agency') {
        final s1 = await usersColl.where('userType', isEqualTo: 'agency').get();
        final s2 = await usersColl.where('userType', isEqualTo: 'agency_owner').get();
        final map = <String, DocumentSnapshot>{};
        for (var d in s1.docs) {
          map[d.id] = d;
        }
        for (var d in s2.docs) {
          map[d.id] = d;
        }
        targetDocs = map.values.toList();
      } else if (targetGroup == 'seller') {
        final snap = await usersColl.where('userType', isEqualTo: 'seller').get();
        targetDocs = snap.docs;
      } else if (targetGroup == 'new_user') {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final snap = await usersColl
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .get();
        targetDocs = snap.docs;
      } else if (targetGroup == 'custom' && customRecipients != null && customRecipients.isNotEmpty) {
        final map = <String, DocumentSnapshot>{};
        for (var rawId in customRecipients) {
          final query = rawId.trim();
          if (query.isEmpty) continue;

          // 3.1 Try direct doc ID
          try {
            final doc = await usersColl.doc(query).get();
            if (doc.exists) {
              map[doc.id] = doc;
              continue;
            }
          } catch (_) {}

          // 3.2 Try searchId field (string)
          try {
            final sSnap = await usersColl.where('searchId', isEqualTo: query).limit(1).get();
            if (sSnap.docs.isNotEmpty) {
              map[sSnap.docs.first.id] = sSnap.docs.first;
              continue;
            }
          } catch (_) {}

          // 3.3 Try searchId field (numeric)
          final numVal = int.tryParse(query);
          if (numVal != null) {
            try {
              final nSnap = await usersColl.where('searchId', isEqualTo: numVal).limit(1).get();
              if (nSnap.docs.isNotEmpty) {
                map[nSnap.docs.first.id] = nSnap.docs.first;
                continue;
              }
            } catch (_) {}
          }
        }
        targetDocs = map.values.toList();
      }

      // 4. Batch dispatch to user mailboxes & FCM (chunks of 10)
      int count = 0;
      const int batchSize = 10;
      for (int i = 0; i < targetDocs.length; i += batchSize) {
        final chunk = targetDocs.skip(i).take(batchSize).toList();
        await Future.wait(chunk.map((doc) async {
          final receiverId = doc.id;
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final token = data['deviceToken'] ?? data['fcm_token'] ?? data['fcmToken'] ?? '';
          final receiverName = data['fullname'] ?? data['name'] ?? '';

          String userSpecificMsg = messageText.replaceAll('[UserName]', receiverName);

          final msgMap = {
            'msgId': msgId,
            'senderId': officialTeamId,
            'type': messageType,
            'textMsg': userSpecificMsg,
            'fileUrl': audioUrl ?? imageUrl ?? '',
            'roomShare': roomShare,
            'linkUrl': linkUrl ?? '',
            'isRead': false,
            'sentAt': sentAt,
            'senderUserId': senderUserId,
          };

          try {
            await Future.wait([
              _firestore
                  .collection('Users/$receiverId/Chats/$officialTeamId/Messages')
                  .doc(msgId)
                  .set(msgMap),
              _firestore
                  .collection('Users/$receiverId/official_notifications')
                  .doc(msgId)
                  .set(msgMap),
              _firestore
                  .collection('Users/$receiverId/Chats')
                  .doc(officialTeamId)
                  .set({
                'senderId': officialTeamId,
                'msgType': messageType,
                'lastMsg': previewText,
                'msgId': msgId,
                'unread': FieldValue.increment(1),
                'updatedAt': sentAt,
              }, SetOptions(merge: true)),
            ]);

            if (token.isNotEmpty) {
              try {
                PushNotificationService.sendNotification(
                  type: NotificationType.message,
                  title: 'imChat Team',
                  body: previewText,
                  deviceToken: token,
                  call: {
                    'senderId': officialTeamId,
                    'msgId': msgId,
                  },
                );
              } catch (_) {}
            }
            count++;
          } catch (e) {
            debugPrint('Error sending to $receiverId: $e');
          }
        }));
      }

      // 4.1. If targetGroup is not 'all', also copy to sender's own chat so sender sees it immediately in real-time
      if (targetGroup != 'all' && senderUserId.isNotEmpty) {
        try {
          final senderMsgMap = {
            'msgId': msgId,
            'senderId': officialTeamId,
            'type': messageType,
            'textMsg': messageText,
            'fileUrl': audioUrl ?? imageUrl ?? '',
            'roomShare': roomShare,
            'linkUrl': linkUrl ?? '',
            'isRead': true,
            'sentAt': sentAt,
            'senderUserId': senderUserId,
          };
          await Future.wait([
            _firestore
                .collection('Users/$senderUserId/Chats/$officialTeamId/Messages')
                .doc(msgId)
                .set(senderMsgMap),
            _firestore
                .collection('Users/$senderUserId/Chats')
                .doc(officialTeamId)
                .set({
              'senderId': officialTeamId,
              'msgType': messageType,
              'lastMsg': previewText,
              'msgId': msgId,
              'updatedAt': sentAt,
            }, SetOptions(merge: true)),
          ]);
        } catch (e) {
          debugPrint('Error saving copy to sender chat: $e');
        }
      }

      // 5. Update permitted user's broadcast stats
      try {
        await _firestore.collection('app_notification_permissions').doc(senderUserId).update({
          'totalBroadcasts': FieldValue.increment(1),
          'lastBroadcastAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return count;
    } catch (e) {
      debugPrint('broadcastByPermittedUser() error: $e');
      rethrow;
    }
  }
}
