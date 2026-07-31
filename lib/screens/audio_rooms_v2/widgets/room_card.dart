import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

/// Widget for displaying an audio room card
class RoomCard extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool showJoinButton;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
    this.showJoinButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with room info and participant count
              Row(
                children: [
                  // Room image
                  CachedCircleAvatar(
                    imageUrl: room.imageUrl ?? '',
                    radius: 25,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    borderColor: primaryColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                  
                  // Room name and creator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'by ${room.creatorName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Participant count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconlyLight.user2,
                          size: 14,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${room.participantCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Room description
              Text(
                room.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Participants avatars and action button
              Row(
                children: [
                  // Participants avatars
                  Expanded(
                    child: _buildParticipantsAvatars(),
                  ),
                  
                  // Join button or status
                  if (showJoinButton)
                    _buildActionButton(context),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Room metadata
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeago.format(room.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (room.isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'FULL',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build participants avatars
  Widget _buildParticipantsAvatars() {
    if (room.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show up to 4 participants
    final displayParticipants = room.participants.take(4).toList();
    final remainingCount = room.participantCount - displayParticipants.length;

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // Participants avatars
          ...displayParticipants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
              child: CachedCircleAvatar(
                imageUrl: participant.userImageUrl ?? '',
                radius: 12,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                borderWidth: 1,
                borderColor: Colors.white,
              ),
            );
          }),
          
          // Remaining count
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build action button (Join/Full)
  Widget _buildActionButton(BuildContext context) {
    if (room.isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Full',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Join',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
