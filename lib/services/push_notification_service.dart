import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/services/backend_engine_manager.dart';
import 'package:chat_messenger/services/vps_api_service.dart';

enum NotificationType { alert, call, cancel_call, message, group, follower_room }

abstract class PushNotificationService {
  //
  // Firebase Push Notifications Service & Dual-Engine VPS Routing
  //
  static final _functions = FirebaseFunctions.instance;

  /// Send push notification (dynamically routes through VPS or Firebase Cloud Functions)
  static Future<void> sendNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String deviceToken,
    Map<String, dynamic>? call,
  }) async {
    if (deviceToken.isEmpty) {
      debugPrint('[PushNotificationService] deviceToken is empty, skipping push notification');
      return;
    }

    final senderId = AuthController.instance.currentUser.userId;
    final senderAvatar = AuthController.instance.currentUser.photoUrl;

    // 1. Check if VPS Backend Engine is Active
    if (Get.isRegistered<BackendEngineManager>()) {
      final backendManager = Get.find<BackendEngineManager>();
      if (backendManager.isVpsActive && backendManager.vpsBaseUrl.isNotEmpty) {
        try {
          final vpsApi = Get.isRegistered<VpsApiService>()
              ? Get.find<VpsApiService>()
              : Get.put(VpsApiService());

          final res = await vpsApi.post('/api/notification/send', body: {
            'type': type.name,
            'title': title,
            'body': body,
            'deviceToken': deviceToken,
            'call': call ?? {},
            'senderId': senderId,
            'senderAvatar': senderAvatar,
          });

          if (res != null && (res['success'] == true || res['status'] == 'success')) {
            debugPrint('[PushNotificationService] Sent push notification via VPS Server successfully');
            return;
          } else {
            debugPrint('[PushNotificationService] VPS notification responded: $res. Falling back to Firebase Cloud Functions...');
          }
        } catch (e) {
          debugPrint('[PushNotificationService] VPS Notification failed ($e), falling back to Firebase Functions...');
        }
      }
    }

    // 2. Default / Fallback to Firebase Cloud Functions
    try {
      await _functions.httpsCallable('sendPushNotification').call({
        'type': type.name,
        'title': title,
        'body': body,
        'deviceToken': deviceToken,
        'call': call ?? {},
        'senderId': senderId,
        'senderAvatar': senderAvatar,
      });
      debugPrint('sendPushNotification() [Firebase Cloud Functions] -> success');
    } catch (e) {
      debugPrint('sendPushNotification() -> error: $e');
    }
  }

  // static String getMessageType(MessageType type) {
  //   return switch (type) {
  //     MessageType.text => '📩 ${'new_text_message'.tr}',
  //     MessageType.image => '📷 ${'photo'.tr}',
  //     MessageType.gif => '🎬 GIF',
  //     MessageType.audio => '🎵 ${'audio'.tr}',
  //     MessageType.video => '📹 ${'video'.tr}',
  //     MessageType.doc => '📄 ${'document'.tr}',
  //     MessageType.location => '📍 ${'location_shared'.tr}',
  //     _ => '',
  //   };
  // }
  static String getMessageType(Message message) {
    // Special case for text messages, return the actual message text
    if (message.type == MessageType.text) {
      return message
          .textMsg; // This assumes the text content is in `message.content`
    }

    // Return predefined labels for other message types
    return switch (message.type) {
      MessageType.image => '📷 ${'photo'.tr}',
      MessageType.gif => '🎬 GIF',
      MessageType.audio => '🎵 ${'audio'.tr}',
      MessageType.video => '📹 ${'video'.tr}',
      MessageType.doc => '📄 ${'document'.tr}',
      MessageType.location => '📍 ${'location_shared'.tr}',
      MessageType.roomShare => '🎙️ Voice Room Shared',
      MessageType.hostInvitation => '🏆 Agency Invitation',
      MessageType.relationshipInvitation => '❤️ Intimacy Invitation',
      _ => '',
    };
  }
}
