import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/services/entrance_effect_service.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';

/// Repository for managing Audio Rooms v2 data
class AudioRoomsRepository {
  static const String _collectionName = 'audio_rooms_v2';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _roomsSubscription;
  StreamSubscription<DocumentSnapshot>? _singleRoomSubscription;

  AudioRoomsRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Get collection reference
  CollectionReference get _roomsCollection =>
      _firestore.collection(_collectionName);

  /// Get all active audio rooms - FORCE SERVER QUERY
  Future<List<AudioRoomV2>> getAllRooms() async {
    try {
      // Force server query to get fresh data
      final querySnapshot = await _roomsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      final rooms = querySnapshot.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      final now = DateTime.now();
      rooms.sort((a, b) {
        final aPinned = a.isPinned && a.pinnedUntil != null && a.pinnedUntil!.isAfter(now);
        final bPinned = b.isPinned && b.pinnedUntil != null && b.pinnedUntil!.isAfter(now);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return rooms;
    } catch (e) {
      debugPrint('Error getting all rooms: $e');
      throw Exception('Failed to get rooms: $e');
    }
  }

  /// Update YouTube player state for the room
  Future<void> updateYoutubeState({
    required String roomId,
    required String? videoId,
    required bool isPlaying,
    required int syncPosition,
  }) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'activeYoutubeVideoId': videoId,
        'youtubeIsPlaying': isPlaying,
        'youtubeSyncPosition': syncPosition,
        'youtubeUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating YouTube state: $e');
      throw Exception('Failed to update YouTube state: $e');
    }
  }

  /// Update Ludo state for the room
  Future<void> updateLudoState({
    required String roomId,
    required bool isActive,
    int? maxPlayers,
  }) async {
    try {
      final updates = <String, dynamic>{
        'isLudoActive': isActive,
      };
      
      if (isActive && maxPlayers != null) {
        // Also initialize the Ludo game state when starting
        final ludoState = {
          'maxPlayers': maxPlayers,
          'players': {},
          'currentTurn': 'LudoColor.red',
          'diceValue': 1,
          'isDiceRolled': false,
          'winner': null,
          'tokens': [],
        };
        await FirebaseDatabase.instance
            .ref('rooms/$roomId/ludo/state')
            .set(ludoState);
      }
      
      await _roomsCollection.doc(roomId).update(updates);
    } catch (e) {
      debugPrint('Error updating Ludo state: $e');
      throw Exception('Failed to update Ludo state: $e');
    }
  }

  /// Update Voting state for the room
  Future<void> updateVotingState({
    required String roomId,
    required bool isActive,
  }) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'isVotingActive': isActive,
      });
    } catch (e) {
      debugPrint('Error updating Voting state: $e');
      throw Exception('Failed to update Voting state: $e');
    }
  }

  /// Get user's audio rooms (created or joined) - FORCE SERVER QUERY
  Future<List<AudioRoomV2>> getUserRooms(String userId) async {
    try {
      // 1. Get rooms created by user - force server query (fetch both active and inactive so they can resume)
      final createdRoomsQuery = await _roomsCollection
          .where('creatorId', isEqualTo: userId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      // 2. Get rooms where user is an Admin - force server query
      final adminRoomsQuery = await _roomsCollection
          .where('settings.adminIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      // 3. Get rooms that the user has joined (by joinedUserIds)
      final joinedRoomsQuery = await _roomsCollection
          .where('joinedUserIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      // 4. Get rooms where user is a participant - legacy query
      final participantRoomsQuery = await _roomsCollection
          .where('participants', arrayContainsAny: [
            {'userId': userId}
          ])
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      final createdRooms = createdRoomsQuery.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      final adminRooms = adminRoomsQuery.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      final joinedRooms = joinedRoomsQuery.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      final participantRooms = participantRoomsQuery.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      // Deduplicate rooms by ID
      final Map<String, AudioRoomV2> uniqueRooms = {};
      for (final room in createdRooms) {
        uniqueRooms[room.id] = room;
      }
      for (final room in adminRooms) {
        uniqueRooms[room.id] = room;
      }
      for (final room in joinedRooms) {
        uniqueRooms[room.id] = room;
      }
      for (final room in participantRooms) {
        uniqueRooms[room.id] = room;
      }

      final allUniqueRooms = uniqueRooms.values.toList();

      // Categorize and sort as requested:
      // - The user’s own room at the very top (if the user is a room owner)
      // - Rooms where the user is an Admin
      // - Rooms that the user has already joined
      final List<AudioRoomV2> ownerRoomsList = [];
      final List<AudioRoomV2> adminRoomsList = [];
      final List<AudioRoomV2> joinedRoomsList = [];

      for (final room in allUniqueRooms) {
        if (room.creatorId == userId) {
          ownerRoomsList.add(room);
        } else if (room.settings.adminIds.contains(userId)) {
          adminRoomsList.add(room);
        } else {
          joinedRoomsList.add(room);
        }
      }

      // Sort each category by updatedAt
      ownerRoomsList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      adminRoomsList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      joinedRoomsList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return [...ownerRoomsList, ...adminRoomsList, ...joinedRoomsList];
    } catch (e) {
      throw Exception('Failed to fetch user rooms: $e');
    }
  }

  /// Create new audio room
  Future<AudioRoomV2> createRoom({
    required String name,
    required String description,
    File? imageFile,
    required String creatorId,
    required String creatorName,
    String? creatorImageUrl,
    String? creatorFrameId,
    AudioRoomSettings? settings,
    String? category,
  }) async {
    try {
      debugPrint('🏠 [AudioRooms] Starting room creation for: $name');
      final startTime = DateTime.now();

      // Generate unique 7-8 digit numeric Room ID
      String roomId = '';
      bool exists = true;
      final random = Random();

      while (exists) {
        // Generate random number between 1,000,000 and 99,999,999
        final number = 1000000 + random.nextInt(99000000);
        roomId = number.toString();

        final doc = await _roomsCollection.doc(roomId).get();
        exists = doc.exists;
      }

      debugPrint('🏠 [AudioRooms] Generated numeric Room ID: $roomId');

      // Create initial seat configuration based on room mode
      final roomSettings = settings ?? const AudioRoomSettings();
      final initialSeats = <SeatInfo>[];

      // Create seats based on room mode (seat 1 is always for host)
      for (int i = 1; i <= roomSettings.roomMode.seatCount; i++) {
        initialSeats.add(SeatInfo(
          seatNumber: i,
          isLocked: false,
          occupiedBy: i == 1 ? creatorId : null, // Host gets seat 1
        ));
      }

      // Create room immediately without waiting for image upload
      final room = AudioRoomV2(
        id: roomId,
        name: name,
        description: description,
        imageUrl: null, // Will be updated after upload
        creatorId: creatorId,
        creatorName: creatorName,
        creatorImageUrl: creatorImageUrl,
        participants: [
          AudioRoomParticipant(
            userId: creatorId,
            userName: creatorName,
            userImageUrl: creatorImageUrl,
            frameId: creatorFrameId,
            joinedAt: DateTime.now(),
            isHost: true,
            isSpeaker: true,
            seatNumber: 1, // Host gets seat 1
            isSeated: true, // Host is seated
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        settings: roomSettings.copyWith(seatConfiguration: initialSeats),
        joinedUserIds: [creatorId],
        category: category ?? 'Game',
        roomLink: 'https://imchat.com/audioroom?id=$roomId',
      );

      debugPrint('🏠 [AudioRooms] Saving room to Firestore...');
      await _roomsCollection.doc(roomId).set(room.toFirestore());

      final roomCreationTime =
          DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
          '🏠 [AudioRooms] Room created successfully in ${roomCreationTime}ms');

      // Upload image asynchronously after room creation
      if (imageFile != null) {
        debugPrint('🏠 [AudioRooms] Starting image upload asynchronously...');
        _uploadRoomImageAsync(roomId, imageFile);
      }

      return room;
    } catch (e) {
      debugPrint('🏠 [AudioRooms] Error creating room: $e');
      throw Exception('Failed to create room: $e');
    }
  }

  /// Join audio room
  Future<AudioRoomV2> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    String? userImageUrl,
    String? userFrameId,
  }) async {
    try {
      // Validate input parameters
      if (roomId.isEmpty || userId.isEmpty || userName.isEmpty) {
        throw Exception('Invalid parameters provided');
      }

      // Force server query to get fresh room data
      final roomDoc = await _roomsCollection
          .doc(roomId)
          .get(const GetOptions(source: Source.server));

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is blocked from entering
      if (room.isUserBlocked(userId)) {
        throw Exception('You are blocked from entering this room.');
      }

      // Check if user was kicked recently (within 24 hours)
      try {
        final removedUserList = room.removedUsers.where((u) => u['userId'] == userId).toList();
        if (removedUserList.isNotEmpty) {
           removedUserList.sort((a, b) {
             DateTime parseTime(dynamic val) {
               if (val == null) return DateTime.now();
               if (val is Timestamp) return val.toDate();
               if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
               if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
               if (val is DateTime) return val;
               return DateTime.now();
             }
             final aTime = parseTime(a['removedAt']);
             final bTime = parseTime(b['removedAt']);
             return bTime.compareTo(aTime);
           });
           
           final mostRecentKick = removedUserList.first;
           DateTime? removedAt;
           final val = mostRecentKick['removedAt'];
           if (val != null) {
             if (val is Timestamp) removedAt = val.toDate();
             else if (val is int) removedAt = DateTime.fromMillisecondsSinceEpoch(val);
             else if (val is String) removedAt = DateTime.tryParse(val);
             else if (val is DateTime) removedAt = val;
           }
           
           if (removedAt != null) {
             final now = DateTime.now();
             if (now.difference(removedAt).inHours < 24) {
               throw Exception('You have been removed from this room and cannot join for 24 hours.');
             }
           }
        }
      } catch (e) {
         if (e.toString().contains('cannot join for 24 hours')) rethrow;
         // Ignore parsing errors
      }

      // Check if user is already in room
      if (room.isParticipant(userId)) {
        // Update existing participant info (e.g. frameId, name, image)
        debugPrint(
            '👤 [AudioRooms] User $userId already in room. Updating info...');

        final participantIndex =
            room.participants.indexWhere((p) => p.userId == userId);
        if (participantIndex != -1) {
          final existingParticipant = room.participants[participantIndex];

          // Check if owner needs to be added to joinedUserIds
          final isCreator = room.isCreator(userId);
          List<String> updatedJoinedUserIds = List<String>.from(room.joinedUserIds);
          bool joinedIdsChanged = false;
          if (isCreator && !updatedJoinedUserIds.contains(userId)) {
            updatedJoinedUserIds.add(userId);
            joinedIdsChanged = true;
          }

          Map<String, DateTime> updatedLastActive = Map<String, DateTime>.from(room.membersLastActive);
          updatedLastActive[userId] = DateTime.now();

          // Check auto-sit logic for Owner/Admin on rejoin
          bool autoSitRejoin = false;
          int? newSeatNumber = existingParticipant.seatNumber;
          bool newIsSeated = existingParticipant.isSeated;
          bool newIsSpeaker = existingParticipant.isSpeaker;
          bool newIsMuted = existingParticipant.isMuted;
          AudioRoomSettings updatedSettingsForRejoin = room.settings;

          if (!existingParticipant.isSeated && (isCreator || room.settings.adminIds.contains(userId))) {
            final seat1 = room.settings.seatConfiguration.firstWhere(
                (s) => s.seatNumber == 1,
                orElse: () => SeatInfo(seatNumber: 1, isLocked: true));
            if (seat1.occupiedBy == null && !seat1.isLocked) {
              autoSitRejoin = true;
              newSeatNumber = 1;
              newIsSeated = true;
              newIsSpeaker = true;
              newIsMuted = false;

              final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);
              final seatIndex = updatedSeats.indexWhere((s) => s.seatNumber == 1);
              if (seatIndex != -1) {
                updatedSeats[seatIndex] = updatedSeats[seatIndex].copyWith(occupiedBy: userId);
              }
              updatedSettingsForRejoin = updatedSettingsForRejoin.copyWith(seatConfiguration: updatedSeats);
            }
          }

          // Only update if something changed to avoid unnecessary writes
          if (existingParticipant.frameId != userFrameId ||
              existingParticipant.userImageUrl != userImageUrl ||
              existingParticipant.userName != userName ||
              joinedIdsChanged ||
              autoSitRejoin ||
              true) { // always update to keep last active precise
            final updatedParticipant = existingParticipant.copyWith(
              userName: userName,
              userImageUrl: userImageUrl,
              frameId: userFrameId,
              seatNumber: newSeatNumber,
              isSeated: newIsSeated,
              isSpeaker: newIsSpeaker,
              isMuted: newIsMuted,
            );

            final updatedParticipants =
                List<AudioRoomParticipant>.from(room.participants);
            updatedParticipants[participantIndex] = updatedParticipant;

            final updatedRoom = room.copyWith(
              participants: updatedParticipants,
              settings: updatedSettingsForRejoin,
              joinedUserIds: updatedJoinedUserIds,
              membersLastActive: updatedLastActive,
              updatedAt: DateTime.now(),
            );

            // Use batch write for consistency
            final batch = _firestore.batch();
            batch.update(
                _roomsCollection.doc(roomId), updatedRoom.toFirestore());
            await batch.commit();

            return updatedRoom;
          }
        }
        return room;
      }

      // Check if room is full
      if (room.isFull) {
        throw Exception('Room is full');
      }

      // New participants join as viewers (unseated) — unless they are owner/admin and seat 1 is empty
      final isPersistentAdmin = room.settings.adminIds.contains(userId);
      final isCreator = room.isCreator(userId);
      
      bool autoSit = false;
      int? seatNumber;
      if (isCreator || isPersistentAdmin) {
        final seat1 = room.settings.seatConfiguration.firstWhere(
            (s) => s.seatNumber == 1,
            orElse: () => SeatInfo(seatNumber: 1, isLocked: true));
        if (seat1.occupiedBy == null && !seat1.isLocked) {
          autoSit = true;
          seatNumber = 1;
        }
      }

      final newParticipant = AudioRoomParticipant(
        userId: userId,
        userName: userName,
        userImageUrl: userImageUrl,
        frameId: userFrameId,
        joinedAt: DateTime.now(),
        isMuted: autoSit ? false : true,
        isSpeaker: autoSit,
        isHost:
            isPersistentAdmin, // Grant admin status if user is in persistent admin list
        seatNumber: seatNumber,
        isSeated: autoSit,
      );

      final updatedParticipants = [...room.participants, newParticipant];

      AudioRoomSettings updatedSettings = room.settings;
      if (autoSit) {
        final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);
        final seatIndex = updatedSeats.indexWhere((s) => s.seatNumber == 1);
        if (seatIndex != -1) {
          updatedSeats[seatIndex] = updatedSeats[seatIndex].copyWith(occupiedBy: userId);
        } else {
          updatedSeats.add(SeatInfo(seatNumber: 1, isLocked: false, occupiedBy: userId));
        }
        updatedSettings = updatedSettings.copyWith(seatConfiguration: updatedSeats);
      }

      // Ensure room owner is automatically in joinedUserIds
      List<String> updatedJoinedUserIds = List<String>.from(room.joinedUserIds);
      if (isCreator && !updatedJoinedUserIds.contains(userId)) {
        updatedJoinedUserIds.add(userId);
      }

      Map<String, DateTime> updatedLastActive = Map<String, DateTime>.from(room.membersLastActive);
      updatedLastActive[userId] = DateTime.now();

      final updatedRoom = room.copyWith(
        participants: updatedParticipants,
        settings: updatedSettings,
        joinedUserIds: updatedJoinedUserIds,
        membersLastActive: updatedLastActive,
        updatedAt: DateTime.now(),
      );

      // Use batch write for faster update
      final batch = _firestore.batch();
      batch.update(_roomsCollection.doc(roomId), updatedRoom.toFirestore());
      await batch.commit();

      // Trigger entrance effect if user has one equipped
      _triggerEntranceEffectIfEquipped(
        roomId: roomId,
        userId: userId,
        userName: userName,
        userAvatar: userImageUrl,
      );

      // Set Realtime Database presence for auto-exit
      try {
        final databaseRef = FirebaseDatabase.instance.ref('audio_room_presence/$roomId/$userId');
        await databaseRef.set({
          'joinedAt': ServerValue.timestamp,
        });
        await databaseRef.onDisconnect().remove();
      } catch (e) {
        debugPrint('⚠️ [AudioRooms] Failed to set RTDB presence: $e');
      }

      return updatedRoom;
    } catch (e) {
      throw Exception('Failed to join room: $e');
    }
  }

  /// Leave audio room
  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Find the participant who is leaving to get their seat number
      final leavingParticipant = room.participants.firstWhere(
        (p) => p.userId == userId,
        orElse: () => throw Exception('Participant not found'),
      );

      // Remove participant
      final updatedParticipants =
          room.participants.where((p) => p.userId != userId).toList();

      // Clear the seat if the participant was sitting
      List<SeatInfo> updatedSeats = List.from(room.settings.seatConfiguration);
      if (leavingParticipant.seatNumber != null) {
        final seatIndex = updatedSeats.indexWhere(
          (seat) => seat.seatNumber == leavingParticipant.seatNumber,
        );
        if (seatIndex != -1) {
          updatedSeats[seatIndex] = SeatInfo(
            seatNumber: leavingParticipant.seatNumber!,
            isLocked: updatedSeats[seatIndex].isLocked,
            occupiedBy: null, // Clear the seat
          );
          debugPrint(
              '🪑 [AudioRooms] Cleared seat ${leavingParticipant.seatNumber} for leaving participant ${leavingParticipant.userName}');
        }
      }

      bool shouldEndRoom = false;
      // If creator leaves, the live room ends (since deletion is disabled, we set isActive = false)
      if (room.isCreator(userId) && room.category == 'Live') {
        shouldEndRoom = true;
        debugPrint('🗑️ [RoomCleanup] Admin leaving Live room, ending the room by setting isActive = false.');
      } else if (room.isCreator(userId)) {
        debugPrint('🚪 [RoomCleanup] Admin leaving Audio room, room remains active.');
      }

      // Regular users cannot delete the room - just leave
      // Room can only be deleted by admin or when admin leaves empty room
      if (updatedParticipants.isEmpty && !room.isCreator(userId)) {
        debugPrint(
            '🚪 [RoomCleanup] Regular user left empty room, but only admin can delete. Room will remain.');
        // Don't delete - room stays active but empty
      }

      Map<String, DateTime> updatedLastActive = Map<String, DateTime>.from(room.membersLastActive);
      updatedLastActive[userId] = DateTime.now();

      final updatedRoom = room.copyWith(
        participants: updatedParticipants,
        settings: room.settings.copyWith(seatConfiguration: updatedSeats),
        membersLastActive: updatedLastActive,
        isActive: !shouldEndRoom,
        updatedAt: DateTime.now(),
      );

      await _roomsCollection.doc(roomId).update(updatedRoom.toFirestore());

      // Clear Realtime Database presence since user left cleanly
      try {
        await FirebaseDatabase.instance.ref('audio_room_presence/$roomId/$userId').remove();
      } catch (e) {
        debugPrint('⚠️ [AudioRooms] Failed to clear RTDB presence: $e');
      }

      // Track live hours if leaving user was the host of the room
      if (leavingParticipant.isHost || room.isCreator(userId)) {
        _updateHostLiveHours(userId, leavingParticipant.joinedAt);
      }
    } catch (e) {
      throw Exception('Failed to leave room: $e');
    }
  }

  /// Resume a hidden Live room by setting isActive = true
  Future<void> resumeRoom(String roomId) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'isActive': true,
        'updatedAt': DateTime.now(),
      });
      debugPrint('▶️ [AudioRooms] Resumed Live Room $roomId (isActive = true)');
    } catch (e) {
      debugPrint('⚠️ [AudioRooms] Failed to resume room: $e');
      throw Exception('Failed to resume room: $e');
    }
  }

  /// Update host live hours in the hosts collection.
  /// Called when a host leaves a room — calculates session duration from joinedAt.
  /// Also increments the current Monday-to-Monday weekly live hours field.
  Future<void> _updateHostLiveHours(
      String userId, DateTime joinedAt) async {
    try {
      final sessionHours =
          DateTime.now().difference(joinedAt).inMinutes / 60.0;
      if (sessionHours <= 0) return;

      // Find host doc by userId (hosts collection uses auto-generated IDs)
      final hostQuery = await _firestore
          .collection('hosts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (hostQuery.docs.isEmpty) {
        debugPrint(
            '⏱️ [AudioRooms] User $userId is not a registered host, skipping live hours');
        return;
      }

      final hostDocId = hostQuery.docs.first.id;
      final weeklyKey = 'performance.weeklyLiveHours_${RankingHelper.mondayWeeklySuffix}';

      await _firestore.collection('hosts').doc(hostDocId).update({
        'performance.totalLiveHours': FieldValue.increment(sessionHours),
        weeklyKey: FieldValue.increment(sessionHours),
        'performance.lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint(
          '⏱️ [AudioRooms] Updated host $hostDocId live hours +${sessionHours.toStringAsFixed(2)}h '
          '(weekly key: $weeklyKey)');
    } catch (e) {
      // Non-critical — don't block room leave if this fails
      debugPrint('⏱️ [AudioRooms] Failed to update live hours: $e');
    }
  }

  /// Delete audio room (DISABLED)
  Future<void> deleteRoom(String roomId, String userId) async {
    debugPrint('🗑️ [AudioRooms] deleteRoom called but is DISABLED.');
    // Room deletion is now disabled per client request
    return;
  }

  /// Completely delete room (DISABLED)
  Future<void> deleteRoomCompletely(String roomId, String userId) async {
    debugPrint('🗑️ [AudioRooms] deleteRoomCompletely called but is DISABLED.');
    // Room deletion is now disabled per client request
    return;
  }

  /// Update room participant
  Future<void> updateParticipant({
    required String roomId,
    required String userId,
    required AudioRoomParticipant updatedParticipant,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);
      final participantIndex = room.participants
          .indexWhere((p) => p.userId == updatedParticipant.userId);

      if (participantIndex == -1) {
        throw Exception('Participant not found in room');
      }

      final updatedParticipants =
          List<AudioRoomParticipant>.from(room.participants);
      updatedParticipants[participantIndex] = updatedParticipant;

      // Update persistent admin list if isHost status changed
      AudioRoomSettings updatedSettings = room.settings;
      final oldParticipant = room.participants[participantIndex];

      if (oldParticipant.isHost != updatedParticipant.isHost) {
        final currentAdminIds = List<String>.from(room.settings.adminIds);
        if (updatedParticipant.isHost) {
          // Promoted to Admin - add to persistent list if not already there
          if (!currentAdminIds.contains(updatedParticipant.userId)) {
            currentAdminIds.add(updatedParticipant.userId);
            debugPrint(
                '👤 [AudioRooms] Added persistent admin: ${updatedParticipant.userName} (${updatedParticipant.userId})');
          }
        } else {
          // Demoted from Admin - remove from persistent list
          currentAdminIds.remove(updatedParticipant.userId);
          debugPrint(
              '👤 [AudioRooms] Removed persistent admin: ${updatedParticipant.userName} (${updatedParticipant.userId})');
        }
        updatedSettings = room.settings.copyWith(adminIds: currentAdminIds);
      }

      await _roomsCollection.doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update participant: $e');
    }
  }

  /// Toggle admin mute status for a participant
  Future<void> toggleAdminMute(String roomId, String userId, bool mutedByAdmin) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) throw Exception('Room not found');

      final room = AudioRoomV2.fromFirestore(roomDoc);
      final participantIndex = room.participants.indexWhere((p) => p.userId == userId);
      
      if (participantIndex != -1) {
        final updatedParticipants = List<AudioRoomParticipant>.from(room.participants);
        updatedParticipants[participantIndex] = updatedParticipants[participantIndex].copyWith(
          isMutedByAdmin: mutedByAdmin,
          isMuted: mutedByAdmin ? true : updatedParticipants[participantIndex].isMuted, // Force mute if admin muting
        );

        await _roomsCollection.doc(roomId).update({
          'participants': updatedParticipants.map((p) => p.toJson()).toList(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error toggling admin mute: $e');
      rethrow;
    }
  }

  /// Toggle messaging block for a participant
  Future<void> toggleMessagingBlock(String roomId, String userId, bool isBlocked) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) throw Exception('Room not found');

      final room = AudioRoomV2.fromFirestore(roomDoc);
      final participantIndex = room.participants.indexWhere((p) => p.userId == userId);
      
      if (participantIndex != -1) {
        final updatedParticipants = List<AudioRoomParticipant>.from(room.participants);
        updatedParticipants[participantIndex] = updatedParticipants[participantIndex].copyWith(
          isMessagingBlocked: isBlocked,
        );

        await _roomsCollection.doc(roomId).update({
          'participants': updatedParticipants.map((p) => p.toJson()).toList(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error toggling messaging block: $e');
      rethrow;
    }
  }

  /// Toggle seat access block for a participant
  Future<void> toggleSeatBlock(String roomId, String userId, bool isBlocked) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) throw Exception('Room not found');

      final room = AudioRoomV2.fromFirestore(roomDoc);
      final participantIndex = room.participants.indexWhere((p) => p.userId == userId);
      
      if (participantIndex != -1) {
        final updatedParticipants = List<AudioRoomParticipant>.from(room.participants);
        var participant = updatedParticipants[participantIndex];
        
        participant = participant.copyWith(
          isSeatBlocked: isBlocked,
        );

        AudioRoomSettings updatedSettings = room.settings;

        // If blocking and user is seated, remove them from seat
        if (isBlocked && participant.isSeated) {
          final seatNumber = participant.seatNumber;
          participant = participant.copyWith(
            clearSeatNumber: true,
            isSeated: false,
            isSpeaker: false,
            isMuted: true,
          );

          if (seatNumber != null) {
            final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);
            final seatIndex = updatedSeats.indexWhere((s) => s.seatNumber == seatNumber);
            if (seatIndex != -1) {
              if (updatedSeats[seatIndex].isLocked) {
                updatedSeats[seatIndex] = updatedSeats[seatIndex].copyWith(
                  occupiedBy: null,
                );
              } else if (seatNumber != 1) {
                // Remove unoccupied seat if not locked and not seat 1
                updatedSeats.removeAt(seatIndex);
              } else {
                updatedSeats[seatIndex] = updatedSeats[seatIndex].copyWith(
                  occupiedBy: null,
                );
              }
              updatedSettings = room.settings.copyWith(seatConfiguration: updatedSeats);
            }
          }
        }

        updatedParticipants[participantIndex] = participant;

        await _roomsCollection.doc(roomId).update({
          'participants': updatedParticipants.map((p) => p.toJson()).toList(),
          'settings': updatedSettings.toJson(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('Error toggling seat block: $e');
      rethrow;
    }
  }

  /// Search audio rooms
  Future<List<AudioRoomV2>> searchRooms(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Firebase doesn't support full-text search, so we'll use a simple approach
      // For production, consider using Algolia or Elasticsearch
      final querySnapshot = await _roomsCollection
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server));

      final allRooms = querySnapshot.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      // Filter rooms by name or description containing query (case-insensitive)
      final searchQuery = query.toLowerCase();
      return allRooms.where((room) {
        return room.name.toLowerCase().contains(searchQuery) ||
            room.description.toLowerCase().contains(searchQuery) ||
            room.creatorName.toLowerCase().contains(searchQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search rooms: $e');
    }
  }

  /// Get real-time updates for all rooms
  Stream<List<AudioRoomV2>> getRoomsStream() {
    return _roomsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map((doc) => AudioRoomV2.fromFirestore(doc))
          .toList();

      final now = DateTime.now();
      rooms.sort((a, b) {
        final aPinned = a.isPinned &&
            a.pinnedUntil != null &&
            a.pinnedUntil!.isAfter(now);
        final bPinned = b.isPinned &&
            b.pinnedUntil != null &&
            b.pinnedUntil!.isAfter(now);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return rooms;
    });
  }

  /// Get real-time updates for a specific room
  Stream<AudioRoomV2> getRoomStream(String roomId) {
    return _roomsCollection.doc(roomId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception('Room not found');
      }
      return AudioRoomV2.fromFirestore(doc);
    });
  }

  /// Upload room image to Firebase Storage
  /// Upload room image synchronously (with timeout)
  Future<String> _uploadRoomImage(String roomId, File imageFile) async {
    try {
      debugPrint('🏠 [AudioRooms] Uploading room image for: $roomId');
      final startTime = DateTime.now();

      final ref = _storage.ref().child('audio_rooms_v2/$roomId/room_image.jpg');
      final uploadTask = ref.putFile(imageFile);

      // Add timeout to prevent hanging
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              '🏠 [AudioRooms] Image upload timed out for room: $roomId');
          throw Exception('Image upload timed out');
        },
      );

      final downloadUrl = await snapshot.ref.getDownloadURL();
      final uploadTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
          '🏠 [AudioRooms] Image uploaded successfully in ${uploadTime}ms');

      return downloadUrl;
    } catch (e) {
      debugPrint('🏠 [AudioRooms] Error uploading room image: $e');
      throw Exception('Failed to upload room image: $e');
    }
  }

  /// Upload room image asynchronously and update room
  void _uploadRoomImageAsync(String roomId, File imageFile) {
    _uploadRoomImage(roomId, imageFile).then((imageUrl) {
      debugPrint('🏠 [AudioRooms] Updating room with image URL: $roomId');
      // Update room with image URL
      _roomsCollection.doc(roomId).update({
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }).then((_) {
        debugPrint('🏠 [AudioRooms] Room image URL updated successfully');
      }).catchError((error) {
        debugPrint(
            '🏠 [AudioRooms] Error updating room with image URL: $error');
      });
    }).catchError((error) {
      debugPrint('🏠 [AudioRooms] Async image upload failed: $error');
      // Don't throw error since room creation was already successful
    });
  }

  /// Update room settings (only creator/host can update)
  Future<void> updateRoomSettings({
    required String roomId,
    required String userId,
    required AudioRoomSettings settings,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update settings');
      }

      await _roomsCollection.doc(roomId).update({
        'settings': settings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update room settings: $e');
    }
  }

  /// Update PK Battle State (only creator/host can update)
  Future<void> updatePKBattleState({
    required String roomId,
    required String userId,
    required PKBattleState pkBattleState,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update PK battle state');
      }

      await _roomsCollection.doc(roomId).update({
        'pkBattleState': pkBattleState.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      debugPrint('⚔️ PK battle state updated for room: $roomId (Active: ${pkBattleState.isActive})');
    } catch (e) {
      throw Exception('Failed to update PK battle state: $e');
    }
  }

  /// Update room name (only creator/host can update)
  Future<void> updateRoomName(
      String roomId, String userId, String newName) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update room name');
      }

      await _roomsCollection.doc(roomId).update({
        'name': newName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('📝 Room name updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update room name: $e');
    }
  }

  /// Update room description (only creator/host can update)
  Future<void> updateRoomDescription(
      String roomId, String userId, String newDescription) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception(
            'Only room creator or host can update room description');
      }

      await _roomsCollection.doc(roomId).update({
        'description': newDescription,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('📝 Room description updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update room description: $e');
    }
  }

  /// Upload room image (public wrapper)
  Future<String> uploadRoomImage(String roomId, File imageFile) async {
    return _uploadRoomImage(roomId, imageFile);
  }

  /// Update room image URL (only creator/host can update)
  Future<void> updateRoomImage(
      String roomId, String userId, String imageUrl) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update room image');
      }

      // If there was an old image, we might want to delete it, but for now we skip that complexity
      // to avoid deleting the default image or if it's used elsewhere

      await _roomsCollection.doc(roomId).update({
        'imageUrl': imageUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🖼️ Room image updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update room image: $e');
    }
  }

  /// Update seat configuration (using maxSpeakers)
  Future<void> updateSeatConfiguration(
      String roomId, String userId, int seatCount) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception(
            'Only room creator or host can update seat configuration');
      }

      // Use maxSpeakers as seat count
      final updatedSettings = room.settings.copyWith(maxSpeakers: seatCount);

      // Check for participants that need to be unseated
      final updatedParticipants = List<AudioRoomParticipant>.from(room.participants);
      bool participantsChanged = false;
      
      for (int i = 0; i < updatedParticipants.length; i++) {
        final p = updatedParticipants[i];
        if (p.isSeated && p.seatNumber != null && p.seatNumber! > seatCount) {
          updatedParticipants[i] = p.copyWith(
            isSeated: false,
            seatNumber: null,
            isSpeaker: false,
          );
          participantsChanged = true;
        }
      }

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        if (participantsChanged) 'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '🪑 Seat configuration updated for room: $roomId - Seats: $seatCount');
    } catch (e) {
      throw Exception('Failed to update seat configuration: $e');
    }
  }

  /// Update background image
  Future<void> updateBackgroundImage(
      String roomId, String userId, String? imageUrl) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception(
            'Only room creator or host can update background image');
      }

      final updatedSettings = room.settings.copyWith(
        backgroundImageUrl: imageUrl,
        clearBackgroundImage: imageUrl == null,
      );

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🖼️ Background image updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update background image: $e');
    }
  }

  /// Update room announcement
  Future<void> updateRoomAnnouncement(
      String roomId, String userId, String? announcement) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception(
            'Only room creator or host can update room announcement');
      }

      final updatedSettings =
          room.settings.copyWith(announcement: announcement);

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('📢 Room announcement updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update room announcement: $e');
    }
  }

  /// Update music settings
  Future<void> updateMusicSettings(
      String roomId, String userId, bool musicEnabled, String? musicUrl) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update music settings');
      }

      final updatedSettings = room.settings.copyWith(
        musicEnabled: musicEnabled,
        musicUrl: musicUrl,
      );

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🎵 Music settings updated for room: $roomId');
    } catch (e) {
      throw Exception('Failed to update music settings: $e');
    }
  }

  /// Update room mode
  Future<void> updateRoomMode(
      String roomId, String userId, RoomMode roomMode) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Check if user is creator or host
      final isHost = room.isCreator(userId) ||
          room.participants.any((p) => p.userId == userId && p.isHost);

      if (!isHost) {
        throw Exception('Only room creator or host can update room mode');
      }

      // Update seat configuration to match new room mode
      final newSeatCount = roomMode.seatCount;
      final currentSeatCount = room.settings.seatConfiguration.length;

      List<SeatInfo> updatedSeats =
          List<SeatInfo>.from(room.settings.seatConfiguration);

      if (newSeatCount > currentSeatCount) {
        // Add new seats
        for (int i = currentSeatCount + 1; i <= newSeatCount; i++) {
          updatedSeats.add(SeatInfo(
            seatNumber: i,
            isLocked: false,
            occupiedBy: null,
          ));
        }
        debugPrint(
            '🎭 [RoomMode] Added ${newSeatCount - currentSeatCount} new seats (total: $newSeatCount)');
      } else if (newSeatCount < currentSeatCount) {
        // Remove excess seats (only if they're not occupied)
        updatedSeats = updatedSeats.where((seat) {
          if (seat.seatNumber > newSeatCount) {
            if (seat.occupiedBy != null) {
              debugPrint(
                  '🎭 [RoomMode] Warning: Cannot remove seat ${seat.seatNumber} - occupied by ${seat.occupiedBy}');
              return true; // Keep occupied seats
            }
            return false; // Remove unoccupied seats
          }
          return true; // Keep seats within new count
        }).toList();
        debugPrint(
            '🎭 [RoomMode] Removed ${currentSeatCount - updatedSeats.length} unoccupied seats (total: ${updatedSeats.length})');
      }

      final updatedSettings = room.settings.copyWith(
        roomMode: roomMode,
        seatConfiguration: updatedSeats,
      );

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '🎭 Room mode updated for room: $roomId - Mode: ${roomMode.displayName}');
    } catch (e) {
      throw Exception('Failed to update room mode: $e');
    }
  }

  /// Fix seat configuration mismatch for existing rooms
  Future<void> fixSeatConfigurationMismatch(String roomId) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();

      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);
      final expectedSeatCount = room.settings.roomMode.seatCount;
      final currentSeatCount = room.settings.seatConfiguration.length;

      if (expectedSeatCount == currentSeatCount) {
        return;
      }

      List<SeatInfo> updatedSeats =
          List<SeatInfo>.from(room.settings.seatConfiguration);

      if (expectedSeatCount > currentSeatCount) {
        // Add missing seats
        for (int i = currentSeatCount + 1; i <= expectedSeatCount; i++) {
          updatedSeats.add(SeatInfo(
            seatNumber: i,
            isLocked: false,
            occupiedBy: null,
          ));
        }
        debugPrint(
            '🎭 [FixSeats] Added ${expectedSeatCount - currentSeatCount} missing seats');
      } else {
        // Remove excess seats (only if unoccupied)
        updatedSeats = updatedSeats.where((seat) {
          if (seat.seatNumber > expectedSeatCount) {
            if (seat.occupiedBy != null) {
              debugPrint(
                  '🎭 [FixSeats] Warning: Cannot remove occupied seat ${seat.seatNumber}');
              return true; // Keep occupied seats
            }
            return false; // Remove unoccupied excess seats
          }
          return true; // Keep seats within expected count
        }).toList();
        debugPrint(
            '🎭 [FixSeats] Removed ${currentSeatCount - updatedSeats.length} excess seats');
      }

      // Only update if there are actual changes
      if (updatedSeats.length != room.settings.seatConfiguration.length) {
        final updatedSettings =
            room.settings.copyWith(seatConfiguration: updatedSeats);

        await _roomsCollection.doc(roomId).update({
          'settings': updatedSettings.toJson(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      debugPrint('🎭 [FixSeats] ❌ Failed to fix seat configuration: $e');
      throw Exception('Failed to fix seat configuration: $e');
    }
  }

  /// Upload background image to Firebase Storage with retry and compression
  Future<String> uploadBackgroundImage(String roomId, File imageFile) async {
    const maxRetries = 3;
    const timeoutDuration = Duration(seconds: 30); // Increased timeout

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '🖼️ Uploading background image for room: $roomId (attempt $attempt/$maxRetries)');
        final startTime = DateTime.now();

        // Compress image before upload to reduce size and upload time
        final compressedFile = await _compressImageFile(imageFile, roomId);
        final fileSize = await compressedFile.length();
        debugPrint(
            '🖼️ Compressed image size: ${(fileSize / 1024).toStringAsFixed(1)} KB');

        final ref = _storage.ref().child(
            'audio_rooms_v2/$roomId/background_${DateTime.now().millisecondsSinceEpoch}.jpg');

        // Create upload task with metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'roomId': roomId,
            'uploadTime': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = ref.putFile(compressedFile, metadata);

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('🖼️ Upload progress: ${progress.toStringAsFixed(1)}%');
        });

        // Add timeout with better error handling
        final snapshot = await uploadTask.timeout(
          timeoutDuration,
          onTimeout: () {
            debugPrint(
                '🖼️ Background image upload timed out for room: $roomId (attempt $attempt)');
            uploadTask.cancel(); // Cancel the upload task
            throw Exception(
                'Upload timed out after ${timeoutDuration.inSeconds} seconds');
          },
        );

        final downloadUrl = await snapshot.ref.getDownloadURL();
        final uploadTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint(
            '🖼️ ✅ Background image uploaded successfully in ${uploadTime}ms');

        // Clean up compressed file
        try {
          await compressedFile.delete();
        } catch (e) {
          debugPrint('🖼️ Warning: Could not delete compressed file: $e');
        }

        return downloadUrl;
      } catch (e) {
        debugPrint('🖼️ ❌ Upload attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          // Final attempt failed
          debugPrint('🖼️ 🚨 All upload attempts failed for room: $roomId');
          throw Exception(
              'Failed to upload background image after $maxRetries attempts: ${e.toString()}');
        }

        // Wait before retry (exponential backoff)
        final waitTime = Duration(seconds: attempt * 2);
        debugPrint('🖼️ ⏳ Waiting ${waitTime.inSeconds}s before retry...');
        await Future.delayed(waitTime);
      }
    }

    throw Exception('Upload failed after all retry attempts');
  }

  /// Compress image file to reduce upload time and storage
  Future<File> _compressImageFile(File originalFile, String roomId) async {
    try {
      debugPrint('🖼️ Compressing image for room: $roomId');

      // Read original file
      final originalBytes = await originalFile.readAsBytes();
      final originalSize = originalBytes.length;
      debugPrint(
          '🖼️ Original image size: ${(originalSize / 1024).toStringAsFixed(1)} KB');

      // For now, we'll use a simple approach - just copy the file
      // In a production app, you'd want to use image compression libraries like flutter_image_compress
      final compressedPath =
          '${originalFile.parent.path}/compressed_${roomId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = await originalFile.copy(compressedPath);

      debugPrint('🖼️ Image compression completed');
      return compressedFile;
    } catch (e) {
      debugPrint('🖼️ Error compressing image: $e, using original file');
      return originalFile;
    }
  }

  /// Send chat message
  Future<void> sendChatMessage(String roomId, String userId, String username,
      String? userAvatar, String message) async {
    try {
      final messageId = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc()
          .id;

      final chatMessage = ChatMessage(
        id: messageId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        message: message,
        timestamp: DateTime.now(),
        roomId: roomId,
      );

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('chat')
          .doc(messageId)
          .set(chatMessage.toJson());

      debugPrint('💬 Chat message sent to room: $roomId');
    } catch (e) {
      debugPrint('💬 Error sending chat message: $e');
      throw Exception('Failed to send chat message: $e');
    }
  }

  /// Get chat messages stream
  Stream<List<ChatMessage>> getChatMessagesStream(String roomId) {
    return _firestore
        .collection('audio_rooms_v2')
        .doc(roomId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .limit(50) // Limit to last 50 messages
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return ChatMessage.fromJson(doc.data());
            } catch (e) {
              debugPrint('💬 Error parsing chat message: $e');
              return null;
            }
          })
          .where((message) => message != null)
          .cast<ChatMessage>()
          .toList();
    });
  }

  /// Toggle seat lock/unlock
  /// Toggle lock for all 15 seats
  Future<void> toggleAllSeatsLock(String roomId, String hostId, bool isLocked) async {
    try {
      debugPrint('🪑 [SeatManagement] Toggling ALL seats lock to $isLocked in room: $roomId');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can manage seats');
      }

      // Generate updated seat configuration for all seats
      final List<SeatInfo> updatedSeats = room.settings.seatConfiguration.map((seat) {
        String? newOccupiedBy = seat.occupiedBy;
        
        // If locking all seats, unseat everyone
        if (isLocked) {
          newOccupiedBy = null;
        }

        return SeatInfo(
          seatNumber: seat.seatNumber,
          isLocked: isLocked,
          occupiedBy: newOccupiedBy,
          lockedAt: isLocked ? DateTime.now() : null,
          lockedBy: isLocked ? hostId : null,
        );
      }).toList();

      final updatedSettings = room.settings.copyWith(seatConfiguration: updatedSeats);
      final updatedParticipants = List<AudioRoomParticipant>.from(room.participants);
      
      final batch = FirebaseFirestore.instance.batch();
      
      if (isLocked) {
        // Kick everyone sitting
        for (int i = 0; i < updatedParticipants.length; i++) {
          if (updatedParticipants[i].isSeated) {
            final pId = updatedParticipants[i].userId;
            updatedParticipants[i] = updatedParticipants[i].copyWith(
              isSeated: false,
              seatNumber: null,
              isSpeaker: false,
            );
            
            // Legacy subcollection update (just in case)
            final pDoc = _roomsCollection.doc(roomId).collection('participants').doc(pId);
            // Catch error if document doesn't exist in subcollection
            try {
               batch.update(pDoc, {
                 'isSeated': false,
                 'seatNumber': null,
                 'seatedAt': null,
               });
            } catch (e) {
               // Ignore missing subcollection document
            }
          }
        }
      }
      
      batch.update(_roomsCollection.doc(roomId), {
        'settings': updatedSettings.toJson(),
        if (isLocked) 'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
      debugPrint('🪑 [SeatManagement] All seats ${isLocked ? 'locked' : 'unlocked'} successfully');
    } catch (e) {
      debugPrint('🪑 [SeatManagement] Error toggling all seats lock: $e');
      rethrow;
    }
  }

  /// Toggle lock for specific seat
  Future<void> toggleSeatLock(
      String roomId, String hostId, int seatNumber, bool isLocked) async {
    try {
      debugPrint(
          '🪑 [SeatManagement] Toggling seat $seatNumber lock to $isLocked in room: $roomId');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can manage seats');
      }

      // Update seat configuration
      final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);
      final existingSeatIndex =
          updatedSeats.indexWhere((s) => s.seatNumber == seatNumber);

      if (existingSeatIndex >= 0) {
        updatedSeats[existingSeatIndex] =
            updatedSeats[existingSeatIndex].copyWith(
          isLocked: isLocked,
          lockedAt: isLocked ? DateTime.now() : null,
          lockedBy: isLocked ? hostId : null,
        );
      } else {
        updatedSeats.add(SeatInfo(
          seatNumber: seatNumber,
          isLocked: isLocked,
          lockedAt: isLocked ? DateTime.now() : null,
          lockedBy: isLocked ? hostId : null,
        ));
      }

      final updatedSettings =
          room.settings.copyWith(seatConfiguration: updatedSeats);

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '🪑 [SeatManagement] Seat $seatNumber ${isLocked ? 'locked' : 'unlocked'} successfully');
    } catch (e) {
      debugPrint('🪑 [SeatManagement] Error toggling seat lock: $e');
      throw Exception('Failed to toggle seat lock: $e');
    }
  }

  /// Move participant to different seat
  Future<void> moveParticipantToSeat(
      String roomId, String userId, int fromSeat, int toSeat) async {
    try {
      debugPrint('🪑 [SeatManagement] ===== MOVE PARTICIPANT START =====');
      debugPrint(
          '🪑 [SeatManagement] Moving participant $userId from seat $fromSeat to $toSeat');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      debugPrint('🪑 [SeatManagement] Current room seat configuration:');
      for (final seat in room.settings.seatConfiguration) {
        debugPrint(
            '🪑 [SeatManagement] - Seat ${seat.seatNumber}: occupied by ${seat.occupiedBy}, locked: ${seat.isLocked}');
      }

      debugPrint('🪑 [SeatManagement] Current participant data:');
      for (final p in room.participants) {
        debugPrint(
            '🪑 [SeatManagement] - ${p.userName} (${p.userId}): seat ${p.seatNumber}');
      }

      // Check if user can move to target seat (special case: toSeat = 0 means leaving all seats)
      if (toSeat != 0 && !room.canUserMoveToSeat(userId, toSeat)) {
        throw Exception('Cannot move to this seat');
      }

      // Special handling for admin/creator moving to occupied seat
      final isAdmin = room.isCreator(userId);
      final isMovingToOccupiedSeat = toSeat != 0 && room.isSeatOccupied(toSeat);

      if (isAdmin && isMovingToOccupiedSeat) {
        final currentOccupant = room.getParticipantInSeat(toSeat);
        if (currentOccupant != null) {
          debugPrint(
              '🪑 [SeatManagement] Admin $userId moving to occupied seat $toSeat, kicking current occupant ${currentOccupant.userName}');
        }
      }

      // Special handling for leaving seats (toSeat = 0)
      final isLeavingAllSeats = (toSeat == 0);
      if (isLeavingAllSeats) {
        debugPrint(
            '🪑 [SeatManagement] User $userId is leaving all seats (becoming listener)');
      }

      // Update participant seat number and speaker status
      final updatedParticipants = room.participants.map((p) {
        if (p.userId == userId) {
          debugPrint(
              '🪑 [SeatManagement] Updating participant ${p.userName} from seat ${p.seatNumber} to seat $toSeat');
          if (isLeavingAllSeats) {
            // Leaving all seats - become a listener
            return p.copyWith(
              clearSeatNumber: true, // Explicitly clear seat number
              isSpeaker: false, // Become listener
              isMuted: true, // Mute when becoming listener
              isSeated: false, // Not seated anymore
            );
          } else {
            // Moving to a specific seat - become a speaker
            return p.copyWith(
              seatNumber: toSeat,
              isSpeaker:
                  true, // Automatically become a speaker when moving to seat
              // Unmute when becoming a speaker ONLY if not muted by admin
              isMuted: p.isMutedByAdmin ? true : false,
              isSeated: true, // Now seated
            );
          }
        }

        // Special case: If admin is moving to occupied seat, kick the current occupant
        if (isAdmin &&
            isMovingToOccupiedSeat &&
            p.seatNumber == toSeat &&
            p.userId != userId) {
          debugPrint(
              '🪑 [SeatManagement] Kicking current occupant ${p.userName} from seat $toSeat (admin takeover)');
          return p.copyWith(
            clearSeatNumber: true, // Remove from seat
            isSpeaker: false, // Become listener
            isMuted: true, // Mute when becoming listener
            isSeated: false, // Not seated anymore
          );
        }

        return p;
      }).toList();

      // Safety check: Ensure no other participant has the target seat
      final conflictingParticipants = updatedParticipants
          .where((p) => p.userId != userId && p.seatNumber == toSeat)
          .toList();

      if (conflictingParticipants.isNotEmpty) {
        debugPrint(
            '🪑 [SeatManagement] WARNING: Found ${conflictingParticipants.length} conflicting participants in seat $toSeat');
        for (final conflict in conflictingParticipants) {
          debugPrint(
              '🪑 [SeatManagement] Conflict: ${conflict.userName} also in seat $toSeat');
        }
      }

      // Update seat configuration - CRITICAL: Clear old seat first
      final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);

      debugPrint(
          '🪑 [SeatManagement] Before update - Total seats configured: ${updatedSeats.length}');

      // Step 1: Use cleanup method to clear ALL seats occupied by this user
      debugPrint(
          '🪑 [SeatManagement] BEFORE cleanup - seats occupied by $userId:');
      for (final seat in updatedSeats) {
        if (seat.occupiedBy == userId) {
          debugPrint('🪑 [SeatManagement] - User in seat ${seat.seatNumber}');
        }
      }

      final cleanedSeats = _cleanupUserSeats(updatedSeats, userId, toSeat);
      updatedSeats.clear();
      updatedSeats.addAll(cleanedSeats);

      debugPrint(
          '🪑 [SeatManagement] AFTER cleanup - seats occupied by $userId:');
      for (final seat in updatedSeats) {
        if (seat.occupiedBy == userId) {
          debugPrint(
              '🪑 [SeatManagement] - User still in seat ${seat.seatNumber}');
        }
      }

      // Step 2: Clear the specific old seat (if it exists) - double safety check
      final oldSeatIndex =
          updatedSeats.indexWhere((s) => s.seatNumber == fromSeat);
      if (oldSeatIndex >= 0) {
        final oldSeat = updatedSeats[oldSeatIndex];
        debugPrint(
            '🪑 [SeatManagement] Processing old seat $fromSeat (locked: ${oldSeat.isLocked})');

        if (oldSeat.isLocked || fromSeat == 1) {
          // If seat is locked OR it's seat 1 (admin seat), keep it in config but clear occupancy
          updatedSeats[oldSeatIndex] = oldSeat.copyWith(occupiedBy: null);
          debugPrint(
              '🪑 [SeatManagement] Old seat $fromSeat cleared but kept (${oldSeat.isLocked ? 'locked' : 'admin seat'})');
        } else {
          // If seat is not locked and not seat 1, remove it completely from config
          updatedSeats.removeAt(oldSeatIndex);
          debugPrint(
              '🪑 [SeatManagement] Old seat $fromSeat removed from configuration (unlocked)');
        }
      }

      // Step 3: Occupy new seat (skip if leaving all seats)
      if (!isLeavingAllSeats) {
        final newSeatIndex =
            updatedSeats.indexWhere((s) => s.seatNumber == toSeat);
        if (newSeatIndex >= 0) {
          final targetSeat = updatedSeats[newSeatIndex];
          debugPrint(
              '🪑 [SeatManagement] Occupying existing seat $toSeat (currently locked: ${targetSeat.isLocked})');
          updatedSeats[newSeatIndex] = targetSeat.copyWith(occupiedBy: userId);
          debugPrint(
              '🪑 [SeatManagement] Target seat $toSeat now occupied, still locked: ${updatedSeats[newSeatIndex].isLocked}');
        } else {
          debugPrint(
              '🪑 [SeatManagement] Creating new seat $toSeat for user (unlocked by default)');
          updatedSeats.add(SeatInfo(
              seatNumber: toSeat, occupiedBy: userId, isLocked: false));
        }
      } else {
        debugPrint(
            '🪑 [SeatManagement] User leaving all seats - no new seat to occupy');
      }

      // Final verification - check ALL seats for this user
      debugPrint('🪑 [SeatManagement] FINAL STATE VERIFICATION:');
      int userSeatCount = 0;
      for (final seat in updatedSeats) {
        if (seat.occupiedBy == userId) {
          userSeatCount++;
          debugPrint(
              '🪑 [SeatManagement] ✅ User $userId found in seat ${seat.seatNumber}');
        }
        if (seat.seatNumber == fromSeat ||
            (!isLeavingAllSeats && seat.seatNumber == toSeat)) {
          debugPrint(
              '🪑 [SeatManagement] 📍 Seat ${seat.seatNumber}: occupied=${seat.occupiedBy}, locked=${seat.isLocked}');
        }
      }

      final expectedSeatCount = isLeavingAllSeats ? 0 : 1;
      if (userSeatCount != expectedSeatCount) {
        debugPrint(
            '🪑 [SeatManagement] ⚠️ ERROR: User $userId found in $userSeatCount seats (should be $expectedSeatCount)');
      } else {
        final statusText =
            isLeavingAllSeats ? 'no seats (listener)' : 'exactly 1 seat';
        debugPrint(
            '🪑 [SeatManagement] ✅ SUCCESS: User $userId found in $statusText');
      }

      debugPrint(
          '🪑 [SeatManagement] User $userId move complete: $fromSeat → $toSeat');

      // FINAL SAFETY CHECK: Ensure user has correct seat count
      final finalUserSeats =
          updatedSeats.where((s) => s.occupiedBy == userId).toList();
      final expectedCondition = isLeavingAllSeats
          ? finalUserSeats.isEmpty
          : (finalUserSeats.length == 1 &&
              finalUserSeats.first.seatNumber == toSeat);

      if (!expectedCondition) {
        debugPrint(
            '🪑 [SeatManagement] 🚨 CRITICAL ERROR: Final seat assignment failed!');
        if (isLeavingAllSeats) {
          debugPrint(
              '🪑 [SeatManagement] Expected: user in no seats (listener)');
        } else {
          debugPrint('🪑 [SeatManagement] Expected: user in seat $toSeat only');
        }
        debugPrint(
            '🪑 [SeatManagement] Actual: user in ${finalUserSeats.length} seats: ${finalUserSeats.map((s) => s.seatNumber).join(', ')}');

        // FORCE FIX: Clear ALL seats and set only target seat (if not leaving)
        for (int i = 0; i < updatedSeats.length; i++) {
          if (updatedSeats[i].occupiedBy == userId) {
            updatedSeats[i] = updatedSeats[i].copyWith(occupiedBy: null);
          }
          if (!isLeavingAllSeats && updatedSeats[i].seatNumber == toSeat) {
            updatedSeats[i] = updatedSeats[i].copyWith(occupiedBy: userId);
          }
        }
        final fixText = isLeavingAllSeats
            ? 'user cleared from all seats'
            : 'user now only in seat $toSeat';
        debugPrint('🪑 [SeatManagement] 🔧 FORCE FIX applied - $fixText');
      }

      final updatedSettings =
          room.settings.copyWith(seatConfiguration: updatedSeats);

      debugPrint(
          '🪑 [SeatManagement] 💾 Updating Firebase with cleaned seat configuration');
      await _roomsCollection.doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🪑 [SeatManagement] ✅ Firebase update complete');

      debugPrint('🪑 [SeatManagement] Participant moved successfully');
    } catch (e) {
      debugPrint('🪑 [SeatManagement] Error moving participant: $e');
      throw Exception('Failed to move participant: $e');
    }
  }

  /// Remove participant from seat
  Future<void> removeParticipantFromSeat(String roomId, String hostId,
      String participantId, int seatNumber) async {
    try {
      debugPrint(
          '🪑 [SeatManagement] Removing participant $participantId from seat $seatNumber');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can remove participants from seats');
      }

      // Update participant to remove seat number and make them a listener
      final updatedParticipants = room.participants.map((p) {
        if (p.userId == participantId) {
          return p.copyWith(
            clearSeatNumber: true, // Explicitly clear seat number
            isSpeaker: false, // Become listener when removed from seat
            isMuted: true, // Mute when becoming listener
            isSeated: false, // Not seated anymore
          );
        }
        return p;
      }).toList();

      // Update seat configuration to clear occupancy or remove seat
      final updatedSeats = List<SeatInfo>.from(room.settings.seatConfiguration);
      final seatIndex =
          updatedSeats.indexWhere((s) => s.seatNumber == seatNumber);
      if (seatIndex >= 0) {
        final seat = updatedSeats[seatIndex];
        if (seat.isLocked) {
          // If seat is locked, keep it in config but clear occupancy
          updatedSeats[seatIndex] = seat.copyWith(occupiedBy: null);
          debugPrint(
              '🪑 [SeatManagement] Seat $seatNumber cleared but kept (locked)');
        } else {
          // If seat is not locked, remove it completely from config
          updatedSeats.removeAt(seatIndex);
          debugPrint(
              '🪑 [SeatManagement] Seat $seatNumber removed from configuration (unlocked)');
        }
      }

      final updatedSettings =
          room.settings.copyWith(seatConfiguration: updatedSeats);

      await _roomsCollection.doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '🪑 [SeatManagement] Participant removed from seat successfully');
    } catch (e) {
      debugPrint(
          '🪑 [SeatManagement] Error removing participant from seat: $e');
      throw Exception('Failed to remove participant from seat: $e');
    }
  }

  /// Kick participant from room
  Future<void> kickParticipant(
      String roomId, String hostId, String participantId, String reason) async {
    try {
      debugPrint(
          '🚪 [ParticipantManagement] Kicking participant $participantId from room: $roomId');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can kick participants');
      }

      // First, mute the participant before removing them from the room
      final updatedParticipants = room.participants.map((p) {
        if (p.userId == participantId) {
          // Mute the participant before kicking them
          return p.copyWith(
            isMuted: true,
            isSpeaker: false,
            clearSeatNumber: true, // Remove from seat
          );
        }
        return p;
      }).toList();

      // Then remove the participant from the room
      final finalParticipants =
          updatedParticipants.where((p) => p.userId != participantId).toList();

      // Clear participant from any seats
      final updatedSeats = room.settings.seatConfiguration.map((seat) {
        if (seat.occupiedBy == participantId) {
          return seat.copyWith(occupiedBy: null);
        }
        return seat;
      }).toList();

      final updatedSettings =
          room.settings.copyWith(seatConfiguration: updatedSeats);

      // Check if room should be auto-deleted (empty room after kicking)
      if (finalParticipants.isEmpty) {
        debugPrint(
            '🗑️ [RoomCleanup] Room became empty after kicking participant, auto-deleting');
        await deleteRoomCompletely(roomId, hostId);
        return;
      }

      await _roomsCollection.doc(roomId).update({
        'participants': finalParticipants.map((p) => p.toJson()).toList(),
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🚪 [ParticipantManagement] Participant kicked successfully');
    } catch (e) {
      debugPrint('🚪 [ParticipantManagement] Error kicking participant: $e');
      throw Exception('Failed to kick participant: $e');
    }
  }

  /// Block participant from room
  Future<void> blockParticipant(
      String roomId, String hostId, String participantId, String reason) async {
    try {
      debugPrint(
          '🚫 [ParticipantManagement] Blocking participant $participantId from room: $roomId');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can block participants');
      }

      // Get participant info before removing
      final participantToBlock =
          room.participants.firstWhere((p) => p.userId == participantId);

      // Remove participant from room
      final updatedParticipants =
          room.participants.where((p) => p.userId != participantId).toList();

      // Clear participant from any seats
      final updatedSeats = room.settings.seatConfiguration.map((seat) {
        if (seat.occupiedBy == participantId) {
          return seat.copyWith(occupiedBy: null);
        }
        return seat;
      }).toList();

      // Add to blocked users list
      final blockedUser = BlockedUser(
        userId: participantId,
        userName: participantToBlock.userName,
        userImageUrl: participantToBlock.userImageUrl,
        blockedAt: DateTime.now(),
        blockedBy: hostId,
        reason: reason,
      );

      final updatedBlockedUsers = [...room.settings.blockedUsers, blockedUser];

      final updatedSettings = room.settings.copyWith(
        seatConfiguration: updatedSeats,
        blockedUsers: updatedBlockedUsers,
      );

      await _roomsCollection.doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toJson()).toList(),
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('🚫 [ParticipantManagement] Participant blocked successfully');
    } catch (e) {
      debugPrint('🚫 [ParticipantManagement] Error blocking participant: $e');
      throw Exception('Failed to block participant: $e');
    }
  }

  /// Unblock participant
  Future<void> unblockParticipant(
      String roomId, String hostId, String participantId) async {
    try {
      debugPrint(
          '✅ [ParticipantManagement] Unblocking participant $participantId from room: $roomId');

      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      final room = AudioRoomV2.fromFirestore(roomDoc);

      // Verify host permissions
      if (!room.isCreator(hostId)) {
        throw Exception('Only hosts can unblock participants');
      }

      // Remove from blocked users list
      final updatedBlockedUsers = room.settings.blockedUsers
          .where((b) => b.userId != participantId)
          .toList();

      final updatedSettings =
          room.settings.copyWith(blockedUsers: updatedBlockedUsers);

      await _roomsCollection.doc(roomId).update({
        'settings': updatedSettings.toJson(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint(
          '✅ [ParticipantManagement] Participant unblocked successfully');
    } catch (e) {
      debugPrint('✅ [ParticipantManagement] Error unblocking participant: $e');
      throw Exception('Failed to unblock participant: $e');
    }
  }

  /// Clean up duplicate seat assignments for a user - AGGRESSIVE CLEANUP
  List<SeatInfo> _cleanupUserSeats(
      List<SeatInfo> seats, String userId, int targetSeat) {
    final cleanedSeats = <SeatInfo>[];

    debugPrint(
        '🪑 [Cleanup] 🧹 AGGRESSIVE CLEANUP for user $userId, target seat: $targetSeat');
    debugPrint('🪑 [Cleanup] Total seats to check: ${seats.length}');

    for (final seat in seats) {
      if (seat.occupiedBy == userId) {
        // ALWAYS clear this user from ALL seats first - we'll add them to target seat later
        debugPrint(
            '🪑 [Cleanup] ❌ FORCE CLEARING user from seat ${seat.seatNumber} (was locked: ${seat.isLocked})');

        if (seat.isLocked) {
          // If seat is locked, keep it in config but clear occupancy
          cleanedSeats.add(seat.copyWith(occupiedBy: null));
          debugPrint(
              '🪑 [Cleanup] 🔒 Seat ${seat.seatNumber} cleared but kept (locked)');
        } else {
          // If seat is not locked, remove it completely from config
          debugPrint(
              '🪑 [Cleanup] 🗑️ Seat ${seat.seatNumber} removed from configuration (unlocked)');
          // Don't add to cleanedSeats - effectively removing it
        }
      } else {
        // Seat not occupied by this user, keep as is
        debugPrint(
            '🪑 [Cleanup] ➡️ Seat ${seat.seatNumber} occupied by: ${seat.occupiedBy ?? 'nobody'}');
        cleanedSeats.add(seat);
      }
    }

    debugPrint(
        '🪑 [Cleanup] 🧹 AGGRESSIVE CLEANUP complete. User cleared from ALL seats.');
    return cleanedSeats;
  }

  /// Clear Firebase cache to force fresh data
  Future<void> clearCache() async {
    try {
      // Clear Firestore cache
      await _firestore.clearPersistence();
    } catch (e) {
      // Cache clearing might fail if there are active listeners
      // This is normal and not critical
    }
  }

  /// Trigger entrance effect if user has one equipped
  Future<void> _triggerEntranceEffectIfEquipped({
    required String roomId,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    try {
      // Fetch user document to get entrance effect
      final userDoc = await _firestore.collection('Users').doc(userId).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedEntryEffectId = customization?['selectedEntryEffectId'];

      if (selectedEntryEffectId == null || selectedEntryEffectId.isEmpty) {
        debugPrint(
            '🎬 [EntranceEffect] No entrance effect equipped for $userName');
        return;
      }

      // Fetch entrance effect details from store
      final effectDoc = await _firestore
          .collection('market_items')
          .doc(selectedEntryEffectId)
          .get();

      if (!effectDoc.exists) {
        debugPrint(
            '🎬 [EntranceEffect] Effect not found: $selectedEntryEffectId');
        return;
      }

      final effectData = effectDoc.data();
      final effectUrl = effectData?['fileUrl'] ??
          effectData?['thumbnailUrl'] ??
          effectData?['imageUrl'] ??
          effectData?['image'] ??
          '';

      if (effectUrl.isEmpty) {
        debugPrint('🎬 [EntranceEffect] No URL found for effect');
        return;
      }

      debugPrint(
          '🎬 [EntranceEffect] Triggering effect for $userName: $effectUrl');

      // Trigger the entrance effect
      final entranceService = EntranceEffectService();
      await entranceService.triggerEntranceEffect(
        roomId: roomId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        effectId: selectedEntryEffectId,
        effectUrl: effectUrl,
      );
    } catch (e) {
      debugPrint('❌ [EntranceEffect] Error triggering entrance effect: $e');
      // Don't throw - entrance effects are non-critical
    }
  }

  /// Send a join request to the room
  Future<void> sendJoinRequest(String roomId, String userId) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'joinRequests': FieldValue.arrayUnion([userId]),
      });
      debugPrint('📩 [JoinRequest] User $userId sent join request to room $roomId');
    } catch (e) {
      debugPrint('Error sending join request: $e');
      throw Exception('Failed to send join request: $e');
    }
  }

  /// Accept a join request and remove it from the list
  Future<void> acceptJoinRequest(String roomId, String userId) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'joinRequests': FieldValue.arrayRemove([userId]),
      });
      debugPrint('✅ [JoinRequest] User $userId join request accepted for room $roomId');
    } catch (e) {
      debugPrint('Error accepting join request: $e');
      throw Exception('Failed to accept join request: $e');
    }
  }

  /// Reject a join request and remove it from the list
  Future<void> rejectJoinRequest(String roomId, String userId) async {
    try {
      await _roomsCollection.doc(roomId).update({
        'joinRequests': FieldValue.arrayRemove([userId]),
      });
      debugPrint('❌ [JoinRequest] User $userId join request rejected for room $roomId');
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
      throw Exception('Failed to reject join request: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _roomsSubscription?.cancel();
    _singleRoomSubscription?.cancel();
  }
}
