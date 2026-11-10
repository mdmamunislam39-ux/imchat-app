import 'dart:io';

import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/preferences_controller.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/tabs/groups/components/update_message.dart';
import 'package:get/get.dart';

import 'components/appbar_tools.dart';
import 'components/encrypted_notice.dart';
import 'components/msg_appbar_tools.dart';
import 'controllers/block_controller.dart';
import 'components/bubble_message.dart';
import 'components/chat_input_field.dart';
import 'components/group_active_audio_room_bar.dart';
import 'components/pending_friend_request_banner.dart';
import 'components/group_date_separator.dart';
import 'components/scroll_down_button.dart';
import 'controllers/message_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud_firestore;
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'components/official_team_broadcast_input_bar.dart';

class MessageScreen extends StatelessWidget {
  const MessageScreen({
    super.key,
    required this.isGroup,
    this.user,
    this.groupId,
  });

  final bool isGroup;
  final User? user;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    // Generate unique tag for this chat instance
    final String tag = isGroup ? (groupId ?? user?.userId ?? '') : (user?.userId ?? '');

    // Init controllers
    final MessageController controller = Get.put(
      MessageController(isGroup: isGroup, user: user, groupId: groupId),
      tag: tag,
    );
    Get.put(BlockController(user?.userId), tag: tag);

    // Find instance
    final PreferencesController prefController = Get.find();

    // Check group
    if (isGroup) {
      prefController.getGroupWallpaperPath(
        controller.selectedGroup!.groupId,
      );
    } else {
      prefController.getChatWallpaperPath();
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Obx(() {
          final Group? group = controller.selectedGroup;
          return controller.selectedMessage.value != null
              ? MsgAppBarTools(controller: controller)
              : AppBarTools(controller: controller, isGroup: isGroup, user: user, group: group);
        }),
      ),
      body: Obx(
        () {
          // Get wallpaper path
          final String? wallpaperPath = isGroup
              ? prefController.groupWallpaperPath.value
              : prefController.chatWallpaperPath.value;

          return Container(
            decoration: BoxDecoration(
              image: wallpaperPath != null
                  ? DecorationImage(
                      image: FileImage(File(wallpaperPath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // <-- Active Group Audio Room Bar -->
                if (isGroup)
                  GroupActiveAudioRoomBar(
                    controller: controller,
                    overrideGroupId: groupId,
                  ),

                // <-- Pending Friend Request Banner (for 1-on-1 chats) -->
                if (!isGroup && user != null)
                  PendingFriendRequestBanner(user: user!),

                // <-- List of Messages -->
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding),
                    child: _buildMessagesList(controller, wallpaperPath),
                  ),
                ),
                // <--- ChatInput or Read-Only Notice --->
                if (!_isOfficialChat)
                  ChatInputField(
                    controller: controller,
                    user: user,
                    group: controller.selectedGroup,
                  )
                else
                  _buildOfficialBottomBar(context, controller),
              ],
            ),
          );
        },
      ),
      // Show scroll list button
      floatingActionButton: _buildScrollButton(controller),
    );
  }

  Widget _buildOfficialBottomBar(BuildContext context, MessageController controller) {
    if (user?.userId != 'official_team') {
      return _buildReadOnlyNotice(context);
    }

    final String currentUserId = AuthController.instance.currentUser.userId;
    if (currentUserId.isEmpty) {
      return _buildReadOnlyNotice(context);
    }

    return StreamBuilder<cloud_firestore.DocumentSnapshot>(
      stream: cloud_firestore.FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return _buildReadOnlyNotice(context);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final bool hasPerm = data['hasAppNotificationPermission'] == true;
        final permData = data['appNotificationPermission'] as Map<String, dynamic>? ?? {};
        final bool isActive = permData['isActive'] == true;
        final bool canPost = permData['canPostToImChatTeam'] == true;

        if (hasPerm && isActive && canPost) {
          return OfficialTeamBroadcastInputBar(
            controller: controller,
            permissionData: permData,
          );
        }

        return _buildReadOnlyNotice(context);
      },
    );
  }

  bool get _isOfficialChat =>
      !isGroup &&
      user != null &&
      (user!.userId == 'official_team' ||
          user!.userId.startsWith('official_channel_') ||
          user!.userType == 'channel');

  Widget _buildReadOnlyNotice(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E24) : const Color(0xFFF7F7F8),
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        top: false,
        child: Text(
          'official_messages_read_only'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(MessageController controller, String? wallpaperPath) {
    // Get selected group instance
    Group? group = controller.selectedGroup;

    return Obx(
      () {
        // Show loader while initial loading and messages are empty
        if (controller.messages.isEmpty && (!controller.isInitialDataSettled.value || controller.isLoading.value)) {
          return const Center(child: LoadingIndicator(size: 35));
        } else if (controller.messages.isEmpty) {
          return NoData(
            iconData: IconlyBold.chat,
            text: 'no_messges'.tr,
            textColor: wallpaperPath != null ? Colors.white : null,
          );
        } else {
          // Get Messages List in reversed order
          final List<Message> messages = controller.messages;

          return ListView.builder(
            reverse: true,
            controller: controller.scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              // Get Message Object
              final Message message = messages[index];


              // <--- Handle group date --->
              final DateTime? sentAt = message.sentAt;
              Widget dateSeparator = const SizedBox.shrink();

              // Check sent time
              if (sentAt != null) {
                // Check first element in reverse order
                if (index == messages.length - 1) {
                  dateSeparator = GroupDateSeparator(sentAt.formatDateTime);
                } else if (index + 1 < messages.length) {
                  // Get previous date in reverse order safely
                  final DateTime? prevDate = messages[index + 1].sentAt;
                  if (prevDate != null && !sentAt.isSameDate(prevDate)) {
                    dateSeparator = GroupDateSeparator(
                      sentAt.formatDateTime,
                    );
                  }
                }
              }

              // Get sender user
              final User senderUser =
                  isGroup ? group!.getMemberProfile(message.senderId) : user!;

              final Rxn<Message> selectedMessage = controller.selectedMessage;
              final bool isSelected = selectedMessage.value == message;
              final EdgeInsets? bubblePadding =
                  isSelected ? const EdgeInsets.fromLTRB(16, 0, 16, 16) : null;
              final Color? bubbleColor =
                  isSelected ? primaryColor.withValues(alpha: 0.3) : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show top loading indicator when fetching older messages
                  if (index == messages.length - 1)
                    Obx(() => controller.isLoadingMore.value
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : const SizedBox.shrink()),
                  // Show Group Date time
                  dateSeparator,
                  // Show encrypted notice
                  if (!isGroup && index == messages.length - 1)
                    const EncryptedNotice(),
                  // Bubble message
                  GestureDetector(
                    onLongPress: () {
                      if (message.type == MessageType.groupUpdate || _isOfficialChat) {
                        return;
                      }
                      selectedMessage.value = message;
                    },
                    onTap: () => selectedMessage.value = null,
                    child: Container(
                      padding: bubblePadding,
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: isSelected ? borderRadius : null,
                      ),
                      child: isGroup && message.type == MessageType.groupUpdate
                          ? UpdateMessage(
                              group: group!,
                              message: message,
                            )
                          : BubbleMessage(
                              message: message,
                              user: user,
                              group: group,
                              isReceiverOnline: controller.isReceiverOnline,
                              onTapProfile: message.isSender
                                  ? null
                                  : () => RoutesHelper.toProfileView(
                                      senderUser, isGroup),
                              onReplyMessage: (message.isDeleted || _isOfficialChat)
                                  ? null
                                  : () => controller.replyToMessage(message),
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget _buildScrollButton(MessageController controller) {
    return Obx(() {
      // Check it.
      if (!controller.showScrollButton.value) {
        return const SizedBox.shrink();
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -10,
            bottom: 50,
            child: ScrollDownButton(
              onPress: () => controller.scrollToBottom(),
            ),
          ),
        ],
      );
    });
  }
}
