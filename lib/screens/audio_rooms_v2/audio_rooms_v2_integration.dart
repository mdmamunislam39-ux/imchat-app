import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_screen.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

/// Integration helper for Audio Rooms v2
class AudioRoomsV2Integration {
  
  /// Navigate to Audio Rooms v2 screen
  static void navigateToAudioRooms() {
    try {
      // Check if user is authenticated
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to access audio rooms',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Navigate to Audio Rooms v2 screen
      Get.to(() => const AudioRoomsV2Screen());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open audio rooms: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Navigate directly to a specific room
  static void navigateToRoom(AudioRoomV2 room) {
    try {
      // Check if user is authenticated
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to join rooms',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Create BLoC instance
      final audioRoomsBloc = AudioRoomsBloc(
        repository: AudioRoomsRepository(),
      );

      // Navigate to room screen
      Get.to(() => AudioRoomScreen(
        room: room,
        audioRoomsBloc: audioRoomsBloc,
      ));
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to join room: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Join or navigate to a room by room ID (e.g. from deep link or room share)
  static Future<void> joinRoomById(String roomId) async {
    if (roomId.isEmpty) {
      Get.snackbar(
        'Invalid Link',
        'Room ID is missing.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // Check if user is authenticated
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to join rooms',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Fetch room document from the correct collection with a timeout
      final doc = await FirebaseFirestore.instance
          .collection('audio_rooms_v2') // ✅ correct collection
          .doc(roomId)
          .get(const GetOptions(source: Source.server))
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection.');
        },
      );

      if (!doc.exists) {
        Get.snackbar(
          'Room Not Found',
          'The voice room does not exist or has been deleted.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final room = AudioRoomV2.fromFirestore(doc);

      // Check if room is active
      if (!room.isActive) {
        Get.snackbar(
          'Room Closed',
          'This voice room is no longer active.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final audioRoomsBloc = AudioRoomsBloc(
        repository: AudioRoomsRepository(),
      );

      // If user is already in the room, just navigate there
      if (room.isParticipant(currentUser.userId)) {
        Get.to(() => AudioRoomScreen(
          room: room,
          audioRoomsBloc: audioRoomsBloc,
        ));
        return;
      }

      // Show elegant loading overlay and join room
      Get.showOverlay(
        asyncFunction: () async {
          try {
            final joinedRoom = await AudioRoomsRepository().joinRoom(
              roomId: roomId,
              userId: currentUser.userId,
              userName: currentUser.fullname,
              userImageUrl: currentUser.photoUrl,
              userFrameId: currentUser.customization?.selectedFrameId,
            );
            Get.to(() => AudioRoomScreen(
              room: joinedRoom,
              audioRoomsBloc: audioRoomsBloc,
            ));
          } on Exception catch (e) {
            final msg = e.toString().replaceFirst('Exception: ', '');
            debugPrint('Error joining room from link: $e');
            Get.snackbar(
              'Join Failed',
              msg.isNotEmpty ? msg : 'Could not join the voice room.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
          ),
        ),
      );
    } on Exception catch (e) {
      debugPrint('Error resolving room link: $e');
      Get.snackbar(
        'Error',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Quick create room shortcut
  static void quickCreateRoom({
    required String name,
    required String description,
  }) {
    try {
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to create rooms',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Navigate to audio rooms and trigger create room
      navigateToAudioRooms();
      
      // Note: In a real implementation, you might want to 
      // automatically open the create room dialog with pre-filled data
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create room: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Show create room bottom sheet directly
  static void showCreateRoomDialog(BuildContext context) {
    try {
      // Check if user is authenticated
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to create a room'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show create room bottom sheet
      // Note: This would require BLoC provider setup in the widget tree
      // For now, navigate to the main screen which handles BLoC setup
      navigateToAudioRooms();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create room: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check if Audio Rooms v2 feature is available
  static bool isAudioRoomsAvailable() {
    try {
      // Check if user is authenticated
      final currentUser = AuthController.instance.currentUser;
      return currentUser.userId.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
