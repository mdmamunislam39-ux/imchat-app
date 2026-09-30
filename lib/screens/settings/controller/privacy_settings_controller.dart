import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrivacySettingsController extends GetxController {
  final RxBool isLoading = false.obs;

  // Online & Activity Status
  final RxBool showOnlineStatus = true.obs;
  final RxBool hideRoomPresence = false.obs;
  final RxBool showLastSeen = true.obs;

  // Profile & Asset Privacy
  final RxBool hideWealthLevel = false.obs;
  final RxBool hideGiftWall = false.obs;
  final RxBool hideLocation = false.obs;

  // Interaction Permissions
  final RxString whoCanMessage = 'everyone'.obs; // 'everyone', 'friends', 'nobody'
  final RxString whoCanCall = 'everyone'.obs;    // 'everyone', 'friends', 'nobody'
  final RxBool allowRoomInvites = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final user = AuthController.instance.currentUser;
    final settings = user.privacySettings ?? UserPrivacySettings();

    showOnlineStatus.value = settings.showOnlineStatus;
    hideRoomPresence.value = settings.hideRoomPresence;
    showLastSeen.value = settings.showLastSeen;
    hideWealthLevel.value = settings.hideWealthLevel;
    hideGiftWall.value = settings.hideGiftWall;
    hideLocation.value = settings.hideLocation;
    whoCanMessage.value = settings.whoCanMessage;
    whoCanCall.value = settings.whoCanCall;
    allowRoomInvites.value = settings.allowRoomInvites;
  }

  Future<void> updateField(String key, dynamic value) async {
    final currentUserId = AuthController.instance.currentUser.userId;
    if (currentUserId.isEmpty) return;

    try {
      await UserApi.updateUserData(
        userId: currentUserId,
        data: {
          'privacySettings.$key': value,
        },
      );
    } catch (e) {
      debugPrint('⚠️ [PrivacySettingsController] Error updating $key: $e');
    }
  }

  void toggleShowOnlineStatus(bool value) {
    showOnlineStatus.value = value;
    updateField('showOnlineStatus', value);
  }

  void toggleHideRoomPresence(bool value) {
    hideRoomPresence.value = value;
    updateField('hideRoomPresence', value);
  }

  void toggleShowLastSeen(bool value) {
    showLastSeen.value = value;
    updateField('showLastSeen', value);
  }

  void toggleHideWealthLevel(bool value) {
    hideWealthLevel.value = value;
    updateField('hideWealthLevel', value);
  }

  void toggleHideGiftWall(bool value) {
    hideGiftWall.value = value;
    updateField('hideGiftWall', value);
  }

  void toggleHideLocation(bool value) {
    hideLocation.value = value;
    updateField('hideLocation', value);
  }

  void setWhoCanMessage(String value) {
    whoCanMessage.value = value;
    updateField('whoCanMessage', value);
  }

  void setWhoCanCall(String value) {
    whoCanCall.value = value;
    updateField('whoCanCall', value);
  }

  void toggleAllowRoomInvites(bool value) {
    allowRoomInvites.value = value;
    updateField('allowRoomInvites', value);
  }
}
