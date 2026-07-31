import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'global_settings_service.dart';

import '../models/agora_models.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  String? _initializedAppId;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  final Map<int, AgoraUser> _remoteUsers = {};
  final RxMap<int, bool> remoteUserVideoMuted = <int, bool>{}.obs;

  // Audio state
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isRoomMuted = false;
  bool _isMusicPlaying = false; // Track if music is playing
  AudioQuality _currentAudioQuality = AudioQuality.high;
  AudioEffect _currentAudioEffect = AudioEffect.none;
  VoiceChanger _currentVoiceChanger = VoiceChanger.none;

  // Current user info for mapping UIDs to actual users
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;
  int? _currentUid;
  bool _initialMuteStatus = true; // Store initial mute status
  bool _isAgoraServiceChannel = false; // Tracks if AgoraService managed current channel
  final Map<int, AgoraUser> _uidToUserMap = {}; // Map UID to user info

  // Callbacks
  Function(AgoraUser)? onUserJoined;
  Function(AgoraUser)? onUserLeft;
  Function(AgoraConnectionState)? onConnectionStateChanged;
  Function(String, String)? onError;
  Function(int, bool)? onUserMuted;
  Function(List<AudioVolumeInfo>, int)? onAudioVolumeIndication;
  Function(NetworkQuality)? onNetworkQuality;
  Function(AgoraStats)? onStats;
  Function()? onTokenPrivilegeWillExpire;
  Function()? onAudioMixingFinished;
  Function(int)? onAudioEffectFinished;

  // Getters
  AgoraConnectionState get connectionState => _connectionState;
  Map<int, AgoraUser> get remoteUsers => Map.unmodifiable(_remoteUsers);
  bool get isConnected => _connectionState == AgoraConnectionState.connected;
  bool get isConnecting => _connectionState == AgoraConnectionState.connecting;
  bool get hasRemoteUsers => _remoteUsers.isNotEmpty;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isRoomMuted => _isRoomMuted;
  AudioQuality get currentAudioQuality => _currentAudioQuality;
  AudioEffect get currentAudioEffect => _currentAudioEffect;
  VoiceChanger get currentVoiceChanger => _currentVoiceChanger;
  RtcEngine? get engine => _engine;

  /// Clear all event callbacks
  void clearCallbacks() {
    onUserJoined = null;
    onUserLeft = null;
    onConnectionStateChanged = null;
    onError = null;
    onUserMuted = null;
    onAudioVolumeIndication = null;
    onNetworkQuality = null;
    onStats = null;
    onTokenPrivilegeWillExpire = null;
    onAudioMixingFinished = null;
    onAudioEffectFinished = null;
  }

  /// Initialize the Agora RTC Engine
  Future<bool> initialize([String? appId]) async {
    try {
      debugPrint('🎤 [AgoraService] Initializing Agora RTC Engine...');

      final settingsService = Get.find<GlobalSettingsService>();
      final appIdToUse = appId ?? settingsService.agoraAppId.value;

      if (_engine != null) {
        if (_initializedAppId == appIdToUse) {
          debugPrint('🎤 [AgoraService] Engine already initialized with matching AppID: $appIdToUse');
          setupEventHandlers();
          return true;
        } else {
          debugPrint('🎤 [AgoraService] AppID changed from $_initializedAppId to $appIdToUse. Re-initializing...');
          await dispose();
        }
      }

      // Request permissions
      await _requestPermissions();

      // Create engine
      _engine = createAgoraRtcEngine();

      await _engine!.initialize(RtcEngineContext(
        appId: appIdToUse,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        audioScenario: AudioScenarioType.audioScenarioChatroom,
      ));
      
      _initializedAppId = appIdToUse;

      // Enable background audio persistence
      await _engine!.setParameters("{\"che.audio.keep.audiosession\": true}");
      await _engine!.setParameters(
          "{\"che.audio.opensl\": true}"); // Use OpenSL for Android usually better for background? Optional.

      // Enable speakerphone by default
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      // Enable audio volume indication
      await _engine!.enableAudioVolumeIndication(
        interval: 200, // Update every 200ms
        smooth: 3, // Smoothing factor
        reportVad: true, // Enable Voice Activity Detection
      );

      debugPrint('🎤 [AgoraService] Engine initialized with AppID: $appIdToUse');
      setupEventHandlers();

      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Initialization failed: $e');
      _handleError('Initialization failed', e.toString());
      return false;
    }
  }

  /// Setup event handlers
  void setupEventHandlers() {
    if (_engine == null) return;

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('🎤 [AgoraService] ✅ JOIN CHANNEL SUCCESS EVENT TRIGGERED!');
        debugPrint(
            '🎤 [AgoraService] ✅ Channel: ${connection.channelId}, UID: ${connection.localUid}');
        debugPrint('🎤 [AgoraService] ✅ Elapsed time: ${elapsed}ms');
        _updateConnectionState(AgoraConnectionState.connected);

        // Set initial mute status after joining (only for AgoraService-managed channels)
        if (_isAgoraServiceChannel) {
          debugPrint('🎤 [AgoraService] 🔧 Calling _setInitialMuteStatus...');
          _setInitialMuteStatus().catchError((error) {
            debugPrint(
                '🎤 [AgoraService] ❌ Error in _setInitialMuteStatus: $error');
          });
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('🎤 [AgoraService] 👤 User joined: $remoteUid');
        _handleUserJoined(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint('🎤 [AgoraService] 👤 User left: $remoteUid');
        remoteUserVideoMuted.remove(remoteUid);
        _handleUserLeft(remoteUid);
      },
      onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
        debugPrint('🎤 [AgoraService] 👤 User $remoteUid video muted: $muted');
        remoteUserVideoMuted[remoteUid] = muted;
      },
      onConnectionStateChanged: (RtcConnection connection,
          ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint('🎤 [AgoraService] 🔄 Connection state changed: $state');
        _handleConnectionStateChange(state);
      },
      onAudioVolumeIndication: (RtcConnection connection,
          List<AudioVolumeInfo> speakers, int totalVolume, int speakerNumber) {
        onAudioVolumeIndication?.call(speakers, totalVolume);
      },
      onNetworkQuality: (RtcConnection connection, int remoteUid,
          QualityType txQuality, QualityType rxQuality) {
        final quality =
            NetworkQuality.fromAgora(remoteUid, txQuality, rxQuality);
        onNetworkQuality?.call(quality);
      },
      onRtcStats: (RtcConnection connection, RtcStats stats) {
        final agoraStats = AgoraStats.fromRtcStats(stats);
        onStats?.call(agoraStats);
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('🎤 [AgoraService] 🎫 Token will expire soon');
        onTokenPrivilegeWillExpire?.call();
      },
      onAudioMixingFinished: () {
        debugPrint('🎤 [AgoraService] 🎵 Audio mixing finished');
        onAudioMixingFinished?.call();
      },
      onAudioEffectFinished: (int soundId) {
        debugPrint('🎤 [AgoraService] 🎭 Audio effect finished: $soundId');
        onAudioEffectFinished?.call(soundId);
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('🎤 [AgoraService] ❌ Error: $err - $msg');
        _handleError(msg, err.toString());
      },
    ));
  }

  /// Join a channel
  Future<bool> joinChannel({
    required String channelName,
    required int uid,
    String? userId,
    String? userName,
    String? userImageUrl,
    String? token,
    bool isMuted = true, // Default to muted for new participants
    bool isVideo = false,
  }) async {
    try {
      if (_engine == null) {
        debugPrint('🎤 [AgoraService] ❌ Engine not initialized');
        return false;
      }

      debugPrint(
          '🎤 [AgoraService] Joining channel: $channelName with UID: $uid');
      _updateConnectionState(AgoraConnectionState.connecting);

      // Store current user info for mapping
      _currentUserId = userId;
      _currentUserName = userName;
      _currentUserImageUrl = userImageUrl;
      _currentUid = uid;
      _initialMuteStatus = isMuted; // Store initial mute status
      _isAgoraServiceChannel = true; // Mark as AgoraService managed channel
      debugPrint(
          '🎤 [AgoraService] 🔧 Stored initial mute status: $_initialMuteStatus');

      final options = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideo,
        publishMicrophoneTrack: true,
        publishCameraTrack: isVideo,
      );

      await _engine!.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: options,
      );

      // Set client role after joining (required for LiveBroadcasting profile)
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Add a small delay to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 500));

      // If onJoinChannelSuccess hasn't fired yet, manually trigger it
      if (_connectionState == AgoraConnectionState.connecting) {
        debugPrint(
            '🎤 [AgoraService] ⚠️ onJoinChannelSuccess not fired, manually triggering...');
        _updateConnectionState(AgoraConnectionState.connected);
      }

      // Fallback: Set initial mute status after a delay to ensure it's applied
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_isAgoraServiceChannel) {
          debugPrint(
              '🎤 [AgoraService] 🔧 Fallback: Setting initial mute status...');
          _setInitialMuteStatus().catchError((error) {
            debugPrint(
                '🎤 [AgoraService] ❌ Fallback error in _setInitialMuteStatus: $error');
          });
        }
      });

      // Query existing users in the channel
      await _queryExistingUsers();

      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to join channel: $e');
      _handleError('Failed to join channel', e.toString());
      return false;
    }
  }

  /// Leave the current channel
  Future<bool> leaveChannel() async {
    try {
      if (_engine == null) return false;

      debugPrint('🎤 [AgoraService] Leaving channel...');
      await _engine!.leaveChannel();

      _updateConnectionState(AgoraConnectionState.disconnected);
      _remoteUsers.clear();
      remoteUserVideoMuted.clear();
      _uidToUserMap.clear();
      _currentUserId = null;
      _currentUid = null;
      _isMuted = false;
      _initialMuteStatus = true;
      _isAgoraServiceChannel = false;

      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to leave channel: $e');
      _handleError('Failed to leave channel', e.toString());
      return false;
    }
  }

  /// Mute/unmute microphone
  Future<bool> setMuted(bool muted) async {
    try {
      if (_engine == null) return false;

      if (_isMusicPlaying) {
        // If music IS playing, we CANNOT stop the stream (muteLocalAudioStream).
        // Instead, we just mute the microphone capture volume.
        // We ensure the stream is LIVE (unmuted) so music can pass through.
        await _engine!.updateChannelMediaOptions(
            const ChannelMediaOptions(publishMicrophoneTrack: true));
        await _engine!.muteLocalAudioStream(false);
        await _engine!.adjustRecordingSignalVolume(muted ? 0 : 100);
      } else {
        // Normal behavior: Toggle software mute state and update media options
        if (!muted) {
          // Explicitly restore broadcaster role and enable microphone publishing
          await _engine!
              .setClientRole(role: ClientRoleType.clientRoleBroadcaster);
          await _engine!.updateChannelMediaOptions(
              const ChannelMediaOptions(publishMicrophoneTrack: true));
          await _engine!.muteLocalAudioStream(false);
          await _engine!.adjustRecordingSignalVolume(100);
        } else {
          await _engine!.muteLocalAudioStream(true);
          await _engine!.updateChannelMediaOptions(
              const ChannelMediaOptions(publishMicrophoneTrack: false));
        }
      }

      _isMuted = muted;
      debugPrint(
          '🎤 [AgoraService] Microphone ${muted ? 'muted' : 'unmuted'} (Music playing: $_isMusicPlaying)');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set mute state: $e');
      return false;
    }
  }

  /// Toggle microphone mute
  Future<bool> toggleMute() async {
    return await setMuted(!_isMuted);
  }

  /// Enable/disable speaker
  Future<bool> setSpeakerOn(bool enabled) async {
    try {
      if (_engine == null) return false;

      await _engine!.setEnableSpeakerphone(enabled);
      _isSpeakerOn = enabled;
      debugPrint(
          '🎤 [AgoraService] Speaker ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set speaker state: $e');
      return false;
    }
  }

  /// Toggle speaker
  Future<bool> toggleSpeaker() async {
    return await setSpeakerOn(!_isSpeakerOn);
  }

  /// Mute/unmute all incoming audio (Room Mute)
  Future<bool> setRoomMuted(bool muted) async {
    try {
      if (_engine == null) return false;

      await _engine!.muteAllRemoteAudioStreams(muted);
      _isRoomMuted = muted;
      debugPrint('🎤 [AgoraService] Room audio ${muted ? 'muted' : 'unmuted'}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set room mute state: $e');
      return false;
    }
  }

  /// Toggle room mute
  Future<bool> toggleRoomMute() async {
    return await setRoomMuted(!_isRoomMuted);
  }

  /// Enable Video
  Future<bool> enableVideo() async {
    try {
      if (_engine == null) return false;
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);

      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 30,
          bitrate: 1710,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      await setBeautyEffect(
        true,
        lighteningLevel: 0.7,
        smoothnessLevel: 0.6,
        rednessLevel: 0.1,
        sharpnessLevel: 0.3,
      );

      await _engine!.startPreview();
      await _engine!.updateChannelMediaOptions(const ChannelMediaOptions(
        publishCameraTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ));
      debugPrint('🎤 [AgoraService] 📹 Video enabled (720p) and preview started with Beauty Filter');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to enable video: $e');
      return false;
    }
  }

  /// Disable Video
  Future<bool> disableVideo() async {
    try {
      if (_engine == null) return false;
      await _engine!.updateChannelMediaOptions(const ChannelMediaOptions(
        publishCameraTrack: false,
        autoSubscribeAudio: true,
      ));
      await _engine!.stopPreview();
      await _engine!.enableLocalVideo(false);
      debugPrint('🎤 [AgoraService] 📹 Video disabled');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to disable video: $e');
      return false;
    }
  }

  /// Switch Camera
  Future<bool> switchCamera() async {
    try {
      if (_engine == null) return false;
      await _engine!.switchCamera();
      debugPrint('🎤 [AgoraService] 📹 Camera switched');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to switch camera: $e');
      return false;
    }
  }

  /// Toggle beauty effect
  Future<bool> setBeautyEffect(
    bool enabled, {
    double lighteningLevel = 0.7,
    double smoothnessLevel = 0.5,
    double rednessLevel = 0.1,
    double sharpnessLevel = 0.1,
  }) async {
    try {
      if (_engine == null) return false;

      await _engine!.setBeautyEffectOptions(
        enabled: enabled,
        options: BeautyOptions(
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: lighteningLevel,
          smoothnessLevel: smoothnessLevel,
          rednessLevel: rednessLevel,
          sharpnessLevel: sharpnessLevel,
        ),
      );

      debugPrint('🎤 [AgoraService] ✨ Beauty effect ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set beauty effect: $e');
      return false;
    }
  }

  /// Set audio quality
  Future<bool> setAudioQuality(AudioQuality quality) async {
    try {
      if (_engine == null) return false;

      await _engine!.setAudioProfile(
        profile: quality.agoraProfile,
        scenario: quality.agoraScenario,
      );
      _currentAudioQuality = quality;
      debugPrint(
          '🎤 [AgoraService] Audio quality set to: ${quality.displayName}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set audio quality: $e');
      return false;
    }
  }

  /// Set audio effect
  Future<bool> setAudioEffect(AudioEffect effect) async {
    try {
      if (_engine == null) return false;

      // Apply audio effect using Agora's audio effects
      _currentAudioEffect = effect;
      debugPrint(
          '🎤 [AgoraService] Audio effect set to: ${effect.displayName}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set audio effect: $e');
      return false;
    }
  }

  /// Set voice changer
  Future<bool> setVoiceChanger(VoiceChanger changer) async {
    try {
      if (_engine == null) return false;

      _currentVoiceChanger = changer;
      debugPrint(
          '🎤 [AgoraService] Voice changer set to: ${changer.displayName}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set voice changer: $e');
      return false;
    }
  }

  /// Start audio mixing
  Future<bool> startAudioMixing(AudioMixingConfig config) async {
    try {
      if (_engine == null) return false;

      await _engine!.startAudioMixing(
        filePath: config.filePath,
        loopback: config.loopback,
        cycle: config.cycle,
        startPos: config.startPos,
      );

      _isMusicPlaying = true;
      // Re-apply mute state with new logic (soft mute)
      await setMuted(_isMuted);

      debugPrint('🎤 [AgoraService] Audio mixing started: ${config.filePath}');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to start audio mixing: $e');
      return false;
    }
  }

  /// Stop audio mixing
  Future<bool> stopAudioMixing() async {
    try {
      if (_engine == null) return false;

      await _engine!.stopAudioMixing();

      _isMusicPlaying = false;
      // Re-apply mute state with normal logic (hard mute)
      await setMuted(_isMuted);

      debugPrint('🎤 [AgoraService] Audio mixing stopped');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to stop audio mixing: $e');
      return false;
    }
  }

  /// Pause audio mixing
  Future<bool> pauseAudioMixing() async {
    try {
      if (_engine == null) return false;
      await _engine!.pauseAudioMixing();
      debugPrint('🎤 [AgoraService] Audio mixing paused');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to pause audio mixing: $e');
      return false;
    }
  }

  /// Resume audio mixing
  Future<bool> resumeAudioMixing() async {
    try {
      if (_engine == null) return false;
      await _engine!.resumeAudioMixing();
      debugPrint('🎤 [AgoraService] Audio mixing resumed');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to resume audio mixing: $e');
      return false;
    }
  }

  /// Get current playback position in milliseconds
  Future<int> getAudioMixingCurrentPosition() async {
    try {
      if (_engine != null && _isMusicPlaying) {
        final pos = await _engine!.getAudioMixingCurrentPosition();
        return pos;
      }
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to get mixing position: $e');
    }
    return 0;
  }

  /// Get mixing audio duration in milliseconds
  Future<int> getAudioMixingDuration() async {
    try {
      if (_engine != null && _isMusicPlaying) {
        final duration = await _engine!.getAudioMixingDuration();
        return duration;
      }
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to get mixing duration: $e');
    }
    return 0;
  }

  /// Set audio mixing volume (0-100)
  Future<void> setAudioMixingVolume(int volume) async {
    try {
      if (_engine != null) {
        await _engine!.adjustAudioMixingVolume(volume);
        await _engine!.adjustAudioMixingPublishVolume(volume);
        await _engine!.adjustAudioMixingPlayoutVolume(volume);
        debugPrint('🎤 [AgoraService] Audio mixing volume set to $volume');
      }
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set mixing volume: $e');
    }
  }

  /// Set audio mixing position
  Future<void> setAudioMixingPosition(int posMs) async {
    try {
      if (_engine != null) {
        await _engine!.setAudioMixingPosition(posMs);
        debugPrint('🎤 [AgoraService] Audio mixing seeked to ${posMs}ms');
      }
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to seek audio mixing: $e');
    }
  }

  /// Renew token
  Future<bool> renewToken(String token) async {
    try {
      if (_engine == null) return false;

      await _engine!.renewToken(token);
      debugPrint('🎤 [AgoraService] Token renewed');
      return true;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to renew token: $e');
      return false;
    }
  }

  /// Update remote user information
  void updateRemoteUser(
    int uid, {
    String? userId,
    String? userName,
    String? userImageUrl,
    int? seatNumber,
  }) {
    final user = AgoraUser(
      uid: uid,
      userId: userId ?? uid.toString(),
      userName: userName ?? 'User $uid',
      userImageUrl: userImageUrl,
      lastSpokeAt: DateTime.now(),
      seatNumber: seatNumber,
    );

    _remoteUsers[uid] = user;
    _uidToUserMap[uid] = user;
    debugPrint(
        '🎤 [AgoraService] Updated remote user: ${user.userName} (UID: $uid)');
  }

  /// Map UID to actual user information from room participants
  void mapUidToUser(int uid, String userId, String userName,
      {String? userImageUrl}) {
    final user = AgoraUser(
      uid: uid,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      lastSpokeAt: DateTime.now(),
    );

    _uidToUserMap[uid] = user;
    _remoteUsers[uid] = user;
    debugPrint('🎤 [AgoraService] Mapped UID $uid to user: $userName');
  }

  /// Handle user joined
  void _handleUserJoined(int uid) {
    debugPrint('🎤 [AgoraService] _handleUserJoined called with UID: $uid');
    debugPrint(
        '🎤 [AgoraService] Current UID: $_currentUid, Current User ID: $_currentUserId');

    // Check if this is the current user (local user)
    if (uid == _currentUid &&
        _currentUserId != null &&
        _currentUserName != null) {
      // This is the current user joining - create user with actual info
      final user = AgoraUser(
        uid: uid,
        userId: _currentUserId!,
        userName: _currentUserName!,
        userImageUrl: _currentUserImageUrl,
        lastSpokeAt: DateTime.now(),
      );

      _remoteUsers[uid] = user;
      _uidToUserMap[uid] = user;
      onUserJoined?.call(user);
      debugPrint(
          '🎤 [AgoraService] Current user joined: ${user.userName} (UID: $uid)');
    } else {
      // This is a remote user - try to get info from stored map or create fallback
      AgoraUser? userToEmit = _uidToUserMap[uid];

      if (userToEmit != null) {
        userToEmit = userToEmit.copyWith(lastSpokeAt: DateTime.now());
      } else {
        userToEmit = AgoraUser(
          uid: uid,
          userId: 'user_$uid',
          userName: 'User $uid',
          lastSpokeAt: DateTime.now(),
        );
        _uidToUserMap[uid] = userToEmit;
      }

      _remoteUsers[uid] = userToEmit;
      onUserJoined?.call(userToEmit);
      debugPrint(
          '🎤 [AgoraService] Remote user joined: ${userToEmit.userName} (UID: $uid)');
    }
  }

  /// Handle user left
  void _handleUserLeft(int uid) {
    final user = _remoteUsers.remove(uid);
    if (user != null) {
      onUserLeft?.call(user);
    }
  }

  /// Set initial mute status after joining channel
  Future<void> _setInitialMuteStatus() async {
    try {
      debugPrint(
          '🎤 [AgoraService] 🔧 _setInitialMuteStatus called with _initialMuteStatus: $_initialMuteStatus');
      if (_engine == null) {
        debugPrint(
            '🎤 [AgoraService] ❌ Engine is null, cannot set mute status');
        return;
      }

      debugPrint(
          '🎤 [AgoraService] 🔧 Calling setMuted with: $_initialMuteStatus');
      await setMuted(_initialMuteStatus);
      debugPrint(
          '🎤 [AgoraService] ✅ Initial mute status set: ${_initialMuteStatus ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to set initial mute status: $e');
    }
  }

  /// Handle connection state change
  void _handleConnectionStateChange(ConnectionStateType state) {
    switch (state) {
      case ConnectionStateType.connectionStateConnecting:
        _updateConnectionState(AgoraConnectionState.connecting);
        break;
      case ConnectionStateType.connectionStateConnected:
        _updateConnectionState(AgoraConnectionState.connected);
        break;
      case ConnectionStateType.connectionStateReconnecting:
        _updateConnectionState(AgoraConnectionState.reconnecting);
        break;
      case ConnectionStateType.connectionStateDisconnected:
        _updateConnectionState(AgoraConnectionState.disconnected);
        break;
      case ConnectionStateType.connectionStateFailed:
        _updateConnectionState(AgoraConnectionState.failed);
        break;
    }
  }

  /// Update connection state
  void _updateConnectionState(AgoraConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      onConnectionStateChanged?.call(state);
    }
  }

  /// Handle errors
  void _handleError(String message, String code) {
    onError?.call(message, code);
  }

  /// Request permissions
  Future<bool> _requestPermissions() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Permission request failed: $e');
      return false;
    }
  }

  /// Query existing users in the channel
  Future<void> _queryExistingUsers() async {
    try {
      debugPrint('🎤 [AgoraService] 🔍 Querying existing users in channel...');

      // Note: Agora doesn't provide a direct way to query existing users
      // The onUserJoined events will fire when other users are detected
      // We can check if we're connected and ready to receive events
      debugPrint(
          '🎤 [AgoraService] ✅ User query completed - waiting for onUserJoined events');
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Failed to query users: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _engine?.release();
      _engine = null;
      _remoteUsers.clear();
      _updateConnectionState(AgoraConnectionState.disconnected);
    } catch (e) {
      debugPrint('🎤 [AgoraService] ❌ Dispose failed: $e');
    }
  }
}
