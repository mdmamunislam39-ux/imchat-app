import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

/// Top Global Broadcast Banner for active Lucky Bags across all rooms
/// Features Right-to-Left Slide Animation (Slide In Right -> 3s Pause -> Slide Out Left)
/// and miniature 3D Red Envelope graphic on the right side.
class LuckyBagGlobalBanner extends StatefulWidget {
  final String currentRoomId;
  final AudioRoomsBloc? audioRoomsBloc;

  const LuckyBagGlobalBanner({
    super.key,
    required this.currentRoomId,
    this.audioRoomsBloc,
  });

  @override
  State<LuckyBagGlobalBanner> createState() => _LuckyBagGlobalBannerState();
}

class _LuckyBagGlobalBannerState extends State<LuckyBagGlobalBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  Stream<QuerySnapshot>? _globalBagStream;

  Stream<QuerySnapshot> get globalBagStream =>
      _globalBagStream ??= FirebaseFirestore.instance
          .collection('global_lucky_bags')
          .where('status', isEqualTo: 'active')
          .snapshots();

  String? _activeBagId;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _globalBagStream = FirebaseFirestore.instance
        .collection('global_lucky_bags')
        .where('status', isEqualTo: 'active')
        .snapshots();

    // Total duration: 4000ms = 500ms slide-in right + 3000ms pause center + 500ms slide-out left
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _slideAnimation = TweenSequence<Offset>([
      // 1. Slide in from Right (1.2, 0) to Center (0, 0)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.2, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12.5, // 0.5s
      ),
      // 2. Pause in Center (0, 0) for 3 seconds
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 75.0, // 3.0s
      ),
      // 3. Slide out to Left (-1.2, 0)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.2, 0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 12.5, // 0.5s
      ),
    ]).animate(_animController);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerBannerAnimation(String bagId) {
    if (_activeBagId != bagId) {
      _activeBagId = bagId;
      _isVisible = true;
      _animController.forward(from: 0.0);
    }
  }

  void _showRoomSwitchDialog({
    required BuildContext context,
    required String targetRoomId,
    required LuckyBagModel bag,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.directions_run_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Leave & Join Room?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text(
                    '🎁',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${bag.senderName} dropped a ${bag.totalAmount} 💎 Lucky Bag!',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Do you want to completely leave your current room and join this room to claim the Lucky Bag?',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                final currentUser = AuthController.instance.currentUser;

                // 1. Cleanly exit current room if bloc is available
                if (widget.audioRoomsBloc != null) {
                  widget.audioRoomsBloc!.add(
                    LeaveAudioRoom(
                      roomId: widget.currentRoomId,
                      userId: currentUser.userId,
                    ),
                  );
                }

                // 2. Clear any minimized room overlay
                MinimizedRoomController().clearMinimizedRoom();

                // 3. Fetch target room details
                final doc = await FirebaseFirestore.instance
                    .collection('audio_rooms_v2')
                    .doc(targetRoomId)
                    .get();

                if (doc.exists && doc.data() != null) {
                  final room = AudioRoomV2.fromFirestore(doc);
                  final newBloc = AudioRoomsBloc(
                    repository: AudioRoomsRepository(),
                  );

                  if (!room.isParticipant(currentUser.userId)) {
                    newBloc.add(
                      JoinAudioRoom(
                        roomId: room.id,
                        userId: currentUser.userId,
                        userName: currentUser.fullname,
                        userImageUrl: currentUser.photoUrl,
                      ),
                    );
                  }

                  // 4. Navigate to new room, replacing current screen
                  Get.off(
                    () => AudioRoomScreen(
                      room: room,
                      audioRoomsBloc: newBloc,
                    ),
                  );
                } else {
                  Get.snackbar(
                    'Room Unavailable',
                    'This audio room is no longer active.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                debugPrint('Error switching room: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2A55),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Leave & Join',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a miniature 3D Red Packet graphic for the right side of the banner
  Widget _buildMiniatureRedEnvelope() {
    return Container(
      width: 22,
      height: 26,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B6B), Color(0xFFFF1744)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFFFD54F),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD54F),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: const Center(
              child: Icon(
                Icons.card_giftcard,
                size: 5,
                color: Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: globalBagStream, // Use safe lazy cached stream accessor
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final bags = docs
            .map((doc) => LuckyBagModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((b) => b.isActive)
            .toList();

        if (bags.isEmpty) {
          return const SizedBox.shrink();
        }

        bags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final bag = bags.first;

        // Trigger right-to-left slide animation on new bag detection
        _triggerBannerAnimation(bag.id);

        if (!_isVisible) {
          return const SizedBox.shrink();
        }

        final isOtherRoom = bag.roomId != widget.currentRoomId;

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                if (isOtherRoom) {
                  _showRoomSwitchDialog(
                    context: context,
                    targetRoomId: bag.roomId,
                    bag: bag,
                  );
                }
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0288D1), Color(0xFF00B0FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B0FF).withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Sender Avatar
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.amber,
                      backgroundImage: bag.senderAvatar != null &&
                              bag.senderAvatar!.isNotEmpty
                          ? NetworkImage(bag.senderAvatar!)
                          : null,
                      child: bag.senderAvatar == null ||
                              bag.senderAvatar!.isEmpty
                          ? const Icon(Icons.person,
                              size: 14, color: Colors.white)
                          : null,
                    ),

                    const SizedBox(width: 8),

                    // Announcement Text
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${bag.senderName} ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const TextSpan(
                              text: 'dropped ',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                            TextSpan(
                              text: '${bag.totalAmount} ',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const TextSpan(
                              text: 'Lucky Bag! ',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                            if (isOtherRoom)
                              const TextSpan(
                                text: ' Tap to Join >',
                                style: TextStyle(
                                  color: Color(0xFFFFEEB3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Miniature 3D Red Envelope Graphic on Right Side
                    _buildMiniatureRedEnvelope(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
