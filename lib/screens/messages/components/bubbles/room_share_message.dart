import 'package:chat_messenger/components/cached_card_image.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/room_share.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:flutter/material.dart';

class RoomShareMessage extends StatelessWidget {
  final Message message;
  final bool isGroup;

  const RoomShareMessage({
    super.key,
    required this.message,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final RoomShare? roomShare = message.roomShare;
    if (roomShare == null) {
      return const SizedBox.shrink();
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.7,
      constraints: const BoxConstraints(maxWidth: 290),
      decoration: BoxDecoration(
        color: const Color(0xFFD0E8FF), // pastel sky blue bubble color from mockup
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!message.isSender ? 2 : 16),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(!message.isSender ? 16 : 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Icon + Room Name
          Row(
            children: [
              // Vibrant blue circle containing microphone icon
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF00B0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roomShare.roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0D47A1), // Dark blue text
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Room Cover Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 170,
              child: CachedCardImage(
                roomShare.roomImage.isNotEmpty ? roomShare.roomImage : 'assets/icons/room_default.png',
                placeholder: Container(
                  color: Colors.white.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle / Description Section
          const Text(
            "We're talking about",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            roomShare.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Enter Room Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                AudioRoomsV2Integration.joinRoomById(roomShare.roomId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBEE3FF), // slightly darker blue shade
                foregroundColor: const Color(0xFF0D47A1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Enter Room',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Inline Custom Time and Read Status indicator inside the card bubble
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    message.isDeleted
                        ? message.updatedAt?.formatMsgTime ?? ''
                        : message.sentAt?.formatMsgTime ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      overflow: TextOverflow.ellipsis,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Read/sent ticks
                if (message.isSender && !isGroup)
                  Icon(
                    message.sentAt == null
                        ? Icons.access_time_rounded
                        : (message.isRead ? Icons.done_all : Icons.done),
                    size: 14,
                    color: Colors.blue,
                  ),
                // Tick for group message
                if (isGroup)
                  Icon(
                    message.sentAt == null ? Icons.access_time_rounded : Icons.done_all,
                    size: 12,
                    color: message.isSender ? Colors.blue : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
