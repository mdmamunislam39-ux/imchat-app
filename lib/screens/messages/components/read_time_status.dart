import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:flutter/material.dart';

class ReadTimeStatus extends StatelessWidget {
  const ReadTimeStatus({
    super.key,
    required this.message,
    required this.isGroup,
    this.isInline = false,
  });

  final Message message;
  final bool isGroup;
  final bool isInline;

  static bool isCallMessage(String text) {
    final lower = text.toLowerCase();
    return lower == 'video call' ||
        lower == 'voice call' ||
        lower == 'audio call' ||
        lower.startsWith('video call|') ||
        lower.startsWith('voice call|') ||
        lower.startsWith('audio call|') ||
        lower.startsWith('📹') ||
        lower.startsWith('🎤');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDoc = message.type == MessageType.doc;
    final bool isCall = message.type == MessageType.text && isCallMessage(message.textMsg);

    final Color textColor = isCall
        ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600)
        : (message.isSender ? Colors.white : (Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey));

    final Color iconColor = isCall
        ? (message.isRead ? Colors.blue : (message.sentAt == null ? Colors.grey : Colors.blue.shade700))
        : (message.isRead ? Colors.blue : (message.sentAt == null ? Colors.white70 : Colors.white));

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // <-- Sent time -->
        Opacity(
          opacity: 0.85,
          child: Text(
            message.isDeleted
                ? message.updatedAt?.formatMsgTime ?? ''
                : message.sentAt?.formatMsgTime ?? '',
            style: TextStyle(
              fontSize: isCall ? 11 : 10,
              overflow: TextOverflow.ellipsis,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 3),
        // Read status
        if (message.isSender && !isGroup)
          Icon(
            message.sentAt == null 
                ? Icons.access_time_rounded 
                : (message.isRead ? Icons.done_all : Icons.check),
            size: isCall ? 13 : 16, 
            color: iconColor,
          ),
        // For group message
        if (isGroup && message.isSender)
          Icon(
            message.sentAt == null ? Icons.access_time_rounded : Icons.check,
            size: isCall ? 13 : 16, 
            color: iconColor,
          ),
      ],
    );

    if (isInline) {
      return content;
    }

    return Positioned(
      right: 0,
      bottom: isDoc ? 8 : (isCall ? 2 : 0),
      child: content,
    );
  }
}
