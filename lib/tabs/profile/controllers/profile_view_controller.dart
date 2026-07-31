import 'package:flutter/material.dart';
import 'package:chat_messenger/api/block_api.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/store_service.dart';
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
  final StoreService _storeService = StoreService();

  Future<void> _loadFrame() async {
    try {
      // Fetch latest user data to get customization
      final user = await UserApi.getUser(userId);
      if (user != null && user.customization?.selectedFrameId != null) {
        final frameDetails = await _storeService
            .getStoreItemDetails(user.customization!.selectedFrameId!);

        if (frameDetails != null) {
          currentFrameUrl.value = frameDetails['fileUrl'] ??
              frameDetails['thumbnailUrl'] ??
              frameDetails['imageUrl'] ??
              frameDetails['image'];
        }
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
