import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'minimized_room_overlay.dart';
import '../../services/emoji_chat_service.dart';
import '../../controllers/auth_controller.dart';

/// Global controller to manage minimized audio room state
class MinimizedRoomController extends GetxController {
  // Singleton instance
  static MinimizedRoomController get instance => Get.find();

  // Observable minimized room
  final Rx<AudioRoomV2?> _minimizedRoom = Rx<AudioRoomV2?>(null);

  // Store the BLoC so it doesn't get closed when audio_rooms_v2_screen disposes
  AudioRoomsBloc? _audioRoomsBloc;

  // Preserve the original join time across minimize/restore
  DateTime? _originalJoinTime;

  // Getters
  AudioRoomV2? get minimizedRoom => _minimizedRoom.value;
  AudioRoomV2? get currentRoom => _minimizedRoom.value;
  bool get hasMinimizedRoom => _minimizedRoom.value != null;
  AudioRoomsBloc? get audioRoomsBloc => _audioRoomsBloc;
  DateTime? get originalJoinTime => _originalJoinTime;

  /// Minimize the current room
  void minimizeRoom(AudioRoomV2 room, {AudioRoomsBloc? bloc, DateTime? joinTime}) {
    _minimizedRoom.value = room;
    if (bloc != null) {
      _audioRoomsBloc = bloc;
    }
    if (joinTime != null) {
      _originalJoinTime = joinTime;
    }
    update();
    debugPrint('🔽 [MinimizedRoom] Room minimized: ${room.name}');
  }

  /// Restore the minimized room (called when user taps floating icon)
  /// Returns a record with (room, bloc)
  (AudioRoomV2?, AudioRoomsBloc?) restoreRoom() {
    final room = _minimizedRoom.value;
    final bloc = _audioRoomsBloc;
    _minimizedRoom.value = null;
    // Don't clear the BLoC here - it will be cleared when the room is actually left
    update();
    debugPrint('🔼 [MinimizedRoom] Room restored: ${room?.name}');
    return (room, bloc);
  }

  /// Clear minimized room (called when user actually leaves)
  void clearMinimizedRoom() {
    _minimizedRoom.value = null;
    _audioRoomsBloc = null;
    _originalJoinTime = null;
    try {
      BackgroundService().stopService();
    } catch (_) {}
    update();
    debugPrint('🗑️ [MinimizedRoom] Minimized room cleared');
  }

  /// Update minimized room data (for real-time updates)
  void updateMinimizedRoom(AudioRoomV2 updatedRoom) {
    if (_minimizedRoom.value?.id == updatedRoom.id) {
      _minimizedRoom.value = updatedRoom;
      update();
    }
  }

  /// Exit the current minimized room cleanly
  void leaveCurrentRoomCleanly() {
    try {
      final room = _minimizedRoom.value;
      final bloc = _audioRoomsBloc;

      if (room != null) {
        // 1. Send leave presence message to chat
        try {
          final currentUser = AuthController.instance.currentUser;
          if (currentUser.userId.isNotEmpty) {
            EmojiChatService.sendPresenceMessage(
              roomId: room.id,
              userId: currentUser.userId,
              username: currentUser.fullname,
              userAvatar: currentUser.photoUrl,
              isJoin: false,
            );
          }
        } catch (e) {
          debugPrint('⚠️ [MinimizedController] Error sending leave presence message: $e');
        }

        // 2. Dispatch events to BLoC to leave Agora and the Firestore room
        if (bloc != null && !bloc.isClosed) {
          bloc.add(const LeaveAgoraChannel());
          try {
            final currentUser = AuthController.instance.currentUser;
            if (currentUser.userId.isNotEmpty) {
              bloc.add(LeaveAudioRoom(
                roomId: room.id,
                userId: currentUser.userId,
              ));
            }
          } catch (e) {
            debugPrint('⚠️ [MinimizedController] Error leaving audio room: $e');
          }
        }

        // 3. Clear minimized room data from state
        clearMinimizedRoom();

        // 4. Hide the floating overlay
        MinimizedRoomOverlay.hide();

        // 5. Ensure background service is stopped
        try {
          BackgroundService().stopService();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [MinimizedController] Error leaving room cleanly: $e');
    }
  }

  /// Checks if user is in a minimized room and handles the exit/join flow.
  /// If there is a minimized room and it is different from [targetRoom],
  /// shows a popup asking to leave the current room first.
  /// If the user clicks "Leave", it exits the current room and calls [onProceed].
  /// If there is no minimized room (or it is the same room), calls [onProceed] immediately.
  static void checkAndProceed({
    required BuildContext context,
    required AudioRoomV2 targetRoom,
    required VoidCallback onProceed,
    VoidCallback? onCancel,
  }) {
    // Make sure MinimizedRoomController is registered
    if (!Get.isRegistered<MinimizedRoomController>()) {
      Get.put(MinimizedRoomController());
    }

    final controller = Get.find<MinimizedRoomController>();
    if (controller.hasMinimizedRoom) {
      final prevRoom = controller.minimizedRoom;
      if (prevRoom != null && prevRoom.id != targetRoom.id) {
        // Show leave confirmation popup!
        _showLeaveConfirmationDialog(context, prevRoom, targetRoom, onProceed, onCancel: onCancel);
        return;
      }
    }
    // No minimized room, or it's the same room - proceed directly
    onProceed();
  }

  /// Show premium leave confirmation dialog
  static void _showLeaveConfirmationDialog(
    BuildContext context,
    AudioRoomV2 prevRoom,
    AudioRoomV2 targetRoom,
    VoidCallback onProceed, {
    VoidCallback? onCancel,
  }) {
    bool didProceed = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E142B), // Harmonious premium dark background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purpleAccent.withAlpha(51),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning/Switch Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horizontal_circle_outlined,
                    color: Colors.purpleAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                const Text(
                  'Switch Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  "You are currently in '${prevRoom.name}'. You must leave it first to join '${targetRoom.name}'.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Leave & Join Button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Vibrant premium gradient
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            didProceed = true;
                            Navigator.of(context).pop(); // Close dialog
                            
                            // Exit the previous room cleanly
                            final controller = Get.find<MinimizedRoomController>();
                            controller.leaveCurrentRoomCleanly();

                            // Instantly proceed (join the new room)
                            onProceed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Leave & Join',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (!didProceed) {
        onCancel?.call();
      }
    });
  }
}
