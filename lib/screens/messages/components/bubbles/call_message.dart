import 'package:flutter/material.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/helper/call_helper.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import '../read_time_status.dart';

class CallMessage extends StatelessWidget {
  const CallMessage({
    super.key,
    required this.message,
    required this.partnerUser,
    required this.isMissed,
    required this.isVideo,
    this.isGroup = false,
  });

  final Message message;
  final User? partnerUser;
  final bool isMissed;
  final bool isVideo;
  final bool isGroup;

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    }
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '$minutes min $remainingSeconds sec';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;
    final bool isSender = message.isSender;

    // Determine card background color
    final Color cardBg = isSender
        ? (isDarkMode ? const Color(0xFF1E3854) : const Color(0xFFD6EEFF))
        : (isDarkMode ? const Color(0xFF24262A) : Colors.white);

    // Determine icon & container colors based on state
    final Color iconCircleBg = isSender
        ? (isDarkMode ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFEAF4FF))
        : (isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.white);

    final Color iconColor = isMissed
        ? Colors.red.shade600
        : (isDarkMode ? Colors.white : Colors.black87);

    final IconData callIcon = isMissed
        ? Icons.call_missed
        : (isSender
            ? (isVideo ? Icons.videocam : Icons.call_made)
            : (isVideo ? Icons.videocam : Icons.call_received));

    // Determine title text ("Audio call", "Video call", or Missed call)
    String titleText = isVideo ? 'Video call' : 'Audio call';
    if (isMissed) {
      titleText = message.textMsg.replaceAll('📹', '').replaceAll('🎤', '').trim();
      if (titleText.isEmpty) {
        titleText = isVideo ? 'Missed video call' : 'You missed a voice call..';
      }
    }

    // Parse call duration if available
    String? durationStr;
    if (!isMissed && message.textMsg.contains('|')) {
      final parts = message.textMsg.split('|');
      if (parts.length > 1) {
        final sec = int.tryParse(parts[1].trim());
        if (sec != null && sec > 0) {
          durationStr = _formatDuration(sec);
        } else if (parts[1].trim().isNotEmpty) {
          durationStr = parts[1].trim();
        }
      }
    }

    final Color titleColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return GestureDetector(
      onTap: () {
        if (partnerUser != null) {
          CallHelper.makeCall(isVideo: isVideo, user: partnerUser!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSender
                ? (isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFBCE0FF))
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.grey.shade300),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSender
                  ? (isDarkMode
                      ? Colors.blue.withValues(alpha: 0.15)
                      : const Color(0xFF64B5F6).withValues(alpha: 0.2))
                  : (isDarkMode
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.grey.withValues(alpha: 0.15)),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Icon Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconCircleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSender
                      ? Colors.blue.withValues(alpha: 0.12)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  callIcon,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Call Title & Duration/Subtext + Timestamp (in the yellow box area!)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          durationStr ??
                              (isMissed
                                  ? 'Tap to call back'
                                  : (isVideo ? 'Video call' : 'Voice call')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ReadTimeStatus(
                        message: message,
                        isGroup: isGroup,
                        isInline: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
