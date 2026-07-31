import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'minimized_room_controller.dart';
import 'audio_room_screen.dart';
import 'bloc/audio_rooms_bloc.dart';

/// Service to manage the floating minimized room overlay
class MinimizedRoomOverlay {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// Show the floating minimized room widget
  static void show(BuildContext context, AudioRoomsBloc audioRoomsBloc) {
    if (_isShowing) {
      debugPrint('🔽 [MinimizedOverlay] Overlay already showing');
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _FloatingRoomOverlay(
        audioRoomsBloc: audioRoomsBloc,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
    debugPrint('🔽 [MinimizedOverlay] Overlay inserted');
  }

  /// Hide the floating minimized room widget
  static void hide() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
      debugPrint('🔽 [MinimizedOverlay] Overlay removed');
    }
  }

  /// Check if overlay is currently showing
  static bool get isShowing => _isShowing;
}

/// The actual floating widget that appears as an overlay
class _FloatingRoomOverlay extends StatefulWidget {
  final AudioRoomsBloc audioRoomsBloc;

  const _FloatingRoomOverlay({
    required this.audioRoomsBloc,
  });

  @override
  State<_FloatingRoomOverlay> createState() => _FloatingRoomOverlayState();
}

class _FloatingRoomOverlayState extends State<_FloatingRoomOverlay> {
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MinimizedRoomController>(
      init: MinimizedRoomController(),
      builder: (controller) {
        if (!controller.hasMinimizedRoom) {
          // No minimized room, hide overlay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MinimizedRoomOverlay.hide();
          });
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
            onTap: () => _handleTap(controller),
            child: _buildFloatingWidget(room),
          ),
        );
      },
    );
  }

  void _handleTap(MinimizedRoomController controller) {
    final (room, bloc) = controller.restoreRoom();

    if (room != null) {
      debugPrint('🔼 [MinimizedOverlay] Restoring room: ${room.name}');

      // Use the stored BLoC if available, otherwise use the widget's BLoC
      final activeBloc = bloc ?? widget.audioRoomsBloc;
      
      // Check if the BLoC is still usable
      if (activeBloc.isClosed) {
        debugPrint('🔼 [MinimizedOverlay] ❌ BLoC is closed, cannot restore');
        return;
      }

      // Hide overlay FIRST
      MinimizedRoomOverlay.hide();

      // Small delay to ensure overlay is removed before navigating
      Future.delayed(const Duration(milliseconds: 100), () {
        // Navigate back to the audio room
        Get.to(
          () => AudioRoomScreen(
            room: room,
            audioRoomsBloc: activeBloc,
            isRestoring: true,
          ),
        );
        debugPrint('🔼 [MinimizedOverlay] Navigated to room screen');
      });
    }
  }

  Widget _buildFloatingWidget(room) {
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

/// Pulse ring animation
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
        // Calculate opacity and clamp to valid range (0.0 - 1.0)
        final opacity = ((1 - _animation.value) * 0.5).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: opacity),
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
