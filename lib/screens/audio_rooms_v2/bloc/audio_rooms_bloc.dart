import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/agora_models.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/services/railway_token_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/ban_service.dart';

/// BLoC for managing Audio Rooms v2 with Agora Integration
class AudioRoomsBloc extends Bloc<AudioRoomsEvent, AudioRoomsState> {
  final AudioRoomsRepository _repository;
  final AgoraService _agoraService = AgoraService();
  DateTime? _lastMicToggleTime;

  StreamSubscription<List<AudioRoomV2>>? _roomsStreamSubscription;
  StreamSubscription<AudioRoomV2>? _singleRoomSubscription;
  StreamSubscription<User?>? _userSubscription;

  // Agora state tracking
  bool _agoraInitialized = false;
  String? _currentChannelName;
  int? _currentUid;
  final List<AgoraUser> _agoraUsers = [];

  // Current user for kick detection
  User? _currentUser;
  AudioRoomV2? _currentRoom;
  final Map<int, NetworkQuality> _networkQualities = {};

  // Periodic mute check timer
  Timer? _muteCheckTimer;

  // Seat configuration debounce
  Timer? _seatConfigDebounceTimer;
  String? _lastSeatConfigRoomId;
  bool _isLeavingVoluntarily = false;

  AudioRoomsBloc({
    required AudioRoomsRepository repository,
  })  : _repository = repository,
        super(const AudioRoomsInitial()) {
    // Register event handlers
    on<LoadAudioRooms>(_onLoadAudioRooms);
    on<RefreshAudioRooms>(_onRefreshAudioRooms);
    on<EnforceRealTimeBans>(_onEnforceRealTimeBans);
    on<LoadUserAudioRooms>(_onLoadUserAudioRooms);
    on<CreateAudioRoom>(_onCreateAudioRoom);
    on<ResumeAudioRoom>(_onResumeAudioRoom);
    on<JoinAudioRoom>(_onJoinAudioRoom);
    on<LeaveAudioRoom>(_onLeaveAudioRoom);
    on<DeleteAudioRoom>(_onDeleteAudioRoom);
    on<UpdateRoomParticipant>(_onUpdateRoomParticipant);
    on<SearchAudioRooms>(_onSearchAudioRooms);
    on<ClearSearch>(_onClearSearch);
    on<UpdateRoomSettings>(_onUpdateRoomSettings);
    on<UpdatePKBattleState>(_onUpdatePKBattleState);
    on<ListenToRoomUpdates>(_onListenToRoomUpdates);
    on<StopListeningToRoomUpdates>(_onStopListeningToRoomUpdates);
    on<RoomUpdatedFromStream>(_onRoomUpdatedFromStream);
    on<RoomsListUpdatedFromStream>(_onRoomsListUpdatedFromStream);
    on<UpdateSeatConfiguration>(_onUpdateSeatConfiguration);
    on<UpdateBackgroundImage>(_onUpdateBackgroundImage);
    on<UpdateRoomName>(_onUpdateRoomName);
    on<UpdateRoomDescription>(_onUpdateRoomDescription);
    on<UpdateRoomImage>(_onUpdateRoomImage);
    on<UpdateRoomAnnouncement>(_onUpdateRoomAnnouncement);
    on<UpdateMusicSettings>(_onUpdateMusicSettings);
    on<UpdateRoomMode>(_onUpdateRoomMode);
    on<SendChatMessage>(_onSendChatMessage);
    on<ChatMessagesUpdated>(_onChatMessagesUpdated);
    on<EmojiChatMessagesUpdated>(_onEmojiChatMessagesUpdated);

    // Seat Management Events
    on<ToggleAllSeatsLock>(_onToggleAllSeatsLock);
    on<ToggleSeatLock>(_onToggleSeatLock);
    on<MoveParticipantToSeat>(_onMoveParticipantToSeat);
    on<RemoveParticipantFromSeat>(_onRemoveParticipantFromSeat);
    on<KickParticipant>(_onKickParticipant);
    on<BlockParticipant>(_onBlockParticipant);
    on<UnblockParticipant>(_onUnblockParticipant);
    on<ToggleAdminMute>(_onToggleAdminMute);
    on<ToggleMessagingBlock>(_onToggleMessagingBlock);
    on<ToggleSeatBlock>(_onToggleSeatBlock);

    // Agora Events
    on<InitializeAgora>(_onInitializeAgora);
    on<JoinAgoraChannel>(_onJoinAgoraChannel);
    on<LeaveAgoraChannel>(_onLeaveAgoraChannel);
    on<ToggleMicrophone>(_onToggleMicrophone);
    on<SetMicrophoneMute>(_onSetMicrophoneMute);
    on<ToggleRoomMute>(_onToggleRoomMute);
    on<SetRoomMute>(_onSetRoomMute);

    // Utility Events
    on<ForceLeaveAgoraChannel>(_onForceLeaveAgoraChannel);
    on<FixSeatConfigurationMismatch>(_onFixSeatConfigurationMismatch);
    on<ToggleSpeaker>(_onToggleSpeaker);
    on<SetAudioQuality>(_onSetAudioQuality);
    on<ApplyAudioEffect>(_onApplyAudioEffect);
    on<ApplyVoiceChanger>(_onApplyVoiceChanger);
    on<StartBackgroundMusic>(_onStartBackgroundMusic);
    on<StopBackgroundMusic>(_onStopBackgroundMusic);
    on<PauseBackgroundMusic>(_onPauseBackgroundMusic);
    on<ResumeBackgroundMusic>(_onResumeBackgroundMusic);
    on<RenewAgoraToken>(_onRenewAgoraToken);

    // Agora Callback Events
    on<AgoraUserJoined>(_onAgoraUserJoined);
    on<AgoraUserLeft>(_onAgoraUserLeft);
    on<AgoraUserMuted>(_onAgoraUserMuted);
    on<AudioVolumeIndication>(_onAudioVolumeIndication);
    on<AgoraConnectionStateChanged>(_onAgoraConnectionStateChanged);
    on<NetworkQualityUpdate>(_onNetworkQualityUpdate);
    on<AgoraStatsUpdate>(_onAgoraStatsUpdate);
    on<TokenPrivilegeWillExpire>(_onTokenPrivilegeWillExpire);
    on<AudioMixingFinished>(_onAudioMixingFinished);
    on<AudioEffectFinished>(_onAudioEffectFinished);
    on<AgoraErrorOccurred>(_onAgoraErrorOccurred);

    // Join Request Events
    on<SendJoinRequest>(_onSendJoinRequest);
    on<AcceptJoinRequest>(_onAcceptJoinRequest);
    on<RejectJoinRequest>(_onRejectJoinRequest);

    // Initialize Agora callbacks
    _setupAgoraCallbacks();

    // Listen to current user updates for real-time ban enforcement
    _userSubscription =
        AuthController.instance.currentUserStream.listen((user) {
      if (user != null && !isClosed) {
        add(EnforceRealTimeBans(user));
      }
    });
  }

  /// Handle loading audio rooms
  Future<void> _onEnforceRealTimeBans(
    EnforceRealTimeBans event,
    Emitter<AudioRoomsState> emit,
  ) async {
    _currentUser = event.user;
    if (_currentRoom == null) return;

    try {
      final currentParticipant = _currentRoom!.participants
          .where((p) => p.userId == _currentUser!.userId)
          .firstOrNull;

      if (currentParticipant != null) {
        if (BanService.isMicBanned(event.user) &&
            currentParticipant.isSeated &&
            currentParticipant.seatNumber != 0) {
          debugPrint(
              '🚪 [AudioRoomsBloc] ⚠️ User Mic Banned (Realtime Event), removing from seat...');
          add(RemoveParticipantFromSeat(
            roomId: _currentRoom!.id,
            hostId: _currentRoom!.creatorId,
            participantId: _currentUser!.userId,
            seatNumber: currentParticipant.seatNumber!,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error enforcing real-time ban: $e');
    }
  }

  Future<void> _onLoadAudioRooms(
    LoadAudioRooms event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(const AudioRoomsLoading());

      final rooms = await _repository.getAllRooms();

      emit(AudioRoomsLoaded(
        rooms: rooms,
        userRooms: const [],
      ));
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'LOAD_ROOMS_FAILED',
      ));
    }
  }

  /// Handle refreshing audio rooms
  Future<void> _onRefreshAudioRooms(
    RefreshAudioRooms event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      final currentState = state;

      final rooms = await _repository.getAllRooms();

      if (currentState is AudioRoomsLoaded) {
        emit(currentState.copyWith(rooms: rooms));
      } else {
        emit(AudioRoomsLoaded(
          rooms: rooms,
          userRooms: const [],
        ));
      }
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'REFRESH_ROOMS_FAILED',
      ));
    }
  }

  /// Handle loading user's audio rooms
  Future<void> _onLoadUserAudioRooms(
    LoadUserAudioRooms event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      final currentState = state;

      final userRooms = await _repository.getUserRooms(event.userId);

      if (currentState is AudioRoomsLoaded) {
        emit(currentState.copyWith(userRooms: userRooms));
      } else {
        // Also load all rooms if not loaded yet
        final allRooms = await _repository.getAllRooms();
        emit(AudioRoomsLoaded(
          rooms: allRooms,
          userRooms: userRooms,
        ));
      }
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'LOAD_USER_ROOMS_FAILED',
      ));
    }
  }

  /// Handle creating audio room
  Future<void> _onCreateAudioRoom(
    CreateAudioRoom event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint('🎯 [AudioRoomsBloc] Creating room: ${event.name}');
      final startTime = DateTime.now();

      emit(const CreatingAudioRoom());

      // Rule: Check if user already has a room of the requested type (Live vs Audio)
      final userRooms = await _repository.getUserRooms(event.creatorId);
      final isRequestingLive = event.category == 'Live';

      final ownedMatchingRooms = userRooms.where((room) {
        if (room.creatorId != event.creatorId) return false;
        final isRoomLive = room.category == 'Live';
        return isRequestingLive == isRoomLive;
      }).toList();

      if (ownedMatchingRooms.isNotEmpty) {
        debugPrint(
            '🎯 [AudioRoomsBloc] User ${event.creatorId} already owns a ${isRequestingLive ? 'Live' : 'Audio'} room. Preventing creation.');
        emit(const AudioRoomCreationFailed(
            message: 'You already have a room of this type.'));
        return;
      }

      final room = await _repository.createRoom(
        name: event.name,
        description: event.description,
        imageFile: event.imageFile,
        creatorId: event.creatorId,
        creatorName: event.creatorName,
        creatorImageUrl: event.creatorImageUrl,
        creatorFrameId: event.creatorFrameId,
        settings: event.settings,
        category: event.category,
      );

      final creationTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
          '🎯 [AudioRoomsBloc] Room created successfully in ${creationTime}ms');

      emit(AudioRoomCreated(room: room));

      // Trigger follow notification: notify followers that the user has opened a voice room
      _notifyFollowersRoomOpened(event.creatorId, event.creatorName, room.id);

      // Refresh rooms list
      debugPrint('🎯 [AudioRoomsBloc] Refreshing rooms list...');
      add(const LoadAudioRooms());
    } catch (e) {
      debugPrint('🏠 [AudioRoomsBloc] Error creating room: $e');
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Resume a hidden audio room
  Future<void> _onResumeAudioRoom(
    ResumeAudioRoom event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(AudioRoomsLoading());
      debugPrint('▶️ [AudioRoomsBloc] Resuming room: ${event.room.name}');

      await _repository.resumeRoom(event.room.id);

      // After resuming, automatically join it
      add(JoinAudioRoom(
        roomId: event.room.id,
        userId: _currentUser!.userId,
        userName: _currentUser!.fullname,
        userImageUrl: _currentUser!.photoUrl,
        userFrameId: _currentUser!.customization?.selectedFrameId,
      ));
    } catch (e) {
      debugPrint('▶️ [AudioRoomsBloc] Error resuming room: $e');
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Notify all followers in the background that this user has opened a voice room
  void _notifyFollowersRoomOpened(
      String creatorId, String creatorName, String roomId) async {
    try {
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(creatorId)
          .collection('followers')
          .get();

      for (var doc in followersSnapshot.docs) {
        final followerId = doc.id;
        if (followerId.isNotEmpty) {
          final followerUser = await UserApi.getUser(followerId);
          if (followerUser != null) {
            await OfficialTeamApi.sendFollowedUserOpenedRoomMessage(
                followerUser, creatorName, roomId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying followers of room creation: $e');
    }
  }

  /// Handle joining audio room - OPTIMIZED for speed
  Future<void> _onJoinAudioRoom(
    JoinAudioRoom event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // Validate input parameters
      if (event.roomId.isEmpty ||
          event.userId.isEmpty ||
          event.userName.isEmpty) {
        emit(AudioRoomJoinFailed(
          message: 'Invalid parameters provided',
          roomId: event.roomId,
        ));
        return;
      }

      // Set current user immediately for kick detection
      _currentUser = User(
        userId: event.userId,
        fullname: event.userName,
        photoUrl: event.userImageUrl ?? '',
      );

      // Emit joining state immediately for UI feedback
      emit(JoiningAudioRoom(roomId: event.roomId));

      // Reset voluntary leave flag so we accurately detect kicks in the new room
      _isLeavingVoluntarily = false;

      // Run room join and Agora initialization in parallel for speed
      final futures = await Future.wait([
        _repository.joinRoom(
          roomId: event.roomId,
          userId: event.userId,
          userName: event.userName,
          userImageUrl: event.userImageUrl,
          userFrameId: event.userFrameId,
        ),
        // Pre-initialize Agora while joining room
        _initializeAgoraIfNeeded(),
      ]);

      final updatedRoom = futures[0] as AudioRoomV2;

      // Find the participant with null safety
      AudioRoomParticipant? participant;
      try {
        participant = updatedRoom.participants
            .firstWhere((p) => p.userId == event.userId);
      } catch (e) {
        // Create a fallback participant object
        participant = AudioRoomParticipant(
          userId: event.userId,
          userName: event.userName,
          joinedAt: DateTime.now(),
          isMuted: updatedRoom.settings.autoMuteNewParticipants,
          isSpeaker: false,
          isHost: false,
        );
      }

      // Emit joined state immediately
      emit(AudioRoomJoined(
        room: updatedRoom,
        participant: participant,
      ));

      // Start background operations after UI update
      _startBackgroundOperations(event.roomId);
    } catch (e) {
      // Provide specific error messages for common issues
      String errorMessage = 'Failed to join room';
      if (e.toString().contains('cannot join for 24 hours')) {
        errorMessage =
            'You have been removed from this room and cannot join for 24 hours.';
      } else if (e.toString().contains('blocked from entering')) {
        errorMessage = 'You are blocked from entering this room.';
      } else if (e.toString().contains('Room is full')) {
        errorMessage = 'Room is full. Please try another room.';
      } else if (e.toString().contains('Room not found')) {
        errorMessage = 'Room no longer exists.';
      } else if (e.toString().contains('Invalid parameters')) {
        errorMessage = 'Invalid room or user information.';
      } else {
        errorMessage = 'Failed to join room. Please try again.';
      }

      emit(AudioRoomJoinFailed(
        message: errorMessage,
        roomId: event.roomId,
      ));
    }
  }

  /// Initialize Agora if not already initialized
  Future<bool> _initializeAgoraIfNeeded() async {
    if (!_agoraInitialized) {
      try {
        final success = await _agoraService.initialize();
        if (success) {
          _agoraInitialized = true;
        }
        return success;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  /// Start background operations after room join
  void _startBackgroundOperations(String roomId) {
    // Start periodic mute check
    _startMuteCheckTimer();

    // Start listening to room updates for real-time participant changes
    add(ListenToRoomUpdates(roomId: roomId));

    // Refresh rooms list to update participant counts (in background)
    Future.delayed(const Duration(milliseconds: 100), () {
      add(const RefreshAudioRooms());
    });
  }

  /// Clear cache and force refresh from server
  Future<void> clearCacheAndRefresh() async {
    try {
      // Clear Firebase cache
      await _repository.clearCache();

      // Force refresh from server
      add(const RefreshAudioRooms());

      if (_currentUser != null) {
        add(LoadUserAudioRooms(userId: _currentUser!.userId));
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Handle leaving audio room
  Future<void> _onLeaveAudioRoom(
    LeaveAudioRoom event,
    Emitter<AudioRoomsState> emit,
  ) async {
    final currentState = state;
    try {
      _isLeavingVoluntarily = true;
      emit(LeavingAudioRoom(roomId: event.roomId));

      // Leave Agora channel first to stop audio immediately
      if (_agoraInitialized && _currentChannelName != null) {
        debugPrint('🎤 [AudioRoomsBloc] Leaving Agora channel as part of room leave');
        try {
          await _agoraService.leaveChannel();
          _agoraService.clearCallbacks();
          _currentChannelName = null;
          _currentUid = null;
          _agoraUsers.clear();
          _networkQualities.clear();
        } catch (e) {
          debugPrint('🎤 [AudioRoomsBloc] ⚠️ Error leaving Agora channel: $e');
        }
      }

      await _repository
          .leaveRoom(
            roomId: event.roomId,
            userId: event.userId,
          )
          .timeout(const Duration(seconds: 5));

      // Optimistically remove the room if we are the creator (meaning it was closed)
      if (currentState is AudioRoomsLoaded) {
        final room =
            currentState.rooms.where((r) => r.id == event.roomId).firstOrNull;
        if (room != null && room.creatorId == event.userId) {
          final updatedRooms =
              currentState.rooms.where((r) => r.id != event.roomId).toList();
          final updatedUserRooms = currentState.userRooms
              .where((r) => r.id != event.roomId)
              .toList();
          emit(currentState.copyWith(
              rooms: updatedRooms, userRooms: updatedUserRooms));
        }
      }

      emit(AudioRoomLeft(roomId: event.roomId));

      // Add a delay to ensure Firestore indexes update before fetching the full list again
      await Future.delayed(const Duration(milliseconds: 1000));
      add(const RefreshAudioRooms());
    } catch (e) {
      // Even if it times out, we want to consider the local UI exit successful
      // so the user isn't trapped in a broken state.

      // Optimistically hide from local UI even on error to prevent zombie view for host
      if (currentState is AudioRoomsLoaded) {
        final room =
            currentState.rooms.where((r) => r.id == event.roomId).firstOrNull;
        if (room != null && room.creatorId == event.userId) {
          final updatedRooms =
              currentState.rooms.where((r) => r.id != event.roomId).toList();
          final updatedUserRooms = currentState.userRooms
              .where((r) => r.id != event.roomId)
              .toList();
          emit(currentState.copyWith(
              rooms: updatedRooms, userRooms: updatedUserRooms));
        }
      }

      emit(AudioRoomLeft(roomId: event.roomId));

      // We emit the error but don't prevent the exit
      debugPrint('⚠️ [AudioRoomsBloc] Error or timeout leaving room: $e');
    }
  }

  /// Handle deleting audio room
  Future<void> _onDeleteAudioRoom(
    DeleteAudioRoom event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // emit(DeletingAudioRoom(roomId: event.roomId));
      // await _repository.deleteRoom(event.roomId, event.userId);
      // emit(AudioRoomDeleted(roomId: event.roomId));
      // // Refresh rooms list
      // add(const RefreshAudioRooms());

      debugPrint(
          '🎯 [AudioRoomsBloc] Deletion attempt for room: ${event.roomId} blocked.');
      emit(const AudioRoomsError(
        message: 'Rooms cannot be deleted.',
        errorCode: 'DELETE_DISABLED',
      ));
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'DELETE_ROOM_FAILED',
      ));
    }
  }

  /// Handle updating room participant
  Future<void> _onUpdateRoomParticipant(
    UpdateRoomParticipant event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.updateParticipant(
        roomId: event.roomId,
        userId: event.userId,
        updatedParticipant: event.updatedParticipant,
      );

      // Refresh rooms list to show updated participant
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'UPDATE_PARTICIPANT_FAILED',
      ));
    }
  }

  /// Handle searching audio rooms
  Future<void> _onSearchAudioRooms(
    SearchAudioRooms event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      final currentState = state;

      if (currentState is AudioRoomsLoaded) {
        // Show loading state while searching
        emit(currentState.copyWith(isSearching: true));

        final searchResults = await _repository.searchRooms(event.query);

        emit(currentState.copyWith(
          searchResults: searchResults,
          isSearching: true,
          searchQuery: event.query,
        ));
      }
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'SEARCH_FAILED',
      ));
    }
  }

  /// Handle clearing search
  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<AudioRoomsState> emit,
  ) async {
    final currentState = state;

    if (currentState is AudioRoomsLoaded) {
      emit(currentState.copyWith(
        searchResults: [],
        isSearching: false,
        searchQuery: '',
      ));
    }
  }

  /// Handle updating room settings
  Future<void> _onUpdateRoomSettings(
    UpdateRoomSettings event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.updateRoomSettings(
        roomId: event.roomId,
        userId: event.userId,
        settings: event.settings,
      );

      // Refresh rooms list to show updated settings
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'UPDATE_SETTINGS_FAILED',
      ));
    }
  }

  /// Handle updating PK battle state
  Future<void> _onUpdatePKBattleState(
    UpdatePKBattleState event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.updatePKBattleState(
        roomId: event.roomId,
        userId: event.userId,
        pkBattleState: event.pkBattleState,
      );

      // Ensure _currentUser is initialized for other actions
      if (_currentUser == null) {
        final participant = event.pkBattleState.isActive
            ? null
            : _currentRoom?.participants
                .where((p) => p.userId == event.userId)
                .firstOrNull;
        _currentUser = User(
          userId: event.userId,
          fullname: participant?.userName ?? 'Host',
          photoUrl: participant?.userImageUrl ?? '',
        );
      }

      // Refresh rooms list to show updated state
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'UPDATE_PK_BATTLE_FAILED',
      ));
    }
  }

  /// Handle listening to room updates (real-time)
  Future<void> _onListenToRoomUpdates(
    ListenToRoomUpdates event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🎯 [AudioRoomsBloc] Starting to listen to room updates for: ${event.roomId}');
      await _singleRoomSubscription?.cancel();

      _singleRoomSubscription = _repository.getRoomStream(event.roomId).listen(
        (room) {
          debugPrint(
              '🎯 [AudioRoomsBloc] Room stream update received: ${room.participants.length} participants');
          add(RoomUpdatedFromStream(room: room));
        },
        onError: (error) {
          debugPrint('🎯 [AudioRoomsBloc] Room stream error: $error');
          emit(AudioRoomsError(
            message: error.toString(),
            errorCode: 'ROOM_STREAM_ERROR',
          ));
        },
      );
      debugPrint(
          '🎯 [AudioRoomsBloc] Successfully started listening to room updates');
    } catch (e) {
      debugPrint(
          '🎯 [AudioRoomsBloc] Error starting room updates listener: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'LISTEN_ROOM_FAILED',
      ));
    }
  }

  /// Handle stopping listening to room updates
  Future<void> _onStopListeningToRoomUpdates(
    StopListeningToRoomUpdates event,
    Emitter<AudioRoomsState> emit,
  ) async {
    await _singleRoomSubscription?.cancel();
    _singleRoomSubscription = null;
  }

  /// Handle room updated from stream
  Future<void> _onRoomUpdatedFromStream(
    RoomUpdatedFromStream event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint(
        '🎯 [AudioRoomsBloc] Emitting room update: ${event.room.name} with ${event.room.participants.length} participants');

    // Store current room for mute status checks
    _currentRoom = event.room;

    // Check for seat configuration mismatch and fix it (with debouncing)
    final expectedSeatCount = event.room.settings.roomMode.seatCount;
    final currentSeatCount = event.room.settings.seatConfiguration.length;

    if (expectedSeatCount != currentSeatCount) {
      // Cancel previous timer if exists
      _seatConfigDebounceTimer?.cancel();

      // Only fix if it's a different room or after a delay
      if (_lastSeatConfigRoomId != event.room.id) {
        _lastSeatConfigRoomId = event.room.id;
        add(FixSeatConfigurationMismatch(roomId: event.room.id));
      } else {
        // Debounce: wait 2 seconds before trying again for the same room
        _seatConfigDebounceTimer = Timer(const Duration(seconds: 2), () {
          add(FixSeatConfigurationMismatch(roomId: event.room.id));
        });
      }
    }

    // Check if current user was kicked, blocked, or if the room ended
    final currentUserId = _currentUser?.userId;
    if (currentUserId != null) {
      if (event.room.isActive == false &&
          event.room.creatorId != currentUserId) {
        debugPrint('🚪 [AudioRoomsBloc] ⚠️ Room was ended by the host!');
        add(const ForceLeaveAgoraChannel());
        emit(const AudioRoomsError(
          message: 'The live room has ended by the host.',
          errorCode: 'ROOM_ENDED',
        ));
        return;
      }

      // Enforce Room Ban
      if (event.room.isBanned) {
        debugPrint('🚪 [AudioRoomsBloc] ⚠️ Room is banned!');
        add(const ForceLeaveAgoraChannel());
        emit(const AudioRoomsError(
          message: 'This room has been banned.',
          errorCode: 'ROOM_BANNED',
        ));
        return;
      }

      // Enforce Mic Ban for current user
      final authUser = AuthController.instance.currentUser;
      final currentParticipant = event.room.participants
          .where((p) => p.userId == currentUserId)
          .firstOrNull;
      if (currentParticipant != null &&
          currentParticipant.isSeated &&
          currentParticipant.seatNumber != 0) {
        if (BanService.isMicBanned(authUser)) {
          debugPrint(
              '🚪 [AudioRoomsBloc] ⚠️ User Mic Banned, removing from seat...');
          add(RemoveParticipantFromSeat(
            roomId: event.room.id,
            hostId: event.room.creatorId,
            participantId: currentUserId,
            seatNumber: currentParticipant.seatNumber!,
          ));
        }
      }

      final isBlocked = event.room.settings.blockedUsers
          .any((b) => b.userId == currentUserId);

      bool wasKickedRecently = false;
      try {
        final removedUserList = event.room.removedUsers
            .where((u) => u['userId'] == currentUserId)
            .toList();
        if (removedUserList.isNotEmpty) {
          removedUserList.sort((a, b) {
            DateTime parseTime(dynamic val) {
              if (val == null) return DateTime.now();
              if (val is Timestamp) return val.toDate();
              if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
              if (val is String)
                return DateTime.tryParse(val) ?? DateTime.now();
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
            if (val is Timestamp)
              removedAt = val.toDate();
            else if (val is int)
              removedAt = DateTime.fromMillisecondsSinceEpoch(val);
            else if (val is String)
              removedAt = DateTime.tryParse(val);
            else if (val is DateTime) removedAt = val;
          }

          if (removedAt != null) {
            final now = DateTime.now();
            if (now.difference(removedAt).inHours < 24) {
              wasKickedRecently = true;
            }
          }
        }
      } catch (e) {
        debugPrint('🚪 [AudioRoomsBloc] Error checking removed users: $e');
      }

      if (!_isLeavingVoluntarily && (wasKickedRecently || isBlocked)) {
        debugPrint(
            '🚪 [AudioRoomsBloc] ⚠️ Current user was explicitly kicked or blocked from room!');
        debugPrint('🚪 [AudioRoomsBloc] 🔧 Force leaving Agora channel...');
        add(const ForceLeaveAgoraChannel());
        emit(const AudioRoomsError(
          message: 'You have been removed from this room by the host.',
          errorCode: 'KICKED',
        ));
        return; // Don't emit room update since user is no longer in room
      }
    }

    for (var participant in event.room.participants) {
      debugPrint(
          '🎯 [AudioRoomsBloc] Participant: ${participant.userName} (${participant.userId}) - Emoji: ${participant.activeEmojiUrl}');

      // Map participant to Agora UID for proper user identification
      final uid = _generateUid(participant.userId);
      _agoraService.mapUidToUser(
        uid,
        participant.userId,
        participant.userName,
        userImageUrl: participant.userImageUrl,
      );
    }
    emit(AudioRoomUpdated(room: event.room));
  }

  /// Generate consistent UID from user ID
  int _generateUid(String userId) {
    return userId.hashCode.abs() % 1000000; // Generate UID from user ID hash
  }

  /// Handle rooms list updated from stream
  Future<void> _onRoomsListUpdatedFromStream(
    RoomsListUpdatedFromStream event,
    Emitter<AudioRoomsState> emit,
  ) async {
    final currentState = state;
    List<AudioRoomV2> userRooms = [];

    // Maintain current userRooms if we have them, or compute them from the new list
    if (currentState is AudioRoomsLoaded) {
      if (_currentUser != null) {
        userRooms = event.rooms
            .where((room) =>
                room.creatorId == _currentUser!.userId ||
                room.participants.any((p) => p.userId == _currentUser!.userId))
            .toList();
      } else {
        userRooms = currentState.userRooms;
      }
      emit(currentState.copyWith(rooms: event.rooms, userRooms: userRooms));
    } else {
      if (_currentUser != null) {
        userRooms = event.rooms
            .where((room) =>
                room.creatorId == _currentUser!.userId ||
                room.participants.any((p) => p.userId == _currentUser!.userId))
            .toList();
      }
      emit(AudioRoomsLoaded(
        rooms: event.rooms,
        userRooms: userRooms,
      ));
    }
  }

  /// Start listening to all rooms stream (optional - for real-time updates)
  void startListeningToAllRooms() {
    _roomsStreamSubscription?.cancel();

    _roomsStreamSubscription = _repository.getRoomsStream().listen(
      (rooms) {
        if (!isClosed) {
          add(RoomsListUpdatedFromStream(rooms: rooms));
        }
      },
      onError: (error) {
        // Fallback to refresh on error
        if (!isClosed) {
          add(const RefreshAudioRooms());
        }
      },
    );
  }

  /// Stop listening to all rooms stream
  void stopListeningToAllRooms() {
    _roomsStreamSubscription?.cancel();
    _roomsStreamSubscription = null;
  }

  /// Handle updating seat configuration
  Future<void> _onUpdateSeatConfiguration(
    UpdateSeatConfiguration event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(AudioRoomsLoading());

      await _repository.updateSeatConfiguration(
        event.roomId,
        event.userId,
        event.seatCount,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Handle updating background image
  Future<void> _onUpdateBackgroundImage(
    UpdateBackgroundImage event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🖼️ [BLoC] Starting background image update for room: ${event.roomId}');
      emit(AudioRoomsLoading());

      String? imageUrl = event.imageUrl;

      // If image file is provided, upload it first
      if (event.imageFile != null) {
        debugPrint('🖼️ [BLoC] Uploading image file...');
        try {
          imageUrl = await _repository.uploadBackgroundImage(
            event.roomId,
            event.imageFile!,
          );
          debugPrint('🖼️ [BLoC] Image uploaded successfully: $imageUrl');
        } catch (uploadError) {
          debugPrint('🖼️ [BLoC] Upload failed: $uploadError');

          // Emit specific error for upload failures
          if (uploadError.toString().contains('timed out')) {
            emit(AudioRoomsError(
                message:
                    'Background upload timed out. Please check your internet connection and try again.'));
          } else if (uploadError.toString().contains('App Check')) {
            emit(AudioRoomsError(
                message:
                    'Upload failed due to security check. Please try again in a moment.'));
          } else {
            emit(AudioRoomsError(
                message:
                    'Failed to upload background image. Please try again.'));
          }
          return;
        }
      }

      // Update room with new background URL
      debugPrint('🖼️ [BLoC] Updating room background URL...');
      await _repository.updateBackgroundImage(
        event.roomId,
        event.userId,
        imageUrl,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      debugPrint('🖼️ [BLoC] Background image update completed successfully');

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      debugPrint('🖼️ [BLoC] Background image update failed: $e');
      emit(AudioRoomsError(
          message: 'Failed to update background: ${e.toString()}'));
    }
  }

  /// Handle updating room name
  Future<void> _onUpdateRoomName(
    UpdateRoomName event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '📝 [BLoC] Starting room name update for room: ${event.roomId}');
      emit(AudioRoomsLoading());

      await _repository.updateRoomName(
        event.roomId,
        event.userId,
        event.newName,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      debugPrint('📝 [BLoC] Room name update completed successfully');

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      debugPrint('📝 [BLoC] Room name update failed: $e');
      emit(AudioRoomsError(
          message: 'Failed to update room name: ${e.toString()}'));
    }
  }

  /// Handle updating room description
  Future<void> _onUpdateRoomDescription(
    UpdateRoomDescription event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '📝 [BLoC] Starting room description update for room: ${event.roomId}');
      emit(AudioRoomsLoading());

      await _repository.updateRoomDescription(
        event.roomId,
        event.userId,
        event.newDescription,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      debugPrint('📝 [BLoC] Room description update completed successfully');

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      debugPrint('📝 [BLoC] Room description update failed: $e');
      emit(AudioRoomsError(
          message: 'Failed to update room description: ${e.toString()}'));
    }
  }

  /// Handle updating room image
  Future<void> _onUpdateRoomImage(
    UpdateRoomImage event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🖼️ [BLoC] Starting room image update for room: ${event.roomId}');
      emit(AudioRoomsLoading());

      // Upload the image file
      debugPrint('🖼️ [BLoC] Uploading room image file...');
      String imageUrl;
      try {
        imageUrl = await _repository.uploadRoomImage(
          event.roomId,
          event.imageFile,
        );
        debugPrint('🖼️ [BLoC] Room image uploaded successfully: $imageUrl');
      } catch (uploadError) {
        debugPrint('🖼️ [BLoC] Upload failed: $uploadError');

        // Emit specific error for upload failures
        if (uploadError.toString().contains('timed out')) {
          emit(AudioRoomsError(
              message:
                  'Image upload timed out. Please check your internet connection and try again.'));
        } else if (uploadError.toString().contains('App Check')) {
          emit(AudioRoomsError(
              message:
                  'Upload failed due to security check. Please try again in a moment.'));
        } else {
          emit(AudioRoomsError(
              message: 'Failed to upload room image. Please try again.'));
        }
        return;
      }

      // Update room with new image URL
      debugPrint('🖼️ [BLoC] Updating room image URL...');
      await _repository.updateRoomImage(
        event.roomId,
        event.userId,
        imageUrl,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      debugPrint('🖼️ [BLoC] Room image update completed successfully');

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      debugPrint('🖼️ [BLoC] Room image update failed: $e');
      emit(AudioRoomsError(
          message: 'Failed to update room image: ${e.toString()}'));
    }
  }

  /// Handle updating room announcement
  Future<void> _onUpdateRoomAnnouncement(
    UpdateRoomAnnouncement event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(AudioRoomsLoading());

      await _repository.updateRoomAnnouncement(
        event.roomId,
        event.userId,
        event.announcement,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Handle updating music settings
  Future<void> _onUpdateMusicSettings(
    UpdateMusicSettings event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(AudioRoomsLoading());

      await _repository.updateMusicSettings(
        event.roomId,
        event.userId,
        event.musicEnabled,
        event.musicUrl,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Handle updating room mode
  Future<void> _onUpdateRoomMode(
    UpdateRoomMode event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(AudioRoomsLoading());

      await _repository.updateRoomMode(
        event.roomId,
        event.userId,
        event.roomMode,
      );

      // Get the updated room data and emit it
      final rooms = await _repository.getAllRooms();
      final updatedRoom = rooms.firstWhere((room) => room.id == event.roomId);
      emit(AudioRoomUpdated(room: updatedRoom));

      // Also refresh the rooms list
      add(const RefreshAudioRooms());
    } catch (e) {
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Handle sending chat message
  Future<void> _onSendChatMessage(
    SendChatMessage event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // Check if user is blocked from messaging
      if (_currentRoom != null) {
        final participant = _currentRoom!.participants
            .where((p) => p.userId == event.userId)
            .firstOrNull;
        if (participant != null && participant.isMessagingBlocked) {
          debugPrint(
              '✉️ [AudioRoomsBloc] ❌ Cannot send message - user is messaging blocked');
          emit(const AudioRoomsError(
            message: 'your message has been block for this room',
            errorCode: 'MESSAGING_BLOCKED',
          ));
          return;
        }
      }

      await _repository.sendChatMessage(
        event.roomId,
        event.userId,
        event.username,
        event.userAvatar,
        event.message,
      );
      debugPrint('💬 Chat message sent successfully');
    } catch (e) {
      emit(AudioRoomsError(message: e.toString()));
    }
  }

  /// Handle chat messages updated from stream
  Future<void> _onChatMessagesUpdated(
    ChatMessagesUpdated event,
    Emitter<AudioRoomsState> emit,
  ) async {
    emit(ChatMessagesLoaded(
      roomId: event.roomId,
      messages: event.messages,
    ));
  }

  /// Handle emoji chat messages updated from stream
  Future<void> _onEmojiChatMessagesUpdated(
    EmojiChatMessagesUpdated event,
    Emitter<AudioRoomsState> emit,
  ) async {
    emit(EmojiChatMessagesLoaded(
      roomId: event.roomId,
      messages: event.messages,
    ));
  }

  /// Handle toggle seat lock
  Future<void> _onToggleSeatLock(
    ToggleSeatLock event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🪑 [AudioRoomsBloc] Toggling seat ${event.seatNumber} lock to ${event.isLocked}');

      await _repository.toggleSeatLock(
        event.roomId,
        event.hostId,
        event.seatNumber,
        event.isLocked,
      );

      emit(SeatLockToggled(
        roomId: event.roomId,
        seatNumber: event.seatNumber,
        isLocked: event.isLocked,
      ));

      debugPrint('🪑 [AudioRoomsBloc] Seat lock toggled successfully');
    } catch (e) {
      debugPrint('🪑 [AudioRoomsBloc] Error toggling seat lock: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_SEAT_LOCK_FAILED',
      ));
    }
  }

  /// Handle toggle all seats lock
  Future<void> _onToggleAllSeatsLock(
    ToggleAllSeatsLock event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🪑 [AudioRoomsBloc] Toggling all seats lock to ${event.isLocked}');

      await _repository.toggleAllSeatsLock(
        event.roomId,
        event.hostId,
        event.isLocked,
      );

      debugPrint('🪑 [AudioRoomsBloc] All seats lock toggled successfully');
    } catch (e) {
      debugPrint('🪑 [AudioRoomsBloc] Error toggling all seats lock: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_ALL_SEATS_LOCK_FAILED',
      ));
    }
  }

  /// Handle move participant to seat
  Future<void> _onMoveParticipantToSeat(
    MoveParticipantToSeat event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      if (_currentRoom != null && _currentRoom!.isBanned) {
        emit(const AudioRoomsError(
          message: 'This room is currently banned.',
          errorCode: 'ROOM_BANNED',
        ));
        return;
      }

      if (event.toSeat != 0 && event.userId == _currentUser?.userId) {
        if (BanService.isMicBanned(AuthController.instance.currentUser)) {
          emit(const AudioRoomsError(
            message:
                'You are temporarily banned from taking a microphone seat.',
            errorCode: 'MIC_BANNED',
          ));
          return;
        }
      }

      debugPrint(
          '🪑 [AudioRoomsBloc] Moving participant ${event.userId} from seat ${event.fromSeat} to ${event.toSeat}');

      await _repository.moveParticipantToSeat(
        event.roomId,
        event.userId,
        event.fromSeat,
        event.toSeat,
      );

      // If the current user moved, sync their local microphone state immediately
      if (event.userId == _currentUser?.userId) {
        if (event.toSeat != 0) {
          add(const SetMicrophoneMute(muted: false));
        } else {
          add(const SetMicrophoneMute(muted: true));
        }
      }

      emit(ParticipantMovedToSeat(
        roomId: event.roomId,
        userId: event.userId,
        fromSeat: event.fromSeat,
        toSeat: event.toSeat,
      ));

      debugPrint('🪑 [AudioRoomsBloc] Participant moved successfully');
    } catch (e) {
      debugPrint('🪑 [AudioRoomsBloc] Error moving participant: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'MOVE_PARTICIPANT_FAILED',
      ));
    }
  }

  /// Handle remove participant from seat
  Future<void> _onRemoveParticipantFromSeat(
    RemoveParticipantFromSeat event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🪑 [AudioRoomsBloc] Removing participant ${event.participantId} from seat ${event.seatNumber}');

      await _repository.removeParticipantFromSeat(
        event.roomId,
        event.hostId,
        event.participantId,
        event.seatNumber,
      );

      // If the current user was removed from seat, mute their microphone
      if (event.participantId == _currentUser?.userId) {
        add(const SetMicrophoneMute(muted: true));
      }

      emit(ParticipantRemovedFromSeat(
        roomId: event.roomId,
        participantId: event.participantId,
        seatNumber: event.seatNumber,
      ));

      debugPrint(
          '🪑 [AudioRoomsBloc] Participant removed from seat successfully');
    } catch (e) {
      debugPrint(
          '🪑 [AudioRoomsBloc] Error removing participant from seat: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'REMOVE_FROM_SEAT_FAILED',
      ));
    }
  }

  /// Handle kick participant
  Future<void> _onKickParticipant(
    KickParticipant event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🚪 [AudioRoomsBloc] Kicking participant ${event.participantId} from room ${event.roomId}');

      // First, try to mute the participant in Agora before removing them from the room
      if (_agoraInitialized) {
        try {
          // Find the participant's Agora UID
          final participantUid = _generateUid(event.participantId);
          debugPrint(
              '🚪 [AudioRoomsBloc] Attempting to mute kicked participant in Agora (UID: $participantUid)');

          // We can't directly mute other users in Agora, but we can trigger their removal
          // by updating the room and letting the Agora service handle the user left event
          // The kicked participant should receive a room update and leave the Agora channel
        } catch (e) {
          debugPrint(
              '🚪 [AudioRoomsBloc] ⚠️ Failed to handle Agora muting: $e');
          // Continue with the kick even if Agora handling fails
        }
      }

      await _repository.kickParticipant(
        event.roomId,
        event.hostId,
        event.participantId,
        event.reason,
      );

      emit(ParticipantKicked(
        roomId: event.roomId,
        participantId: event.participantId,
        reason: event.reason,
      ));

      debugPrint('🚪 [AudioRoomsBloc] Participant kicked successfully');
    } catch (e) {
      debugPrint('🚪 [AudioRoomsBloc] Error kicking participant: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'KICK_PARTICIPANT_FAILED',
      ));
    }
  }

  /// Handle block participant
  Future<void> _onBlockParticipant(
    BlockParticipant event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🚫 [AudioRoomsBloc] Blocking participant ${event.participantId} from room ${event.roomId}');

      await _repository.blockParticipant(
        event.roomId,
        event.hostId,
        event.participantId,
        event.reason,
      );

      emit(ParticipantBlocked(
        roomId: event.roomId,
        participantId: event.participantId,
        reason: event.reason,
      ));

      debugPrint('🚫 [AudioRoomsBloc] Participant blocked successfully');
    } catch (e) {
      debugPrint('🚫 [AudioRoomsBloc] Error blocking participant: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'BLOCK_PARTICIPANT_FAILED',
      ));
    }
  }

  /// Handle unblock participant
  Future<void> _onUnblockParticipant(
    UnblockParticipant event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '✅ [AudioRoomsBloc] Unblocking participant ${event.participantId} from room ${event.roomId}');

      await _repository.unblockParticipant(
        event.roomId,
        event.hostId,
        event.participantId,
      );

      emit(ParticipantUnblocked(
        roomId: event.roomId,
        participantId: event.participantId,
      ));

      debugPrint('✅ [AudioRoomsBloc] Participant unblocked successfully');
    } catch (e) {
      debugPrint('✅ [AudioRoomsBloc] Error unblocking participant: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'UNBLOCK_PARTICIPANT_FAILED',
      ));
    }
  }

  // ========================================
  // AGORA EVENT HANDLERS
  // ========================================

  /// Setup Agora service callbacks
  void _setupAgoraCallbacks() {
    debugPrint('🎤 [AudioRoomsBloc] 🔗 Setting up Agora callbacks...');
    _agoraService.onUserJoined = (user) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserJoined callback triggered for user: ${user.uid}');
      add(AgoraUserJoined(user: user));
    };
    _agoraService.onUserLeft = (user) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserLeft callback triggered for UID: ${user.uid}');
      add(AgoraUserLeft(uid: user.uid));
    };
    _agoraService.onUserMuted = (uid, muted) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserMuted callback triggered for UID: $uid, muted: $muted');
      add(AgoraUserMuted(uid: uid, muted: muted));
    };
    _agoraService.onAudioVolumeIndication = (speakers, totalVolume) {
      final userVolumes = <int, int>{};
      for (final speaker in speakers) {
        int uid = speaker.uid ?? 0;
        // Map local user (0) to actual UID
        if (uid == 0 && _currentUid != null) {
          uid = _currentUid!;
        }
        userVolumes[uid] = speaker.volume ?? 0;
      }
      add(AudioVolumeIndication(
          userVolumes: userVolumes, totalVolume: totalVolume));
    };
    _agoraService.onConnectionStateChanged =
        (state) => add(AgoraConnectionStateChanged(state: state));
    _agoraService.onNetworkQuality =
        (quality) => add(NetworkQualityUpdate(quality: quality));
    _agoraService.onStats = (stats) => add(AgoraStatsUpdate(stats: stats));
    _agoraService.onTokenPrivilegeWillExpire =
        () => add(const TokenPrivilegeWillExpire());
    _agoraService.onAudioMixingFinished =
        () => add(const AudioMixingFinished());
    _agoraService.onAudioEffectFinished =
        (soundId) => add(AudioEffectFinished(soundId: soundId));
    _agoraService.onError = (message, code) =>
        add(AgoraErrorOccurred(message: message, code: code));
  }

  /// Initialize Agora service
  Future<void> _onInitializeAgora(
    InitializeAgora event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🎤 [AudioRoomsBloc] Initializing Agora for room: ${event.roomId}');
      emit(const AgoraInitializing());

      // Always call initialize - it safely reuses the engine if already alive
      // and re-registers event handlers for the new BLoC
      final success = await _agoraService.initialize();
      if (!success) {
        emit(const AgoraInitializationFailed(
            error: 'Failed to initialize Agora SDK'));
        return;
      }
      _agoraInitialized = true;

      // Re-setup BLoC-level callbacks to wire this BLoC to the singleton service
      _setupAgoraCallbacks();

      if (event.isVideo) {
        await _agoraService.enableVideo();
      } else {
        await _agoraService.disableVideo();
      }

      emit(const AgoraInitialized());
      debugPrint('🎤 [AudioRoomsBloc] Agora initialized successfully');
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Agora initialization error: $e');
      emit(AgoraInitializationFailed(error: e.toString()));
    }
  }

  /// Join Agora channel
  Future<void> _onJoinAgoraChannel(
    JoinAgoraChannel event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // Prevent duplicate join attempts
      if (_currentChannelName == event.channelName &&
          _currentUid == event.uid) {
        debugPrint(
            '🎤 [AudioRoomsBloc] ⚠️ Already joining/joined channel ${event.channelName} with UID ${event.uid}, skipping duplicate');
        return;
      }

      // Additional check: if we're already in the process of joining, skip
      if (state is AgoraChannelJoining) {
        debugPrint(
            '🎤 [AudioRoomsBloc] ⚠️ Already in process of joining channel, skipping duplicate');
        return;
      }

      debugPrint(
          '🎤 [AudioRoomsBloc] Joining Agora channel: ${event.channelName}');
      emit(AgoraChannelJoining(channelName: event.channelName));

      // Generate token if not provided
      String? token = event.token;
      if (token == null) {
        debugPrint(
            '🎫 [AudioRoomsBloc] Generating Firebase token for channel: ${event.channelName}');
        debugPrint('🎫 [AudioRoomsBloc] UID: ${event.uid}');

        token = await fetchAgoraToken(
          channelName: event.channelName,
          uid: event.uid,
        );

        if (token == null) {
          debugPrint(
              '🎫 [AudioRoomsBloc] ❌ Firebase token generation failed after all retry attempts');
          emit(AgoraChannelJoinFailed(
            channelName: event.channelName,
            error:
                'Unable to connect to audio service. Please check your authentication and try again.',
          ));
          return;
        } else {
          debugPrint(
              '🎫 [AudioRoomsBloc] ✅ Firebase token generated successfully');
          debugPrint('🎫 [AudioRoomsBloc] Token length: ${token.length}');
        }
      }

      // Join channel
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔧 Joining with mute status: ${event.isMuted}');
      final success = await _agoraService.joinChannel(
        channelName: event.channelName,
        uid: event.uid,
        userId: event.userId,
        userName: event.userName,
        token: token,
        isMuted: event.isMuted,
        isVideo: event.isVideo,
      );

      if (success) {
        _currentChannelName = event.channelName;
        _currentUid = event.uid;

        emit(AgoraChannelJoined(
          channelName: event.channelName,
          uid: event.uid,
          connectionState: _agoraService.connectionState,
          users: _agoraUsers,
          isMuted: _agoraService.isMuted,
          isSpeakerOn: _agoraService.isSpeakerOn,
          audioQuality: _agoraService.currentAudioQuality,
          audioEffect: _agoraService.currentAudioEffect,
          voiceChanger: _agoraService.currentVoiceChanger,
        ));

        debugPrint('🎤 [AudioRoomsBloc] Successfully joined Agora channel');
      } else {
        emit(AgoraChannelJoinFailed(
          channelName: event.channelName,
          error: 'Failed to join channel',
        ));
      }
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Join channel error: $e');
      emit(AgoraChannelJoinFailed(
        channelName: event.channelName,
        error: e.toString(),
      ));
    }
  }

  /// Leave Agora channel
  Future<void> _onLeaveAgoraChannel(
    LeaveAgoraChannel event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint('🎤 [AudioRoomsBloc] Leaving Agora channel');

      await _agoraService.leaveChannel();
      _agoraService.clearCallbacks();

      _currentChannelName = null;
      _currentUid = null;
      _agoraUsers.clear();
      _networkQualities.clear();

      emit(const AgoraChannelLeft());
      debugPrint('🎤 [AudioRoomsBloc] Left Agora channel successfully');
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Leave channel error: $e');
      emit(AgoraError(message: e.toString(), code: 'LEAVE_CHANNEL_FAILED'));
    }
  }

  /// Toggle microphone
  Future<void> _onToggleMicrophone(
    ToggleMicrophone event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // Check if current user is seated
      if (_currentUser != null && _currentRoom != null) {
        final currentParticipant = _currentRoom!.participants
            .where((p) => p.userId == _currentUser!.userId)
            .firstOrNull;

        if (currentParticipant != null && !currentParticipant.isSeated) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot toggle mic - user is not seated');
          emit(AgoraError(
            message: 'You must be seated to use the microphone',
            code: 'NOT_SEATED',
          ));
          return;
        }
        if (currentParticipant != null && currentParticipant.isMutedByAdmin) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot toggle mic - user is muted by admin');
          emit(AgoraError(
            message: 'You have been muted by an admin',
            code: 'MUTED_BY_ADMIN',
          ));
          return;
        }
      }

      // Allow users to toggle their microphone freely
      await _agoraService.toggleMute();
      final bool newMutedState = _agoraService.isMuted;
      emit(MicrophoneToggled(isMuted: newMutedState));

      // Sync mute state to Firestore
      if (_currentUser != null && _currentRoom != null) {
        final currentParticipant = _currentRoom!.participants
            .where((p) => p.userId == _currentUser!.userId)
            .firstOrNull;

        if (currentParticipant != null) {
          final updatedParticipant =
              currentParticipant.copyWith(isMuted: newMutedState);
          await _repository.updateParticipant(
            roomId: _currentRoom!.id,
            userId: _currentUser!.userId,
            updatedParticipant: updatedParticipant,
          );
        }
      }

      debugPrint(
          '🎤 [AudioRoomsBloc] Microphone toggled: ${newMutedState ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Toggle microphone error: $e');
      emit(AgoraError(message: e.toString(), code: 'TOGGLE_MIC_FAILED'));
    }
  }

  /// Set microphone mute
  Future<void> _onSetMicrophoneMute(
    SetMicrophoneMute event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // Check if current user is seated
      if (_currentUser != null && _currentRoom != null) {
        final currentParticipant = _currentRoom!.participants
            .where((p) => p.userId == _currentUser!.userId)
            .firstOrNull;

        // Only block if they are trying to UNMUTE while muted by an admin
        if (currentParticipant != null &&
            currentParticipant.isMutedByAdmin &&
            !event.muted) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot unmute mic - user is muted by admin');
          emit(AgoraError(
            message: 'You have been muted by an admin',
            code: 'MUTED_BY_ADMIN',
          ));
          return;
        }
      }

      // Allow users to set their microphone state freely
      await _agoraService.setMuted(event.muted);
      emit(MicrophoneToggled(isMuted: event.muted));

      // Sync mute state to Firestore
      if (_currentUser != null && _currentRoom != null) {
        final currentParticipant = _currentRoom!.participants
            .where((p) => p.userId == _currentUser!.userId)
            .firstOrNull;

        if (currentParticipant != null) {
          final updatedParticipant =
              currentParticipant.copyWith(isMuted: event.muted);
          await _repository.updateParticipant(
            roomId: _currentRoom!.id,
            userId: _currentUser!.userId,
            updatedParticipant: updatedParticipant,
          );
        }
      }

      debugPrint(
          '🎤 [AudioRoomsBloc] Microphone set to: ${event.muted ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Set microphone error: $e');
      emit(AgoraError(message: e.toString(), code: 'SET_MIC_FAILED'));
    }
  }

  /// Handle toggle admin mute
  Future<void> _onToggleAdminMute(
    ToggleAdminMute event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.toggleAdminMute(
          event.roomId, event.participantId, event.mutedByAdmin);
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_ADMIN_MUTE_FAILED',
      ));
    }
  }

  /// Handle toggle messaging block
  Future<void> _onToggleMessagingBlock(
    ToggleMessagingBlock event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.toggleMessagingBlock(
          event.roomId, event.participantId, event.isBlocked);
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_MESSAGING_BLOCK_FAILED',
      ));
    }
  }

  /// Handle toggle seat block
  Future<void> _onToggleSeatBlock(
    ToggleSeatBlock event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.toggleSeatBlock(
          event.roomId, event.participantId, event.isBlocked);
    } catch (e) {
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_SEAT_BLOCK_FAILED',
      ));
    }
  }

  /// Toggle room mute
  Future<void> _onToggleRoomMute(
    ToggleRoomMute event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.toggleRoomMute();
      emit(RoomMuteToggled(isRoomMuted: _agoraService.isRoomMuted));
      debugPrint(
          '🔇 [AudioRoomsBloc] Room Mute toggled: ${_agoraService.isRoomMuted ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('🔇 [AudioRoomsBloc] Toggle room mute error: $e');
      emit(AgoraError(message: e.toString(), code: 'TOGGLE_ROOM_MUTE_FAILED'));
    }
  }

  /// Set room mute
  Future<void> _onSetRoomMute(
    SetRoomMute event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.setRoomMuted(event.muted);
      emit(RoomMuteToggled(isRoomMuted: event.muted));
      debugPrint(
          '🔇 [AudioRoomsBloc] Room Mute set to: ${event.muted ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('🔇 [AudioRoomsBloc] Set room mute error: $e');
      emit(AgoraError(message: e.toString(), code: 'SET_ROOM_MUTE_FAILED'));
    }
  }

  /// Toggle speaker
  Future<void> _onToggleSpeaker(
    ToggleSpeaker event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.toggleSpeaker();
      emit(SpeakerToggled(isSpeakerOn: _agoraService.isSpeakerOn));
      debugPrint(
          '🔊 [AudioRoomsBloc] Speaker toggled: ${_agoraService.isSpeakerOn ? "on" : "off"}');
    } catch (e) {
      debugPrint('🔊 [AudioRoomsBloc] Toggle speaker error: $e');
      emit(AgoraError(message: e.toString(), code: 'TOGGLE_SPEAKER_FAILED'));
    }
  }

  /// Set audio quality
  Future<void> _onSetAudioQuality(
    SetAudioQuality event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.setAudioQuality(event.quality);
      emit(AudioQualityChanged(quality: event.quality));
      debugPrint(
          '🎵 [AudioRoomsBloc] Audio quality changed to: ${event.quality.displayName}');
    } catch (e) {
      debugPrint('🎵 [AudioRoomsBloc] Set audio quality error: $e');
      emit(AgoraError(message: e.toString(), code: 'SET_QUALITY_FAILED'));
    }
  }

  /// Apply audio effect
  Future<void> _onApplyAudioEffect(
    ApplyAudioEffect event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.setAudioEffect(event.effect);
      emit(AudioEffectApplied(effect: event.effect));
      debugPrint(
          '🎭 [AudioRoomsBloc] Audio effect applied: ${event.effect.displayName}');
    } catch (e) {
      debugPrint('🎭 [AudioRoomsBloc] Apply audio effect error: $e');
      emit(AgoraError(message: e.toString(), code: 'APPLY_EFFECT_FAILED'));
    }
  }

  /// Apply voice changer
  Future<void> _onApplyVoiceChanger(
    ApplyVoiceChanger event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.setVoiceChanger(event.changer);
      emit(VoiceChangerApplied(changer: event.changer));
      debugPrint(
          '🗣️ [AudioRoomsBloc] Voice changer applied: ${event.changer.displayName}');
    } catch (e) {
      debugPrint('🗣️ [AudioRoomsBloc] Apply voice changer error: $e');
      emit(AgoraError(message: e.toString(), code: 'APPLY_VOICE_FAILED'));
    }
  }

  /// Start background music
  Future<void> _onStartBackgroundMusic(
    StartBackgroundMusic event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      emit(const BackgroundMusicStarting());

      final success = await _agoraService.startAudioMixing(event.config);

      if (success) {
        emit(BackgroundMusicStarted(config: event.config));
        debugPrint(
            '🎵 [AudioRoomsBloc] Background music started: ${event.config.filePath}');
      } else {
        emit(const BackgroundMusicFailed(
            error: 'Failed to start background music'));
      }
    } catch (e) {
      debugPrint('🎵 [AudioRoomsBloc] Start background music error: $e');
      emit(BackgroundMusicFailed(error: e.toString()));
    }
  }

  /// Stop background music
  Future<void> _onStopBackgroundMusic(
    StopBackgroundMusic event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.stopAudioMixing();
      emit(const BackgroundMusicStopped());
      debugPrint('🎵 [AudioRoomsBloc] Background music stopped');
    } catch (e) {
      debugPrint('🎵 [AudioRoomsBloc] Stop background music error: $e');
      emit(AgoraError(message: e.toString(), code: 'STOP_MUSIC_FAILED'));
    }
  }

  /// Pause background music
  Future<void> _onPauseBackgroundMusic(
    PauseBackgroundMusic event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.pauseAudioMixing();
      emit(const BackgroundMusicPaused());
      debugPrint('🎵 [AudioRoomsBloc] Background music paused');
    } catch (e) {
      debugPrint('🎵 [AudioRoomsBloc] Pause background music error: $e');
      emit(AgoraError(message: e.toString(), code: 'PAUSE_MUSIC_FAILED'));
    }
  }

  /// Resume background music
  Future<void> _onResumeBackgroundMusic(
    ResumeBackgroundMusic event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _agoraService.resumeAudioMixing();
      emit(const BackgroundMusicResumed());
      debugPrint('🎵 [AudioRoomsBloc] Background music resumed');
    } catch (e) {
      debugPrint('🎵 [AudioRoomsBloc] Resume background music error: $e');
      emit(AgoraError(message: e.toString(), code: 'RESUME_MUSIC_FAILED'));
    }
  }

  /// Renew Agora token
  Future<void> _onRenewAgoraToken(
    RenewAgoraToken event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint('🎫 [AudioRoomsBloc] Renewing Agora token');
      emit(const TokenRenewing());

      final success = await _agoraService.renewToken(event.token);

      if (success) {
        emit(TokenRenewed(token: event.token));
        debugPrint('🎫 [AudioRoomsBloc] Token renewed successfully');
      } else {
        emit(const TokenRenewalFailed(error: 'Failed to renew token'));
      }
    } catch (e) {
      debugPrint('🎫 [AudioRoomsBloc] Token renewal error: $e');
      emit(TokenRenewalFailed(error: e.toString()));
    }
  }

  // ========================================
  // AGORA CALLBACK EVENT HANDLERS
  // ========================================

  /// Handle Agora user joined
  Future<void> _onAgoraUserJoined(
    AgoraUserJoined event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint('👤 [AudioRoomsBloc] Agora user joined: ${event.user.uid}');

    _agoraUsers.removeWhere((u) => u.uid == event.user.uid);
    _agoraUsers.add(event.user);

    emit(AgoraUserUpdated(user: event.user, action: 'joined'));
  }

  /// Handle Agora user left
  Future<void> _onAgoraUserLeft(
    AgoraUserLeft event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint('👤 [AudioRoomsBloc] Agora user left: ${event.uid}');

    final user = _agoraUsers.firstWhere(
      (u) => u.uid == event.uid,
      orElse: () => AgoraUser(
        uid: event.uid,
        userId: event.uid.toString(),
        userName: 'User ${event.uid}',
        lastSpokeAt: DateTime.now(),
      ),
    );

    _agoraUsers.removeWhere((u) => u.uid == event.uid);
    _networkQualities.remove(event.uid);

    emit(AgoraUserUpdated(user: user, action: 'left'));
  }

  /// Handle Agora user muted
  Future<void> _onAgoraUserMuted(
    AgoraUserMuted event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint(
        '🔇 [AudioRoomsBloc] Agora user ${event.muted ? "muted" : "unmuted"}: ${event.uid}');

    final userIndex = _agoraUsers.indexWhere((u) => u.uid == event.uid);
    if (userIndex != -1) {
      _agoraUsers[userIndex] =
          _agoraUsers[userIndex].copyWith(isMuted: event.muted);
      emit(AgoraUserUpdated(
        user: _agoraUsers[userIndex],
        action: event.muted ? 'muted' : 'unmuted',
      ));
    }
  }

  /// Handle audio volume indication
  Future<void> _onAudioVolumeIndication(
    AudioVolumeIndication event,
    Emitter<AudioRoomsState> emit,
  ) async {
    // Update user audio levels
    for (final entry in event.userVolumes.entries) {
      final uid = entry.key;
      final volume = entry.value;

      final userIndex = _agoraUsers.indexWhere((u) => u.uid == uid);
      if (userIndex != -1) {
        final isSpeaking = volume > 10;
        _agoraUsers[userIndex] = _agoraUsers[userIndex].copyWith(
          audioLevel: volume,
          isSpeaking: isSpeaking,
          lastSpokeAt:
              isSpeaking ? DateTime.now() : _agoraUsers[userIndex].lastSpokeAt,
        );
      }
    }

    emit(AudioVolumeUpdated(
      userVolumes: event.userVolumes,
      totalVolume: event.totalVolume,
    ));
  }

  /// Handle connection state changed
  Future<void> _onAgoraConnectionStateChanged(
    AgoraConnectionStateChanged event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint(
        '🔗 [AudioRoomsBloc] Connection state changed: ${event.state.displayName}');
    emit(AgoraConnectionUpdated(state: event.state));
  }

  /// Handle network quality update
  Future<void> _onNetworkQualityUpdate(
    NetworkQualityUpdate event,
    Emitter<AudioRoomsState> emit,
  ) async {
    _networkQualities[event.quality.uid] = event.quality;
    emit(NetworkQualityUpdated(quality: event.quality));
  }

  /// Handle Agora stats update
  Future<void> _onAgoraStatsUpdate(
    AgoraStatsUpdate event,
    Emitter<AudioRoomsState> emit,
  ) async {
    emit(AgoraStatsUpdated(stats: event.stats));
  }

  /// Handle token privilege will expire
  Future<void> _onTokenPrivilegeWillExpire(
    TokenPrivilegeWillExpire event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint('🎫 [AudioRoomsBloc] Token will expire soon, auto-renewing...');

    if (_currentChannelName != null && _currentUid != null) {
      try {
        final token = await fetchAgoraToken(
          channelName: _currentChannelName!,
          uid: _currentUid!,
        );

        if (token != null) {
          add(RenewAgoraToken(token: token));
        }
      } catch (e) {
        debugPrint('🎫 [AudioRoomsBloc] Auto token renewal failed: $e');
      }
    }
  }

  /// Handle audio mixing finished
  Future<void> _onAudioMixingFinished(
    AudioMixingFinished event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint('🎵 [AudioRoomsBloc] Audio mixing finished');
    emit(const BackgroundMusicStopped());
  }

  /// Handle audio effect finished
  Future<void> _onAudioEffectFinished(
    AudioEffectFinished event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint('🎭 [AudioRoomsBloc] Audio effect finished: ${event.soundId}');
  }

  /// Handle Agora error
  Future<void> _onAgoraErrorOccurred(
    AgoraErrorOccurred event,
    Emitter<AudioRoomsState> emit,
  ) async {
    debugPrint(
        '❌ [AudioRoomsBloc] Agora error: ${event.message} (${event.code})');
    emit(AgoraError(message: event.message, code: event.code));
  }

  // ========================================
  // HELPER METHODS
  // ========================================

  /// Fix seat configuration mismatch
  Future<void> _onFixSeatConfigurationMismatch(
    FixSeatConfigurationMismatch event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.fixSeatConfigurationMismatch(event.roomId);
    } catch (e) {
      debugPrint('🎭 [AudioRoomsBloc] ❌ Failed to fix seat configuration: $e');
      emit(AudioRoomsError(message: 'Failed to fix seat configuration: $e'));
    }
  }

  /// Force leave Agora channel (for kicked participants)
  Future<void> _onForceLeaveAgoraChannel(
    ForceLeaveAgoraChannel event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🚪 [AudioRoomsBloc] Force leaving Agora channel (participant was kicked)');

      if (_agoraInitialized) {
        await _agoraService.leaveChannel();
        _agoraInitialized = false;
        _currentChannelName = null;
        _currentUid = null;
        debugPrint('🚪 [AudioRoomsBloc] ✅ Forced to leave Agora channel');
      }
    } catch (e) {
      debugPrint(
          '🚪 [AudioRoomsBloc] ❌ Failed to force leave Agora channel: $e');
    }
  }

  /// Start periodic mute check timer
  void _startMuteCheckTimer() {
    _muteCheckTimer?.cancel();
    _muteCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkAndEnforceMuteStatus();
    });
    debugPrint('🎤 [AudioRoomsBloc] Started periodic mute check timer');
  }

  /// Check and enforce mute status from room data
  void _checkAndEnforceMuteStatus() {
    if (_currentUser == null || _currentRoom == null || !_agoraInitialized) {
      return;
    }

    try {
      final currentParticipant = _currentRoom!.participants
          .where((p) => p.userId == _currentUser!.userId)
          .firstOrNull;

      if (currentParticipant != null) {
        // Enforce Mic Ban Realtime
        final authUser = AuthController.instance.currentUser;
        if (BanService.isMicBanned(authUser) &&
            currentParticipant.isSeated &&
            currentParticipant.seatNumber != 0) {
          debugPrint(
              '🚪 [AudioRoomsBloc] ⚠️ User Mic Banned (Realtime), removing from seat...');
          add(RemoveParticipantFromSeat(
            roomId: _currentRoom!.id,
            hostId: _currentRoom!.creatorId,
            participantId: _currentUser!.userId,
            seatNumber: currentParticipant.seatNumber!,
          ));
        }

        if (currentParticipant.isMuted != _agoraService.isMuted) {
          debugPrint(
              '🎤 [AudioRoomsBloc] 🔄 Syncing local mute status to match room data: ${currentParticipant.isMuted}');
          add(SetMicrophoneMute(muted: currentParticipant.isMuted));
        }
      }
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] Error in mute check: $e');
    }
  }

  // Join Request Handlers
  Future<void> _onSendJoinRequest(
    SendJoinRequest event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.sendJoinRequest(event.roomId, event.userId);
    } catch (e) {
      debugPrint('Error sending join request: $e');
    }
  }

  Future<void> _onAcceptJoinRequest(
    AcceptJoinRequest event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      // 1. Remove from join requests
      await _repository.acceptJoinRequest(event.roomId, event.userId);

      // 2. Assign to an empty seat
      final currentState = state;
      if (currentState is AudioRoomJoined &&
          currentState.room.id == event.roomId) {
        final room = currentState.room;
        // Find an empty seat (excluding seat 1 which is the host)
        int targetSeat = 0;
        for (var seat in room.settings.seatConfiguration) {
          if (seat.seatNumber != 1 &&
              seat.occupiedBy == null &&
              !seat.isLocked) {
            targetSeat = seat.seatNumber;
            break;
          }
        }

        if (targetSeat != 0) {
          add(MoveParticipantToSeat(
            roomId: event.roomId,
            userId: event.userId,
            fromSeat: 0,
            toSeat: targetSeat,
          ));
        } else {
          debugPrint(
              '❌ [JoinRequest] No empty seats available for user ${event.userId}');
        }
      }
    } catch (e) {
      debugPrint('Error accepting join request: $e');
    }
  }

  Future<void> _onRejectJoinRequest(
    RejectJoinRequest event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      await _repository.rejectJoinRequest(event.roomId, event.userId);
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
    }
  }

  @override
  Future<void> close() async {
    await _userSubscription?.cancel();
    await _roomsStreamSubscription?.cancel();
    await _singleRoomSubscription?.cancel();
    _muteCheckTimer?.cancel();
    _seatConfigDebounceTimer?.cancel();

    // Cleanup Agora (Do NOT dispose the engine, just leave the channel and clear callbacks)
    if (_agoraInitialized) {
      // The engine is a singleton, we want to keep it alive for faster room switching
      // The actual leave channel is already handled by LeaveAgoraChannel event
      _agoraService.clearCallbacks();
    }

    _repository.dispose();
    return super.close();
  }
}
