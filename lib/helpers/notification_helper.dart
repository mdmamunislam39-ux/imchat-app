import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/app_logo.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/routes/app_routes.dart';

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
        // Get call data
        final Call call = Call.fromMap(data: jsonDecode(payload['call']));

        // Go to incoming call page if not already there
        if (Get.currentRoute != AppRoutes.incomingCall) {
          Get.toNamed(AppRoutes.incomingCall, arguments: {'call': call});
        }
        break;

      case 'message':
        final String? senderId = payload['senderId'];
        if (senderId != null) {
          // Navigate immediately to avoid hang/loading screen
          final User sender = User.fromMap({
            'userId': senderId,
            'fullname': title.isNotEmpty ? title : 'User',
          });
          RoutesHelper.toMessages(isGroup: false, user: sender);
        }
        break;

      case 'group':
        final String? groupId = payload['groupId'];
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
        final Map<String, dynamic> callData = payload['call'] != null
            ? (payload['call'] is String ? Map<String, dynamic>.from(jsonDecode(payload['call'])) : Map<String, dynamic>.from(payload['call']))
            : {};
        final String? roomId = callData['roomId'];
        if (roomId != null && roomId.isNotEmpty) {
          // Navigate immediately to the room without dialog
          AudioRoomsV2Integration.joinRoomById(roomId);
        }
        break;
    }
  }
}
