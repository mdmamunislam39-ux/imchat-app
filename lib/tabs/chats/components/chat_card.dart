import 'package:flutter/material.dart';
import 'package:chat_messenger/components/message_badge.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/components/badge_count.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/sent_time.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/app_helper.dart';

class ChatCard extends StatelessWidget {
  const ChatCard(this.chat, {super.key, required this.onDeleteChat});

  final Chat chat;
  final Function()? onDeleteChat;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final User receiver = chat.receiver ?? User(userId: chat.senderId, fullname: 'User');
    final bool isOfficial = receiver.userId == 'official_team' ||
        receiver.userId.startsWith('official_channel_') ||
        receiver.userType == 'channel';
    final String displayName = isOfficial
        ? receiver.fullname
        : (receiver.fullname.isNotEmpty ? receiver.fullname.formattedUsername : 'User');

    return InkWell(
      onTap: () async {
        RoutesHelper.toMessages(user: receiver);
        chat.viewChat();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? greyLight.withValues(alpha: 0.10) : greyLight,
            ),
          ),
        ),
        child: GestureDetector(
          onLongPress: onDeleteChat,
          child: Row(
            children: [
              // Profile avatar
              (isOfficial && receiver.photoUrl.isEmpty)
                  ? Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: Image.asset(
                          "assets/images/app_logo.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : CachedCircleAvatar(
                      imageUrl: receiver.photoUrl,
                      radius: 25,
                      isOnline: receiver.isOnline,
                      borderColor: chat.unread > 0 ? primaryColor : null,
                      lastActive: receiver.lastActive?.millisecondsSinceEpoch,
                      showOfflineStatus: true,
                    ),
              const SizedBox(width: 12),
              // Profile info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 01 - name & sent time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Profile name
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              text: displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                              children: [
                                if (isOfficial || receiver.isVerified == true)
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sent time
                        SentTime(
                          time: chat.isDeleted ? chat.updatedAt : chat.sentAt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 02 - Last message & unread
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Last message
                        LastMessage(chat: chat, user: receiver),
                        // Show muted icon
                        if (chat.isMuted)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.volume_off, size: 16, color: greyColor),
                          ),
                        // Total unread messages
                        BadgeCount(
                          counter: chat.unread,
                          bgColor: const Color(0xFFfa4e1c),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LastMessage extends StatelessWidget {
  const LastMessage({super.key, required this.chat, required this.user});

  final Chat chat;
  final User user;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: primaryColor);
    final String currentUserId = AuthController.instance.currentUser.userId;

    final bool isTyping = user.isTyping && user.typingTo == currentUserId;
    final bool isRecording = user.isRecording && user.recordingTo == currentUserId;

    // Check chat status
    if (chat.isDeleted) {
      return Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: MessageDeleted(iconSize: 20, isSender: chat.isSender),
        ),
      );
    } else if (isTyping) {
      return Expanded(
        child: Text(
          'typing'.tr,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (isRecording) {
      return Expanded(
        child: Text(
          'recording_audio'.tr,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Expanded(
      child: MessageBadge(
        type: chat.msgType,
        textMsg: chat.lastMsg,
        maxLines: 1,
        textStyle: const TextStyle(fontSize: 14, color: greyColor),
      ),
    );
  }
}
