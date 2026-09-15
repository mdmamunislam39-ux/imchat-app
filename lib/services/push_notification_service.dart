import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:get/get.dart';

enum NotificationType { alert, call, cancel_call, message, group }

abstract class PushNotificationService {
  //
  // Firebase Push Notifications Service
  //
  static final _functions = FirebaseFunctions.instance;

  /// Send push notification
  static Future<void> sendNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String deviceToken,
    Map<String, dynamic>? call,
  }) async {
    try {
      await _functions.httpsCallable('sendPushNotification').call({
        'type': type.name,
        'title': title,
        'body': body,
        'deviceToken': deviceToken,
        'call': call ?? {},
        'senderId': AuthController.instance.currentUser.userId,
        'senderAvatar': AuthController.instance.currentUser.photoUrl,
      });
      debugPrint('sendPushNotification() -> success');
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
