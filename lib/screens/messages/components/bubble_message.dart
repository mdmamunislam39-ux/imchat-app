import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/plugins/swipeto/swipe_to.dart';
import 'package:chat_messenger/screens/messages/components/bubbles/location_message.dart';
import 'package:chat_messenger/screens/messages/components/reply_message.dart';
import 'package:chat_messenger/screens/messages/controllers/message_controller.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'bubbles/audio_message.dart';
import 'bubbles/document_message.dart';
import 'bubbles/gif_message.dart';
import 'bubbles/image_message.dart';
import 'bubbles/text_message.dart';
import 'bubbles/call_message.dart';
import 'bubbles/video_message.dart';
import 'bubbles/room_share_message.dart';
import 'bubbles/host_invitation_message.dart';
import 'bubbles/relationship_invitation_message.dart';
import 'forwarded_badge.dart';
import 'read_time_status.dart';

class BubbleMessage extends StatelessWidget {
  const BubbleMessage({
    super.key,
    required this.message,
    required this.onTapProfile,
    required this.onReplyMessage,
    required this.user,
    required this.group,
    this.isReceiverOnline,
  });

  // final bool isGroup;
  final Message message;
  final User? user;
  final Group? group;
  // final String senderName;
  // final String? profileUrl;
  final Function()? onTapProfile;
  final Function()? onReplyMessage;
  final RxBool? isReceiverOnline;

  @override
  Widget build(BuildContext context) {
    // Variables
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final bool isGroup = group != null;

    // Get sender user
    final User senderUser =
        isGroup ? group!.getMemberProfile(message.senderId) : user!;

    // Get sender profile url
    final String profileUrl = message.isSender
        ? AuthController.instance.currentUser.photoUrl
        : senderUser.photoUrl;

    final bool isSender = message.isSender;
    final bool isCall = message.type == MessageType.text && ReadTimeStatus.isCallMessage(message.textMsg);

    final Color backgroundColor = isCall ||
            message.type == MessageType.roomShare ||
            message.type == MessageType.hostInvitation ||
            message.type == MessageType.relationshipInvitation
        ? Colors.transparent
        : isSender
            ? primaryColor
            : isDarkMode
                ? greyColor.withValues(alpha: 0.5)
                : greyLight;
    final Color senderColor = isDarkMode
        ? Colors.white
        : ColorGenerator.getColorForSender(message.senderId);

    return SwipeTo(
      iconColor: primaryColor,
      onRightSwipe: onReplyMessage,
      child: Container(
        alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isSender)
              GestureDetector(
                onTap: onTapProfile,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                  child: CachedCircleAvatar(
                    imageUrl: senderUser.photoUrl,
                    radius: 14,
                    iconSize: 16,
                  ),
                ),
              ),
            Flexible(
              child: Container(
                margin: EdgeInsets.only(
                  top: defaultPadding,
                  left: isSender ? 50 : 0,
                  right: isSender ? 0 : 50,
                ),
          padding: isCall ||
                  message.type == MessageType.roomShare ||
                  message.type == MessageType.hostInvitation ||
                  message.type == MessageType.relationshipInvitation
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(8, 8, 8, 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: isCall ||
                    message.type == MessageType.roomShare ||
                    message.type == MessageType.hostInvitation ||
                    message.type == MessageType.relationshipInvitation
                ? null
                : BorderRadius.only(
                    topLeft: Radius.circular(!isSender ? 0 : 12),
                    topRight: Radius.circular(isSender ? 0 : 12),
                    bottomLeft: const Radius.circular(12),
                    bottomRight: const Radius.circular(12),
                  ),
          ),
          child: isCall
              ? _showMessageContent(profileUrl)
              : Stack(
            children: [
              // <--- Show message content -->
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Forwarded badge
                  if (message.isForwarded && !message.isDeleted)
                    ForwardedBadge(isSender: isSender),
                  // Show sender name
                  if (isGroup && !isSender && !message.isDeleted)
                    GestureDetector(
                      onTap: onTapProfile,
                      child: Text(
                        isSender ? 'you'.tr : "~ ${senderUser.fullname}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: senderColor,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  // Reply message
                  if (message.replyMessage != null)
                    ReplyMessage(
                      message: message.replyMessage!,
                      senderName: isGroup
                          ? group!
                              .getMemberProfile(message.replyMessage!.senderId)
                              .fullname
                          : user!.fullname,
                      bgColor: message.isSender
                          ? isDarkMode
                              ? Colors.black
                              : greyLight
                          : null,
                      lineColor: message.isSender ? secondaryColor : null,
                    ),
                  // Main message
                  _showMessageContent(profileUrl),
                ],
              ),
              // <-- Show sent time -->
              if (message.type != MessageType.roomShare &&
                  message.type != MessageType.hostInvitation &&
                  message.type != MessageType.relationshipInvitation)
                ReadTimeStatus(
                  message: message,
                  isGroup: isGroup,
                  receiver: isGroup ? null : user,
                  isReceiverOnline: isReceiverOnline,
                ),
            ],
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle message type
  Widget _showMessageContent(String profileUrl) {
    // Check type
    switch (message.type) {
      case MessageType.text:
        // Check if it's a call message
        final text = message.textMsg;
        if (ReadTimeStatus.isCallMessage(text)) {
          final isMissed = text.startsWith('📹') || text.startsWith('🎤') || text.toLowerCase().contains('missed');
          final isVideo = text.toLowerCase().contains('video') || text.startsWith('📹');
          final bool isGrp = group != null;
          final User sUser = isGrp ? group!.getMemberProfile(message.senderId) : user!;
          
          return CallMessage(
            message: message,
            partnerUser: isGrp ? null : (message.isSender ? user : sUser),
            isMissed: isMissed,
            isVideo: isVideo,
            isGroup: isGrp,
            isReceiverOnline: isReceiverOnline,
          );
        }
        
        // Show text msg
        return TextMessage(message);

      case MessageType.image:
        // Show image msg
        return ImageMessage(message);

      case MessageType.gif:
        // Show GIF msg
        return GifMessage(message);

      case MessageType.audio:
        // Show audio msg
        return AudioMessage(
          message,
          profileUrl: profileUrl,
        );

      case MessageType.video:
        // Show video msg
        return VideoMessage(message);

      case MessageType.doc:
        // Show document msg
        return DocumentMessage(
          message: message,
        );

      case MessageType.location:
        return LocationMessage(message);

      case MessageType.roomShare:
        return RoomShareMessage(message: message, isGroup: group != null);

      case MessageType.hostInvitation:
        return HostInvitationMessage(message: message, isGroup: group != null);

      case MessageType.relationshipInvitation:
        return RelationshipInvitationMessage(message: message, isGroup: group != null);

      default:
        return const SizedBox.shrink();
    }
  }
}
