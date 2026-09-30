import 'dart:async';

import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/chat_api.dart';
import 'package:chat_messenger/models/chat.dart';

import 'package:chat_messenger/services/global_settings_service.dart';

class ChatController extends GetxController {
  // Get the current instance
  static ChatController get instance => Get.find<ChatController>();

  // Vars
  final RxBool isLoading = RxBool(true);
  final RxList<Chat> chats = RxList();
  final RxBool isSearching = RxBool(false);
  final TextEditingController searchController = TextEditingController();
  StreamSubscription<List<Chat>>? _stream;

  bool get newMessage => chats.where((el) => el.unread > 0).isNotEmpty;

  /// Total number of unread messages across all chats
  int get totalUnreadCount => chats.fold(0, (sum, chat) => sum + chat.unread);

  @override
  void onInit() {
    // Load chats
    _getChats();

    // Dynamically re-bind chat stream when backend engine is switched from Admin Panel
    if (Get.isRegistered<GlobalSettingsService>()) {
      ever(Get.find<GlobalSettingsService>().activeBackendEngine, (_) {
        debugPrint('🔄 [ChatController] Backend Engine changed! Switching chat stream in real-time...');
        _stream?.cancel();
        isLoading.value = true;
        _getChats();
      });
    }

    super.onInit();
  }

  @override
  void onClose() {
    _stream?.cancel();
    searchController.dispose();
    super.onClose();
  }

  void _getChats() {
    _stream = ChatApi.getChats().listen((event) {
      chats.value = event;
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }

  Chat? getChat(String receiverId) {
    try {
      for (final chat in chats) {
        if (chat.receiver?.userId == receiverId) {
          return chat;
        }
      }
    } catch (_) {}
    return null;
  }

  bool isChatMuted(String receiverId) {
    try {
      final Chat? chat = getChat(receiverId);
      return chat?.isMuted ?? false;
    } catch (_) {
      return false;
    }
  }

  // Search chats by user full name or message content
  List<Chat> searchChat() {
    final String text = searchController.text.trim().toLowerCase();

    isSearching.value = text.isNotEmpty;
    if (text.isEmpty) return chats;
    return chats
        .where((chat) =>
            (chat.receiver?.fullname.toLowerCase().contains(text) ?? false) ||
            chat.lastMsg.toLowerCase().contains(text))
        .toList();
  }

  void clearSerachInput(BuildContext context) {
    searchController.clear();
    isSearching.value = false;
    FocusScope.of(context).unfocus();
  }

  void deleteChat(String userId) {
    // Confirm delete chat
    DialogHelper.showAlertDialog(
      titleColor: errorColor,
      title: Text('delete_chat'.tr),
      content: Text('this_action_cannot_be_reversed'.tr),
      actionText: 'DELETE'.tr.toUpperCase(),
      action: () {
        Get.back();
        ChatApi.deleteChat(userId: userId);
      },
    );
  }
}
