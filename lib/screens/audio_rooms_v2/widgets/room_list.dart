import 'package:flutter/material.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/modern_room_card.dart';

/// Widget for displaying a list of audio rooms
class RoomList extends StatelessWidget {
  final List<AudioRoomV2> rooms;
  final String title;
  final bool showTitle;
  final Function(AudioRoomV2)? onRoomTap;
  final Function(AudioRoomV2)? onJoinRoom;
  final bool isLoading;
  final String emptyMessage;
  final Widget? emptyWidget;
  final Widget? headerWidget;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool showTotalCount;

  const RoomList({
    super.key,
    required this.rooms,
    this.title = 'Rooms',
    this.showTitle = true,
    this.onRoomTap,
    this.onJoinRoom,
    this.isLoading = false,
    this.emptyMessage = 'No rooms available',
    this.emptyWidget,
    this.headerWidget,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.showTotalCount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (rooms.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (showTitle) _buildTitle(),
        
        // Room list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            shrinkWrap: shrinkWrap,
            physics: physics,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: headerWidget != null ? rooms.length + 1 : rooms.length,
            itemBuilder: (context, index) {
              if (headerWidget != null && index == 0) {
                return headerWidget!;
              }
              final roomIndex = headerWidget != null ? index - 1 : index;
              final room = rooms[roomIndex];
              return ModernRoomCard(
                room: room,
                onTap: () => onRoomTap?.call(room),
                onJoin: () => onJoinRoom?.call(room),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build title section
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (rooms.isNotEmpty && showTotalCount)
            Text(
              '${rooms.length} rooms',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Column(
      children: [
        if (showTitle) _buildTitle(),
        Expanded(
          child: ListView.builder(
            shrinkWrap: shrinkWrap,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: headerWidget != null ? 6 : 5, // Show 5 skeleton cards + 1 header if any
            itemBuilder: (context, index) {
              if (headerWidget != null && index == 0) return headerWidget!;
              return _buildSkeletonCard();
            },
          ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Column(
      children: [
        if (showTitle) _buildTitle(),
        Expanded(
          child: headerWidget != null 
            ? ListView(
                children: [
                  headerWidget!,
                  SizedBox(
                    height: 400, // Fixed height to push empty widget down slightly
                    child: emptyWidget ?? _buildDefaultEmptyWidget(),
                  ),
                ],
              )
            : (emptyWidget ?? _buildDefaultEmptyWidget()),
        ),
      ],
    );
  }

  /// Build default empty widget
  Widget _buildDefaultEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.voice_chat_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new room or join an existing one to get started.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build skeleton card for loading state
  Widget _buildSkeletonCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                // Avatar skeleton
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Title and subtitle skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Participant count skeleton
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description skeleton
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Bottom row skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Participants skeleton
                Row(
                  children: List.generate(3, (index) => 
                    Padding(
                      padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Join button skeleton
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal room list widget
class HorizontalRoomList extends StatelessWidget {
  final List<AudioRoomV2> rooms;
  final String title;
  final Function(AudioRoomV2)? onRoomTap;
  final Function(AudioRoomV2)? onJoinRoom;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const HorizontalRoomList({
    super.key,
    required this.rooms,
    required this.title,
    this.onRoomTap,
    this.onJoinRoom,
    this.isLoading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and see all button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (rooms.length > 3 && onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See All'),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Horizontal room list
        SizedBox(
          height: 200,
          child: isLoading ? _buildLoadingList() : _buildRoomList(),
        ),
      ],
    );
  }

  /// Build horizontal room list
  Widget _buildRoomList() {
    if (rooms.isEmpty) {
      return Center(
        child: Text(
          'No rooms available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          child: _buildHorizontalRoomCard(room),
        );
      },
    );
  }

  /// Build horizontal room card
  Widget _buildHorizontalRoomCard(AudioRoomV2 room) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onRoomTap?.call(room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room image and participant count
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: room.imageUrl != null
                        ? NetworkImage(room.imageUrl!)
                        : null,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: room.imageUrl == null
                        ? Icon(
                            Icons.voice_chat,
                            size: 16,
                            color: primaryColor,
                          )
                        : null,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${room.participantCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Room name
              Text(
                room.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Creator name
              Text(
                'by ${room.creatorName}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Join button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: room.isFull ? null : () => onJoinRoom?.call(room),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    room.isFull ? 'Full' : 'Join',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build loading list
  Widget _buildLoadingList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
