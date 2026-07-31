import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../minimized_room_controller.dart';
import '../audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';

/// Floating minimized room widget that appears globally
class FloatingMinimizedRoom extends StatefulWidget {
  final AudioRoomsBloc audioRoomsBloc;

  const FloatingMinimizedRoom({
    super.key,
    required this.audioRoomsBloc,
  });

  @override
  State<FloatingMinimizedRoom> createState() => _FloatingMinimizedRoomState();
}

class _FloatingMinimizedRoomState extends State<FloatingMinimizedRoom> {
  // Draggable position
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MinimizedRoomController>(
      init: MinimizedRoomController(), // Auto-initialize if not found
      builder: (controller) {
        if (!controller.hasMinimizedRoom) {
          return const SizedBox.shrink();
        }

        final room = controller.minimizedRoom!;

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position.dx + details.delta.dx,
                  _position.dy + details.delta.dy,
                );
              });
            },
            onPanEnd: (details) {
              // Snap to edges
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;

              setState(() {
                // Snap to left or right edge
                if (_position.dx < screenWidth / 2) {
                  _position = Offset(20, _position.dy);
                } else {
                  _position = Offset(screenWidth - 80, _position.dy);
                }

                // Keep within vertical bounds
                if (_position.dy < 50) {
                  _position = Offset(_position.dx, 50);
                } else if (_position.dy > screenHeight - 150) {
                  _position = Offset(_position.dx, screenHeight - 150);
                }
              });
            },
            onTap: _handleTap,
            child: _buildFloatingWidget(room),
          ),
        );
      },
    );
  }

  /// Handle tap on floating widget - restore room
  void _handleTap() {
    try {
      final controller = Get.find<MinimizedRoomController>();
      final (restoredRoom, restoredBloc) = controller.restoreRoom();

      if (restoredRoom != null) {
        // Navigate back to the audio room
        Get.to(
          () => AudioRoomScreen(
            room: restoredRoom,
            audioRoomsBloc: restoredBloc ?? widget.audioRoomsBloc,
            isRestoring: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FloatingRoom] Error restoring room: $e');
    }
  }

  /// Build the floating widget UI
  Widget _buildFloatingWidget(AudioRoomV2 room) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Room image or icon
          Center(
            child: room.imageUrl != null
                ? ClipOval(
                    child: Image.network(
                      room.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 30,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 30,
                  ),
          ),

          // Pulse animation ring
          Positioned.fill(
            child: _PulseRing(),
          ),

          // Live indicator
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulse ring animation for the floating widget
class _PulseRing extends StatefulWidget {
  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: (1 - _animation.value) * 0.5),
              width: 2,
            ),
          ),
          transform: Matrix4.identity()..scale(_animation.value),
          transformAlignment: Alignment.center,
        );
      },
    );
  }
}
