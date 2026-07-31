import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';

import 'package:flutter/material.dart';
import 'package:chat_messenger/screens/messages/controllers/audio_player_controller.dart';
import 'package:get/get.dart';

class AudioMessage extends StatelessWidget {
  const AudioMessage(
    this.message, {
    super.key,
    this.profileUrl,
  });

  final Message message;
  final String? profileUrl;

  @override
  Widget build(BuildContext context) {
    // Put Audio Controller for each item by tag
    Get.put(
      AudioPlayerController(fileUrl: message.fileUrl, isRecording: true),
      tag: message.msgId,
    );

    // Variables

    return Obx(() {
      // Find Audio Controller for each item by tag
      final AudioPlayerController controller = Get.find(tag: message.msgId);

      final bool isPlaying = controller.isPlaying.value;
      final Duration duration = controller.duration.value;
      final Duration position = controller.position.value;
      final bool isSender = message.isSender;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        constraints: const BoxConstraints(maxWidth: 240),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Play Button (Black Circle with White Icon)
            GestureDetector(
              onTap: () => controller.playAudio(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSender ? Colors.black87 : Colors.black87,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Waveform & Duration Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimal Waveform implementation
                _buildFakeWaveform(
                  isSender, 
                  duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0
                ),
                const SizedBox(height: 6),
                
                // Duration & timestamp layout
                Text(
                  MediaHelper.formatDuration(duration),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSender ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    });
  }

  Widget _buildFakeWaveform(bool isSender, double progress) {
    final List<double> heights = [8, 12, 18, 10, 14, 20, 16, 8, 14, 22, 12, 8, 16, 20, 10];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(heights.length, (index) {
        final isActive = index / heights.length <= progress;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: heights[index],
          decoration: BoxDecoration(
            color: isActive 
                ? (isSender ? Colors.white : primaryColor) 
                : (isSender ? Colors.white.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
