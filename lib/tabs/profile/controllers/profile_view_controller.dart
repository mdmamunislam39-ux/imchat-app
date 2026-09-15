import 'package:flutter/material.dart';
import 'package:chat_messenger/api/block_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';
import 'package:get/get.dart';

class ProfileViewController extends GetxController {
  final String userId;

  ProfileViewController(this.userId);

  final RxBool isBlocked = RxBool(false);

  @override
  void onInit() {
    _checkBlockedUser();
    _loadFrame();
    super.onInit();
  }

  Future<void> _checkBlockedUser() async {
    final User currentUser = AuthController.instance.currentUser;

    isBlocked.value = await BlockApi.isBlocked(
      userId1: currentUser.userId,
      userId2: userId,
    );
  }

  final RxnString currentFrameUrl = RxnString();

  Future<void> _loadFrame() async {
    try {
      // 1. Check synchronous cache first for instant UI response
      final cachedUrl = FrameHelper.getCachedUserFrameUrl(userId);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        currentFrameUrl.value = cachedUrl;
        return;
      }

      final resolvedUrl = await FrameHelper.getFrameUrlFromUserId(userId);
      if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
        currentFrameUrl.value = resolvedUrl;
      }
    } catch (e) {
      debugPrint('❌ Error loading frame: $e');
    }
  }

  Future<void> toggleBlockUser() async {
    final User currentUser = AuthController.instance.currentUser;

    if (isBlocked.value) {
      BlockApi.unblockUser(
          currentUserId: currentUser.userId, otherUserId: userId);
    } else {
      BlockApi.blockUser(
          currentUserId: currentUser.userId, otherUserId: userId);
    }
    isBlocked.toggle();
  }
}
