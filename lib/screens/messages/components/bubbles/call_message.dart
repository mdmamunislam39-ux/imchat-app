import 'package:flutter/material.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/helper/call_helper.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:get/get.dart';
import '../read_time_status.dart';

class CallMessage extends StatelessWidget {
  const CallMessage({
    super.key,
    required this.message,
    required this.partnerUser,
    required this.isMissed,
    required this.isVideo,
    this.isGroup = false,
    this.isReceiverOnline,
  });

  final Message message;
  final User? partnerUser;
  final bool isMissed;
  final bool isVideo;
  final bool isGroup;
  final RxBool? isReceiverOnline;

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

    // 1. Parse structured payload: call|<type>|<status>|<duration>
    String status = '';
    int durationSec = 0;
    bool isVideoCall = isVideo;

    final String raw = message.textMsg.trim();
    if (raw.startsWith('call|')) {
      final parts = raw.split('|');
      if (parts.length > 1) {
        isVideoCall = parts[1].toLowerCase() == 'video';
      }
      if (parts.length > 2) {
        status = parts[2].toLowerCase(); // 'canceled', 'rejected', 'missed', 'completed'
      }
      if (parts.length > 3) {
        durationSec = int.tryParse(parts[3]) ?? 0;
      }
    } else if (raw.toLowerCase().contains('missed') || isMissed) {
      status = 'missed';
    } else if (raw.contains('|')) {
      final parts = raw.split('|');
      durationSec = int.tryParse(parts.last.trim()) ?? 0;
      status = durationSec > 0 ? 'completed' : 'ended';
    }

    if (durationSec > 0 && (status.isEmpty || status == 'ended')) {
      status = 'completed';
    }

    // 2. Titles, Subtitles, Icons & Colors
    String titleText = isVideoCall ? 'Video call' : 'Audio call';
    String subtitleText = isSender ? 'Tap to call again' : 'Tap to call back';
    IconData iconData = isVideoCall ? Icons.videocam : (isSender ? Icons.call_made : Icons.call_received);
    Color iconColor = isDarkMode ? Colors.white : Colors.black87;

    if (isSender) {
      // --- Caller (Outgoing side) ---
      if (status == 'rejected') {
        titleText = 'Rejected';
        subtitleText = 'Tap to call again';
        iconData = Icons.phone_disabled_rounded;
        iconColor = isDarkMode ? Colors.white70 : const Color(0xFF2C2D30);
      } else if (status == 'canceled' || status == 'missed') {
        titleText = 'Canceled';
        subtitleText = 'Tap to call again';
        iconData = isVideoCall ? Icons.videocam : Icons.call_made_rounded;
        iconColor = isDarkMode ? Colors.white70 : const Color(0xFF2C2D30);
      } else if (status == 'completed' || durationSec > 0) {
        titleText = isVideoCall ? 'Video call' : 'Audio call';
        subtitleText = _formatDuration(durationSec);
        iconData = isVideoCall ? Icons.videocam : Icons.call_made_rounded;
        iconColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
      }
    } else {
      // --- Receiver (Incoming side) ---
      if (status == 'missed' || status == 'canceled') {
        titleText = isVideoCall ? 'Missed Video Call' : 'Missed Audio Call';
        subtitleText = 'Tap to call back';
        iconData = Icons.call_missed_rounded;
        iconColor = const Color(0xFFE53935); // Prominent Red
      } else if (status == 'rejected') {
        titleText = isVideoCall ? 'Incoming Video Call' : 'Incoming Audio Call';
        subtitleText = 'Declined';
        iconData = Icons.call_end_rounded;
        iconColor = const Color(0xFFE53935);
      } else if (status == 'completed' || durationSec > 0) {
        titleText = isVideoCall ? 'Video call' : 'Audio call';
        subtitleText = _formatDuration(durationSec);
        iconData = isVideoCall ? Icons.videocam : Icons.call_received_rounded;
        iconColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
      }
    }

    // 3. Card Backgrounds (IMO-style soft blue for sender, white for receiver)
    final Color cardBg = isSender
        ? (isDarkMode ? const Color(0xFF1E3854) : const Color(0xFFCBE7FE))
        : (isDarkMode ? const Color(0xFF24262A) : Colors.white);

    final Color iconCircleBg = isSender
        ? (isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.white)
        : (isDarkMode ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF7F8FA));

    final Color titleColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final Color subTextColor = isDarkMode ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () {
        if (partnerUser != null) {
          CallHelper.makeCall(isVideo: isVideoCall, user: partnerUser!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSender
                ? (isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFBCE0FF))
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.04),
              blurRadius: 6,
              spreadRadius: 0.5,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Icon Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconCircleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Call Title & Duration/Subtext + Timestamp
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
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ReadTimeStatus(
                        message: message,
                        isGroup: isGroup,
                        isInline: true,
                        receiver: partnerUser,
                        isReceiverOnline: isReceiverOnline,
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
