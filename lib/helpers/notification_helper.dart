import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/app_logo.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/routes/app_routes.dart';

import 'package:chat_messenger/api/user_api.dart';
import 'dialog_helper.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';

abstract class NotificationHelper {
  //
  // NotificationHelper
  //

  // Handle notification click. E.g: open a route..
  static Future<void> onNotificationClick({
    bool openRoute = false,
    Map<String, dynamic>? payload,
  }) async {
    if (payload == null) return;
    
    // Vars
    String type = payload['type'] ?? '';
    String title = payload['title'] ?? '';
    String message = payload['message'] ?? '';

    // Handle notification type
    switch (type) {
      case 'call':
        try {
          final dynamic rawCall = payload['call'];
          final Map<String, dynamic> callMap = rawCall is Map
              ? Map<String, dynamic>.from(rawCall)
              : (rawCall is String ? jsonDecode(rawCall) : {});
          final Call call = Call.fromMap(data: callMap);

          // Go to incoming call page if not already on a call screen
          if (Get.currentRoute != AppRoutes.incomingCall &&
              Get.currentRoute != AppRoutes.voiceCall &&
              Get.currentRoute != AppRoutes.videoCall &&
              Get.currentRoute != AppRoutes.groupCall) {
            Get.toNamed(AppRoutes.incomingCall, arguments: {'call': call});
          }
        } catch (e) {
          debugPrint('Error parsing incoming call payload: $e');
        }
        break;

      case 'message':
        final dynamic rawMsgCall = payload['call'];
        final Map<String, dynamic> msgCallMap = rawMsgCall is Map
            ? Map<String, dynamic>.from(rawMsgCall)
            : (rawMsgCall is String && rawMsgCall.isNotEmpty
                ? (jsonDecode(rawMsgCall) is Map ? Map<String, dynamic>.from(jsonDecode(rawMsgCall)) : {})
                : {});
        final String? senderId = payload['senderId'] ?? msgCallMap['senderId'];
        if (senderId != null && senderId.isNotEmpty) {
          User? sender;
          try {
            sender = await UserApi.getUser(senderId);
          } catch (e) {
            debugPrint('Error fetching user for message notification: $e');
          }
          sender ??= User.fromMap({
            'userId': senderId,
            'fullname': title.isNotEmpty ? title : 'User',
            'photoUrl': payload['senderAvatar'] ?? '',
          });
          await RoutesHelper.toMessages(isGroup: false, user: sender);
        }
        break;

      case 'group':
        final dynamic rawGrpCall = payload['call'];
        final Map<String, dynamic> grpCallMap = rawGrpCall is Map
            ? Map<String, dynamic>.from(rawGrpCall)
            : (rawGrpCall is String && rawGrpCall.isNotEmpty
                ? (jsonDecode(rawGrpCall) is Map ? Map<String, dynamic>.from(jsonDecode(rawGrpCall)) : {})
                : {});
        final String? groupId = payload['groupId'] ?? grpCallMap['groupId'];
        if (groupId != null) {
          await RoutesHelper.toMessages(isGroup: true, groupId: groupId);
        }
        break;

      case 'alert':
        // Show alert dialog info
        DialogHelper.showAlertDialog(
          icon: const AppLogo(width: 35, height: 35),
          title: title.isNotEmpty ? Text(title) : const Text(AppConfig.appName),
          content: Text(message),
          actionText: 'OK'.tr,
          action: () => Get.back(),
          showCancelButton: false,
        );
        break;

      case 'room_invite':
        final Map<String, dynamic> callData = payload['call'] != null
            ? Map<String, dynamic>.from(jsonDecode(payload['call']))
            : {};
        final String? roomId = callData['roomId'];
        if (roomId != null && roomId.isNotEmpty) {
          DialogHelper.showAlertDialog(
            icon: const AppLogo(width: 35, height: 35),
            title: Text(title.isNotEmpty ? title : 'Room Invitation'),
            content: Text(message.isNotEmpty ? message : 'Join our voice room!'),
            actionText: 'Join',
            action: () {
              Get.back();
              // Navigate to the room
              AudioRoomsV2Integration.joinRoomById(roomId);
            },
            showCancelButton: true,
            cancelAction: () => Get.back(),
          );
        }
        break;

      case 'follower_room':
        final dynamic rawCall = payload['call'];
        final Map<String, dynamic> callData = rawCall is Map
            ? Map<String, dynamic>.from(rawCall)
            : (rawCall is String && rawCall.isNotEmpty
                ? (jsonDecode(rawCall) is Map ? Map<String, dynamic>.from(jsonDecode(rawCall)) : {})
                : {});
        final String? roomId = callData['roomId'] ?? payload['roomId'];
        if (roomId != null && roomId.isNotEmpty) {
          // Navigate immediately to the room without dialog
          AudioRoomsV2Integration.joinRoomById(roomId);
        }
        break;
    }
  }
}
