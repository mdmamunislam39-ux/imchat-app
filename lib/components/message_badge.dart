import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/screens/messages/components/rich_text_message.dart';
import 'package:chat_messenger/screens/messages/components/read_time_status.dart';
import 'package:get/get.dart';

class MessageBadge extends StatelessWidget {
  const MessageBadge({
    super.key,
    required this.type,
    required this.textMsg,
    this.maxLines,
    this.textStyle,
  });

  final MessageType type;
  final String textMsg;
  final TextStyle? textStyle;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (type == MessageType.text && ReadTimeStatus.isCallMessage(textMsg)) {
      final isVideo = textMsg.toLowerCase().contains('video') || textMsg.startsWith('📹');
      final isMissed = textMsg.toLowerCase().contains('missed') || textMsg.startsWith('📹') || textMsg.startsWith('🎤');
      
      String displayTitle = isVideo ? 'Video call' : 'Audio call';
      if (textMsg.startsWith('call|')) {
        final parts = textMsg.split('|');
        final status = parts.length > 2 ? parts[2] : '';
        final dur = parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0;
        if (status == 'missed') {
          displayTitle = isVideo ? 'Missed Video Call' : 'Missed Audio Call';
        } else if (status == 'canceled') {
          displayTitle = 'Canceled Call';
        } else if (status == 'rejected') {
          displayTitle = 'Rejected Call';
        } else if (dur > 0) {
          final m = dur ~/ 60;
          final s = dur % 60;
          final durStr = m > 0 ? (s > 0 ? '$m min $s sec' : '$m min') : '$s sec';
          displayTitle = '${isVideo ? 'Video call' : 'Audio call'} ($durStr)';
        }
      } else if (isMissed) {
        displayTitle = isVideo ? 'Missed Video Call' : 'Missed Audio Call';
      }

      final icon = isMissed
          ? Icons.call_missed
          : (isVideo ? Icons.videocam : Icons.call);
      final color = isMissed ? Colors.red : greyColor;

      return Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 20, color: color),
          ),
          Expanded(
            child: RichTexMessage(
              text: displayTitle,
              maxLines: maxLines,
              defaultStyle: textStyle ??
                  const TextStyle(
                    fontSize: 14,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
          ),
        ],
      );
    }

    return switch (type) {
      MessageType.text => rowInfo(title: textMsg),
      MessageType.image => rowInfo(icon: Icons.image, title: 'photo'.tr),
      MessageType.gif => rowInfo(icon: Icons.gif_box, title: 'GIF'),
      MessageType.audio => rowInfo(icon: Icons.headphones, title: 'audio'.tr),
      MessageType.video => rowInfo(icon: IconlyBold.video, title: 'video'.tr),
      MessageType.doc =>
        rowInfo(icon: IconlyBold.document, title: 'document'.tr),
      MessageType.location =>
        rowInfo(icon: IconlyBold.location, title: 'location'.tr),
      MessageType.hostInvitation =>
        rowInfo(icon: Icons.business_center, title: textMsg.isNotEmpty ? textMsg : '🏆 Agency Invitation'),
      MessageType.relationshipInvitation =>
        rowInfo(icon: Icons.favorite, title: textMsg.isNotEmpty ? textMsg : '❤️ Intimacy Invitation'),
      MessageType.roomShare =>
        rowInfo(icon: Icons.mic, title: textMsg.isNotEmpty ? textMsg : '🎙️ Voice Room Shared'),
      _ => rowInfo(title: textMsg),
    };
  }

  Widget rowInfo({
    IconData? icon,
    required String title,
  }) {
    return Row(
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 20, color: greyColor),
          ),
        Expanded(
          child: RichTexMessage(
            text: title,
            maxLines: maxLines,
            defaultStyle: textStyle ??
                const TextStyle(
                  fontSize: 14,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
        ),
      ],
    );
  }
}

class MessageDeleted extends StatelessWidget {
  const MessageDeleted({
    super.key,
    required this.isSender,
    this.iconColor = greyColor,
    this.iconSize,
    this.style,
  });

  final bool isSender;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String deletedMsg = isSender
        ? 'you_deleted_this_message'.tr
        : 'this_message_was_deleted'.tr;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: iconSize, color: iconColor),
        const SizedBox(width: 3),
        Text(deletedMsg, style: style),
      ],
    );
  }
}
