import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/services/top_exposure_service.dart';

/// Floating overlay displayed in the center of the room screen when top exposure is active
class TopExposureCenterBanner extends StatefulWidget {
  final String currentRoomId;
  final AudioRoomsBloc? audioRoomsBloc;

  const TopExposureCenterBanner({
    super.key,
    required this.currentRoomId,
    this.audioRoomsBloc,
  });

  @override
  State<TopExposureCenterBanner> createState() => _TopExposureCenterBannerState();
}

class _TopExposureCenterBannerState extends State<TopExposureCenterBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Worker? _worker;
  String? _lastExposureId;
  Timer? _hideTimer;

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _animController.status == AnimationStatus.completed) {
        _animController.reverse();
      }
    });
  }

  void _showRoomSwitchDialog({
    required BuildContext context,
    required TopExposure exposure,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 26),
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
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('🌟', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${exposure.senderName} sent ${exposure.giftName} (×${exposure.quantity}) in ${exposure.roomName}!',
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
            Text(
              'Do you want to completely leave your current room and join ${exposure.roomName}?',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                    .doc(exposure.roomId)
                    .get();

                if (doc.exists && doc.data() != null) {
                  final room = AudioRoomV2.fromFirestore(doc);
                  if (room.isUserBlocked(currentUser.userId)) {
                    Get.snackbar('Access Denied', 'You are blocked from entering this room.',
                        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                    return;
                  }
                  if (room.isUserKickedRecently(currentUser.userId)) {
                    Get.snackbar('Access Denied', 'You have been removed from this room and cannot join for 24 hours.',
                        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                    return;
                  }
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
                debugPrint('Error switching room for Grab The Top: $e');
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    final service = TopExposureService.instance;
    _worker = ever(service.activeTopExposure, (exposure) {
      if (exposure != null && !exposure.isExpired && exposure.roomId == widget.currentRoomId) {
        if (_lastExposureId != exposure.id || _animController.status == AnimationStatus.dismissed) {
          _lastExposureId = exposure.id;
          _animController.forward(from: 0.0);
          _startHideTimer();
        }
      } else {
        if (_animController.status != AnimationStatus.dismissed) {
          _animController.reverse();
        }
      }
    });

    // Check current initial value
    final current = service.activeTopExposure.value;
    if (current != null && !current.isExpired && current.roomId == widget.currentRoomId) {
      _lastExposureId = current.id;
      _animController.forward();
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _worker?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = TopExposureService.instance;

    return Obx(() {
      final exposure = service.activeTopExposure.value;
      if (exposure == null || exposure.isExpired || exposure.roomId != widget.currentRoomId) {
        return const SizedBox.shrink();
      }

      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          if (_fadeAnimation.value == 0) return const SizedBox.shrink();

          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                onTap: () {
                  if (exposure.roomId != widget.currentRoomId) {
                    _showRoomSwitchDialog(
                      context: context,
                      exposure: exposure,
                    );
                  }
                },
                child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B11B0).withValues(alpha: 0.85),
                      const Color(0xFF33045E).withValues(alpha: 0.90),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatars connected with Golden Arrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sender Avatar with Gold Ring
                        _buildCenterAvatar(exposure.senderImageUrl, isSender: true),

                        const SizedBox(width: 12),

                        // Golden Arrow Icon
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFD700),
                          ),
                          child: const Icon(
                            Icons.east_rounded,
                            color: Colors.black,
                            size: 14,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Receiver Avatar with Gold Ring
                        _buildCenterAvatar(exposure.receiverImageUrl, isSender: false),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Text: "☆ sender_name send 💋 x 600 to receiver_name"
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                        children: [
                          const TextSpan(
                            text: '☆ ',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: exposure.senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const TextSpan(text: ' send '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: exposure.giftPngUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: exposure.giftPngUrl,
                                    width: 20,
                                    height: 20,
                                    errorWidget: (_, __, ___) =>
                                        const Text('💋', style: TextStyle(fontSize: 14)),
                                  )
                                : const Text('💋', style: TextStyle(fontSize: 14)),
                          ),
                          TextSpan(
                            text: ' × ${exposure.quantity} ',
                            style: const TextStyle(
                              color: Color(0xFFFF4081),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: 'to '),
                          TextSpan(
                            text: exposure.receiverName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtext: "Get the top exposure"
                    Text(
                      'Get the top exposure',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      );
    });
  }

  Widget _buildCenterAvatar(String? url, {required bool isSender}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
        child: ClipOval(
          child: url != null && url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(
                    isSender ? Icons.person : Icons.stars,
                    color: Colors.white,
                    size: 26,
                  ),
                )
              : Icon(
                  isSender ? Icons.person : Icons.stars,
                  color: Colors.amberAccent,
                  size: 26,
                ),
        ),
      ),
    );
  }
}
