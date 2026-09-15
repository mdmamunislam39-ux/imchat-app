import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:chat_messenger/services/premium_room_service.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_screen.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';

/// Integration helper for Audio Rooms v2
class AudioRoomsV2Integration {
  static bool _isNavigating = false;
  
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

  /// Open or create private Audio Room for a Group Chat
  static Future<void> openGroupAudioRoom(Group group) async {
    try {
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to join audio room.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Check member access
      final memberIds = group.members.map((m) => m.userId).toList();
      if (memberIds.isNotEmpty && !memberIds.contains(currentUser.userId) && group.createdBy != currentUser.userId) {
        Get.snackbar(
          'Access Denied',
          'Only members of this group can join the audio room.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      try {
        // Check if active audio room for this group exists
        final existingQuery = await FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .where('groupId', isEqualTo: group.groupId)
            .get();

        final activeDocs = existingQuery.docs.where((d) {
          final data = d.data();
          return data['isActive'] == true;
        }).toList();

        AudioRoomV2 room;
        final repository = AudioRoomsRepository();

        if (activeDocs.isNotEmpty) {
          final doc = activeDocs.first;
          room = AudioRoomV2.fromFirestore(doc);

          // Update member access list & admin list in case group members changed
          final updatedAdminIds = Set<String>.from(room.settings.adminIds)..addAll(group.adminMembers);
          if (group.createdBy.isNotEmpty) updatedAdminIds.add(group.createdBy);

          final updatedAllowed = Set<String>.from(room.allowedUserIds)..addAll(memberIds);
          if (group.createdBy.isNotEmpty) updatedAllowed.add(group.createdBy);

          final updatedJoined = Set<String>.from(room.joinedUserIds)..addAll(memberIds);
          if (group.createdBy.isNotEmpty) updatedJoined.add(group.createdBy);

          await FirebaseFirestore.instance
              .collection('audio_rooms_v2')
              .doc(room.id)
              .update({
            'allowedUserIds': updatedAllowed.toList(),
            'joinedUserIds': updatedJoined.toList(),
            'settings.adminIds': updatedAdminIds.toList(),
          });

          // Join existing room if not already a participant
          if (!room.isParticipant(currentUser.userId)) {
            room = await repository.joinRoom(
              roomId: room.id,
              userId: currentUser.userId,
              userName: currentUser.fullname,
              userImageUrl: currentUser.photoUrl,
              userFrameId: currentUser.customization?.selectedFrameId,
            );
          }
        } else {
          // Create new group room
          final ownerId = group.createdBy.isNotEmpty ? group.createdBy : currentUser.userId;
          final adminIds = group.adminMembers.isNotEmpty
              ? group.adminMembers
              : [ownerId];

          // Allowed user IDs includes all group members and owner
          final allowedIds = Set<String>.from(memberIds);
          allowedIds.add(ownerId);

          // Setup initial room settings
          final initialAdminIds = Set<String>.from(adminIds)..add(ownerId);
          final settings = AudioRoomSettings(
            adminIds: initialAdminIds.toList(),
          );

          // Generate numeric room ID
          final random = Random();
          String roomId = '';
          bool exists = true;
          while (exists) {
            final number = 1000000 + random.nextInt(99000000);
            roomId = number.toString();
            final doc = await FirebaseFirestore.instance
                .collection('audio_rooms_v2')
                .doc(roomId)
                .get();
            exists = doc.exists;
          }

          final initialSeats = <SeatInfo>[];
          for (int i = 1; i <= settings.roomMode.seatCount; i++) {
            initialSeats.add(SeatInfo(
              seatNumber: i,
              isLocked: false,
              occupiedBy: i == 1 ? currentUser.userId : null,
            ));
          }

          room = AudioRoomV2(
            id: roomId,
            name: '${group.name} AudioRoom',
            description: group.description.isNotEmpty ? group.description : 'Group Audio Room',
            imageUrl: group.photoUrl.isNotEmpty ? group.photoUrl : null,
            creatorId: ownerId,
            creatorName: group.createdBy == currentUser.userId ? currentUser.fullname : 'Group Owner',
            creatorImageUrl: group.createdBy == currentUser.userId ? currentUser.photoUrl : group.photoUrl,
            participants: [
              AudioRoomParticipant(
                userId: currentUser.userId,
                userName: currentUser.fullname,
                userImageUrl: currentUser.photoUrl,
                frameId: currentUser.customization?.selectedFrameId,
                joinedAt: DateTime.now(),
                isHost: currentUser.userId == ownerId,
                isSpeaker: true,
                seatNumber: 1,
                isSeated: true,
              ),
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            settings: settings.copyWith(seatConfiguration: initialSeats),
            joinedUserIds: allowedIds.toList(),
            category: 'Event',
            roomLink: 'https://invite.imchatapp.com/room/$roomId',
            groupId: group.groupId,
            isGroupRoom: true,
            isPrivate: true,
            allowedUserIds: allowedIds.toList(),
            excludeFromRanking: true,
          );

          await FirebaseFirestore.instance
              .collection('audio_rooms_v2')
              .doc(roomId)
              .set(room.toFirestore());
        }

        final audioRoomsBloc = AudioRoomsBloc(repository: repository);
        Get.to(() => AudioRoomScreen(
          room: room,
          audioRoomsBloc: audioRoomsBloc,
        ));
      } catch (e) {
        debugPrint('Error opening group audio room: $e');
        Get.snackbar(
          'Error',
          'Failed to open audio room: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not start audio room: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Navigate directly to a specific room
  static void navigateToRoom(AudioRoomV2 room, [BuildContext? context]) {
    if (_isNavigating) {
      debugPrint('⚠️ [AudioRoomsV2Integration] Navigation in progress, ignoring duplicate tap.');
      return;
    }
    _isNavigating = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      _isNavigating = false;
    });

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

      // Check minimized room controller
      if (!Get.isRegistered<MinimizedRoomController>()) {
        Get.put(MinimizedRoomController());
      }
      final minimizedCtrl = Get.find<MinimizedRoomController>();

      if (minimizedCtrl.hasMinimizedRoom) {
        final currentMinRoom = minimizedCtrl.minimizedRoom;
        if (currentMinRoom != null) {
          if (currentMinRoom.id == room.id) {
            // Restoring the SAME room! Reuse existing BLoC without re-joining Agora or freezing
            final (restoredRoom, restoredBloc) = minimizedCtrl.restoreRoom();
            final roomToUse = restoredRoom ?? room;
            final blocToUse = restoredBloc ?? AudioRoomsBloc(repository: AudioRoomsRepository());

            Get.to(() => AudioRoomScreen(
              room: roomToUse,
              audioRoomsBloc: blocToUse,
              isRestoring: true,
            ));
            return;
          } else if (context != null) {
            // User is in a DIFFERENT room: ask to leave first
            MinimizedRoomController.checkAndProceed(
              context: context,
              targetRoom: room,
              onProceed: () => _internalNavigateToRoom(room),
            );
            return;
          } else {
            // Leave previous room cleanly and join new room
            minimizedCtrl.leaveCurrentRoomCleanly();
          }
        }
      }

      _internalNavigateToRoom(room);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to join room: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  static void _internalNavigateToRoom(AudioRoomV2 room) {
    // Create BLoC instance
    final audioRoomsBloc = AudioRoomsBloc(
      repository: AudioRoomsRepository(),
    );

    // Navigate to room screen
    Get.to(() => AudioRoomScreen(
      room: room,
      audioRoomsBloc: audioRoomsBloc,
    ));
  }

  /// Check if user has active audio room
  static Future<bool> hasActiveRoom() async {
    try {
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) return false;

      final snapshot = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .where('creatorId', isEqualTo: currentUser.userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user's active audio room
  static Future<AudioRoomV2?> getActiveRoom() async {
    try {
      final currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .where('creatorId', isEqualTo: currentUser.userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return AudioRoomV2.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Navigate to user's active room or create new one
  static Future<void> navigateToActiveRoomOrCreate(BuildContext context) async {
    try {
      final activeRoom = await getActiveRoom();
      if (activeRoom != null) {
        // Navigate to existing active room
        final audioRoomsBloc = AudioRoomsBloc(
          repository: AudioRoomsRepository(),
        );
        Get.to(() => AudioRoomScreen(
          room: activeRoom,
          audioRoomsBloc: audioRoomsBloc,
        ));
      } else {
        // Show create room dialog
        if (context.mounted) {
          showCreateRoomDialog(context);
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to handle audio room: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Join or navigate to a room by room ID (e.g. from deep link or room share)
  static Future<void> joinRoomById(String roomId) async {
    String cleanId = roomId.trim();
    if (cleanId.isEmpty) {
      Get.snackbar(
        'Invalid Link',
        'Room ID is missing.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Extract ID if a full URL was passed
    if (cleanId.startsWith('http://') ||
        cleanId.startsWith('https://') ||
        cleanId.startsWith('imchat://') ||
        cleanId.startsWith('imchatapp://')) {
      final parsedUri = Uri.tryParse(cleanId);
      if (parsedUri != null) {
        final parsedMap = DeepLinkService.parseDeepLink(parsedUri);
        if (parsedMap != null && parsedMap['type'] == 'room' && parsedMap['id'] != null) {
          cleanId = parsedMap['id']!;
        }
      }
    }

    try {
      // Check if user is authenticated
      var currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isEmpty) {
        final fbUser = auth.FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          try {
            await AuthController.instance.getCurrentUserAndLoadData();
            currentUser = AuthController.instance.currentUser;
          } catch (_) {}
        }
      }

      if (currentUser.userId.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please log in to join rooms',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Resolve vanity / short ID if applicable
      String targetDocId = cleanId;
      try {
        final resolved = await PremiumRoomService.instance.resolveRoomId(cleanId);
        if (resolved != null && resolved.isNotEmpty) {
          targetDocId = resolved;
        }
      } catch (e) {
        debugPrint('resolveRoomId error: $e');
      }

      // Fetch room document from Firestore
      DocumentSnapshot? doc;
      try {
        final exactDoc = await FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .doc(targetDocId)
            .get();
        if (exactDoc.exists) {
          doc = exactDoc;
        }
      } catch (_) {}

      // Fallback search if doc wasn't found by direct ID
      if (doc == null || !doc.exists) {
        try {
          final querySnap = await FirebaseFirestore.instance
              .collection('audio_rooms_v2')
              .where(FieldPath.documentId, isGreaterThanOrEqualTo: cleanId)
              .where(FieldPath.documentId, isLessThanOrEqualTo: '$cleanId\uf8ff')
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

          if (querySnap.docs.isNotEmpty) {
            doc = querySnap.docs.first;
          }
        } catch (_) {}
      }

      if (doc == null || !doc.exists) {
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

      // Close existing minimized overlay if joining a different room
      if (Get.isRegistered<MinimizedRoomController>()) {
        final minCtrl = Get.find<MinimizedRoomController>();
        if (minCtrl.hasMinimizedRoom && minCtrl.minimizedRoom?.id != room.id) {
          minCtrl.leaveCurrentRoomCleanly();
        }
      }

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
              roomId: room.id,
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
