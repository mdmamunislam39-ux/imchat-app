import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/create_lucky_bag_sheet.dart';

class RoomToolsBottomSheet extends StatelessWidget {
  final AudioRoomV2? room;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatar;

  const RoomToolsBottomSheet({
    super.key,
    this.room,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatar,
  });

  static void show(
    BuildContext context, {
    AudioRoomV2? room,
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomToolsBottomSheet(
        room: room,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserAvatar: currentUserAvatar,
      ),
    ).then((_) {
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.48,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161823), // Sleek dark glassmorphic background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title & Subtitle Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room Tools & Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Select a tool to activate in this room',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tools Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                // 1. Lucky Bag (ACTIVE)
                _buildToolTile(
                  context: context,
                  title: 'Lucky Bag',
                  subtitle: 'লাকি ব্যাগ',
                  iconWidget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  badgeText: 'HOT',
                  badgeColor: const Color(0xFFFF1744),
                  onTap: () {
                    Navigator.pop(context); // Close tools sheet
                    if (room != null) {
                      CreateLuckyBagBottomSheet.show(
                        context,
                        roomId: room!.id,
                        senderId: currentUserId,
                        senderName: currentUserName,
                        senderAvatar: currentUserAvatar,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room connection issue. Please retry.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),

                // 2. Room Music (Placeholder)
                _buildToolTile(
                  context: context,
                  title: 'Music',
                  subtitle: 'মিউজিক',
                  iconWidget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF262938),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white38,
                      size: 26,
                    ),
                  ),
                  badgeText: 'SOON',
                  badgeColor: Colors.white24,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room Music coming soon!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // 3. Room Decor (Placeholder)
                _buildToolTile(
                  context: context,
                  title: 'Decor',
                  subtitle: 'সাজসজ্জা',
                  iconWidget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF262938),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Colors.white38,
                      size: 26,
                    ),
                  ),
                  badgeText: 'SOON',
                  badgeColor: Colors.white24,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room Decor feature coming soon!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // 4. Room Vote / Poll (Placeholder)
                _buildToolTile(
                  context: context,
                  title: 'Vote',
                  subtitle: 'ভোট',
                  iconWidget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF262938),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.how_to_vote_rounded,
                      color: Colors.white38,
                      size: 26,
                    ),
                  ),
                  badgeText: 'SOON',
                  badgeColor: Colors.white24,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Room Poll feature coming soon!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget iconWidget,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              iconWidget,
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontFamily: 'Inter',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
