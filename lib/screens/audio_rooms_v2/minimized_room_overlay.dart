import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/audio_room_v2.dart';
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

  Widget _buildFloatingWidget(AudioRoomV2 room) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F8),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            // Room Image (Filling the inner area)
            Positioned.fill(
              child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                  ? Image.network(
                      room.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
            ),

            // Bottom-Right Corner Activity Equalizer Badge (White Cutout)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                  ),
                ),
                padding: const EdgeInsets.only(top: 6, left: 6, right: 3, bottom: 3),
                child: const Center(
                  child: _ActivityEqualizerBars(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic cyan audio equalizer activity animation for bottom-right corner
class _ActivityEqualizerBars extends StatefulWidget {
  const _ActivityEqualizerBars();

  @override
  State<_ActivityEqualizerBars> createState() => _ActivityEqualizerBarsState();
}

class _ActivityEqualizerBarsState extends State<_ActivityEqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar((5 + (val * 9)).clamp(4.0, 15.0)),
            const SizedBox(width: 2.5),
            _buildBar((11 + ((1 - val) * 5)).clamp(4.0, 16.0)),
            const SizedBox(width: 2.5),
            _buildBar((6 + (val * 8)).clamp(4.0, 14.0)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 3.2,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
