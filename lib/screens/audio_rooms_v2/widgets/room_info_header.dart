import 'package:flutter/material.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/top_exposure_header_pill.dart';

/// Room information header widget
class RoomInfoHeader extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onChangeBackground;

  const RoomInfoHeader({
    super.key,
    required this.room,
    this.onChangeBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Top row with room icon, title, and member count
          Row(
            children: [
              // Room icon/avatar
              SizedBox(
                width: 54, // Expanded to accommodate frame
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Avatar (44x44)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: room.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(room.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: room.imageUrl == null ? primaryColor : null,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: room.imageUrl == null
                          ? const Icon(
                              Icons.group,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                    
                    // Room Frame (Overlay)
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
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Room title and member count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            room.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.isOfficial) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF1DA1F2),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Members: ${room.participantCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Right side buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share / Lock button
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          (room.isGroupRoom || room.isPrivate) ? Icons.lock : Elusive.share,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 18,
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Close button
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 18,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  TopExposureHeaderPill(
                    currentRoomId: room.id,
                  ),
                ],
              ),
            ],
          ),
          
          
          // Room description and host info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Host info
                Row(
                  children: [
                    CachedCircleAvatar(
                      imageUrl: room.creatorImageUrl ?? '',
                      radius: 16,
                      backgroundColor: primaryColor.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                room.creatorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'HOST',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Room Creator',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Change background button (host only)
                    if (onChangeBackground != null)
                      GestureDetector(
                        onTap: onChangeBackground,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.image,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (room.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    room.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact room header for smaller spaces
class CompactRoomHeader extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;

  const CompactRoomHeader({
    super.key,
    required this.room,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Room avatar
            CachedCircleAvatar(
              imageUrl: room.imageUrl ?? room.creatorImageUrl ?? '',
              radius: 12,
              backgroundColor: primaryColor.withValues(alpha: 0.2),
            ),
            
            const SizedBox(width: 8),
            
            // Room name
            Flexible(
              child: Text(
                room.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Member count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${room.participantCount}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Room stats widget showing various room statistics
class RoomStats extends StatelessWidget {
  final AudioRoomV2 room;

  const RoomStats({
    super.key,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    final speakers = room.participants.where((p) => p.isSpeaker || p.isHost).length;
    final listeners = room.participantCount - speakers;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.mic,
            label: 'Speakers',
            value: speakers.toString(),
          ),
          _buildStatItem(
            icon: Icons.hearing,
            label: 'Listeners',
            value: listeners.toString(),
          ),
          _buildStatItem(
            icon: Icons.access_time,
            label: 'Duration',
            value: _formatDuration(DateTime.now().difference(room.createdAt)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
