// import 'package:flutter/material.dart';
// import 'package:chat_messenger/api/user_api.dart';
// import 'package:chat_messenger/components/message_badge.dart';
// import 'package:chat_messenger/controllers/auth_controller.dart';
// import 'package:chat_messenger/helpers/routes_helper.dart';
// import 'package:get/get.dart';
// import 'package:chat_messenger/models/chat.dart';
// import 'package:chat_messenger/models/user.dart';
// import 'package:chat_messenger/components/badge_count.dart';
// import 'package:chat_messenger/components/cached_circle_avatar.dart';
// import 'package:chat_messenger/components/sent_time.dart';
// import 'package:chat_messenger/theme/app_theme.dart';
// import 'package:chat_messenger/config/theme_config.dart';

// // ignore: must_be_immutable
// class ChatCard extends StatelessWidget {
//   ChatCard(
//     this.chat, {
//     super.key,
//     required this.onDeleteChat,
//   });

//   final Chat chat;
//   User? updatedUser;
//   final Function()? onDeleteChat;

//   @override
//   Widget build(BuildContext context) {
//     // Vars
//     final bool isDarkMode = AppTheme.of(context).isDarkMode;
//     final User user = chat.receiver!;

//     return InkWell(
//       onTap: () async {
//         // Go to messages page
//         RoutesHelper.toMessages(user: updatedUser ?? user);
//         // Read chat
//         chat.viewChat();
//       },
//       child: Container(
//         padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
//         decoration: BoxDecoration(
//           border: Border(
//             bottom: BorderSide(
//               color: isDarkMode ? greyLight.withValues(alpha: 0.10) : greyLight,
//             ),
//           ),
//         ),
//         child: StreamBuilder<User>(
//           stream: UserApi.getUserUpdates(user.userId),
//           builder: (context, snapshot) {
//             updatedUser = snapshot.data;
//             final User receiver = updatedUser ?? user;

//             return GestureDetector(
//               onLongPress: onDeleteChat,
//               child: Row(
//                 children: [
//                   // Profile avatar
//                   CachedCircleAvatar(
//                     imageUrl: receiver.photoUrl,
//                     radius: 28,
//                     isOnline: receiver.isOnline,
//                     borderColor: chat.unread > 0 ? primaryColor : null,
//                   ),
//                   const SizedBox(width: 10),
//                   // Profile info
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Row 01 - name & sent time
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             // Profile name
//                             Text(
//                               receiver.fullname,
//                               style: Theme.of(context).textTheme.titleMedium,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             // Sent time
//                             SentTime(
//                               time:
//                                   chat.isDeleted ? chat.updatedAt : chat.sentAt,
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 2),

//                         // Row 02 - Last message & unread
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             // Last message
//                             LastMessage(chat: chat, user: receiver),
//                             // Show muted icon
//                             if (chat.isMuted)
//                               const Icon(
//                                 Icons.volume_off,
//                                 color: greyColor,
//                               ),
//                             // Total unread messages
//                             BadgeCount(
//                               counter: chat.unread,
//                               bgColor: const Color(0xFFfa4e1c),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class LastMessage extends StatelessWidget {
//   const LastMessage({
//     super.key,
//     required this.chat,
//     required this.user,
//   });

//   final Chat chat;
//   final User user;

//   @override
//   Widget build(BuildContext context) {
//     // Get text style
//     final TextStyle style =
//         Theme.of(context).textTheme.bodyMedium!.copyWith(color: primaryColor);
//     // Get current user ID.
//     final String currentUserId = AuthController.instance.currentUser.userId;

//     final bool isTyping = user.isTyping && user.typingTo == currentUserId;
//     final bool isRecording =
//         user.isRecording && user.recordingTo == currentUserId;

//     // Check chat status
//     if (chat.isDeleted) {
//       return MessageDeleted(
//         iconSize: 22,
//         isSender: chat.isSender,
//       );
//     } else if (isTyping) {
//       return Text('typing'.tr, style: style);
//     } else if (isRecording) {
//       return Text('recording_audio'.tr, style: style);
//     }
//     return Expanded(
//       child: MessageBadge(
//         type: chat.msgType,
//         textMsg: chat.lastMsg,
//         maxLines: 1,
//         textStyle: const TextStyle(fontSize: 16, color: greyColor),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:chat_messenger/api/user_api.dart';
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

class ChatCard extends StatefulWidget {
  const ChatCard(this.chat, {super.key, required this.onDeleteChat});

  final Chat chat;
  final Function()? onDeleteChat;

  @override
  State<ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends State<ChatCard> {
  late Stream<User> _userStream;
  User? _updatedUser;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant ChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chat.receiver?.userId != oldWidget.chat.receiver?.userId) {
      _initStream();
    }
  }

  void _initStream() {
    final user = widget.chat.receiver!;
    _userStream = user.userType == 'channel' ||
                  user.userId == 'official_team' ||
                  user.userId.startsWith('official_channel_')
              ? Stream.value(user)
              : UserApi.getUserUpdates(user.userId);
  }

  @override
  Widget build(BuildContext context) {
    // Vars
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final User user = widget.chat.receiver!;

    return InkWell(
      onTap: () async {
        // Go to messages page
        RoutesHelper.toMessages(user: _updatedUser ?? user);
        // Read chat
        widget.chat.viewChat();
      },
      child: Container(
        padding: const EdgeInsets.only(
          top: 14,
          bottom: 14,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? greyLight.withValues(alpha: 0.10) : greyLight,
            ),
          ),
        ),
        child: StreamBuilder<User>(
          stream: _userStream,
          builder: (context, snapshot) {
            _updatedUser = snapshot.data;
            final User receiver = _updatedUser ?? user;
            final bool isOfficial =
                receiver.userId == 'official_team' ||
                receiver.userId.startsWith('official_channel_') ||
                receiver.userType == 'channel';
            final String displayName = isOfficial
                ? receiver.fullname
                : receiver.fullname.formattedUsername;

            return GestureDetector(
              onLongPress: widget.onDeleteChat,
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
                          borderColor: widget.chat.unread > 0 ? primaryColor : null,
                          lastActive:
                              receiver.lastActive?.millisecondsSinceEpoch,
                          showOfflineStatus: true,
                        ),
                  const SizedBox(width: 10),
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
                                        child: Icon(
                                          Icons.verified,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Sent time
                            SentTime(
                              time: widget.chat.isDeleted
                                  ? widget.chat.updatedAt
                                  : widget.chat.sentAt,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Row 02 - Last message & unread
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Last message
                            LastMessage(chat: widget.chat, user: receiver),
                            // Show muted icon
                            if (widget.chat.isMuted)
                              const Icon(Icons.volume_off, color: greyColor),
                            // Total unread messages
                            BadgeCount(
                              counter: widget.chat.unread,
                              bgColor: const Color(0xFFfa4e1c),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // IconButton(onPressed: (){}, icon: Icon(Icons.call,size: 25,color: primaryColor,))
                ],
              ),
            );
          },
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
    // Get text style
    final TextStyle style = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: primaryColor);
    // Get current user ID.
    final String currentUserId = AuthController.instance.currentUser.userId;

    final bool isTyping = user.isTyping && user.typingTo == currentUserId;
    final bool isRecording =
        user.isRecording && user.recordingTo == currentUserId;

    // Check chat status
    if (chat.isDeleted) {
      return Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: MessageDeleted(iconSize: 22, isSender: chat.isSender),
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
        textStyle: const TextStyle(fontSize: 16, color: greyColor),
      ),
    );
  }
}
