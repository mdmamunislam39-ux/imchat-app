import 'package:flutter/material.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/mini_equalizer.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_level_badge_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modern, premium room card based on the user's provided aesthetic.
class ModernRoomCard extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const ModernRoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Image (Large square on the left)
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Avatar (80x80)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                          ? Image.network(
                              room.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    
                    // Room Frame (Overlaying Avatar)
                    if (room.roomFrameUrl != null &&
                        room.roomFrameUrl!.isNotEmpty &&
                        (room.roomFrameUntil == null ||
                            room.roomFrameUntil!.isAfter(DateTime.now())))
                      Positioned.fill(
                        child: IgnorePointer(
                          child: UniversalAssetWidget(
                            url: room.roomFrameUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      
                    // Room Level Badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: RoomLevelBadgeWidget(
                        totalRevenue: room.totalRevenue,
                        height: 28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Center Section (Title, Creator, Avatars)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('Users').doc(room.creatorId).snapshots(),
                      builder: (context, snapshot) {
                        String displayName = room.creatorName;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          if (userData != null && userData.containsKey('fullname')) {
                            displayName = userData['fullname'] ?? room.creatorName;
                          }
                        }
                        return Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    // Participant Avatars
                    _buildParticipantAvatars(),
                  ],
                ),
              ),

              // Right Section (Participant Count + Icon)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      MiniEqualizer(
                        color: Colors.pinkAccent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.participantCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(Icons.mic, color: Colors.white54, size: 30),
    );
  }

  Widget _buildParticipantAvatars() {
    if (room.participants.isEmpty) {
      return const SizedBox(height: 24);
    }

    final displayParticipants = room.participants.take(5).toList();

    return SizedBox(
      height: 24,
      child: Row(
        children: displayParticipants.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CachedCircleAvatar(
              imageUrl: entry.value.userImageUrl ?? '',
              radius: 10,
              borderWidth: 1,
              borderColor: Colors.white24,
            ),
          );
        }).toList(),
      ),
    );
  }
}
