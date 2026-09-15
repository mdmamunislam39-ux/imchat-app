import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/top_exposure_service.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

/// Modal bottom sheet for "Grab the Top" exposure info and action
class GrabTheTopBottomSheet extends StatelessWidget {
  final TopExposure? exposure;
  final String? currentRoomId;
  final AudioRoomsBloc? audioRoomsBloc;
  final VoidCallback? onGrabTheTop;

  const GrabTheTopBottomSheet({
    super.key,
    this.exposure,
    this.currentRoomId,
    this.audioRoomsBloc,
    this.onGrabTheTop,
  });

  static void show(
    BuildContext context, {
    TopExposure? exposure,
    String? currentRoomId,
    AudioRoomsBloc? audioRoomsBloc,
    VoidCallback? onGrabTheTop,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GrabTheTopBottomSheet(
        exposure: exposure,
        currentRoomId: currentRoomId,
        audioRoomsBloc: audioRoomsBloc,
        onGrabTheTop: onGrabTheTop,
      ),
    );
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
                if (audioRoomsBloc != null && currentRoomId != null) {
                  audioRoomsBloc!.add(
                    LeaveAudioRoom(
                      roomId: currentRoomId!,
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
  Widget build(BuildContext context) {
    final hasExposure = exposure != null && exposure!.roomId.isNotEmpty && !exposure!.isExpired;
    final isDifferentRoom = hasExposure && currentRoomId != null && currentRoomId != exposure!.roomId;
    final senderAvatar = exposure?.senderImageUrl;
    final receiverAvatar = exposure?.receiverImageUrl;
    final giftPngUrl = exposure?.giftPngUrl;
    final quantity = exposure?.quantity ?? 0;
    final diamonds = exposure?.totalDiamonds ?? 0;

    return GestureDetector(
      onTap: () {
        if (isDifferentRoom) {
          Navigator.of(context).pop(); // Close bottom sheet
          _showRoomSwitchDialog(
            context: context,
            exposure: exposure!,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top speech bubble arrow pointing up
          CustomPaint(
            size: const Size(24, 12),
            painter: _SpeechArrowPainter(color: const Color(0xFF23083B)),
          ),
          
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF280A40), Color(0xFF150426)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top exposure preview card (Tap to navigate to the target room)
                  GestureDetector(
                    onTap: () {
                      if (isDifferentRoom) {
                        Navigator.of(context).pop(); // Close bottom sheet
                        _showRoomSwitchDialog(
                          context: context,
                          exposure: exposure!,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF371254).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF9036E7).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Sender Avatar with Golden Frame
                          _buildFramedAvatar(senderAvatar, isSender: true),

                          // Center Gift info & Diamond progress (Only show if a gift is selected/active!)
                          Expanded(
                            child: hasExposure
                                ? Column(
                                    children: [
                                      // Gift icon & count
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (giftPngUrl != null && giftPngUrl.isNotEmpty)
                                            CachedNetworkImage(
                                              imageUrl: giftPngUrl,
                                              width: 28,
                                              height: 28,
                                              errorWidget: (_, __, ___) => const Text('💋', style: TextStyle(fontSize: 22)),
                                            )
                                          else
                                            const Text('💋', style: TextStyle(fontSize: 22)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '×$quantity',
                                            style: const TextStyle(
                                              color: Color(0xFFFF4081),
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 6),

                                      // Progress Line Indicator
                                      Container(
                                        height: 3,
                                        width: 80,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF4081), Color(0xFF9C27B0)],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Diamond badge using app wallet Diamond PNG
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const DynamicDiamondIcon(
                                            width: 22,
                                            height: 22,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$diamonds',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        color: Color(0xFFFFD700),
                                        size: 32,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Top Exposure',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          // Receiver Avatar with Golden Frame
                          _buildFramedAvatar(receiverAvatar, isSender: false),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main CTA Button "Grab the Top 🪑"
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isDifferentRoom) {
                          Navigator.of(context).pop(); // Close bottom sheet
                          _showRoomSwitchDialog(
                            context: context,
                            exposure: exposure!,
                          );
                        } else {
                          Navigator.of(context).pop();
                          if (onGrabTheTop != null) {
                            onGrabTheTop!();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFFA830FF).withValues(alpha: 0.5),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFBA42FF), Color(0xFF8812EC)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFE2A6FF).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '🪑 ',
                                style: TextStyle(fontSize: 22),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Grab the Top',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFramedAvatar(String? url, {required bool isSender}) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Gold Glow/Frame
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF23083B),
              ),
              child: ClipOval(
                child: url != null && url.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          isSender ? Icons.person : Icons.stars,
                          color: Colors.white,
                          size: 30,
                        ),
                      )
                    : Icon(
                        isSender ? Icons.person : Icons.stars,
                        color: Colors.amberAccent,
                        size: 30,
                      ),
              ),
            ),
          ),

          // Sparkle overlay ring
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFF4B8).withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechArrowPainter extends CustomPainter {
  final Color color;
  _SpeechArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
