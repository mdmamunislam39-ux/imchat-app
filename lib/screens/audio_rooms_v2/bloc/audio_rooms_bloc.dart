import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
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
import 'package:chat_messenger/services/background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:chat_messenger/services/rtc_engine_manager.dart';
import 'package:chat_messenger/services/livekit_service.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/services/live_notification_service.dart';

/// BLoC for managing Audio Rooms v2 with Agora & LiveKit Integration
class AudioRoomsBloc extends Bloc<AudioRoomsEvent, AudioRoomsState> {
  final AudioRoomsRepository _repository;
  final AgoraService _agoraService = AgoraService();
  AgoraService get agoraService => _agoraService;

  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  ap.AudioPlayer get audioPlayer => _audioPlayer;

  bool get isLiveKit =>
      Get.isRegistered<RtcEngineManager>() &&
      Get.find<RtcEngineManager>().isLiveKitActive;

  LiveKitService get _livekitService {
    if (!Get.isRegistered<LiveKitService>()) {
      Get.put(LiveKitService(), permanent: true);
    }
    return Get.find<LiveKitService>();
  }

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
  final Map<int, Timer> _offlineUserTimers = {};

  // Periodic mute check timer
  Timer? _muteCheckTimer;

  // Seat configuration debounce
  Timer? _seatConfigDebounceTimer;
  String? _lastSeatConfigRoomId;
  bool _isLeavingVoluntarily = false;
  DateTime? _lastLocalMuteChangeTime;

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
    on<ToggleAllMicsMute>(_onToggleAllMicsMute);
    on<ToggleAllCommentsBan>(_onToggleAllCommentsBan);
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

      // Trigger follow notification: notify active followers that the user has opened a voice room
      LiveNotificationService.notifyActiveFollowersOnLive(
        creatorId: event.creatorId,
        creatorName: event.creatorName,
        creatorAvatar: event.creatorImageUrl ?? '',
        roomId: room.id,
        roomName: room.name,
      );

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

      // Trigger follow notification: notify active followers that this user joined / is live in this room
      LiveNotificationService.notifyActiveFollowersOnLive(
        creatorId: event.userId,
        creatorName: event.userName,
        creatorAvatar: event.userImageUrl ?? '',
        roomId: event.roomId,
        roomName: updatedRoom.name,
      );

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
    if (isLiveKit) return true;
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

    // Start background persistent notification for audio room keep-alive & minimize
    try {
      BackgroundService().startCallService(
        title: 'VoiceRoom is running now',
        content: 'click back to the VoiceRoom',
      );
    } catch (_) {}

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

      // Leave RTC channel first to stop audio immediately
      if (_livekitService.isConnected.value) {
        try {
          await _livekitService.leaveRoom();
        } catch (e) {
          debugPrint('🎤 [AudioRoomsBloc] ⚠️ Error leaving LiveKit room: $e');
        }
      }
      if (_agoraInitialized && _currentChannelName != null) {
        final leavingChannel = _currentChannelName;
        debugPrint(
            '🎤 [AudioRoomsBloc] Leaving Agora channel as part of room leave: $leavingChannel');
        try {
          await _agoraService.leaveChannelAndRelease(channelName: leavingChannel);
          _agoraService.clearCallbacks(channelName: leavingChannel, owner: this);
          _currentChannelName = null;
          _currentUid = null;
          _agoraUsers.clear();
          _networkQualities.clear();
        } catch (e) {
          debugPrint('🎤 [AudioRoomsBloc] ⚠️ Error leaving Agora channel: $e');
        }
      }

      // Stop background service when leaving room only if no other channel is active
      if (_agoraService.currentChannelId == null && !_livekitService.isConnected.value) {
        try {
          await BackgroundService().stopService();
        } catch (_) {}
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
      if (_currentRoom != null && _currentRoom!.id == event.roomId) {
        final locallyUpdatedRoom = _currentRoom!.copyWith(settings: event.settings);
        _currentRoom = locallyUpdatedRoom;
        emit(AudioRoomUpdated(room: locallyUpdatedRoom));
      }

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
    final oldRoom = _currentRoom;
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

      // Only treat as kicked if the user was actively a participant before,
      // and is now removed from participants list
      final wasParticipantBefore =
          oldRoom != null && oldRoom.isParticipant(currentUserId);
      final isParticipantNow = event.room.isParticipant(currentUserId);

      bool wasKickedJustNow = false;
      if (wasParticipantBefore && !isParticipantNow) {
        wasKickedJustNow = true;
      }

      if (!_isLeavingVoluntarily && (wasKickedJustNow || isBlocked)) {
        debugPrint(
            '🚪 [AudioRoomsBloc] ⚠️ Current user was explicitly kicked or blocked from room!');
        debugPrint('🚪 [AudioRoomsBloc] 🔧 Force leaving Agora channel...');
        add(const ForceLeaveAgoraChannel());
        emit(AudioRoomsError(
          message: isBlocked
              ? 'You are blocked from entering this room.'
              : 'You have been removed from this room by the host.',
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

    // Synchronize Agora role and microphone state for current user only within the active channel
    if (currentUserId != null && _agoraInitialized && _currentChannelName == event.room.id) {
      final bool isSameRoom = oldRoom != null && oldRoom.id == event.room.id;
      if (isSameRoom) {
        final oldParticipant = oldRoom.participants
            .where((p) => p.userId == currentUserId)
            .firstOrNull;
        final newParticipant = event.room.participants
            .where((p) => p.userId == currentUserId)
            .firstOrNull;

        final bool wasSeated =
            (oldParticipant?.isSeated ?? false) ||
            (oldParticipant?.isSpeaker ?? false) ||
            (oldParticipant?.seatNumber != null && oldParticipant!.seatNumber! >= 0);
        final bool isNowSeated =
            (newParticipant?.isSeated ?? false) ||
            (newParticipant?.isSpeaker ?? false) ||
            (newParticipant?.seatNumber != null && newParticipant!.seatNumber! >= 0);

        if (isNowSeated && !wasSeated) {
          debugPrint(
              '🎤 [AudioRoomsBloc] 🪑 User moved to seat via remote update -> Switching Agora role to Broadcaster');
          // When user moves to a seat, they are UNMUTED by default unless muted by admin
          bool shouldBeMuted = newParticipant?.isMutedByAdmin == true;

          if (!shouldBeMuted) {
            try {
              final micStatus = await Permission.microphone.status;
              if (!micStatus.isGranted) {
                final req = await Permission.microphone.request();
                if (!req.isGranted) {
                  shouldBeMuted = true;
                }
              }
            } catch (e) {
              shouldBeMuted = true;
              debugPrint('🎤 [AudioRoomsBloc] Error requesting mic permission: $e');
            }
          }

          if (!isLiveKit) {
            await _agoraService.setClientRole(ClientRoleType.clientRoleBroadcaster, isMuted: shouldBeMuted);
          }
          add(SetMicrophoneMute(muted: shouldBeMuted));
        } else if (!isNowSeated && wasSeated) {
          debugPrint(
              '🎤 [AudioRoomsBloc] 🪑 User removed from seat via remote update -> Switching role to Audience');
          if (!isLiveKit) {
            await _agoraService.setClientRole(ClientRoleType.clientRoleAudience, isMuted: true);
          }
          add(const SetMicrophoneMute(muted: true));
        } else if (isNowSeated && oldParticipant != null && newParticipant != null) {
          // Already seated: ONLY synchronize if Admin changed the mute status remotely
          if (oldParticipant.isMutedByAdmin != newParticipant.isMutedByAdmin) {
            debugPrint(
                '🎤 [AudioRoomsBloc] 🪑 Remote admin mute sync for seated user -> mutedByAdmin: ${newParticipant.isMutedByAdmin}');
            final bool targetMute = newParticipant.isMutedByAdmin;
            if (!isLiveKit) {
              await _agoraService.setMuted(targetMute);
            }
            add(SetMicrophoneMute(muted: targetMute));
          }
        }
      }
    }

    emit(AudioRoomUpdated(room: event.room));
  }

  /// Generate consistent UID from user ID
  int _generateUid(String userId) {
    return generateAgoraUid(userId);
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
                room.category != 'Live' &&
                (room.creatorId == _currentUser!.userId ||
                room.participants.any((p) => p.userId == _currentUser!.userId)))
            .toList();
      } else {
        userRooms = currentState.userRooms.where((r) => r.category != 'Live').toList();
      }
      emit(currentState.copyWith(rooms: event.rooms, userRooms: userRooms));
    } else {
      if (_currentUser != null) {
        userRooms = event.rooms
            .where((room) =>
                room.category != 'Live' &&
                (room.creatorId == _currentUser!.userId ||
                room.participants.any((p) => p.userId == _currentUser!.userId)))
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

  /// Handle toggle all mics mute
  Future<void> _onToggleAllMicsMute(
    ToggleAllMicsMute event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🎙️ [AudioRoomsBloc] Toggling all mics mute to ${event.muteAll}');

      await _repository.toggleAllMicsMute(
        event.roomId,
        event.hostId,
        event.muteAll,
      );

      debugPrint('🎙️ [AudioRoomsBloc] All mics mute toggled successfully');
    } catch (e) {
      debugPrint('🎙️ [AudioRoomsBloc] Error toggling all mics mute: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_ALL_MICS_MUTE_FAILED',
      ));
    }
  }

  /// Handle toggle all comments ban
  Future<void> _onToggleAllCommentsBan(
    ToggleAllCommentsBan event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '💬 [AudioRoomsBloc] Toggling all comments ban to ${event.banAll}');

      await _repository.toggleAllCommentsBan(
        event.roomId,
        event.hostId,
        event.banAll,
      );

      debugPrint('💬 [AudioRoomsBloc] All comments ban toggled successfully');
    } catch (e) {
      debugPrint('💬 [AudioRoomsBloc] Error toggling all comments ban: $e');
      emit(AudioRoomsError(
        message: e.toString(),
        errorCode: 'TOGGLE_ALL_COMMENTS_BAN_FAILED',
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

      if (event.toSeat >= 0 && event.userId == _currentUser?.userId) {
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
        if (event.toSeat >= 0) {
          // Check if participant is muted by admin
          final existingParticipant = _currentRoom?.participants
              .where((p) => p.userId == event.userId)
              .firstOrNull;
          final bool isMutedByAdmin = existingParticipant?.isMutedByAdmin == true;
          // When user joins a seat, they are UNMUTED by default unless muted by admin
          bool targetMuted = isMutedByAdmin;

          if (!targetMuted) {
            try {
              final micStatus = await Permission.microphone.status;
              if (!micStatus.isGranted) {
                final req = await Permission.microphone.request();
                if (!req.isGranted) {
                  targetMuted = true;
                }
              }
            } catch (_) {
              targetMuted = false;
            }
          }

          // Update in-memory room participant immediately to prevent race condition with Firestore stream
          if (_currentRoom != null) {
            final updatedParticipants = _currentRoom!.participants.map((p) {
              if (p.userId == event.userId) {
                return p.copyWith(
                  seatNumber: event.toSeat,
                  isSeated: true,
                  isSpeaker: true,
                  isMuted: targetMuted,
                );
              }
              return p;
            }).toList();
            _currentRoom = _currentRoom!.copyWith(participants: updatedParticipants);
          }

          if (!isLiveKit) {
            await _agoraService.setClientRole(ClientRoleType.clientRoleBroadcaster, isMuted: targetMuted);
          }
          add(SetMicrophoneMute(muted: targetMuted));
        } else {
          // Leaving seat: revert to Audience
          if (_currentRoom != null) {
            final updatedParticipants = _currentRoom!.participants.map((p) {
              if (p.userId == event.userId) {
                return p.copyWith(
                  clearSeatNumber: true,
                  isSeated: false,
                  isSpeaker: false,
                  isMuted: true,
                );
              }
              return p;
            }).toList();
            _currentRoom = _currentRoom!.copyWith(participants: updatedParticipants);
          }

          if (!isLiveKit) {
            await _agoraService.setClientRole(ClientRoleType.clientRoleAudience, isMuted: true);
          }
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

      // If the current user was removed from seat, mute their microphone and revert to audience role
      if (event.participantId == _currentUser?.userId) {
        if (_currentRoom != null) {
          final updatedParticipants = _currentRoom!.participants.map((p) {
            if (p.userId == event.participantId) {
              return p.copyWith(
                clearSeatNumber: true,
                isSeated: false,
                isMuted: true,
              );
            }
            return p;
          }).toList();
          _currentRoom = _currentRoom!.copyWith(participants: updatedParticipants);
        }
        if (!isLiveKit) {
          await _agoraService.setClientRole(ClientRoleType.clientRoleAudience, isMuted: true);
        }
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
    debugPrint('🎤 [AudioRoomsBloc] 🔗 Setting up Agora callbacks (owner: $hashCode)...');
    _agoraService.setOwner(this);
    _agoraService.onUserJoined = (user) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserJoined callback triggered for user: ${user.uid}');
      AgoraUser resolvedUser = user;
      if (_currentRoom != null) {
        AudioRoomParticipant? participant;
        for (final p in _currentRoom!.participants) {
          if (generateAgoraUid(p.userId) == user.uid) {
            participant = p;
            break;
          }
        }
        if (participant != null) {
          resolvedUser = user.copyWith(
            userId: participant.userId,
            userName: participant.userName,
          );
        } else if (_currentRoom!.creatorId.isNotEmpty &&
            generateAgoraUid(_currentRoom!.creatorId) == user.uid) {
          resolvedUser = user.copyWith(
            userId: _currentRoom!.creatorId,
            userName: _currentRoom!.creatorName,
          );
        }
      }
      if (!isClosed) add(AgoraUserJoined(user: resolvedUser));
    };
    _agoraService.onUserLeft = (user) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserLeft callback triggered for UID: ${user.uid}');
      if (!isClosed) add(AgoraUserLeft(uid: user.uid));
    };
    _agoraService.onUserMuted = (uid, muted) {
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔗 onUserMuted callback triggered for UID: $uid, muted: $muted');
      if (!isClosed) add(AgoraUserMuted(uid: uid, muted: muted));
    };
    bool lastHadSpeaking = false;
    DateTime lastNetworkQualityTime = DateTime.fromMillisecondsSinceEpoch(0);
    DateTime lastStatsTime = DateTime.fromMillisecondsSinceEpoch(0);

    _agoraService.onAudioVolumeIndication = (speakers, totalVolume) {
      if (isClosed) return;

      final userVolumes = <int, int>{};
      bool hasAnySpeaking = false;

      for (final speaker in speakers) {
        final int uid = speaker.uid ?? 0;
        final int volume = speaker.volume ?? 0;
        userVolumes[uid] = volume;
        if (volume > 0) {
          hasAnySpeaking = true;
        }
        // Ensure local user (0) is also accessible via their resolved Agora UID
        if (uid == 0 && _currentUid != null) {
          userVolumes[_currentUid!] = volume;
        }
      }

      if (!hasAnySpeaking && totalVolume > 0) {
        hasAnySpeaking = true;
      }

      // Continuous silence: do not flood BLoC with duplicate silence events
      if (!hasAnySpeaking && !lastHadSpeaking) {
        return;
      }
      lastHadSpeaking = hasAnySpeaking;

      add(AudioVolumeIndication(
          userVolumes: userVolumes, totalVolume: totalVolume));
    };
    _agoraService.onConnectionStateChanged =
        (state) {
      if (!isClosed) add(AgoraConnectionStateChanged(state: state));
    };
    _agoraService.onNetworkQuality = (quality) {
      if (isClosed) return;
      final now = DateTime.now();
      if (now.difference(lastNetworkQualityTime).inSeconds >= 4) {
        lastNetworkQualityTime = now;
        add(NetworkQualityUpdate(quality: quality));
      }
    };
    _agoraService.onStats = (stats) {
      if (isClosed) return;
      final now = DateTime.now();
      if (now.difference(lastStatsTime).inSeconds >= 5) {
        lastStatsTime = now;
        add(AgoraStatsUpdate(stats: stats));
      }
    };
    _agoraService.onTokenPrivilegeWillExpire =
        () {
      if (!isClosed) add(const TokenPrivilegeWillExpire());
    };
    _agoraService.onAudioMixingFinished =
        () {
      if (!isClosed) add(const AudioMixingFinished());
    };
    _agoraService.onAudioEffectFinished =
        (soundId) {
      if (!isClosed) add(AudioEffectFinished(soundId: soundId));
    };
    _agoraService.onRemoteAudioStateChanged = (remoteUid, state, reason) {
      debugPrint('🎤 [AudioRoomsBloc] 🔊 Remote audio state for UID $remoteUid: $state ($reason)');
    };
    _agoraService.onError = (message, code) {
      if (!isClosed) add(AgoraErrorOccurred(message: message, code: code));
    };
  }

  /// Initialize Agora service
  Future<void> _onInitializeAgora(
    InitializeAgora event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      debugPrint(
          '🎤 [AudioRoomsBloc] Initializing RTC (LiveKit/Agora) for room: ${event.roomId}');
      emit(const AgoraInitializing());

      if (isLiveKit) {
        debugPrint('🎤 [AudioRoomsBloc] LiveKit is active engine for Audio Rooms v2 - bypassing Agora init');
        emit(const AgoraInitialized());
        return;
      }

      // Always call initialize - it safely reuses the engine if already alive
      // and re-registers event handlers for the new BLoC
      bool success = await _agoraService.initialize();
      if (!success) {
        debugPrint('🎤 [AudioRoomsBloc] First initialization attempt failed, retrying with fallback AppID...');
        await Future.delayed(const Duration(milliseconds: 200));
        success = await _agoraService.initialize('c74eafbb98784225bae6be9b7e7f6225');
      }

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
      debugPrint('🎤 [AudioRoomsBloc] RTC initialized successfully');
    } catch (e) {
      debugPrint('🎤 [AudioRoomsBloc] RTC initialization notice: $e');
      if (isLiveKit) {
        emit(const AgoraInitialized());
      } else {
        emit(AgoraInitializationFailed(error: e.toString()));
      }
    }
  }

  /// Join Agora channel
  Future<void> _onJoinAgoraChannel(
    JoinAgoraChannel event,
    Emitter<AudioRoomsState> emit,
  ) async {
    try {
      int uidToUse = event.uid;
      if (uidToUse == 0 && event.userId.isNotEmpty) {
        uidToUse = generateAgoraUid(event.userId);
        debugPrint('🎤 [AudioRoomsBloc] 🔧 Auto-assigned non-zero UID: $uidToUse for ${event.userId}');
      }

      // If currently on a different channel, cleanly release it first before joining the new one
      if (_currentChannelName != null && _currentChannelName != event.channelName) {
        debugPrint(
            '🎤 [AudioRoomsBloc] 🔄 Switching channels: releasing $_currentChannelName before joining ${event.channelName}');
        if (_livekitService.isConnected.value) {
          await _livekitService.leaveRoom();
        }
        await _agoraService.leaveChannelAndRelease(channelName: _currentChannelName);
        _agoraService.clearCallbacks(channelName: _currentChannelName, owner: this);
        _currentChannelName = null;
        _currentUid = null;
        _agoraUsers.clear();
        _networkQualities.clear();
      }

      // Prevent duplicate join attempts if already connected to the same channel
      if (_currentChannelName == event.channelName &&
          _currentUid == uidToUse &&
          (_agoraService.isConnected || _livekitService.isConnected.value)) {
        debugPrint(
            '🎤 [AudioRoomsBloc] ⚠️ Already joined and active on channel ${event.channelName} with UID $uidToUse, skipping duplicate');
        return;
      }

      // Additional check: if we're already in the process of joining, skip
      if (state is AgoraChannelJoining) {
        debugPrint(
            '🎤 [AudioRoomsBloc] ⚠️ Already in process of joining channel, skipping duplicate');
        return;
      }

      debugPrint(
          '🎤 [AudioRoomsBloc] Joining RTC channel: ${event.channelName} with UID: $uidToUse');
      emit(AgoraChannelJoining(channelName: event.channelName));

      // 1. Dual-Engine Check: Try LiveKit first if enabled in Admin Panel
      if (isLiveKit) {
        try {
          final serverUrl = Get.isRegistered<GlobalSettingsService>()
              ? Get.find<GlobalSettingsService>().livekitServerUrl.value.trim()
              : 'https://live.imchat.tech';
          final identity = event.userId.isNotEmpty ? event.userId : uidToUse.toString();
          final userName = event.userName.isNotEmpty ? event.userName : 'User';

          debugPrint('🌐 [AudioRoomsBloc] Connecting to Audio Room via LiveKit ($serverUrl)...');
          final lkToken = await _livekitService.generateToken(
            roomName: event.channelName,
            identity: identity,
            userName: userName,
          );

          _livekitService.onActiveSpeakersChanged = (speakers) {
            if (!isClosed) {
              final Map<int, int> userVolumes = {};
              int totalVol = 0;
              for (final speakerIdentity in speakers) {
                final sUid = generateAgoraUid(speakerIdentity);
                userVolumes[sUid] = 100;
                totalVol += 100;
              }
              add(AudioVolumeIndication(userVolumes: userVolumes, totalVolume: totalVol));
            }
          };

          _livekitService.onParticipantJoined = (participant) {
            if (!isClosed) {
              final pUid = generateAgoraUid(participant.identity);
              final agoraUser = AgoraUser(
                uid: pUid,
                userId: participant.identity,
                userName: participant.name.isNotEmpty ? participant.name : 'User $pUid',
                isMuted: false,
                lastSpokeAt: DateTime.now(),
              );
              add(AgoraUserJoined(user: agoraUser));
            }
          };

          _livekitService.onParticipantLeft = (participant) {
            if (!isClosed) {
              final pUid = generateAgoraUid(participant.identity);
              add(AgoraUserLeft(uid: pUid));
            }
          };

          final bool lkSuccess = await _livekitService.connectToRoom(
            url: serverUrl,
            token: lkToken,
            enableAudio: true,
            enableVideo: event.isVideo,
            autoPublishMic: event.isSeated && !event.isMuted,
          );

          if (lkSuccess) {
            _currentChannelName = event.channelName;
            _currentUid = uidToUse;

            try {
              await BackgroundService().startCallService(
                title: 'VoiceRoom is running now',
                content: 'click back to the VoiceRoom',
              );
            } catch (_) {}

            emit(AgoraChannelJoined(
              channelName: event.channelName,
              uid: uidToUse,
              connectionState: AgoraConnectionState.connected,
              users: _agoraUsers,
              isMuted: event.isMuted,
              isSpeakerOn: true,
              audioQuality: AudioQuality.high,
              audioEffect: AudioEffect.none,
              voiceChanger: VoiceChanger.none,
            ));
            debugPrint('🌐 [AudioRoomsBloc] ✅ Successfully joined Audio Room via LiveKit WebRTC');
            return;
          } else {
            debugPrint('🌐 [AudioRoomsBloc] ❌ LiveKit connection failed');
            emit(AgoraChannelJoinFailed(
              channelName: event.channelName,
              error: 'Network connection issue',
            ));
            return;
          }
        } catch (lkErr) {
          debugPrint('🌐 [AudioRoomsBloc] ❌ LiveKit error: $lkErr');
          emit(AgoraChannelJoinFailed(
            channelName: event.channelName,
            error: 'Network connection issue',
          ));
          return;
        }
      }

      // 2. Agora Engine Execution (100% untouched original logic)
      // Generate token if not provided
      String? token = event.token;
      if (token == null) {
        debugPrint(
            '🎫 [AudioRoomsBloc] Generating Firebase token for channel: ${event.channelName}');
        debugPrint('🎫 [AudioRoomsBloc] UID: $uidToUse');

        token = await fetchAgoraToken(
          channelName: event.channelName,
          uid: uidToUse,
        );

        if (token == null) {
          debugPrint(
              '🎫 [AudioRoomsBloc] ❌ Firebase token generation failed, attempting fallback join...');
          _setupAgoraCallbacks();
          final fallbackSuccess = await _agoraService.joinChannel(
            channelName: event.channelName,
            uid: uidToUse,
            userId: event.userId,
            userName: event.userName,
            token: '',
            isMuted: event.isMuted,
            isVideo: event.isVideo,
            isSeated: event.isSeated,
          );

          if (fallbackSuccess) {
            debugPrint('🎫 [AudioRoomsBloc] ✅ Channel joined via fallback without token');
            return;
          }

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

      // Always ensure callbacks are registered before joining channel
      _setupAgoraCallbacks();

      // Join channel
      debugPrint(
          '🎤 [AudioRoomsBloc] 🔧 Joining with mute status: ${event.isMuted}, isSeated: ${event.isSeated}');
      bool success = await _agoraService.joinChannel(
        channelName: event.channelName,
        uid: uidToUse,
        userId: event.userId,
        userName: event.userName,
        token: token,
        isMuted: event.isMuted,
        isVideo: event.isVideo,
        isSeated: event.isSeated,
      );

      if (!success) {
        debugPrint('🎤 [AudioRoomsBloc] ⚠️ Initial joinChannel failed, retrying with fresh engine init...');
        await _agoraService.initialize();
        _setupAgoraCallbacks();
        final retryToken = await fetchAgoraToken(channelName: event.channelName, uid: uidToUse);
        success = await _agoraService.joinChannel(
          channelName: event.channelName,
          uid: uidToUse,
          userId: event.userId,
          userName: event.userName,
          token: retryToken ?? token,
          isMuted: event.isMuted,
          isVideo: event.isVideo,
          isSeated: event.isSeated,
        );
      }

      if (success) {
        _currentChannelName = event.channelName;
        _currentUid = uidToUse;

        emit(AgoraChannelJoined(
          channelName: event.channelName,
          uid: uidToUse,
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
    final leavingChannel = event.channelName ?? _currentChannelName;
    try {
      debugPrint('🎤 [AudioRoomsBloc] Leaving RTC channel: $leavingChannel');

      if (_livekitService.isConnected.value || isLiveKit) {
        await _livekitService.leaveRoom();
      } else {
        await _agoraService.leaveChannelAndRelease(channelName: leavingChannel);
        _agoraService.clearCallbacks(channelName: leavingChannel, owner: this);
      }

      _currentChannelName = null;
      _currentUid = null;
      _agoraUsers.clear();
      _networkQualities.clear();
      for (final timer in _offlineUserTimers.values) {
        timer.cancel();
      }
      _offlineUserTimers.clear();

      if (_agoraService.currentChannelId == null || _agoraService.currentChannelId == leavingChannel) {
        try {
          await BackgroundService().stopService();
        } catch (_) {}
      }

      emit(const AgoraChannelLeft());
      debugPrint('🎤 [AudioRoomsBloc] Left RTC channel successfully');
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

        final bool isUserSeated =
            (currentParticipant?.isSeated == true) ||
            (currentParticipant?.isSpeaker == true) ||
            (currentParticipant?.seatNumber != null && currentParticipant!.seatNumber! >= 0);

        if (!isUserSeated) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot toggle mic - user is not seated');
          emit(const AgoraError(
            message: 'You must be seated to use the microphone',
            code: 'NOT_SEATED',
          ));
          emit(const MicrophoneToggled(isMuted: true));
          return;
        }
        if (currentParticipant != null && currentParticipant.isMutedByAdmin) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot toggle mic - user is muted by admin');
          emit(AgoraError(
            message: 'You have been muted by an admin',
            code: 'MUTED_BY_ADMIN',
          ));
          emit(const MicrophoneToggled(isMuted: true));
          return;
        }
      }

      final bool isCurrentMuted = _livekitService.isConnected.value
          ? _livekitService.isMicMuted.value
          : _agoraService.isMuted;

      // If user is currently muted and trying to unmute, verify microphone permission
      if (isCurrentMuted) {
        try {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            final req = await Permission.microphone.request();
            if (!req.isGranted) {
              debugPrint('🎤 [AudioRoomsBloc] ❌ Microphone permission denied');
              emit(const AgoraError(
                message: 'Microphone permission is required to speak',
                code: 'MIC_PERMISSION_DENIED',
              ));
              emit(const MicrophoneToggled(isMuted: true));
              return;
            }
          }
        } catch (e) {
          debugPrint('🎤 [AudioRoomsBloc] Error checking mic permission: $e');
        }
      }

      _lastLocalMuteChangeTime = DateTime.now();

      // Allow users to toggle their microphone freely
      if (_livekitService.isConnected.value || isLiveKit) {
        final newMuted = !_livekitService.isMicMuted.value;
        await _livekitService.setMicrophoneEnabled(!newMuted);
      } else {
        await _agoraService.toggleMute();
      }
      final bool newMutedState = (_livekitService.isConnected.value || isLiveKit)
          ? _livekitService.isMicMuted.value
          : _agoraService.isMuted;
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

        final bool isUserSeated =
            (currentParticipant?.isSeated == true) ||
            (currentParticipant?.isSpeaker == true) ||
            (currentParticipant?.seatNumber != null && currentParticipant!.seatNumber! >= 0);

        if (!event.muted && !isUserSeated) {
          debugPrint(
              '🎤 [AudioRoomsBloc] ❌ Cannot unmute mic - user is not seated');
          emit(const AgoraError(
            message: 'You must be seated to use the microphone',
            code: 'NOT_SEATED',
          ));
          emit(const MicrophoneToggled(isMuted: true));
          return;
        }

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
          emit(const MicrophoneToggled(isMuted: true));
          return;
        }
      }

      // If trying to unmute, verify microphone permission
      if (!event.muted) {
        try {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            final req = await Permission.microphone.request();
            if (!req.isGranted) {
              debugPrint('🎤 [AudioRoomsBloc] ❌ Microphone permission denied');
              emit(const AgoraError(
                message: 'Microphone permission is required to speak',
                code: 'MIC_PERMISSION_DENIED',
              ));
              emit(const MicrophoneToggled(isMuted: true));
              return;
            }
          }
        } catch (e) {
          debugPrint('🎤 [AudioRoomsBloc] Error checking mic permission: $e');
        }
      }

      _lastLocalMuteChangeTime = DateTime.now();

      // Allow users to set their microphone state freely
      if (_livekitService.isConnected.value || isLiveKit) {
        await _livekitService.setMicrophoneEnabled(!event.muted);
      } else {
        await _agoraService.setMuted(event.muted);
      }
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
      emit(AgoraError(message: e.toString(), code: 'SET_MIC_MUTE_FAILED'));
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
      if (_livekitService.isConnected.value || isLiveKit) {
        final newSpeakerOn = !_agoraService.isSpeakerOn;
        await _livekitService.setSpeakerphoneEnabled(newSpeakerOn);
        _agoraService.setSpeakerOn(newSpeakerOn);
        emit(SpeakerToggled(isSpeakerOn: newSpeakerOn));
        debugPrint(
            '🔊 [AudioRoomsBloc] LiveKit Speaker toggled: ${newSpeakerOn ? "on" : "off"}');
      } else {
        await _agoraService.toggleSpeaker();
        emit(SpeakerToggled(isSpeakerOn: _agoraService.isSpeakerOn));
        debugPrint(
            '🔊 [AudioRoomsBloc] Agora Speaker toggled: ${_agoraService.isSpeakerOn ? "on" : "off"}');
      }
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

      if (isLiveKit) {
        try {
          await _audioPlayer.stop();
          await _audioPlayer.setReleaseMode(
            event.config.cycle == -1 ? ap.ReleaseMode.loop : ap.ReleaseMode.release,
          );
          await _audioPlayer.setVolume(event.config.playoutVolume / 100.0);
          await _audioPlayer.play(ap.DeviceFileSource(event.config.filePath));
          emit(BackgroundMusicStarted(config: event.config));
          debugPrint('🎵 [AudioRoomsBloc] Background music started via AudioPlayer: ${event.config.filePath}');
          return;
        } catch (apErr) {
          debugPrint('🎵 [AudioRoomsBloc] AudioPlayer error: $apErr');
          emit(BackgroundMusicFailed(error: apErr.toString()));
          return;
        }
      }

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
      if (isLiveKit) {
        await _audioPlayer.stop();
      } else {
        await _agoraService.stopAudioMixing();
      }
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
      if (isLiveKit) {
        await _audioPlayer.pause();
      } else {
        await _agoraService.pauseAudioMixing();
      }
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
      if (isLiveKit) {
        await _audioPlayer.resume();
      } else {
        await _agoraService.resumeAudioMixing();
      }
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

    // Cancel any pending auto-exit timer if the user reconnected within grace period
    final pendingTimer = _offlineUserTimers.remove(event.user.uid);
    if (pendingTimer != null) {
      debugPrint('⏱️ [AudioRoomsBloc] Cancelled auto-exit grace timer for reconnected user: ${event.user.uid}');
      pendingTimer.cancel();
    }

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

    // --- Automatic Auto-Exit with Grace Timer ---
    // If a user disconnected unexpectedly (network drop, phone power-off/killed),
    // give them 10 seconds grace period to reconnect. If they do not return,
    // auto-exit them from the room and clear their seat in Firestore.
    if (_currentRoom != null) {
      AudioRoomParticipant? offlineParticipant;
      for (final p in _currentRoom!.participants) {
        if (generateAgoraUid(p.userId) == event.uid || p.userId == event.uid.toString()) {
          offlineParticipant = p;
          break;
        }
      }

      if (offlineParticipant != null) {
        final targetUserId = offlineParticipant.userId;
        final targetUserName = offlineParticipant.userName;
        final targetRoomId = _currentRoom!.id;

        // Cancel any existing timer for this UID
        _offlineUserTimers.remove(event.uid)?.cancel();

        debugPrint('⏱️ [AudioRoomsBloc] Starting 10-second offline grace timer for $targetUserName ($targetUserId)...');

        _offlineUserTimers[event.uid] = Timer(const Duration(seconds: 10), () async {
          _offlineUserTimers.remove(event.uid);

          if (isClosed || _currentRoom == null || _currentRoom!.id != targetRoomId) return;

          final myUserId = _currentUser?.userId ?? AuthController.instance.currentUser.userId;
          if (myUserId.isEmpty || myUserId == targetUserId) return;

          // Check if user is still in participants or occupying a seat
          final isStillInParticipants = _currentRoom!.participants.any((p) => p.userId == targetUserId);
          final isStillSeated = _currentRoom!.settings.seatConfiguration.any((s) => s.occupiedBy == targetUserId);

          if (!isStillInParticipants && !isStillSeated) {
            debugPrint('🚪 [AudioRoomsBloc] User $targetUserName already left room, skipping auto-exit.');
            return;
          }

          // Decide which connected client dispatches the leave operation:
          // Prefer Room Creator, then Room Admins, then lowest UID participant to prevent duplicate writes
          final isCreator = _currentRoom!.isCreator(myUserId);
          final isAdmin = _currentRoom!.settings.adminIds.contains(myUserId);

          bool shouldDispatch = isCreator || isAdmin;
          if (!shouldDispatch) {
            final activeParticipants = _currentRoom!.participants.where((p) => p.userId != targetUserId).toList();
            if (activeParticipants.isNotEmpty && activeParticipants.first.userId == myUserId) {
              shouldDispatch = true;
            }
          }

          if (shouldDispatch) {
            debugPrint('🚪 [AudioRoomsBloc] User $targetUserName ($targetUserId) timed out (10s offline). Executing auto-exit from room $targetRoomId...');
            try {
              await _repository.leaveRoom(
                roomId: targetRoomId,
                userId: targetUserId,
              );
              debugPrint('🚪 [AudioRoomsBloc] Successfully auto-exited offline user $targetUserName.');
            } catch (e) {
              debugPrint('🚪 [AudioRoomsBloc] ⚠️ Failed to auto-exit offline user: $e');
            }
          }
        });
      }
    }
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
    } else {
      final remoteUser = _agoraService.remoteUsers[event.uid] ??
          AgoraUser(
            uid: event.uid,
            userId: event.uid.toString(),
            userName: 'User ${event.uid}',
            isMuted: event.muted,
            lastSpokeAt: DateTime.now(),
          );
      final updated = remoteUser.copyWith(isMuted: event.muted);
      _agoraUsers.add(updated);
      emit(AgoraUserUpdated(
        user: updated,
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
    if (event.code.contains('errInvalidToken') ||
        event.code.contains('errTokenExpired')) {
      debugPrint(
          '🎫 [AudioRoomsBloc] Invalid/Expired token detected, triggering auto-renew...');
      add(const TokenPrivilegeWillExpire());
      return;
    }
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
          '🚪 [AudioRoomsBloc] Force leaving RTC channel (participant was kicked)');

      final leavingChannel = _currentChannelName;
      if (_livekitService.isConnected.value) {
        await _livekitService.leaveRoom();
      }
      await _agoraService.leaveChannelAndRelease(channelName: leavingChannel);
      _agoraService.clearCallbacks(channelName: leavingChannel, owner: this);
      _agoraInitialized = false;
      _currentChannelName = null;
      _currentUid = null;
      _agoraUsers.clear();
      _networkQualities.clear();
      try {
        await BackgroundService().stopService();
      } catch (_) {}
      emit(const AgoraChannelLeft());
      debugPrint('🚪 [AudioRoomsBloc] ✅ Forced to leave RTC channel');
    } catch (e) {
      debugPrint(
          '🚪 [AudioRoomsBloc] ❌ Failed to force leave RTC channel: $e');
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

        final bool isCurrentMuted = _livekitService.isConnected.value
            ? _livekitService.isMicMuted.value
            : _agoraService.isMuted;

        // Only enforce mute if the participant is muted by admin and local mic is unmuted.
        // We do NOT overwrite voluntary user mic toggles with stale room data to prevent mute toggle loops.
        if (currentParticipant.isMutedByAdmin && !isCurrentMuted) {
          debugPrint(
              '🎤 [AudioRoomsBloc] 🔒 Admin mute enforced: muting local mic');
          add(const SetMicrophoneMute(muted: true));
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
    for (final timer in _offlineUserTimers.values) {
      timer.cancel();
    }
    _offlineUserTimers.clear();

    // Cleanup Agora (Do NOT dispose the engine, just leave the channel and clear callbacks)
    if (_agoraInitialized) {
      // The engine is a singleton, we want to keep it alive for faster room switching
      // The actual leave channel is already handled by LeaveAgoraChannel event
      _agoraService.clearCallbacks(channelName: _currentChannelName, owner: this);
    }

    if (_agoraService.currentChannelId == null || _agoraService.currentChannelId == _currentChannelName) {
      try {
        await BackgroundService().stopService();
      } catch (_) {}
    }

    try {
      await _audioPlayer.dispose();
    } catch (_) {}

    _repository.dispose();
    return super.close();
  }
}
