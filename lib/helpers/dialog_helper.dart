import 'dart:io';

import 'package:chat_messenger/config/app_config.dart';
import 'package:flutter/material.dart';

import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/story/submodels/seen_by.dart';
import 'package:chat_messenger/screens/messages/components/audio-recorder/audio_recorder_modal.dart';
import 'package:chat_messenger/tabs/groups/components/create_group_modal.dart';
import 'package:chat_messenger/tabs/groups/components/group_actions_modal.dart';
import 'package:chat_messenger/tabs/stories/components/story_seen_by_modal.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/pick_image_modal.dart';
import 'package:chat_messenger/dialogs/custom_alert.dart';
import 'package:chat_messenger/dialogs/processing_dialog.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';

enum SnackMsgType { error, success, info, custom }

abstract class DialogHelper {
  //
  // Dialog Messages Methods
  //
  static BuildContext get context => Get.context!;

  // Show Snackbar Message
  static void showSnackbarMessage(
    SnackMsgType type,
    String message, {
    String? customTitle,
    Color? bgColor = primaryColor,
    SnackPosition position = SnackPosition.BOTTOM,
    int duration = 5,
  }) {
    String title = '';
    IconData iconData = Icons.info_outline;

    // Check type
    switch (type) {
      case SnackMsgType.error:
        title = 'error'.tr;
        bgColor = errorColor;
        iconData = Icons.error_outline;
        break;
      case SnackMsgType.success:
        title = 'success'.tr;
        iconData = Icons.check_circle_outline;
        break;
      case SnackMsgType.info:
        title = 'info'.tr;
        iconData = Icons.info_outline;
        break;
      case SnackMsgType.custom:
        title = customTitle ?? '';
        iconData = Icons.notifications_none;
        break;
    }

    Future.delayed(Duration.zero, () {
      if (Get.overlayContext != null) {
        Get.snackbar(
          title,
          message,
          colorText: Colors.white,
          icon: Icon(iconData, color: Colors.white),
          backgroundColor: bgColor,
          snackPosition: position,
          borderRadius: defaultRadius,
          duration: Duration(seconds: duration),
          margin: const EdgeInsets.all(defaultMargin),
        );
      } else {
        debugPrint('Warning: Get.overlayContext is null. Cannot show snackbar: $message');
      }
    });
  }

  static void showProcessingDialog({
    String? title,
    String? description,
    bool barrierDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext _) =>
          ProcessingDialog(title, description: description),
    );
  }

  static Future showAlertDialog<T>({
    required Widget title,
    Color titleColor = primaryColor,
    Widget? icon,
    Widget? content,
    String? actionText,
    Function()? action,
    Function()? cancelAction,
    bool showCancelButton = true,
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) => CustomAlert(
        title: title,
        titleColor: titleColor,
        icon: icon,
        content: content,
        actionText: actionText,
        action: action,
        showCancelButton: showCancelButton,
        barrierDismissible: barrierDismissible,
        cancelAction: cancelAction,
      ),
    );
  }

  static Future<File?> showPickImageDialog({bool isAvatar = false}) {
    return showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(defaultRadius)),
      ),
      builder: (BuildContext context) => PickImageModal(isAvatar: isAvatar),
    );
  }

  static Future<File?> showAudioRecorderModal(String? receiverId) {
    return showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(defaultRadius)),
      ),
      builder: (BuildContext context) => AudioRecorderModal(receiverId),
    );
  }

  static Future createGroupModal() {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(defaultRadius)),
      ),
      builder: (BuildContext context) => const CreateGroupModal(),
    );
  }

  static Future<File?> showGroupOptionsModal({
    required Group group,
    required User member,
    required bool isAdmin,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(defaultRadius)),
      ),
      builder: (BuildContext context) =>
          GroupActionsModal(group: group, member: member, isAdmin: isAdmin),
    );
  }

  static Future<void> showStorySeenByModal({
    required List<SeenBy> seenByList,
    required Function()? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(defaultRadius)),
      ),
      builder: (BuildContext context) => StorySeenByModal(
        seenByList: seenByList,
        onDelete: onDelete,
      ),
    );
  }

  static void showBlockedGroupDialog() {
    showAlertDialog(
      title: Text('group_blocked'.tr),
      content: Text(
          'group_blocked_message'.trParams({'appEmail': AppConfig.appEmail})),
      actionText: 'OK'.tr,
      action: () => Get.back(),
    );
  }

  static void closeDialog({bool closeOverlays = false}) {
    Get.back(closeOverlays: closeOverlays);
  }
}
