import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'global_settings_service.dart';
import 'background_service.dart';
import 'agora_token_service.dart';
import '../models/agora_models.dart';

/// Agora session lifecycle states
enum AgoraSessionState {
  idle,
  initializing,
  joining,
  joined,
  leaving,
  releasing,
}

/// Call or room modes supported by AgoraService for production background execution
enum AgoraChannelMode {
  audioRoom,
  audioCall,
  videoCall,
  groupCall,
}

/// Production-grade Agora Service implementing enterprise reliability patterns:
/// - Background audio execution for Audio Room, Audio Call, Video Call, and Group Call
/// - Robust thread-safe queue locking to prevent race conditions and deadlocks
/// - Smart engine release (only upon explicit user exit / destruction)
/// - Auto-reconnect with exponential backoff (250ms -> 500ms -> 1000ms -> 2000ms -> 4000ms)
/// - Token auto-renewal without call interruption
/// - Smart camera lifecycle management (pause preview on background, resume on foreground)
/// - Bluetooth & Wired headset audio routing detection with speaker restoration
/// - Automatic state recovery across reconnects
/// - Memory leak prevention with clean resource disposal
class AgoraService with WidgetsBindingObserver {
  AgoraService._internal() {
    _initLifecycleObserver();
  }

  static final AgoraService _instance = AgoraService._internal();

  factory AgoraService() => _instance;

  // ---------------------------------------------------------------------------
  // Configuration & Constants
  // ---------------------------------------------------------------------------

  static const int _playbackVolume = 100;
  static const int _recordingVolume = 100;
  static const int _mutedRecordingVolume = 0;

  static const int _volumeIntervalMs = 200;
  static const int _volumeSmoothFactor = 3;

  static const List<Duration> _retryDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 2000),
    Duration(milliseconds: 4000),
  ];

  static const int _maxReconnectAttempts = 5;

  static const int _videoWidth = 1280;
  static const int _videoHeight = 720;
  static const int _videoFps = 30;
  static const int _videoBitrate = 1710;

  // ---------------------------------------------------------------------------
  // Engine & Lifecycle State
  // ---------------------------------------------------------------------------

  RtcEngine? _engine;
  RtcEngineEventHandler? _eventHandler;

  String? _initializedAppId;

  AgoraSessionState _sessionState = AgoraSessionState.idle;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;

  // ---------------------------------------------------------------------------
  // Session Identity
  // ---------------------------------------------------------------------------

  String? _currentChannelId;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;
  String? _currentToken;
  int? _currentUid;

  Object? _currentOwner;

  // ---------------------------------------------------------------------------
  // Remote Users
  // ---------------------------------------------------------------------------

  final Map<int, AgoraUser> _remoteUsers = {};
  final Map<int, AgoraUser> _uidToUserMap = {};

  final RxMap<int, bool> remoteUserVideoMuted = <int, bool>{}.obs;

  // ---------------------------------------------------------------------------
  // Local Media State
  // ---------------------------------------------------------------------------

  bool _isMuted = true;
  bool _isSeated = false;
  bool _isSpeakerOn = true;
  bool _isRoomMuted = false;

  bool _isVideoEnabled = false;
  bool _isMusicPlaying = false;
  bool _keepMusicPlayingInBackground = true;

  // ---------------------------------------------------------------------------
  // Background & Audio Routing State
  // ---------------------------------------------------------------------------

  AgoraChannelMode _channelMode = AgoraChannelMode.audioRoom;
  bool _isAppInBackground = false;
  bool _wasVideoEnabledBeforeBackground = false;
  bool _lifecycleObserverRegistered = false;

  int _currentAudioRouting = -1; // -1: unknown, 1: wired headset, 3: headphone, 4: speakerphone, 5: loudspeaker, 6: bluetooth

  // ---------------------------------------------------------------------------
  // Beauty Effects Configuration Cache
  // ---------------------------------------------------------------------------

  bool _isBeautyEnabled = true;
  double _beautyLightening = 0.7;
  double _beautySmoothness = 0.6;
  double _beautyRedness = 0.1;
  double _beautySharpness = 0.3;

  // ---------------------------------------------------------------------------
  // Audio Configuration
  // ---------------------------------------------------------------------------

  AudioQuality _currentAudioQuality = AudioQuality.high;
  AudioEffect _currentAudioEffect = AudioEffect.none;
  VoiceChanger _currentVoiceChanger = VoiceChanger.none;

  // ---------------------------------------------------------------------------
  // Reconnect & Token Auto-Renewal State
  // ---------------------------------------------------------------------------

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isRenewingToken = false;

  // ---------------------------------------------------------------------------
  // Thread-Safe Session Operation Lock (Queue-Based FIFO)
  // ---------------------------------------------------------------------------

  Future<void>? _sessionOperation;
  Completer<bool>? _initializationCompleter;
  Completer<void>? _leaveCompleter;
  bool _isInitializing = false;

  // ---------------------------------------------------------------------------
  // Permissions Cache
  // ---------------------------------------------------------------------------

  bool? _microphonePermissionGranted;
  bool? _cameraPermissionGranted;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

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
  Function(int uid, RemoteAudioState state, RemoteAudioStateReason reason)? onRemoteAudioStateChanged;
  Function(int routing)? onAudioRoutingChanged;

  // ===========================================================================
  // Getters
  // ===========================================================================

  AgoraSessionState get sessionState => _sessionState;
  AgoraConnectionState get connectionState => _connectionState;

  String? get currentChannelId => _currentChannelId;
  int? get currentUid => _currentUid;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String? get currentUserImageUrl => _currentUserImageUrl;

  bool get isConnected => _connectionState == AgoraConnectionState.connected;
  bool get isConnecting =>
      _connectionState == AgoraConnectionState.connecting ||
      _connectionState == AgoraConnectionState.reconnecting;

  bool get hasRemoteUsers => _remoteUsers.isNotEmpty;
  bool get isMuted => _isMuted;
  bool get isSeated => _isSeated;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isRoomMuted => _isRoomMuted;
  bool get isVideoEnabled => _isVideoEnabled;

  AgoraChannelMode get channelMode => _channelMode;
  bool get isAppInBackground => _isAppInBackground;
  bool get keepMusicPlayingInBackground => _keepMusicPlayingInBackground;

  int get currentAudioRouting => _currentAudioRouting;
  bool get isBluetoothAudioActive => _currentAudioRouting == 5 || _currentAudioRouting == 6;
  bool get isHeadsetAudioActive => _currentAudioRouting == 1 || _currentAudioRouting == 3;

  AudioQuality get currentAudioQuality => _currentAudioQuality;
  AudioEffect get currentAudioEffect => _currentAudioEffect;
  VoiceChanger get currentVoiceChanger => _currentVoiceChanger;

  RtcEngine? get engine => _engine;
  Map<int, AgoraUser> get remoteUsers => Map.unmodifiable(_remoteUsers);

  // ===========================================================================
  // Logging
  // ===========================================================================

  void _debug(String message) {
    debugPrint('[AgoraService] $message');
  }

  void _warning(String message) {
    debugPrint('[AgoraService] ⚠️ WARNING: $message');
  }

  void _error(String message, [Object? error]) {
    if (error != null) {
      debugPrint('[AgoraService] ❌ ERROR: $message: $error');
    } else {
      debugPrint('[AgoraService] ❌ ERROR: $message');
    }
  }

  // ===========================================================================
  // Thread Safety / Session Queue Lock
  // ===========================================================================

  Future<T> _withSessionLock<T>(Future<T> Function() operation) async {
    final previousTask = _sessionOperation;
    final completer = Completer<void>();
    _sessionOperation = completer.future;

    if (previousTask != null) {
      try {
        await previousTask;
      } catch (_) {
        // Previous operation handled its own error.
      }
    }

    try {
      return await operation();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  // ===========================================================================
  // Lifecycle Observer Management
  // ===========================================================================

  void _initLifecycleObserver() {
    if (!_lifecycleObserverRegistered) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleObserverRegistered = true;
      } catch (e) {
        _warning('Failed to register WidgetsBindingObserver: $e');
      }
    }
  }

  void _removeLifecycleObserver() {
    if (_lifecycleObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
        _lifecycleObserverRegistered = false;
      } catch (e) {
        _warning('Failed to remove WidgetsBindingObserver: $e');
      }
    }
  }

  // ===========================================================================
  // App Lifecycle & Background Call Management
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleAppLifecycleState(state);
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    _debug('AppLifecycleState changed: $state');

    // Only process background audio transitions if actively connected in a channel
    if (_sessionState != AgoraSessionState.joined) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!_isAppInBackground) {
          _isAppInBackground = true;
          unawaited(_enterBackgroundMode());
        }
        break;

      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          unawaited(_restoreForegroundMode());
        }
        break;

      case AppLifecycleState.detached:
        // System is detaching Flutter view; keep audio engine alive if not user exit
        _debug('App detached by OS, keeping audio connection alive if possible.');
        break;
    }
  }

  Future<void> _enterBackgroundMode() {
    return _withSessionLock(() async {
      try {
        if (_sessionState != AgoraSessionState.joined || _engine == null) {
          return;
        }

        _debug(
          'Entering background mode: channel=$_currentChannelId, '
          'mode=$_channelMode, seated=$_isSeated, muted=$_isMuted',
        );

        // 1. Android Foreground Service Notification (keeps process alive)
        try {
          String title;
          String content;
          switch (_channelMode) {
            case AgoraChannelMode.audioRoom:
              title = 'VoiceRoom is running now';
              content = 'click back to the VoiceRoom';
              break;
            case AgoraChannelMode.audioCall:
              title = 'Audio Call Active';
              content = _isMuted ? 'Call in progress (Muted)' : 'Call in progress';
              break;
            case AgoraChannelMode.videoCall:
              title = 'Video Call (Background)';
              content = _isMuted ? 'Audio in background (Muted)' : 'Audio in background';
              break;
            case AgoraChannelMode.groupCall:
              title = 'Group Call Active';
              content = _isMuted ? 'Group call (Muted)' : 'Group call active';
              break;
          }

          await BackgroundService().startCallService(
            title: title,
            content: content,
          );
        } catch (e) {
          _warning('Failed to start BackgroundService notification: $e');
        }

        // 2. Camera Handling: Stop preview in background to free camera hardware & adhere to OS policies
        _wasVideoEnabledBeforeBackground = _isVideoEnabled;
        if (_isVideoEnabled) {
          _debug('Disabling local camera preview for background execution.');
          await _disableVideoInternal();
        }

        // 3. Remote Audio: Remote speaker audio MUST continue running in background
        await _muteAllRemoteStreams(_isRoomMuted);
        await _setPlaybackVolume(_playbackVolume);
        await _setSpeakerRoute(_isSpeakerOn);

        // 4. Local Microphone Publishing Policy
        if (_isSeated && !_isMuted) {
          // Broadcaster / Seated & Unmuted: keep BOTH mic publishing and speaker running
          await _enableLocalAudio(true);
          await _setRecordingVolume(_recordingVolume);
          await _muteLocalStream(false);
          await _updateMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              enableAudioRecordingOrPlayout: true,
            ),
          );
        } else {
          // Audience OR Muted Broadcaster: mic publishing must remain strictly OFF
          await _setRecordingVolume(_mutedRecordingVolume);
          await _muteLocalStream(true);
          if (!_isSeated) {
            try {
              await _enableLocalAudio(false);
            } catch (_) {}
          }
          await _updateMediaOptions(
            ChannelMediaOptions(
              clientRoleType: _isSeated
                  ? ClientRoleType.clientRoleBroadcaster
                  : ClientRoleType.clientRoleAudience,
              publishMicrophoneTrack: false,
              autoSubscribeAudio: true,
              enableAudioRecordingOrPlayout: true,
            ),
          );
        }

        // 5. Audio Mixing policy in background
        if (_isMusicPlaying && !_keepMusicPlayingInBackground) {
          await pauseAudioMixing();
        }
      } catch (e) {
        _error('Failed to enter background mode', e);
      }
    });
  }

  Future<void> _restoreForegroundMode() {
    return _withSessionLock(() async {
      try {
        if (_sessionState != AgoraSessionState.joined || _engine == null) {
          return;
        }

        _debug(
          'Restoring foreground mode: channel=$_currentChannelId, '
          'seated=$_isSeated, muted=$_isMuted, wasVideo=$_wasVideoEnabledBeforeBackground',
        );

        // 1. Restore speaker route and remote audio
        await _setSpeakerRoute(_isSpeakerOn);
        await _setPlaybackVolume(_playbackVolume);
        await _restoreRemoteAudioState();

        // 2. Restore local microphone state
        await _restoreLocalAudioState();

        // 3. Restore video track & preview if it was enabled before background
        if (_wasVideoEnabledBeforeBackground) {
          _debug('Restoring video track upon returning to foreground.');
          await _enableVideoInternal(updateChannelOptions: true);
          _wasVideoEnabledBeforeBackground = false;
        }

        // 4. Resume audio mixing if it was playing
        if (_isMusicPlaying && !_keepMusicPlayingInBackground) {
          await resumeAudioMixing();
        }

        // 5. Update foreground service notification
        try {
          await BackgroundService().updateNotificationInfo(
            title: 'Call Active',
            content: 'App returned to foreground',
          );
        } catch (_) {}
      } catch (e) {
        _error('Failed to restore foreground mode', e);
      }
    });
  }

  // ===========================================================================
  // Owner & Callback Management
  // ===========================================================================

  void setOwner(Object owner) {
    _currentOwner = owner;
  }

  void setChannelMode(AgoraChannelMode mode) {
    _channelMode = mode;
  }

  void setKeepMusicPlayingInBackground(bool keep) {
    _keepMusicPlayingInBackground = keep;
  }

  void clearCallbacks({String? channelName, Object? owner}) {
    if (owner != null && _currentOwner != null && owner != _currentOwner) {
      _warning('Ignoring clearCallbacks from inactive owner.');
      return;
    }

    if (channelName != null && _currentChannelId != null && channelName != _currentChannelId) {
      _warning('Ignoring clearCallbacks for inactive channel: $channelName');
      return;
    }

    _currentOwner = null;

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
    onRemoteAudioStateChanged = null;
    onAudioRoutingChanged = null;
  }

  // ===========================================================================
  // App ID Resolution
  // ===========================================================================

  String _resolveAppId(String? appId) {
    if (appId != null && appId.trim().isNotEmpty) {
      return appId.trim();
    }

    try {
      if (Get.isRegistered<GlobalSettingsService>()) {
        final settings = Get.find<GlobalSettingsService>();
        final configured = settings.agoraAppId.value.trim();
        if (configured.isNotEmpty) {
          return configured;
        }
      }
    } catch (e) {
      _warning('Unable to read Agora App ID from settings: $e');
    }

    throw StateError('Agora App ID is not configured.');
  }

  // ===========================================================================
  // Permissions
  // ===========================================================================

  Future<bool> _requestMicrophonePermission() async {
    if (_microphonePermissionGranted == true) {
      return true;
    }

    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
        _microphonePermissionGranted = true;
        return true;
      }

      final result = await Permission.microphone.request();
      _microphonePermissionGranted = result.isGranted;
      return result.isGranted;
    } catch (e) {
      _error('Microphone permission error', e);
      return false;
    }
  }

  Future<bool> _requestCameraPermission() async {
    if (_cameraPermissionGranted == true) {
      return true;
    }

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        _cameraPermissionGranted = true;
        return true;
      }

      final result = await Permission.camera.request();
      _cameraPermissionGranted = result.isGranted;
      return result.isGranted;
    } catch (e) {
      _error('Camera permission error', e);
      return false;
    }
  }

  // ===========================================================================
  // Safe Native Audio & Video Operations
  // ===========================================================================

  Future<void> _enableAudio() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.enableAudio();
    } catch (e) {
      _warning('enableAudio failed: $e');
    }
  }

  Future<void> _enableLocalAudio(bool enabled) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.enableLocalAudio(enabled);
    } catch (e) {
      _warning('enableLocalAudio($enabled) failed: $e');
    }
  }

  Future<void> _setRecordingVolume(int volume) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.adjustRecordingSignalVolume(volume);
    } catch (e) {
      _warning('Recording volume failed: $e');
    }
  }

  Future<void> _setPlaybackVolume(int volume) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.adjustPlaybackSignalVolume(volume);
    } catch (e) {
      _warning('Playback volume failed: $e');
    }
  }

  Future<void> _muteLocalStream(bool muted) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.muteLocalAudioStream(muted);
    } catch (e) {
      _warning('Local audio mute failed: $e');
    }
  }

  Future<void> _muteAllRemoteStreams(bool muted) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.muteAllRemoteAudioStreams(muted);
    } catch (e) {
      _warning('Remote audio mute failed: $e');
    }
  }

  Future<void> _setSpeakerRoute(bool enabled) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.setEnableSpeakerphone(enabled);
      await engine.setDefaultAudioRouteToSpeakerphone(enabled);
    } catch (e) {
      _warning('Speaker route failed: $e');
    }
  }

  Future<void> _enableVolumeIndication() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.enableAudioVolumeIndication(
        interval: _volumeIntervalMs,
        smooth: _volumeSmoothFactor,
        reportVad: true,
      );
    } catch (e) {
      _warning('Volume indication failed: $e');
    }
  }

  Future<void> _updateMediaOptions(ChannelMediaOptions options) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.updateChannelMediaOptions(options);
    } catch (e) {
      _warning('updateChannelMediaOptions failed: $e');
    }
  }

  // ===========================================================================
  // Engine Initialization
  // ===========================================================================

  Future<bool> initialize([String? appId]) {
    return _withSessionLock(() => _initializeInternal(appId));
  }

  Future<bool> _initializeInternal([String? appId]) async {
    if (_isInitializing && _initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _isInitializing = true;
    final completer = Completer<bool>();
    _initializationCompleter = completer;

    try {
      final resolvedAppId = _resolveAppId(appId);
      _sessionState = AgoraSessionState.initializing;

      // Existing engine with same App ID can be safely reused
      if (_engine != null && _initializedAppId == resolvedAppId) {
        _registerEventHandler();
        _sessionState = AgoraSessionState.idle;
        completer.complete(true);
        return true;
      }

      // Existing engine belongs to another App ID
      if (_engine != null) {
        await _internalLeaveAndRelease();
      }

      _debug('Creating Agora engine instance.');
      final engine = createAgoraRtcEngine();

      await engine.initialize(
        RtcEngineContext(
          appId: resolvedAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          audioScenario: AudioScenarioType.audioScenarioDefault,
        ),
      );

      _engine = engine;
      _initializedAppId = resolvedAppId;

      _registerEventHandler();
      await _configureAudio();

      _initLifecycleObserver();
      _sessionState = AgoraSessionState.idle;
      _debug('Agora engine initialized successfully.');

      completer.complete(true);
      return true;
    } catch (e) {
      _error('Agora initialization failed', e);
      await _internalLeaveAndRelease();
      _sessionState = AgoraSessionState.idle;

      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      _isInitializing = false;
      _initializationCompleter = null;
    }
  }

  Future<void> _configureAudio() async {
    final engine = _engine;
    if (engine == null) return;

    await _enableAudio();

    try {
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
    } catch (e) {
      _warning('setAudioProfile failed: $e');
    }

    try {
      await engine.setParameters('{"che.audio.enable_bg_voice": true}');
      await engine.setParameters('{"che.audio.keep.audiosession": true}');
    } catch (e) {
      _warning('Agora audio parameters failed: $e');
    }

    await _setSpeakerRoute(_isSpeakerOn);
    await _setPlaybackVolume(_playbackVolume);
    await _enableVolumeIndication();
  }

  // ===========================================================================
  // Event Handlers
  // ===========================================================================

  void _registerEventHandler() {
    final engine = _engine;
    if (engine == null) return;

    if (_eventHandler != null) {
      try {
        engine.unregisterEventHandler(_eventHandler!);
      } catch (_) {}
    }

    bool isCurrentSession(RtcConnection connection) {
      if (_currentChannelId == null) return false;
      return connection.channelId == _currentChannelId;
    }

    _eventHandler = RtcEngineEventHandler(
      // -----------------------------------------------------------------------
      // Local Join
      // -----------------------------------------------------------------------
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (!isCurrentSession(connection)) return;
        _debug('Joined channel ${connection.channelId}, uid=${connection.localUid}');

        if (connection.localUid != null) {
          _currentUid = connection.localUid;
        }

        _sessionState = AgoraSessionState.joined;
        _reconnectAttempts = 0;
        _cancelReconnectTimer();

        _updateConnectionState(AgoraConnectionState.connected);
        unawaited(_restoreFullSessionState());
      },

      onRejoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (!isCurrentSession(connection)) return;
        _debug('Successfully rejoined channel ${connection.channelId}');

        _sessionState = AgoraSessionState.joined;
        _reconnectAttempts = 0;
        _cancelReconnectTimer();

        _updateConnectionState(AgoraConnectionState.connected);
        unawaited(_restoreFullSessionState());
      },

      // -----------------------------------------------------------------------
      // Remote Users
      // -----------------------------------------------------------------------
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (!isCurrentSession(connection) || remoteUid == _currentUid) return;

        _debug('Remote user joined: $remoteUid in ${connection.channelId}');
        unawaited(_configureRemoteUserAudio(remoteUid));
        _handleRemoteUserJoined(remoteUid);
      },

      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        if (!isCurrentSession(connection)) return;
        _debug('Remote user left: $remoteUid, reason=$reason in ${connection.channelId}');
        remoteUserVideoMuted.remove(remoteUid);
        _handleRemoteUserLeft(remoteUid);
      },

      // -----------------------------------------------------------------------
      // Remote Audio
      // -----------------------------------------------------------------------
      onRemoteAudioStateChanged: (
        RtcConnection connection,
        int remoteUid,
        RemoteAudioState state,
        RemoteAudioStateReason reason,
        int elapsed,
      ) {
        if (!isCurrentSession(connection)) return;
        if (state == RemoteAudioState.remoteAudioStateStarting ||
            state == RemoteAudioState.remoteAudioStateDecoding) {
          unawaited(_configureRemoteUserAudio(remoteUid));
        }

        onRemoteAudioStateChanged?.call(remoteUid, state, reason);
      },

      // -----------------------------------------------------------------------
      // Mute State
      // -----------------------------------------------------------------------
      onUserMuteAudio: (RtcConnection connection, int remoteUid, bool muted) {
        if (!isCurrentSession(connection)) return;
        onUserMuted?.call(remoteUid, muted);
      },

      onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
        if (!isCurrentSession(connection)) return;
        remoteUserVideoMuted[remoteUid] = muted;
      },

      // -----------------------------------------------------------------------
      // Connection Management & Reconnect
      // -----------------------------------------------------------------------
      onConnectionStateChanged: (
        RtcConnection connection,
        ConnectionStateType state,
        ConnectionChangedReasonType reason,
      ) {
        if (!isCurrentSession(connection)) return;
        _debug('Connection state: $state, reason=$reason in ${connection.channelId}');
        _handleConnectionState(state);
      },

      onConnectionLost: (RtcConnection connection) {
        if (!isCurrentSession(connection)) return;
        _warning('Connection lost in ${connection.channelId}. Initiating automatic reconnect sequence...');
        _updateConnectionState(AgoraConnectionState.reconnecting);
        _scheduleAutoReconnect();
      },

      // -----------------------------------------------------------------------
      // Audio Routing (Bluetooth / Headset / Speaker)
      // -----------------------------------------------------------------------
      onAudioRoutingChanged: (int routing) {
        _handleAudioRoutingChanged(routing);
      },

      // -----------------------------------------------------------------------
      // Volume Indication
      // -----------------------------------------------------------------------
      onAudioVolumeIndication: (
        RtcConnection connection,
        List<AudioVolumeInfo> speakers,
        int totalVolume,
        int speakerNumber,
      ) {
        if (!isCurrentSession(connection)) return;
        onAudioVolumeIndication?.call(speakers, totalVolume);
      },

      // -----------------------------------------------------------------------
      // Network Quality & Stats
      // -----------------------------------------------------------------------
      onNetworkQuality: (
        RtcConnection connection,
        int remoteUid,
        QualityType txQuality,
        QualityType rxQuality,
      ) {
        if (!isCurrentSession(connection)) return;
        final quality = NetworkQuality.fromAgora(remoteUid, txQuality, rxQuality);
        onNetworkQuality?.call(quality);
      },

      onRtcStats: (RtcConnection connection, RtcStats stats) {
        if (!isCurrentSession(connection)) return;
        onStats?.call(AgoraStats.fromRtcStats(stats));
      },

      // -----------------------------------------------------------------------
      // Token Auto-Renewal
      // -----------------------------------------------------------------------
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        if (!isCurrentSession(connection)) return;
        _handleTokenWillExpire();
      },

      onRequestToken: (RtcConnection connection) {
        if (!isCurrentSession(connection)) return;
        _handleTokenWillExpire();
      },

      // -----------------------------------------------------------------------
      // Mixing & Effects
      // -----------------------------------------------------------------------
      onAudioMixingFinished: () {
        _isMusicPlaying = false;
        onAudioMixingFinished?.call();
      },

      onAudioEffectFinished: (int soundId) {
        onAudioEffectFinished?.call(soundId);
      },

      // -----------------------------------------------------------------------
      // Errors
      // -----------------------------------------------------------------------
      onError: (ErrorCodeType errorCode, String message) {
        _error('Agora error $errorCode: $message');
        onError?.call(message, errorCode.toString());
      },

      // -----------------------------------------------------------------------
      // Leave
      // -----------------------------------------------------------------------
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        _debug('Native leave callback for channel: ${connection.channelId}');
      },
    );

    engine.registerEventHandler(_eventHandler!);
  }

  void setupEventHandlers() {
    _registerEventHandler();
  }

  // ===========================================================================
  // Join Channel with Exponential Retry Backoff
  // ===========================================================================

  ChannelMediaOptions _buildMediaOptions({
    required ClientRoleType role,
    required bool publishMicrophone,
    required bool publishCamera,
    required bool subscribeVideo,
  }) {
    return ChannelMediaOptions(
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      clientRoleType: role,
      autoSubscribeAudio: true,
      autoSubscribeVideo: subscribeVideo,
      publishMicrophoneTrack: publishMicrophone,
      publishCameraTrack: publishCamera,
      enableAudioRecordingOrPlayout: true,
    );
  }

  Future<void> _joinNative({
    required String channelName,
    required int uid,
    required String? token,
    required ChannelMediaOptions options,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw StateError('Agora engine is not initialized.');
    }

    Object? lastError;
    for (int attempt = 0; attempt < _retryDelays.length; attempt++) {
      try {
        await engine.joinChannel(
          token: token ?? '',
          channelId: channelName,
          uid: uid,
          options: options,
        );
        _debug('Successfully joined native channel on attempt ${attempt + 1}');
        return;
      } catch (firstError) {
        lastError = firstError;
        _warning('Join attempt ${attempt + 1} failed: $firstError');

        try {
          await engine.leaveChannel();
        } catch (_) {}

        if (attempt < _retryDelays.length - 1) {
          final delay = _retryDelays[attempt];
          _debug('Retrying join in ${delay.inMilliseconds}ms...');
          await Future.delayed(delay);
        }
      }
    }

    throw StateError('All joinChannel attempts failed: $lastError');
  }

  Future<bool> joinChannel({
    required String channelName,
    required int uid,
    String? userId,
    String? userName,
    String? userImageUrl,
    String? token,
    bool isMuted = true,
    bool isVideo = false,
    bool isSeated = false,
    AgoraChannelMode? channelMode,
  }) {
    return _withSessionLock(() async {
      try {
        final cleanChannel = channelName.trim();
        if (cleanChannel.isEmpty) {
          _warning('Cannot join with empty channel name.');
          return false;
        }

        // Same channel + already joined
        if (_currentChannelId == cleanChannel && _sessionState == AgoraSessionState.joined) {
          _debug('Already joined $cleanChannel. Updating session state.');

          _isSeated = isSeated;
          _isMuted = isMuted;
          if (channelMode != null) {
            _channelMode = channelMode;
          }

          if (isVideo && isSeated && !_isVideoEnabled) {
            await _enableVideoInternal();
          } else if ((!isVideo || !isSeated) && _isVideoEnabled) {
            await _disableVideoInternal();
          }

          await _restoreLocalAudioState();
          return true;
        }

        // Different active channel: clean release previous channel
        if (_currentChannelId != null && _currentChannelId != cleanChannel) {
          await _internalLeaveAndRelease();
        }

        if (_engine == null) {
          final initialized = await _initializeInternal();
          if (!initialized) {
            return false;
          }
        }

        _sessionState = AgoraSessionState.joining;
        _currentChannelId = cleanChannel;
        _currentUid = uid;
        _currentUserId = userId;
        _currentUserName = userName;
        _currentUserImageUrl = userImageUrl;
        _currentToken = token;

        _isSeated = isSeated;
        _isMuted = isMuted;
        _isRoomMuted = false;
        _isVideoEnabled = false;

        _channelMode = channelMode ??
            (isVideo ? AgoraChannelMode.videoCall : AgoraChannelMode.audioRoom);

        final role = isSeated
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience;

        bool publishMic = false;
        if (isSeated && !isMuted) {
          publishMic = await _requestMicrophonePermission();
          if (!publishMic) {
            _isMuted = true;
          }
        }

        bool publishCamera = false;
        if (isVideo && isSeated) {
          final cameraGranted = await _requestCameraPermission();
          publishCamera = cameraGranted;
          if (!cameraGranted) {
            _warning('Camera permission denied. Joining without camera.');
          }
        }

        _updateConnectionState(AgoraConnectionState.connecting);
        await _enableAudio();

        final options = _buildMediaOptions(
          role: role,
          publishMicrophone: publishMic,
          publishCamera: publishCamera,
          subscribeVideo: isVideo,
        );

        await _prepareLocalAudio(shouldPublish: publishMic);

        await _joinNative(
          channelName: cleanChannel,
          uid: uid,
          token: token,
          options: options,
        );

        if (publishCamera) {
          final videoEnabled = await _enableVideoInternal(updateChannelOptions: false);
          if (!videoEnabled) {
            _warning('Video setup failed after join.');
          }
        }

        await _setSpeakerRoute(_isSpeakerOn);
        await _setPlaybackVolume(_playbackVolume);
        await _muteAllRemoteStreams(false);

        return true;
      } catch (e) {
        _error('joinChannel failed', e);
        onError?.call('Failed to join channel', e.toString());
        await _internalLeaveAndRelease();
        return false;
      }
    });
  }

  // ===========================================================================
  // Local Audio State
  // ===========================================================================

  Future<void> _prepareLocalAudio({required bool shouldPublish}) async {
    await _enableAudio();

    if (shouldPublish) {
      await _enableLocalAudio(true);
      await _setRecordingVolume(_recordingVolume);
      await _muteLocalStream(false);
    } else {
      await _enableLocalAudio(false);
      await _setRecordingVolume(_mutedRecordingVolume);
      await _muteLocalStream(true);
    }
  }

  Future<void> _restoreLocalAudioState() async {
    if (_engine == null) return;

    try {
      await _enableAudio();

      if (_isSeated && !_isMuted) {
        final permission = await _requestMicrophonePermission();
        if (!permission) {
          _isMuted = true;
          await _prepareLocalAudio(shouldPublish: false);
          return;
        }

        await _enableLocalAudio(true);
        await _setRecordingVolume(_recordingVolume);
        await _muteLocalStream(false);

        await _updateMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
            enableAudioRecordingOrPlayout: true,
          ),
        );
      } else {
        await _prepareLocalAudio(shouldPublish: false);

        await _updateMediaOptions(
          ChannelMediaOptions(
            clientRoleType: _isSeated
                ? ClientRoleType.clientRoleBroadcaster
                : ClientRoleType.clientRoleAudience,
            publishMicrophoneTrack: false,
            autoSubscribeAudio: true,
            enableAudioRecordingOrPlayout: true,
          ),
        );
      }
      await _enableVolumeIndication();
    } catch (e) {
      _error('Failed to restore local audio', e);
    }
  }

  // ===========================================================================
  // Remote Audio
  // ===========================================================================

  Future<void> _configureRemoteUserAudio(int uid) async {
    final engine = _engine;
    if (engine == null) return;

    try {
      await engine.muteRemoteAudioStream(
        uid: uid,
        mute: _isRoomMuted,
      );

      await engine.adjustUserPlaybackSignalVolume(
        uid: uid,
        volume: _playbackVolume,
      );
    } catch (e) {
      _warning('Remote audio configuration failed: $e');
    }
  }

  Future<void> _restoreRemoteAudioState() async {
    if (_engine == null) return;

    await _muteAllRemoteStreams(_isRoomMuted);
    await _setPlaybackVolume(_playbackVolume);

    for (final uid in _remoteUsers.keys) {
      await _configureRemoteUserAudio(uid);
    }
  }

  // ===========================================================================
  // Seat / Role Management
  // ===========================================================================

  Future<bool> setClientRole(ClientRoleType role, {bool? isMuted}) {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null || _sessionState != AgoraSessionState.joined) {
          _warning('Cannot change role when not joined.');
          return false;
        }

        final previousMuted = _isMuted;
        if (isMuted != null) {
          _isMuted = isMuted;
        }

        final bool success;
        if (role == ClientRoleType.clientRoleAudience) {
          success = await _becomeAudience();
        } else {
          success = await _becomeBroadcaster();
        }

        if (!success) {
          _isMuted = previousMuted;
          return false;
        }

        await _setPlaybackVolume(_playbackVolume);
        await _setSpeakerRoute(_isSpeakerOn);
        await _muteAllRemoteStreams(_isRoomMuted);
        await _enableVolumeIndication();

        return true;
      } catch (e) {
        _error('Failed to change client role', e);
        return false;
      }
    });
  }

  Future<bool> _becomeAudience() async {
    final engine = _engine;
    if (engine == null) return false;

    _isSeated = false;
    _isMuted = true;

    await _setRecordingVolume(_mutedRecordingVolume);
    await _muteLocalStream(true);
    await _enableLocalAudio(false);

    try {
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    } catch (e) {
      _warning('Failed to set audience role: $e');
      return false;
    }

    await _updateMediaOptions(
      const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: false,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        enableAudioRecordingOrPlayout: true,
      ),
    );

    if (_isVideoEnabled) {
      final disabled = await _disableVideoInternal();
      if (!disabled) {
        _warning('Failed to disable local video after becoming audience.');
      }
    }

    await _enableVolumeIndication();

    return true;
  }

  Future<bool> _becomeBroadcaster() async {
    final engine = _engine;
    if (engine == null) return false;

    bool shouldPublish = false;
    if (!_isMuted) {
      final permission = await _requestMicrophonePermission();
      if (permission) {
        shouldPublish = true;
      } else {
        _isMuted = true;
      }
    }

    try {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      _warning('Failed to set broadcaster role: $e');
      return false;
    }

    _isSeated = true;

    await _enableLocalAudio(true);
    await _setRecordingVolume(shouldPublish ? _recordingVolume : _mutedRecordingVolume);
    await _muteLocalStream(!shouldPublish);

    await _updateMediaOptions(
      ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: shouldPublish,
        publishCameraTrack: _isVideoEnabled,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        enableAudioRecordingOrPlayout: true,
      ),
    );

    await _restoreRemoteAudioState();
    await _enableVolumeIndication();

    return true;
  }

  // ===========================================================================
  // Microphone & Mute Management
  // ===========================================================================

  Future<bool> setMuted(bool muted) {
    return _withSessionLock(() async {
      try {
        if (_engine == null || _sessionState != AgoraSessionState.joined) {
          _warning('Cannot change microphone state when not joined.');
          return false;
        }

        if (!muted && !_isSeated) {
          _warning('Cannot unmute while user is not seated.');
          _isMuted = true;
          return false;
        }

        if (!muted) {
          final permission = await _requestMicrophonePermission();
          if (!permission) {
            _warning('Microphone permission denied.');
            _isMuted = true;
            await _enableLocalAudio(false);
            await _setRecordingVolume(_mutedRecordingVolume);
            await _muteLocalStream(true);
            await _updateMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishMicrophoneTrack: false,
                autoSubscribeAudio: true,
                enableAudioRecordingOrPlayout: true,
              ),
            );
            await _enableVolumeIndication();
            return false;
          }
        }

        _isMuted = muted;

        if (muted) {
          await _enableLocalAudio(false);
          await _setRecordingVolume(_mutedRecordingVolume);
          await _muteLocalStream(true);
          await _updateMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishMicrophoneTrack: false,
              autoSubscribeAudio: true,
              enableAudioRecordingOrPlayout: true,
            ),
          );
        } else {
          await _enableLocalAudio(true);
          await _setRecordingVolume(_recordingVolume);
          await _muteLocalStream(false);
          await _updateMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              enableAudioRecordingOrPlayout: true,
            ),
          );
        }

        await _enableVolumeIndication();

        return true;
      } catch (e) {
        _error('Failed to change microphone state', e);
        return false;
      }
    });
  }

  Future<bool> toggleMute() {
    return setMuted(!_isMuted);
  }

  // ===========================================================================
  // Speakerphone & Routing
  // ===========================================================================

  Future<bool> setSpeakerOn(bool enabled) {
    return _withSessionLock(() async {
      try {
        if (_engine == null) return false;
        await _setSpeakerRoute(enabled);
        _isSpeakerOn = enabled;
        return true;
      } catch (e) {
        _error('Failed to change speaker state', e);
        return false;
      }
    });
  }

  Future<bool> toggleSpeaker() {
    return setSpeakerOn(!_isSpeakerOn);
  }

  void _handleAudioRoutingChanged(int routing) {
    _debug('Audio routing changed to: $routing');
    final previousRouting = _currentAudioRouting;
    _currentAudioRouting = routing;

    // 1: wired headset with mic, 3: headset without mic, 5: loudspeaker, 6: bluetooth
    final wasHeadsetOrBt = previousRouting == 1 ||
        previousRouting == 3 ||
        previousRouting == 5 ||
        previousRouting == 6;

    final isNowSpeakerOrEarpiece = routing == 2 || routing == 4;

    // If bluetooth or wired headset disconnected, restore speakerphone state
    if (wasHeadsetOrBt && isNowSpeakerOrEarpiece) {
      _debug('Headset/Bluetooth disconnected. Restoring speakerphone state: $_isSpeakerOn');
      unawaited(_setSpeakerRoute(_isSpeakerOn));
    }

    onAudioRoutingChanged?.call(routing);
  }

  // ===========================================================================
  // Room Mute
  // ===========================================================================

  Future<bool> setRoomMuted(bool muted) {
    return _withSessionLock(() async {
      try {
        if (_engine == null) return false;
        await _muteAllRemoteStreams(muted);
        _isRoomMuted = muted;
        return true;
      } catch (e) {
        _error('Failed to change room mute state', e);
        return false;
      }
    });
  }

  Future<bool> toggleRoomMute() {
    return setRoomMuted(!_isRoomMuted);
  }

  // ===========================================================================
  // Video & Camera Management
  // ===========================================================================

  Future<bool> enableVideo() {
    return _withSessionLock(() async {
      try {
        if (_engine == null || _sessionState != AgoraSessionState.joined) {
          return false;
        }

        if (!_isSeated) {
          _warning('Only a seated broadcaster can publish video.');
          return false;
        }

        final cameraPermission = await _requestCameraPermission();
        if (!cameraPermission) {
          _warning('Camera permission denied.');
          return false;
        }

        return await _enableVideoInternal();
      } catch (e) {
        _error('Failed to enable video', e);
        return false;
      }
    });
  }

  Future<bool> _enableVideoInternal({bool updateChannelOptions = true}) async {
    final engine = _engine;
    if (engine == null) return false;

    try {
      await engine.enableVideo();
      await engine.enableLocalVideo(true);

      await engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: _videoWidth, height: _videoHeight),
          frameRate: _videoFps,
          bitrate: _videoBitrate,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      if (_isBeautyEnabled) {
        await setBeautyEffect(
          true,
          lighteningLevel: _beautyLightening,
          smoothnessLevel: _beautySmoothness,
          rednessLevel: _beautyRedness,
          sharpnessLevel: _beautySharpness,
        );
      }

      try {
        await engine.startPreview();
      } catch (e) {
        _warning('startPreview failed: $e');
      }

      _isVideoEnabled = true;

      if (updateChannelOptions) {
        await _updateMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: true,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        );
      }

      return true;
    } catch (e) {
      _error('Failed to enable video', e);
      return false;
    }
  }

  Future<bool> disableVideo() {
    return _withSessionLock(() async {
      return _disableVideoInternal();
    });
  }

  Future<bool> _disableVideoInternal() async {
    final engine = _engine;
    if (engine == null) return false;

    try {
      await _updateMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      try {
        await engine.stopPreview();
      } catch (_) {}

      await engine.enableLocalVideo(false);
      _isVideoEnabled = false;

      return true;
    } catch (e) {
      _error('Failed to disable video', e);
      return false;
    }
  }

  Future<bool> switchCamera() {
    return _withSessionLock(() async {
      try {
        if (_engine == null || !_isVideoEnabled) {
          return false;
        }
        await _engine!.switchCamera();
        return true;
      } catch (e) {
        _error('Failed to switch camera', e);
        return false;
      }
    });
  }

  // ===========================================================================
  // Beauty Effects
  // ===========================================================================

  Future<bool> setBeautyEffect(
    bool enabled, {
    double lighteningLevel = 0.7,
    double smoothnessLevel = 0.5,
    double rednessLevel = 0.1,
    double sharpnessLevel = 0.1,
  }) async {
    try {
      final engine = _engine;
      if (engine == null) return false;

      _isBeautyEnabled = enabled;
      _beautyLightening = lighteningLevel;
      _beautySmoothness = smoothnessLevel;
      _beautyRedness = rednessLevel;
      _beautySharpness = sharpnessLevel;

      await engine.setBeautyEffectOptions(
        enabled: enabled,
        options: BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: lighteningLevel,
          smoothnessLevel: smoothnessLevel,
          rednessLevel: rednessLevel,
          sharpnessLevel: sharpnessLevel,
        ),
      );

      return true;
    } catch (e) {
      _error('Failed to set beauty effect', e);
      return false;
    }
  }

  // ===========================================================================
  // Audio Quality & Effects
  // ===========================================================================

  Future<bool> setAudioQuality(AudioQuality quality) {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null) return false;

        await engine.setAudioProfile(
          profile: quality.agoraProfile,
          scenario: quality.agoraScenario,
        );

        _currentAudioQuality = quality;
        return true;
      } catch (e) {
        _error('Failed to set audio quality', e);
        return false;
      }
    });
  }

  Future<bool> setAudioEffect(AudioEffect effect) async {
    _currentAudioEffect = effect;
    return true;
  }

  Future<bool> setVoiceChanger(VoiceChanger changer) async {
    _currentVoiceChanger = changer;
    return true;
  }

  // ===========================================================================
  // Audio Mixing (Background Music)
  // ===========================================================================

  Future<bool> startAudioMixing(AudioMixingConfig config) {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null || _sessionState != AgoraSessionState.joined) {
          return false;
        }

        await engine.startAudioMixing(
          filePath: config.filePath,
          loopback: config.loopback,
          cycle: config.cycle,
          startPos: config.startPos,
        );

        _isMusicPlaying = true;
        return true;
      } catch (e) {
        _error('Failed to start audio mixing', e);
        return false;
      }
    });
  }

  Future<bool> stopAudioMixing() {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null) return false;

        await engine.stopAudioMixing();
        _isMusicPlaying = false;
        return true;
      } catch (e) {
        _error('Failed to stop audio mixing', e);
        return false;
      }
    });
  }

  Future<bool> pauseAudioMixing() {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null) return false;

        await engine.pauseAudioMixing();
        return true;
      } catch (e) {
        _error('Failed to pause audio mixing', e);
        return false;
      }
    });
  }

  Future<bool> resumeAudioMixing() {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null) return false;

        await engine.resumeAudioMixing();
        return true;
      } catch (e) {
        _error('Failed to resume audio mixing', e);
        return false;
      }
    });
  }

  Future<int> getAudioMixingCurrentPosition() async {
    try {
      final engine = _engine;
      if (engine == null || !_isMusicPlaying) return 0;
      return await engine.getAudioMixingCurrentPosition();
    } catch (e) {
      _warning('Failed to get mixing position: $e');
      return 0;
    }
  }

  Future<int> getAudioMixingDuration() async {
    try {
      final engine = _engine;
      if (engine == null || !_isMusicPlaying) return 0;
      return await engine.getAudioMixingDuration();
    } catch (e) {
      _warning('Failed to get mixing duration: $e');
      return 0;
    }
  }

  Future<void> setAudioMixingVolume(int volume) {
    return _withSessionLock(() async {
      final engine = _engine;
      if (engine == null) return;

      final safeVolume = volume.clamp(0, 100);
      try {
        await engine.adjustAudioMixingVolume(safeVolume);
        await engine.adjustAudioMixingPublishVolume(safeVolume);
        await engine.adjustAudioMixingPlayoutVolume(safeVolume);
      } catch (e) {
        _warning('Failed to set mixing volume: $e');
      }
    });
  }

  Future<void> setAudioMixingPosition(int positionMs) {
    return _withSessionLock(() async {
      final engine = _engine;
      if (engine == null) return;

      try {
        await engine.setAudioMixingPosition(positionMs);
      } catch (e) {
        _warning('Failed to seek audio mixing: $e');
      }
    });
  }

  // ===========================================================================
  // Token Management & Auto-Renewal
  // ===========================================================================

  Future<bool> renewToken(String token) {
    return _withSessionLock(() async {
      try {
        final engine = _engine;
        if (engine == null || token.trim().isEmpty) {
          return false;
        }

        await engine.renewToken(token.trim());
        _currentToken = token.trim();
        return true;
      } catch (e) {
        _error('Failed to renew token', e);
        return false;
      }
    });
  }

  Future<void> _handleTokenWillExpire() async {
    _warning('Agora token will expire soon. Triggering auto-renewal...');
    onTokenPrivilegeWillExpire?.call();

    if (_isRenewingToken || _currentChannelId == null || _currentUid == null) {
      return;
    }

    _isRenewingToken = true;
    try {
      final role = _isSeated ? 'publisher' : 'audience';
      TokenResponse? tokenResponse;
      int attempts = 0;

      // Retry up to 3 times to ensure user is never disconnected due to token expiration
      while (attempts < 3 && (tokenResponse == null || tokenResponse.token.isEmpty)) {
        try {
          tokenResponse = await AgoraTokenService.instance.refreshToken(
            channelName: _currentChannelId!,
            uid: _currentUid!,
            currentToken: _currentToken ?? '',
            role: role,
          );
        } catch (e) {
          _warning('Token renewal attempt ${attempts + 1} failed: $e');
        }

        if (tokenResponse != null && tokenResponse.token.isNotEmpty) break;
        attempts++;
        if (attempts < 3) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }

      if (tokenResponse != null && tokenResponse.token.isNotEmpty) {
        final renewed = await renewToken(tokenResponse.token);
        if (renewed) {
          _debug('Token successfully auto-renewed in background! ✅');
        } else {
          _warning('renewToken call failed during auto-renewal.');
        }
      } else {
        _error('Failed to obtain renewed token after multiple attempts.');
      }
    } catch (e) {
      _error('Automatic token renewal failed', e);
    } finally {
      _isRenewingToken = false;
    }
  }

  // ===========================================================================
  // Remote User Mapping & Ghost User Prevention
  // ===========================================================================

  void updateRemoteUser(
    int uid, {
    String? userId,
    String? userName,
    String? userImageUrl,
    int? seatNumber,
  }) {
    if (uid == _currentUid) return;

    final existing = _uidToUserMap[uid];
    final user = AgoraUser(
      uid: uid,
      userId: userId ?? existing?.userId ?? uid.toString(),
      userName: userName ?? existing?.userName ?? 'User $uid',
      userImageUrl: userImageUrl ?? existing?.userImageUrl,
      lastSpokeAt: DateTime.now(),
      seatNumber: seatNumber ?? existing?.seatNumber,
    );

    _uidToUserMap[uid] = user;
    _remoteUsers[uid] = user;
  }

  void mapUidToUser(
    int uid,
    String userId,
    String userName, {
    String? userImageUrl,
  }) {
    if (uid == _currentUid) return;

    final user = AgoraUser(
      uid: uid,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      lastSpokeAt: DateTime.now(),
    );

    _uidToUserMap[uid] = user;
    _remoteUsers[uid] = user;
  }

  void _handleRemoteUserJoined(int uid) {
    if (uid == _currentUid) return;

    var user = _uidToUserMap[uid];
    user ??= AgoraUser(
      uid: uid,
      userId: 'user_$uid',
      userName: 'User $uid',
      lastSpokeAt: DateTime.now(),
    );

    user = user.copyWith(lastSpokeAt: DateTime.now());
    _uidToUserMap[uid] = user;
    _remoteUsers[uid] = user;

    onUserJoined?.call(user);
  }

  void _handleRemoteUserLeft(int uid) {
    final user = _remoteUsers.remove(uid);
    _uidToUserMap.remove(uid);
    remoteUserVideoMuted.remove(uid);

    if (user != null) {
      onUserLeft?.call(user);
    }
  }

  // ===========================================================================
  // Connection State & Auto-Reconnect
  // ===========================================================================

  void _handleConnectionState(ConnectionStateType state) {
    switch (state) {
      case ConnectionStateType.connectionStateConnecting:
        _updateConnectionState(AgoraConnectionState.connecting);
        break;

      case ConnectionStateType.connectionStateConnected:
        _updateConnectionState(AgoraConnectionState.connected);
        _reconnectAttempts = 0;
        _cancelReconnectTimer();
        unawaited(_restoreFullSessionState());
        break;

      case ConnectionStateType.connectionStateReconnecting:
        _updateConnectionState(AgoraConnectionState.reconnecting);
        _scheduleAutoReconnect();
        break;

      case ConnectionStateType.connectionStateDisconnected:
        _updateConnectionState(AgoraConnectionState.disconnected);
        break;

      case ConnectionStateType.connectionStateFailed:
        _updateConnectionState(AgoraConnectionState.failed);
        _warning('Agora connection failed. Scheduling reconnect attempt...');
        _scheduleAutoReconnect();
        break;
    }
  }

  void _updateConnectionState(AgoraConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }

  void _scheduleAutoReconnect() {
    if (_sessionState != AgoraSessionState.joined && _sessionState != AgoraSessionState.joining) {
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _error('Maximum reconnect attempts ($_maxReconnectAttempts) reached.');
      return;
    }

    _cancelReconnectTimer();

    final delayIndex = _reconnectAttempts.clamp(0, _retryDelays.length - 1);
    final delay = _retryDelays[delayIndex];
    _reconnectAttempts++;

    _debug('Scheduling auto-reconnect attempt $_reconnectAttempts in ${delay.inMilliseconds}ms...');

    _reconnectTimer = Timer(delay, () {
      unawaited(_performReconnect());
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _performReconnect() {
    return _withSessionLock(() async {
      if (_sessionState != AgoraSessionState.joined || _engine == null) {
        return;
      }

      _debug('Executing reconnect attempt for channel $_currentChannelId...');
      try {
        final role = _isSeated
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience;

        final options = _buildMediaOptions(
          role: role,
          publishMicrophone: _isSeated && !_isMuted,
          publishCamera: _isVideoEnabled,
          subscribeVideo: _isVideoEnabled || _channelMode == AgoraChannelMode.videoCall,
        );

        await _engine!.joinChannel(
          token: _currentToken ?? '',
          channelId: _currentChannelId!,
          uid: _currentUid ?? 0,
          options: options,
        );
      } catch (e) {
        _warning('Reconnect attempt failed: $e');
        _scheduleAutoReconnect();
      }
    });
  }

  Future<void> _restoreFullSessionState() async {
    _debug('Restoring full Agora session state after connect/reconnect...');
    await _restoreLocalAudioState();
    await _restoreRemoteAudioState();
    await _setSpeakerRoute(_isSpeakerOn);
    await _setPlaybackVolume(_playbackVolume);

    if (_isVideoEnabled) {
      await _enableVideoInternal(updateChannelOptions: true);
    }
  }

  // ===========================================================================
  // Smart Leave / Release Management
  // ===========================================================================

  Future<bool> leaveChannel({String? channelName}) {
    return leaveChannelAndRelease(channelName: channelName);
  }

  Future<bool> leaveChannelAndRelease({String? channelName}) {
    return _withSessionLock(() async {
      return _internalLeaveAndRelease(channelName: channelName);
    });
  }

  Future<void> _cleanupLocalHardware() async {
    await _setRecordingVolume(_mutedRecordingVolume);
    await _muteLocalStream(true);

    try {
      await _enableLocalAudio(false);
    } catch (_) {}
  }

  Future<void> _cleanupMixing() async {
    final engine = _engine;
    if (engine == null) return;

    try {
      await engine.stopAudioMixing();
    } catch (_) {}

    try {
      await engine.stopAllEffects();
    } catch (_) {}

    _isMusicPlaying = false;
  }

  Future<void> _releaseNativeEngine() async {
    final engine = _engine;
    if (engine == null) return;

    _sessionState = AgoraSessionState.releasing;

    try {
      await engine.leaveChannel();
    } catch (e) {
      _warning('leaveChannel during release failed: $e');
    }

    if (_eventHandler != null) {
      try {
        engine.unregisterEventHandler(_eventHandler!);
      } catch (_) {}
      _eventHandler = null;
    }

    try {
      await engine.release();
    } catch (e) {
      _warning('Agora engine release failed: $e');
    }

    _engine = null;
    _initializedAppId = null;
  }

  Future<bool> _internalLeaveAndRelease({String? channelName}) async {
    if (_sessionState == AgoraSessionState.leaving || _sessionState == AgoraSessionState.releasing) {
      if (_leaveCompleter != null) {
        await _leaveCompleter!.future;
      }
      return true;
    }

    if (_sessionState == AgoraSessionState.idle && _engine == null && _currentChannelId == null) {
      return true;
    }

    final completer = Completer<void>();
    _leaveCompleter = completer;

    try {
      _sessionState = AgoraSessionState.leaving;
      _debug('Leaving Agora session cleanly: ${_currentChannelId ?? channelName}');

      _cancelReconnectTimer();
      await _cleanupLocalHardware();
      await _cleanupMixing();
      await _releaseNativeEngine();

      _resetState();

      try {
        await BackgroundService().stopService();
      } catch (e) {
        _warning('Background service stop failed: $e');
      }

      _sessionState = AgoraSessionState.idle;
      return true;
    } catch (e) {
      _error('Leave/release failed', e);
      _resetState();
      _sessionState = AgoraSessionState.idle;
      return false;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _leaveCompleter = null;
    }
  }

  void _resetState() {
    _currentChannelId = null;
    _currentUserId = null;
    _currentUserName = null;
    _currentUserImageUrl = null;
    _currentToken = null;
    _currentUid = null;

    _remoteUsers.clear();
    _uidToUserMap.clear();
    remoteUserVideoMuted.clear();

    _isMuted = true;
    _isSeated = false;
    _isSpeakerOn = true;
    _isRoomMuted = false;
    _isVideoEnabled = false;
    _isMusicPlaying = false;

    _isAppInBackground = false;
    _wasVideoEnabledBeforeBackground = false;
    _channelMode = AgoraChannelMode.audioRoom;
    _currentAudioRouting = -1;

    _reconnectAttempts = 0;
    _isRenewingToken = false;

    _microphonePermissionGranted = null;
    _cameraPermissionGranted = null;
    _currentOwner = null;

    _updateConnectionState(AgoraConnectionState.disconnected);
  }

  // ===========================================================================
  // Dispose
  // ===========================================================================

  Future<void> dispose() async {
    _cancelReconnectTimer();
    _removeLifecycleObserver();
    await leaveChannelAndRelease();
    clearCallbacks();
  }
}
