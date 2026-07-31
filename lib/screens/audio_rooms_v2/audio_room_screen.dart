// ignore_for_file: deprecated_member_use
import 'package:get/get.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/widgets/spinning_dice_widget.dart';
import 'package:chat_messenger/services/premium_room_service.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_mode_selector.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/live_ended_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:chat_messenger/models/chat.dart' as chat_model;
import 'package:chat_messenger/models/message.dart' as message_model;
import 'package:chat_messenger/api/message_api.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/room_share.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';

import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_controls.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_animation_overlay.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_selection_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/waiting_list_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_pk_settings_sheet.dart';
import 'widgets/room_decor_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/banner_carousel.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/modern_room_card.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/pk_battle_overlay.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_selection_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_widget.dart';
import 'package:chat_messenger/AdminPane/models/gift.dart';
import 'package:chat_messenger/AdminPane/services/gift_service.dart';
import 'package:chat_messenger/models/entrance_effect.dart';
import 'package:chat_messenger/services/entrance_effect_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/entrance_effect_overlay.dart';
import 'package:chat_messenger/controllers/follow_controller.dart';
import 'package:chat_messenger/widgets/follow_button.dart';
import 'package:chat_messenger/services/emoji_chat_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_flight_overlay.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_event_portal_widget.dart';
import 'package:chat_messenger/services/push_notification_service.dart';
import 'package:marquee/marquee.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/youtube_sync_player.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo_game_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/youtube_selection_sheet.dart';

import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/animated_notification.dart';
import 'package:chat_messenger/screens/messages/message_screen.dart';
import 'package:chat_messenger/models/agora_models.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/speaking_ripple_animation.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/room_pk_repository.dart';
import 'package:chat_messenger/models/room_pk_match.dart';
import 'dart:io';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/floating_music_player.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:video_player/video_player.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/room_member_screen.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_setup_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_setup_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_result_sheet.dart';

/// Audio Room Screen - Individual room interface
class AudioRoomScreen extends StatefulWidget {
  final AudioRoomV2 room;
  final AudioRoomsBloc audioRoomsBloc;
  final bool isRestoring;

  const AudioRoomScreen({
    super.key,
    required this.room,
    required this.audioRoomsBloc,
    this.isRestoring = false,
  });

  @override
  State<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends State<AudioRoomScreen>
    with WidgetsBindingObserver {
  late AudioRoomV2 _currentRoom;
  late User _currentUser;
  List<EmojiChatMessage> _chatMessages = [];
  String? _currentUserLevelBadgeUrl;
  List<dynamic>? _roomLevelConfigData;
  StreamSubscription<DocumentSnapshot>? _roomConfigSub;
  bool _isCurrentUserHost = false;
  bool _isMuted = true;
  bool _isSpeakerOn = false;
  bool _isMinimizing = false; // Track if user is minimizing vs leaving
  final Set<String> _invitedUserIds = {};

  // Chat related variables
  StreamSubscription<List<EmojiChatMessage>>? _chatSubscription;

  // Video controllers cache
  final Map<int, VideoViewController> _videoControllers = {};

  VideoViewController _getVideoController(int uid, RtcEngine engine) {
    if (_videoControllers.containsKey(uid)) {
      return _videoControllers[uid]!;
    }

    VideoViewController controller;
    if (uid == 0) {
      controller = VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      );
    } else {
      controller = VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _currentRoom.id),
      );
    }

    _videoControllers[uid] = controller;
    return controller;
  }

  // PK Battle variables
  final RoomPKRepository _pkRepository = RoomPKRepository();
  StreamSubscription<List<RoomPKInvite>>? _pkInviteSubscription;
  late final DateTime
      _joinTime; // Track when user joined to filter old messages
  final List<EmojiChatMessage> _syntheticMessages = [];
  bool _hasInjectedAnnouncementOnJoin = false;

  void _injectAnnouncement(String announcement) {
    if (announcement.trim().isEmpty) return;

    final announcementMsg = EmojiChatMessage(
      id: 'announcement_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'system',
      username: 'System',
      message: announcement,
      messageType: EmojiMessageType.announcement,
      timestamp: DateTime.now(),
      roomId: _currentRoom.id,
    );

    _syntheticMessages.add(announcementMsg);
  }

  // Agora related variables
  bool _agoraChannelJoined = false;
  List<AgoraUser> _agoraUsers = [];
  int? _agoraUid;

  // Gift related
  final GiftService _giftService = GiftService();
  Timer? _giftCleanupTimer;
  final Map<int, GlobalKey> _seatKeys = {};
  final List<FlyingGiftItem> _flyingGifts = [];

  // Entrance effect related
  final EntranceEffectService _entranceEffectService = EntranceEffectService();

  // Follow related
  late final FollowController _followController;

  // Real-time Frame Update Subscription
  StreamSubscription<String>? _frameSubscription;
  // Static cached level configurations
  static List<dynamic>? _cachedSendingLevels;

  // Chat auto-delete timer
  Timer? _autoDeleteTimer;

  // Track pop authorization & offline timer
  bool _canPopScreen = false;
  Timer? _offlineTimer;

  bool _isHostVideoEnabled = true; // Whether the broadcaster's video is on
  bool _isRoomMuted = false; // Whether the incoming room audio is muted

  // Beauty Camera State
  bool _isBeautyCameraEnabled = false;
  double _beautyLighteningLevel = 0.7;
  double _beautySmoothnessLevel = 0.5;
  double _beautyRednessLevel = 0.1;
  double _beautySharpnessLevel = 0.1;

  // Music Player State
  bool _showMusicPlayer = false;

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
    debugPrint('🎯 [AudioRoom] ===== INIT STATE STARTED =====');

    // Reset minimizing flag when screen is created/restored
    _isMinimizing = false;
    debugPrint('🔼 [AudioRoom] Screen initialized, minimizing flag reset');

    // Add lifecycle observer for background audio handling
    WidgetsBinding.instance.addObserver(this);

    // End wakelock to keep CPU running
    WakelockPlus.enable();

    // Start background service to keep network alive
    BackgroundService().startService();

    // Initialize follow controller
    _followController = FollowController();
    _currentRoom = widget.room;

    // Set join time — restore original if coming back from minimize, otherwise use now
    if (widget.isRestoring) {
      final minimizedController = _getMinimizedController();
      _joinTime = minimizedController.originalJoinTime ??
          DateTime.now().subtract(const Duration(seconds: 5));
      debugPrint('🔼 [AudioRoom] Restored original join time: $_joinTime');
    } else {
      _joinTime = DateTime.now();
    }

    // Get current user with null safety
    try {
      _currentUser = AuthController.instance.currentUser;
      debugPrint(
          '🎯 Current user loaded: ${_currentUser.userId} - ${_currentUser.fullname}');
      // Load current user's level badge
      _loadConfigs();
      _isCurrentUserHost = _currentUser.userId == widget.room.creatorId;
      Get.put(RouletteController(widget.room.id, isHost: _isCurrentUserHost),
          tag: 'roulette_${widget.room.id}');
    } catch (e) {
      debugPrint('🎯 Error getting current user: $e');
      // Handle null user case - navigate back or show error
      Navigator.of(context).pop();
      return;
    }

    // Debug participant list
    debugPrint('🎯 Room participants: ${_currentRoom.participants.length}');
    for (var participant in _currentRoom.participants) {
      debugPrint(
          '🎯 Participant: ${participant.userId} - ${participant.userName}');
    }

    // Safety check: don't use a closed BLoC
    if (widget.audioRoomsBloc.isClosed) {
      debugPrint('🎤 [AudioRoom] ❌ BLoC is closed, cannot initialize room');
      // Navigating back if the BLoC is closed
      Navigator.of(context).pop();
      return;
    }

    // Check if current user is a participant
    if (!_currentRoom.isParticipant(_currentUser.userId)) {
      // Automatically join the room if user is not a participant
      widget.audioRoomsBloc.add(JoinAudioRoom(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        userName: _currentUser.fullname,
        userImageUrl: _currentUser.photoUrl,
        userFrameId: _currentUser.customization?.selectedFrameId,
      ));
    }

    // Always initialize Agora for the audio room regardless of participant status
    _initializeAgoraForRoom();

    // Send join/re-join message to chat - ONLY if not restoring from minimize
    if (!widget.isRestoring) {
        EmojiChatService.sendPresenceMessage(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          username: _currentUser.fullname,
          userAvatar: _currentUser.photoUrl,
          isJoin: true,
        );
      } else {
        debugPrint(
            '🔼 [AudioRoom] Skipping join message - restoring from minimized state');
      }

    // Start listening to room updates
    widget.audioRoomsBloc.add(ListenToRoomUpdates(roomId: widget.room.id));

    // Start listening to chat messages
    _startChatListener();

    // Start listening to PK Invites if host
    if (_isCurrentUserHost) {
      _startPKInviteListener();
    }

    // Gift transactions will be handled by StreamBuilder in the UI
    debugPrint(
        '🎁 [AudioRoom] Gift transactions will be handled by StreamBuilder');

    // Start periodic cleanup of old gifts
    _startGiftCleanupTimer();

    // Start auto-delete chat timer (only runs if host)
    _startAutoDeleteTimer();

    // Listen to real-time frame updates
    _frameSubscription = AuthController.instance.currentFrameUrl.listen((url) {
      debugPrint('🖼️ [AudioRoom] Frame updated to: $url, rebuilding UI...');
      if (mounted) {
        setState(() {});
      }
    });

    debugPrint('🎯 [AudioRoom] ===== INIT STATE COMPLETE =====');
  }

  Future<void> _requestInitialPermissions() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('⚠️ [AudioRoom] Microphone permission denied');
      } else {
        debugPrint('✅ [AudioRoom] Microphone permission granted');
        // If the user is the host/speaker and was already supposed to be unmuted, force sync
        if (_isCurrentUserSpeaker && !_isCurrentUserMuted) {
          widget.audioRoomsBloc.add(const SetMicrophoneMute(muted: false));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AudioRoom] Error requesting microphone permission: $e');
    }
  }

  /// Start periodic auto-delete chat timer (runs every 1 minute)
  void _startAutoDeleteTimer() {
    _autoDeleteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isCurrentUserHost) {
        debugPrint(
            '🧹 [AudioRoom] Running periodic chat cleanup ( > 30 mins )...');
        EmojiChatService.cleanupOldMessages(widget.room.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload background image after dependencies are available
    _preloadBackgroundImage();
  }

  /// Preload background image for instant display using cache
  void _preloadBackgroundImage() {
    final backgroundUrl = _currentRoom.settings.backgroundImageUrl;
    if (backgroundUrl != null && backgroundUrl.startsWith('http')) {
      // Preload image asynchronously into Flutter's image cache without blocking
      precacheImage(CachedNetworkImageProvider(backgroundUrl), context);
    }
  }

  String? _getDynamicRoomLevelBadgeUrl() {
    if (_roomLevelConfigData == null) return null;
    final currentLevel = AudioRoomV2.calculateRoomLevel(
        _currentRoom.totalRevenue, _roomLevelConfigData);
    for (final lvl in _roomLevelConfigData!) {
      if (lvl['levelNumber'] == currentLevel) {
        return lvl['imageUrl'] as String?;
      }
    }
    return null;
  }

  Future<void> _loadConfigs() async {
    try {
      // 1. Load Sending Config for current user using static cache
      final user = AuthController.instance.currentUser;
      final level = user.sendingLevel?.level;
      if (level != null) {
        if (_cachedSendingLevels == null) {
          final sendDoc = await FirebaseFirestore.instance
              .collection('level_configurations')
              .doc('sending_config')
              .get();
          if (sendDoc.exists) {
            _cachedSendingLevels = sendDoc.data()?['levels'] as List<dynamic>?;
          }
        }

        if (_cachedSendingLevels != null) {
          for (final lvl in _cachedSendingLevels!) {
            if (lvl['levelNumber'] == level) {
              if (mounted) {
                setState(() {
                  _currentUserLevelBadgeUrl = lvl['imageUrl'] as String?;
                });
              } else {
                _currentUserLevelBadgeUrl = lvl['imageUrl'] as String?;
              }
              debugPrint(
                  '🎯 Loaded current user level badge URL inside _AudioRoomScreenState from cache: $_currentUserLevelBadgeUrl');
              break;
            }
          }
        }
      }

      // 2. Load Room Config using real-time stream
      _roomConfigSub = FirebaseFirestore.instance
          .collection('level_configurations')
          .doc('room_config')
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _roomLevelConfigData = doc.data()?['levels'] as List<dynamic>?;
          });
        }
      });
    } catch (e) {
      debugPrint(
          '❌ Error loading level configurations in _AudioRoomScreenState: $e');
    }
  }

  void _startPKInviteListener() {
    _pkInviteSubscription = _pkRepository
        .listenToIncomingInvites(_currentRoom.id)
        .listen((invites) {
      if (!mounted) return;
      for (var invite in invites) {
        if (!_invitedUserIds.contains(invite.id)) {
          _invitedUserIds.add(invite.id);
          _showPKInviteDialog(invite);
        }
      }
    });
  }

  void _showPKInviteDialog(RoomPKInvite invite) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PK Challenge Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage:
                  CachedNetworkImageProvider(invite.senderRoomImageUrl),
            ),
            const SizedBox(height: 10),
            Text('${invite.senderRoomName} has challenged you to a PK battle!'),
            const SizedBox(height: 5),
            Text('Duration: ${invite.durationMinutes} mins',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pkRepository.rejectInvite(invite.id);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pkRepository.acceptInvite(
                invite: invite,
                targetRoomName: _currentRoom.name,
                targetRoomImageUrl: _currentRoom.imageUrl ?? '',
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  /// Start listening to chat messages
  void _startChatListener() {
    // Use the emoji chat message stream for full emoji support
    _chatSubscription =
        EmojiChatService.getEmojiChatMessagesStream(_currentRoom.id).listen(
      (messages) {
        if (!mounted) {
          debugPrint(
              '💬 [AudioRoom] [$hashCode] ⚠️ Listener fired after dispose! Skipping.');
          return;
        }

        // Filter messages to hide history before join
        // But ALWAYS show messages if we are restoring from minimized state (optional, but requested feature is to hide old messages)
        // User request: "only see messages after him" implies a fresh start.
        // We use _joinTime initialized in initState.

        final newMessages = messages.where((msg) {
          // Subtract 30 seconds to prevent clock synchronization issues and guarantee immediate messages show up perfectly
          return msg.timestamp
              .isAfter(_joinTime.subtract(const Duration(seconds: 30)));
        }).toList();

        debugPrint(
            '💬 [AudioRoom] [$hashCode] Received ${messages.length} messages, filtered to ${newMessages.length}');

        // Inject initial announcement
        if (!_hasInjectedAnnouncementOnJoin &&
            (_currentRoom.settings.announcement?.isNotEmpty ?? false)) {
          _injectAnnouncement(_currentRoom.settings.announcement!);
          _hasInjectedAnnouncementOnJoin = true;
        }

        final allMessages = [...newMessages, ..._syntheticMessages];
        allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Update local emoji messages directly
        setState(() {
          _chatMessages = allMessages;
        });
      },
      onError: (error) {
        debugPrint('💬 Error listening to chat messages: $error');
      },
    );
  }

  /// Clean up extremely old gifts (older than 60 seconds)
  void _cleanupExtremelyOldGifts(List<GiftTransaction> allTransactions) {
    if (!_isCurrentUserHost) return; // Only host handles long-term cleanup

    final now = DateTime.now();
    final oldTransactions = allTransactions.where((transaction) {
      final timeDiff = now.difference(transaction.timestamp).inSeconds;
      return timeDiff > 60; // Older than 60 seconds
    }).toList();

    if (oldTransactions.isNotEmpty) {
      debugPrint(
          '🧹 [AudioRoom] Cleaning up ${oldTransactions.length} extremely old gift transactions');
      _deleteDisplayedGifts(oldTransactions);
    }
  }

  /// Archive gift transactions to user_received_gifts, then delete from gift_transactions
  Future<void> _deleteDisplayedGifts(List<GiftTransaction> transactions) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final transaction in transactions) {
        // Delete from gift_transactions (user_received_gifts is already persisted permanently with full metadata in sendGift)
        batch.delete(
          firestore.collection('gift_transactions').doc(transaction.id),
        );
      }

      await batch.commit();
      debugPrint(
          '🗑️ [AudioRoom] Cleared ${transactions.length} gift transactions from display queue');
    } catch (e) {
      debugPrint('❌ [AudioRoom] Error clearing gift transactions: $e');
    }
  }

  /// Delete displayed entrance effects from Firestore
  Future<void> _deleteDisplayedEntranceEffects(
      List<EntranceEffect> effects) async {
    try {
      for (final effect in effects) {
        await _entranceEffectService.deleteEntranceEffect(
          widget.room.id,
          effect.effectId,
        );
      }
      debugPrint(
          '🗑️ [AudioRoom] Deleted ${effects.length} entrance effects from Firestore');
    } catch (e) {
      debugPrint('❌ [AudioRoom] Error deleting entrance effects: $e');
    }
  }

  /// Start periodic cleanup timer for old gifts
  void _startGiftCleanupTimer() {
    _giftCleanupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      debugPrint('🧹 [AudioRoom] Running periodic gift cleanup...');
      // This will trigger the StreamBuilder to clean up old gifts
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 [AudioRoom] App lifecycle changed to: $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [AudioRoom] App resumed - refreshing audio session...');
      // Re-enable speakerphone to ensure audio route is active
      // Using a slight delay to allow the OS to give audio focus back
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_agoraChannelJoined) {
          // We can toggle to earpiece and back to speaker to force route update,
          // but normally setDefaultAudioRouteToSpeakerphone(true) is enough.
          // Since we don't have direct access to engine here easily without importing agora_rtc_engine,
          // we use the BLoC or Service.
          // However, ToggleSpeaker event flips the state. We want to SET it.
          // Let's assume the service handles "setSpeakerOn".
          // We can just trigger a manual update if we had a "RefreshAudio" event.
          // For now, let's use a workaround:
          // If speaker was ON, toggle it OFF and ON again? No that's jarring.

          // Actually, the issue is often that the audio session was deactivated.
          // We can invoke a specific event or method if we had one.
          // Since we don't, we'll try to trigger a state update.

          // If we have access to AgoraService singleton (we don't import it directly as instance but maybe we can?)
          // AgoraService is a singleton!
          // import 'package:chat_messenger/services/agora_service.dart'; is not imported?
          // It is imported in BLoC, not here.
          // Wait, line 29 imports `agora_models.dart`.
          // Let's check imports.
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Disable WakeLock safely
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint('Error disabling Wakelock: $e');
    }

    // Stop background service safely
    try {
      BackgroundService().stopService();
    } catch (e) {
      debugPrint('Error stopping BackgroundService: $e');
    }

    // Cancel timers safely
    try {
      _giftCleanupTimer?.cancel();
      _pkInviteSubscription?.cancel();
      _autoDeleteTimer?.cancel();
      _offlineTimer?.cancel();
    } catch (e) {
      debugPrint('Error canceling timers: $e');
    }

    // Clean up subscriptions safely
    try {
      _chatSubscription?.cancel();
      _frameSubscription?.cancel();
      _roomConfigSub?.cancel();
    } catch (e) {
      debugPrint('Error canceling subscriptions: $e');
    }

    // Dispose follow controller safely
    try {
      _followController.dispose();
    } catch (e) {
      debugPrint('Error disposing follow controller: $e');
    }

    // Dispose roulette controller safely
    try {
      if (Get.isRegistered<RouletteController>(
          tag: 'roulette_${widget.room.id}')) {
        Get.delete<RouletteController>(tag: 'roulette_${widget.room.id}');
      }
    } catch (e) {
      debugPrint('Error disposing roulette controller: $e');
    }

    // IMPORTANT: Only leave Agora and stop updates if NOT minimizing
    if (!_isMinimizing) {
      // Disable WakeLock safely
      try {
        WakelockPlus.disable();
      } catch (e) {
        debugPrint('Error disabling Wakelock: $e');
      }

      // Stop background service safely
      try {
        BackgroundService().stopService();
      } catch (e) {
        debugPrint('Error stopping BackgroundService: $e');
      }

      try {
        if (_agoraChannelJoined) {
          widget.audioRoomsBloc.add(const LeaveAgoraChannel());
          debugPrint('🎤 [AudioRoom] Leaving Agora channel (actual leave)');
        }
        widget.audioRoomsBloc.add(const StopListeningToRoomUpdates());
      } catch (e) {
        debugPrint('Error adding leave events to bloc: $e');
      }

      _agoraChannelJoined = false;
      _agoraUid = null;
    } else {
      debugPrint(
          '🔽 [AudioRoom] Dispose called but minimizing - keeping connections alive');
    }

    try {
      _videoControllers.clear();
      super.dispose();
    } catch (e) {
      debugPrint('Error in super.dispose: $e');
    }
  }

  /// Handle leaving the room with beautiful bottom sheet
  void _handleLeaveRoom() {
    _showExitConfirmationBottomSheet();
  }

  /// Show exit & minimize options menu as a right side drawer
  void _showExitConfirmationBottomSheet() {
    Future<List<AudioRoomV2>> trendingRoomsFuture =
        AudioRoomsRepository().getAllRooms();
    String selectedCategory = 'All';
    final List<String> categories = [
      'All',
      'Game',
      'Event',
      'PK',
      'Islamic',
      'Talk Show'
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: const Color(
                    0xFF111111), // Dark background matching screenshot
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        // Top Action Buttons (Minimize and Leave)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTopActionButton(
                              icon: Icons.close_fullscreen_rounded,
                              label: 'Minimize',
                              iconColor: Colors.white,
                              textColor: Colors.white,
                              onTap: () =>
                                  Navigator.of(context).pop('minimize'),
                            ),
                            _buildTopActionButton(
                              icon: Icons.power_settings_new_rounded,
                              label: 'Leave',
                              iconColor: Colors.redAccent,
                              textColor: Colors.redAccent,
                              onTap: () => Navigator.of(context).pop('leave'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Banner Image
                        const BannerCarousel(height: 75),

                        const SizedBox(height: 16),

                        // Category Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              ...categories.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedCategory = category;
                                      });
                                    },
                                    child: _buildCategoryChip(category,
                                        isSelected:
                                            selectedCategory == category),
                                  ),
                                );
                              }).toList(),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    trendingRoomsFuture =
                                        AudioRoomsRepository().getAllRooms();
                                  });
                                },
                                child: const Icon(Icons.refresh_rounded,
                                    color: Colors.white70, size: 24),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Trending Rooms Grid
                        Expanded(
                          child: FutureBuilder<List<AudioRoomV2>>(
                            future: trendingRoomsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.blueAccent));
                              }
                              if (snapshot.hasError) {
                                return Center(
                                    child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Failed to load rooms.',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          trendingRoomsFuture =
                                              AudioRoomsRepository()
                                                  .getAllRooms();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.pinkAccent),
                                      child: const Text('Try Again',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ));
                              }

                              final allRooms = snapshot.data ?? [];
                              final popularRooms = allRooms
                                  .where((r) =>
                                      r.id != widget.room.id &&
                                      (selectedCategory == 'All' ||
                                          r.category == selectedCategory))
                                  .toList();
                              popularRooms.sort((a, b) => b.participantCount
                                  .compareTo(a.participantCount));

                              if (popularRooms.isEmpty) {
                                return const Center(
                                    child: Text('No trending rooms right now.',
                                        style:
                                            TextStyle(color: Colors.white54)));
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: popularRooms.length,
                                itemBuilder: (context, index) {
                                  final room = popularRooms[index];
                                  return ModernRoomCard(
                                    room: room,
                                    onTap: () {
                                      Navigator.of(context)
                                          .pop(); // Close bottom sheet

                                      // Cleanly leave current room directly (skips popping the screen inside _handleActualLeave)
                                      setState(() {
                                        _canPopScreen = true;
                                      });
                                      _getMinimizedController()
                                          .clearMinimizedRoom();
                                      widget.audioRoomsBloc.add(LeaveAudioRoom(
                                        roomId: _currentRoom.id,
                                        userId: _currentUser.userId,
                                      ));

                                      // Navigate to new room immediately
                                      final newBloc = AudioRoomsBloc(
                                          repository: AudioRoomsRepository());
                                      final currentUser =
                                          AuthController.instance.currentUser;

                                      if (!room
                                          .isParticipant(currentUser.userId)) {
                                        newBloc.add(JoinAudioRoom(
                                          roomId: room.id,
                                          userId: currentUser.userId,
                                          userName: currentUser.fullname,
                                          userImageUrl: currentUser.photoUrl,
                                          userFrameId: currentUser
                                              .customization?.selectedFrameId,
                                        ));
                                      }

                                      Get.off(
                                          () => AudioRoomScreen(
                                                room: room,
                                                audioRoomsBloc: newBloc,
                                              ),
                                          preventDuplicates: false);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    ).then((result) {
      if (result == 'minimize') {
        _handleMinimize();
      } else if (result == 'leave') {
        _handleActualLeave(fromBottomSheet: false);
      }
    });
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  /// Get or initialize MinimizedRoomController
  MinimizedRoomController _getMinimizedController() {
    try {
      return Get.find<MinimizedRoomController>();
    } catch (e) {
      // Controller not found, initialize it
      debugPrint(
          '⚠️ [AudioRoom] MinimizedRoomController not found, initializing...');
      return Get.put(MinimizedRoomController());
    }
  }

  /// Handle minimize action
  void _handleMinimize() {
    // Set minimizing flag BEFORE popping
    _isMinimizing = true;

    setState(() {
      _canPopScreen = true;
    });

    // Get or initialize controller
    final minimizedController = _getMinimizedController();

    // Minimize the room (save state) - also pass the BLoC so it doesn't get closed
    minimizedController.minimizeRoom(_currentRoom,
        bloc: widget.audioRoomsBloc, joinTime: _joinTime);

    // IMPORTANT: Do NOT leave Agora channel - keep audio connection active!
    // Do NOT stop listening to room updates - keep getting real-time updates

    debugPrint('🔽 [AudioRoom] Room minimized: ${_currentRoom.name}');
    debugPrint('🔽 [AudioRoom] Agora channel kept active for minimized room');

    // Show floating overlay BEFORE navigating back
    MinimizedRoomOverlay.show(context, widget.audioRoomsBloc);

    // Wait for the next frame so PopScope is updated before popping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Navigate back to room list using Get.back()
        Get.back();
      }
    });

    // Reload room list AFTER navigation completes
    // Use LoadAudioRooms to force a fresh fetch from server
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.audioRoomsBloc.add(const LoadAudioRooms());
      debugPrint('🔄 [AudioRoom] Reloading room list after minimize');
    });
  }

  /// Handle actual leave action
  void _handleActualLeave({bool fromBottomSheet = false}) {
    // If it was called from bottom sheet, we don't need to pop bottom sheet anymore as it's already popped.

    setState(() {
      _canPopScreen = true;
    });

    // Get or initialize controller
    final minimizedController = _getMinimizedController();
    minimizedController.clearMinimizedRoom();

    // Leave the room
    widget.audioRoomsBloc.add(LeaveAudioRoom(
      roomId: _currentRoom.id,
      userId: _currentUser.userId,
    ));

    // Wait for the next frame so PopScope is updated before popping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_isCurrentUserHost && _currentRoom.category == 'Live') {
          final int duration =
              DateTime.now().difference(_currentRoom.createdAt).inMinutes;
          final int users = _currentRoom.joinedUserIds.length;
          final int diamonds = _currentRoom.totalRevenue;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LiveEndedSummaryScreen(
                durationMinutes: duration,
                totalUsers: users,
                totalDiamonds: diamonds,
                totalGifts: 0, // TODO: Implement real gift tracking
                hostName: _currentRoom.creatorName,
                hostAvatar: _currentRoom.creatorImageUrl,
              ),
            ),
          );
        } else {
          // Exit room screen
          Navigator.of(context).pop();
        }
      }
    });

    debugPrint('👋 [AudioRoom] User left room: ${_currentRoom.name}');
  }

  /// Handle mute/unmute
  void _handleMuteToggle() {
    debugPrint('🎤 [AudioRoom] 🎙️ Microphone toggle requested...');
    debugPrint(
        '🎤 [AudioRoom]   - Current state: ${_isMuted ? "MUTED" : "UNMUTED"}');
    debugPrint('🎤 [AudioRoom]   - Agora connected: $_agoraChannelJoined');
    debugPrint(
        '🎤 [AudioRoom]   - Is seated: ${_currentParticipant?.isSeated ?? false}');

    // Check if participant is seated - if not, don't allow mic toggle
    if (!(_currentParticipant?.isSeated ?? false)) {
      debugPrint(
          '🎤 [AudioRoom] ❌ Cannot toggle mic - participant is not seated');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be seated to use the microphone'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if muted by admin (Host can bypass this)
    if ((_currentParticipant?.isMutedByAdmin ?? false) &&
        _isMuted &&
        !_isCurrentUserHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have been muted by the host'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_agoraChannelJoined) {
      // Use Agora for mute/unmute
      debugPrint(
          '🎤 [AudioRoom] 🔧 Sending ToggleMicrophone event to Agora...');
      widget.audioRoomsBloc.add(const ToggleMicrophone());
    } else {
      // Fallback to local state if Agora not connected
      debugPrint(
          '🎤 [AudioRoom] ⚠️ Agora not connected, using local state fallback');
      if (mounted) {
        setState(() {
          _isMuted = !_isMuted;
        });
      }

      // Update participant's mute status in the room
      if (_currentParticipant != null) {
        final updatedParticipant =
            _currentParticipant!.copyWith(isMuted: _isMuted);
        widget.audioRoomsBloc.add(UpdateRoomParticipant(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          updatedParticipant: updatedParticipant,
        ));
        debugPrint(
            '🎤 [AudioRoom] 📝 Updated participant mute status in room (local): $_isMuted');
      }

      debugPrint(
          '🎤 [AudioRoom] 📱 Local state updated: ${_isMuted ? "MUTED" : "UNMUTED"}');
    }
  }

  /// Handle speaker toggle
  void _handleSpeakerToggle() {
    debugPrint('🔊 [AudioRoom] 🔊 Speaker toggle requested...');
    debugPrint(
        '🔊 [AudioRoom]   - Current state: ${_isSpeakerOn ? "ON" : "OFF"}');
    debugPrint('🔊 [AudioRoom]   - Agora connected: $_agoraChannelJoined');

    if (_agoraChannelJoined) {
      // Use Agora for speaker toggle
      debugPrint('🔊 [AudioRoom] 🔧 Sending ToggleSpeaker event to Agora...');
      widget.audioRoomsBloc.add(const ToggleSpeaker());
    } else {
      // Fallback to local state if Agora not connected
      debugPrint(
          '🔊 [AudioRoom] ⚠️ Agora not connected, using local state fallback');
      if (mounted) {
        setState(() {
          _isSpeakerOn = !_isSpeakerOn;
        });
      }
      debugPrint(
          '🔊 [AudioRoom] 📱 Local state updated: ${_isSpeakerOn ? "ON" : "OFF"}');
    }
  }

  /// Show Camera Options Bottom Sheet (including Beauty Camera)
  void _showCameraOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Material(
            color: const Color(0xFF1E1E2A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Camera Options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Switch Camera Option
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: const Icon(Icons.flip_camera_ios_rounded,
                        color: Colors.white),
                    title: const Text('Switch Camera',
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      AgoraService().switchCamera();
                      Navigator.pop(
                          context); // Optional: close bottom sheet after switching
                    },
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 5),
                  // Camera On/Off Toggle
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: Colors.pinkAccent,
                    title: const Text('Enable Camera',
                        style: TextStyle(color: Colors.white)),
                    secondary: Icon(
                      _isHostVideoEnabled
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      color: Colors.white,
                    ),
                    value: _isHostVideoEnabled,
                    onChanged: (val) {
                      setState(() {
                        _isHostVideoEnabled = val;
                      });
                      setModalState(() {});
                      if (val) {
                        AgoraService().enableVideo();
                      } else {
                        AgoraService().disableVideo();
                      }
                    },
                  ),
                  const Divider(color: Colors.white24),
                  // Beauty Camera Toggle
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: Colors.pinkAccent,
                    title: const Text('Beauty Camera',
                        style: TextStyle(color: Colors.white)),
                    secondary: const Icon(Icons.face_retouching_natural,
                        color: Colors.white),
                    value: _isBeautyCameraEnabled,
                    onChanged: (val) {
                      setState(() {
                        _isBeautyCameraEnabled = val;
                      });
                      setModalState(() {});
                      AgoraService().setBeautyEffect(
                        val,
                        lighteningLevel: _beautyLighteningLevel,
                        smoothnessLevel: _beautySmoothnessLevel,
                        rednessLevel: _beautyRednessLevel,
                        sharpnessLevel: _beautySharpnessLevel,
                      );
                    },
                  ),
                  if (_isBeautyCameraEnabled) ...[
                    const SizedBox(height: 10),
                    // Lightening Slider
                    _buildBeautySlider(
                      title: 'Lightening',
                      value: _beautyLighteningLevel,
                      onChanged: (val) {
                        setState(() {
                          _beautyLighteningLevel = val;
                        });
                        setModalState(() {});
                        AgoraService().setBeautyEffect(
                          true,
                          lighteningLevel: _beautyLighteningLevel,
                          smoothnessLevel: _beautySmoothnessLevel,
                          rednessLevel: _beautyRednessLevel,
                          sharpnessLevel: _beautySharpnessLevel,
                        );
                      },
                    ),
                    // Smoothness Slider
                    _buildBeautySlider(
                      title: 'Smoothness',
                      value: _beautySmoothnessLevel,
                      onChanged: (val) {
                        setState(() {
                          _beautySmoothnessLevel = val;
                        });
                        setModalState(() {});
                        AgoraService().setBeautyEffect(
                          true,
                          lighteningLevel: _beautyLighteningLevel,
                          smoothnessLevel: _beautySmoothnessLevel,
                          rednessLevel: _beautyRednessLevel,
                          sharpnessLevel: _beautySharpnessLevel,
                        );
                      },
                    ),
                    // Redness Slider
                    _buildBeautySlider(
                      title: 'Redness',
                      value: _beautyRednessLevel,
                      onChanged: (val) {
                        setState(() {
                          _beautyRednessLevel = val;
                        });
                        setModalState(() {});
                        AgoraService().setBeautyEffect(
                          true,
                          lighteningLevel: _beautyLighteningLevel,
                          smoothnessLevel: _beautySmoothnessLevel,
                          rednessLevel: _beautyRednessLevel,
                          sharpnessLevel: _beautySharpnessLevel,
                        );
                      },
                    ),
                    // Sharpness Slider
                    _buildBeautySlider(
                      title: 'Sharpness',
                      value: _beautySharpnessLevel,
                      onChanged: (val) {
                        setState(() {
                          _beautySharpnessLevel = val;
                        });
                        setModalState(() {});
                        AgoraService().setBeautyEffect(
                          true,
                          lighteningLevel: _beautyLighteningLevel,
                          smoothnessLevel: _beautySmoothnessLevel,
                          rednessLevel: _beautyRednessLevel,
                          sharpnessLevel: _beautySharpnessLevel,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBeautySlider({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value,
              activeColor: Colors.pinkAccent,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text((value * 100).toInt().toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Show Live Mic Options Bottom Sheet
  void _showLiveMicOptionsBottomSheet() {
    bool localRoomMuted = _isRoomMuted;
    bool localUserMuted = _isCurrentUserMuted;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Material(
            color: const Color(0xFF1E1E2A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCurrentUserHost)
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.list_alt, color: Colors.white),
                      title: const Text('Waiting List',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        showWaitingListBottomSheet(
                            context, _currentRoom.id, widget.audioRoomsBloc);
                      },
                    ),
                  if (_isCurrentUserHost)
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.block, color: Colors.white),
                      title: const Text('Mute All Users',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(ToggleAdminMute(
                          roomId: _currentRoom.id,
                          participantId: 'ALL',
                          mutedByAdmin: true,
                        ));
                      },
                    ),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(
                        localRoomMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white),
                    title: Text(
                        localRoomMuted
                            ? 'Unmute Room Speaker'
                            : 'Mute Room Speaker',
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setModalState(() {
                        localRoomMuted = !localRoomMuted;
                      });
                      _handleRoomMuteToggle();
                    },
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(localUserMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white),
                    title: Text(
                        localUserMuted
                            ? 'Unmute Microphone'
                            : 'Mute Microphone',
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setModalState(() {
                        localUserMuted = !localUserMuted;
                      });
                      _handleMuteToggle();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handle request to speak
  void _handleRequestToSpeak() {
    // Send a join request
    widget.audioRoomsBloc.add(SendJoinRequest(
      roomId: _currentRoom.id,
      userId: _currentUser.userId,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join request sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Initialize Agora for the audio room
  void _initializeAgoraForRoom() {
    // Safety check: don't add events to a closed BLoC
    if (widget.audioRoomsBloc.isClosed) {
      debugPrint('🎤 [AudioRoom] ❌ Cannot initialize Agora: BLoC is closed');
      return;
    }

    // Generate a unique UID for this user (using userId hash)
    _agoraUid = _currentUser.userId.hashCode.abs() % 1000000;

    // Initialize Agora only - join will happen in BlocListener
    widget.audioRoomsBloc.add(InitializeAgora(
      roomId: _currentRoom.id,
      userId: _currentUser.userId,
      userName: _currentUser.fullname,
      userImageUrl: _currentUser.photoUrl,
      audioQuality: AudioQuality.high,
      isVideo: widget.room.category == 'Live',
    ));
  }

  /// Join Agora channel
  void _joinAgoraChannel() {
    if (_agoraUid == null) {
      debugPrint('🎤 [AudioRoom] ❌ Cannot join channel: UID is null');
      return;
    }

    if (_agoraChannelJoined) {
      debugPrint(
          '🎤 [AudioRoom] ⚠️ Already joined Agora channel, skipping duplicate join');
      return;
    }

    debugPrint('🎤 [AudioRoom] 🚪 Attempting to join Agora channel...');
    debugPrint('🎤 [AudioRoom] 📋 Join Info:');
    debugPrint('🎤 [AudioRoom]   - Channel: ${_currentRoom.id}');
    debugPrint('🎤 [AudioRoom]   - UID: $_agoraUid');
    debugPrint('🎤 [AudioRoom]   - User: ${_currentUser.fullname}');

    // Get current participant's mute status
    final currentParticipant = _currentParticipant;
    final isMuted =
        currentParticipant?.isMuted ?? true; // Default to muted if not found
    debugPrint(
        '🎤 [AudioRoom] 🔧 Participant mute status: $isMuted (participant: ${currentParticipant?.userName}, seat: ${currentParticipant?.seatNumber})');

    widget.audioRoomsBloc.add(JoinAgoraChannel(
      channelName: _currentRoom.id,
      uid: _agoraUid!,
      userId: _currentUser.userId,
      userName: _currentUser.fullname,
      userImageUrl: _currentUser.photoUrl,
      isMuted: isMuted,
      isVideo: _currentRoom.category == 'Live',
    ));
  }

  /// Show Room Decor Sheet (Background & Seat Decor)
  void _showRoomDecorSheet() {
    if (!_currentRoom.isCreator(_currentUser.userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the host can change room decor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomDecorSheet(
        userId: _currentUser.userId,
        currentRoom: _currentRoom,
        audioRoomsBloc: widget.audioRoomsBloc,
      ),
    );
  }

  /// Get current user's participant data with null safety
  AudioRoomParticipant? get _currentParticipant {
    try {
      // Validate current user and room participants exist
      if (_currentUser.userId.isEmpty || _currentRoom.participants.isEmpty) {
        debugPrint('🎯 Current user or participants list is empty');
        return null;
      }

      return _currentRoom.participants
          .firstWhere((p) => p.userId == _currentUser.userId);
    } catch (e) {
      debugPrint('🎯 Current user not found in participants: $e');
      return null;
    }
  }

  /// Check if current user is a speaker
  bool get _isCurrentUserSpeaker {
    return _currentParticipant?.isSpeaker == true;
  }

  /// Check if current user is muted (combines local state and room data)
  bool get _isCurrentUserMuted {
    // If explicitly muted by admin, enforce it
    if (_currentParticipant?.isMutedByAdmin == true) {
      return true;
    }
    // Otherwise rely on our local _isMuted state for instant feedback without UI bounce
    return _isMuted;
  }

  /// Handle room mute toggle
  void _handleRoomMuteToggle() {
    widget.audioRoomsBloc.add(const ToggleRoomMute());
  }

  /// Check if a specific seat is occupied by the host/admin
  bool _isSeatOccupiedByHost(int seatNumber) {
    try {
      final occupant = _currentRoom.participants.firstWhere(
        (p) => p.seatNumber == seatNumber,
      );
      return _currentRoom.isCreator(occupant.userId) || occupant.isHost;
    } catch (e) {
      return false; // Seat is empty
    }
  }

  // Volume Notifiers Cache (UserId -> Notifier)
  final Map<String, ValueNotifier<double>> _userVolumeNotifiers = {};

  ValueNotifier<double> _getVolumeNotifier(String userId) {
    if (!_userVolumeNotifiers.containsKey(userId)) {
      _userVolumeNotifiers[userId] = ValueNotifier<double>(0.0);
    }
    return _userVolumeNotifiers[userId]!;
  }

  /// Helper to map participant UserID to Agora UID (must match BLoC logic)
  int _generateUid(String userId) {
    return userId.hashCode.abs() % 1000000;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.audioRoomsBloc,
      child: BlocListener<AudioRoomsBloc, AudioRoomsState>(
        listener: (context, state) {
          // Handle kicked/blocked or room ended state
          if (state is AudioRoomsError &&
              (state.errorCode == 'KICKED' ||
                  state.errorCode == 'ROOM_ENDED')) {
            debugPrint(
                '🚪 [UI] User has been kicked, blocked, or room ended. Popping screen...');
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          // Handle Agora states
          if (state is AgoraInitializing) {
            debugPrint('🎤 [AudioRoom] 🔄 Agora is initializing...');
          } else if (state is AgoraInitialized) {
            debugPrint('🎤 [AudioRoom] ✅ Agora initialized successfully');
            // Auto-join channel after initialization
            _joinAgoraChannel();
          } else if (state is AgoraInitializationFailed) {
            debugPrint(
                '🎤 [AudioRoom] Agora initialization failed: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Audio initialization failed: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is AgoraChannelJoining) {
            debugPrint(
                '🎤 [AudioRoom] 🔄 Joining Agora channel: ${state.channelName}...');
          } else if (state is AgoraChannelJoined) {
            debugPrint(
                '🎤 [AudioRoom] ✅ Successfully joined Agora channel: ${state.channelName}');
            debugPrint('🎤 [AudioRoom] 📊 Channel Info:');
            debugPrint('🎤 [AudioRoom]   - UID: ${state.uid}');
            debugPrint(
                '🎤 [AudioRoom]   - Connection State: ${state.connectionState}');
            debugPrint(
                '🎤 [AudioRoom]   - Users in channel: ${state.users.length}');
            debugPrint('🎤 [AudioRoom]   - Microphone muted: ${state.isMuted}');
            debugPrint('🎤 [AudioRoom]   - Speaker on: ${state.isSpeakerOn}');
            debugPrint(
                '🎤 [AudioRoom]   - Audio quality: ${state.audioQuality}');

            setState(() {
              _agoraChannelJoined = true;
              _agoraUsers = state.users;
              _isMuted = state.isMuted;
              _isSpeakerOn = state.isSpeakerOn;
            });

            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('🎤 Connected to audio room!'),
            //     backgroundColor: Colors.green,
            //     duration: Duration(seconds: 2),
            //   ),
            // );
          } else if (state is AgoraChannelJoinFailed) {
            debugPrint(
                '🎤 [AudioRoom] Failed to join Agora channel: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to join audio: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is MicrophoneToggled) {
            debugPrint(
                '🎤 [AudioRoom] 🎙️ Microphone toggled: ${state.isMuted ? "🔇 MUTED" : "🎤 UNMUTED"}');
            setState(() {
              _isMuted = state.isMuted;
            });

            // Update participant's mute status in the room
            if (_currentParticipant != null) {
              final updatedParticipant =
                  _currentParticipant!.copyWith(isMuted: state.isMuted);
              widget.audioRoomsBloc.add(UpdateRoomParticipant(
                roomId: _currentRoom.id,
                userId: _currentUser.userId,
                updatedParticipant: updatedParticipant,
              ));
              debugPrint(
                  '🎤 [AudioRoom] 📝 Updated participant mute status in room: ${state.isMuted}');
            }
          } else if (state is RoomMuteToggled) {
            debugPrint(
                '🔇 [AudioRoom] 🔇 Room mute toggled: ${state.isRoomMuted ? "🔇 MUTED" : "🔊 UNMUTED"}');
            setState(() {
              _isRoomMuted = state.isRoomMuted;
            });

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(state.isMuted ? '🔇 Microphone muted' : '🎤 Microphone unmuted'),
            //     backgroundColor: state.isMuted ? Colors.orange : Colors.green,
            //     duration: const Duration(seconds: 1),
            //   ),
            // );
          } else if (state is SpeakerToggled) {
            debugPrint(
                '🔊 [AudioRoom] 🔊 Speaker toggled: ${state.isSpeakerOn ? "🔊 ON" : "🔇 OFF"}');
            setState(() {
              _isSpeakerOn = state.isSpeakerOn;
            });
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(state.isSpeakerOn ? '🔊 Speaker on' : '🔇 Speaker off'),
            //     backgroundColor: state.isSpeakerOn ? Colors.green : Colors.orange,
            //     duration: const Duration(seconds: 1),
            //   ),
            // );
          } else if (state is AgoraUserUpdated) {
            debugPrint(
                '🎤 [AudioRoom] Agora user updated: ${state.user.userName} (${state.action})');
            if (state.action == 'joined') {
              debugPrint(
                  '🎤 [AudioRoom] 🟢 Remote user JOINED Agora channel: ${state.user.userName} (UID: ${state.user.uid})');
              debugPrint(
                  '🎤 [AudioRoom] 🔍 User ID comparison: ${state.user.userId} vs ${_currentUser.userId}');
              // Only show notification if it's not the current user
              if (state.user.userId != _currentUser.userId) {
                debugPrint(
                    '🎤 [AudioRoom] ✅ Showing notification for remote user');
                NotificationManager.show(
                  context: context,
                  message: '${state.user.userName} joined the audio',
                  backgroundColor: Colors.green,
                  icon: Icons.person_add,
                );
              } else {
                debugPrint(
                    '🎤 [AudioRoom] ❌ Skipping notification for current user');
              }
            } else if (state.action == 'left') {
              debugPrint(
                  '🎤 [AudioRoom] 🔴 Remote user LEFT Agora channel: ${state.user.userName} (UID: ${state.user.uid})');
              // Only show notification if it's not the current user
              if (state.user.userId != _currentUser.userId) {
                NotificationManager.show(
                  context: context,
                  message: '${state.user.userName} left the audio',
                  backgroundColor: Colors.orange,
                  icon: Icons.person_remove,
                );
              }
            }

            // Update the user in our local list
            setState(() {
              if (state.action == 'joined') {
                final index =
                    _agoraUsers.indexWhere((u) => u.uid == state.user.uid);
                if (index != -1) {
                  _agoraUsers[index] = state.user;
                } else {
                  _agoraUsers.add(state.user);
                }
              } else if (state.action == 'left') {
                _agoraUsers.removeWhere((u) => u.uid == state.user.uid);
              }
            });
          } else if (state is AgoraConnectionUpdated) {
            debugPrint(
                '🎤 [AudioRoom] 🌐 Connection state changed: ${state.state}');
          } else if (state is AudioVolumeUpdated) {
            // Update volume notifiers efficiently
            state.userVolumes.forEach((uid, volume) {
              try {
                // Find participant with this UID
                // We use firstWhereOrNull logic essentially
                final participant = _currentRoom.participants
                    .cast<AudioRoomParticipant?>()
                    .firstWhere(
                      (p) => p != null && _generateUid(p.userId) == uid,
                      orElse: () => null,
                    );

                if (participant != null) {
                  final notifier = _getVolumeNotifier(participant.userId);

                  bool isActuallyMuted = participant.isMuted;
                  if (participant.userId == _currentUser.userId) {
                    isActuallyMuted = _isCurrentUserMuted;
                  }

                  // Don't show ripple for muted users
                  notifier.value = isActuallyMuted ? 0.0 : volume / 255.0;
                }
              } catch (e) {
                // Ignore errors
              }
            });
          } else if (state is NetworkQualityUpdated) {
            // debugPrint('🎤 [AudioRoom] 📶 Network quality: ${state.quality}');
          } else if (state is AgoraStatsUpdated) {
            // debugPrint('🎤 [AudioRoom] 📊 Agora Stats:');
            // debugPrint('🎤 [AudioRoom]   - Duration: ${state.stats.duration}s');
            // debugPrint('🎤 [AudioRoom]   - Users: ${state.stats.userCount}');
            // debugPrint('🎤 [AudioRoom]   - CPU Usage: ${state.stats.cpuTotalUsage}%');
            if (state.stats.txBytes > 0) {
              debugPrint(
                  '🎤 [AudioRoom]   - TX: ${state.stats.txBytes} bytes (${state.stats.txKBitRate} kbps)');
            }
            if (state.stats.rxBytes > 0) {
              debugPrint(
                  '🎤 [AudioRoom]   - RX: ${state.stats.rxBytes} bytes (${state.stats.rxKBitRate} kbps)');
            }
          } else if (state is TokenPrivilegeWillExpire) {
            debugPrint('🎤 [AudioRoom] ⚠️ Token will expire soon, renewing...');
          } else if (state is TokenRenewed) {
            debugPrint('🎤 [AudioRoom] ✅ Token renewed successfully');
          } else if (state is AgoraError) {
            debugPrint(
                '🎤 [AudioRoom] ❌ Agora Error: ${state.message} (Code: ${state.code})');
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('Audio Error: ${state.message}'),
            //     backgroundColor: Colors.red,
            //     duration: const Duration(seconds: 3),
            //   ),
            // );
          } else if (state is AgoraChannelLeft) {
            debugPrint('🎤 [AudioRoom] 👋 Left Agora channel successfully');
            setState(() {
              _agoraChannelJoined = false;
              _agoraUsers.clear();
            });
          }

          // Handle room states
          if (state is AudioRoomUpdated) {
            final oldRoom = _currentRoom;
            final newRoom = state.room;

            final oldBackgroundUrl = oldRoom.settings.backgroundImageUrl;
            final newBackgroundUrl = newRoom.settings.backgroundImageUrl;

            // Update local state first (UI needs to react)
            setState(() {
              _currentRoom = newRoom;
            });

            final oldAnnouncement = oldRoom.settings.announcement;
            final newAnnouncement = newRoom.settings.announcement;

            if (oldAnnouncement != newAnnouncement &&
                (newAnnouncement?.isNotEmpty ?? false)) {
              _injectAnnouncement(newAnnouncement!);
              setState(() {
                final allMessages = [..._chatMessages, _syntheticMessages.last];
                allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                _chatMessages = allMessages;
              });
            }

            if (newRoom.activeYoutubeVideoId != null) {
              final hostParticipant = newRoom.participants
                  .firstWhereOrNull((p) => p.userId == newRoom.creatorId);
              final isHostInSeat1 = hostParticipant != null &&
                  hostParticipant.isSeated &&
                  hostParticipant.seatNumber == 1;

              if (!isHostInSeat1) {
                final isHostInRoom = hostParticipant != null;
                final shouldIUpdate = (isHostInRoom && _isCurrentUserHost) ||
                    (!isHostInRoom &&
                        newRoom.participants.isNotEmpty &&
                        newRoom.participants.first.userId ==
                            _currentUser.userId);

                if (shouldIUpdate) {
                  AudioRoomsRepository().updateYoutubeState(
                    roomId: newRoom.id,
                    videoId: null,
                    isPlaying: false,
                    syncPosition: 0,
                  );
                }
              }
            }

            // --- NOTIFICATIONS LOGIC ---

            // 1. Find Current User in both states
            final oldMe = oldRoom.participants
                .firstWhereOrNull((p) => p.userId == _currentUser.userId);
            final newMe = newRoom.participants
                .firstWhereOrNull((p) => p.userId == _currentUser.userId);

            if (oldMe != null && newMe != null) {
              // Check Mute Status (Admin Mute)
              if (!oldMe.isMutedByAdmin && newMe.isMutedByAdmin) {
                NotificationManager.show(
                  context: context,
                  message: 'You have been muted by the host or admin',
                  backgroundColor: Colors.red,
                  icon: Icons.mic_off,
                );
              } else if (oldMe.isMutedByAdmin && !newMe.isMutedByAdmin) {
                NotificationManager.show(
                  context: context,
                  message: 'You have been unmuted by the host or admin',
                  backgroundColor: Colors.green,
                  icon: Icons.mic,
                );

                // Trigger official team unmute notification
                try {
                  OfficialTeamApi.sendUnmuteMessage(_currentUser);
                } catch (ex) {
                  debugPrint('Error sending official unmute notification: $ex');
                }
              }

              // Check Seat Status (Removed from Seat)
              if (oldMe.seatNumber != null && newMe.seatNumber == null) {
                NotificationManager.show(
                  context: context,
                  message: 'You have been removed from your seat',
                  backgroundColor: Colors.orange,
                  icon: Icons.event_seat,
                );
              }

              // Check Admin Status
              if (!oldMe.isHost &&
                  newMe.isHost &&
                  newMe.userId != newRoom.creatorId) {
                // Check if promoted (and not just creator)
                NotificationManager.show(
                  context: context,
                  message: 'You are now an Admin',
                  backgroundColor: Colors.purple,
                  icon: Icons.shield,
                );
              } else if (oldMe.isHost && !newMe.isHost) {
                NotificationManager.show(
                  context: context,
                  message: 'You are no longer an Admin',
                  backgroundColor: Colors.grey,
                  icon: Icons.remove_moderator,
                );
              }
            }

            // 2. Check for Joined/Left Participants
            final oldParticipantCount = oldRoom.participants.length;
            final newParticipantCount = newRoom.participants.length;

            if (newParticipantCount > oldParticipantCount) {
              final newParticipants = newRoom.participants
                  .where((p) => !oldRoom.participants
                      .any((old) => old.userId == p.userId))
                  .toList();
              if (newParticipants.isNotEmpty) {
                final newParticipant = newParticipants.first;
                // Only show notification if it's not the current user
                if (newParticipant.userId != _currentUser.userId) {
                  NotificationManager.show(
                    context: context,
                    message: '${newParticipant.userName} joined the room',
                    backgroundColor: Colors.green,
                    icon: Icons.person_add,
                  );
                }
              }
            }

            // Handle background image changes
            if (oldBackgroundUrl != newBackgroundUrl) {
              if (newBackgroundUrl != null &&
                  newBackgroundUrl.startsWith('http')) {
                // Preload new background image for smooth transition
                DefaultCacheManager()
                    .getSingleFile(newBackgroundUrl)
                    .catchError((error) {
                  debugPrint(
                      '🖼️ Failed to preload updated background: $error');
                  throw error;
                });
              }
            }
          } else if (state is AudioRoomLeft) {
            debugPrint('🎯 Successfully left room (screen already popped)');
            // Removed Navigator.of(context).pop() to fix double-pop white screen bug
          } else if (state is AudioRoomJoined) {
            debugPrint(
                '🎯 User successfully joined room from within room screen');
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('Welcome to ${state.room.name}!'),
            //     backgroundColor: Colors.green.withValues(alpha: 0.8),
            //     duration: const Duration(seconds: 2),
            //   ),
            // );
            // Update current room with the joined room data
            setState(() {
              _currentRoom = state.room;
            });

            // Send join message to chat
            EmojiChatService.sendPresenceMessage(
              roomId: state.room.id,
              userId: _currentUser.userId,
              username: _currentUser.fullname,
              userAvatar: _currentUser.photoUrl,
              isJoin: true,
            );
          } else if (state is AudioRoomJoinFailed) {
            debugPrint(
                '🎯 Failed to join room from within room screen: ${state.message}');
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('Failed to join: ${state.message}'),
            //     backgroundColor: Colors.red,
            //     duration: const Duration(seconds: 3),
            //   ),
            // );
            // Navigate back since join failed
            Navigator.of(context).pop();
          } else if (state is JoiningAudioRoom) {
            // Show immediate feedback - no debug prints for speed
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: const Row(
            //       children: [
            //         SizedBox(
            //           width: 16,
            //           height: 16,
            //           child: CircularProgressIndicator(
            //             strokeWidth: 2,
            //             valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            //           ),
            //         ),
            //         SizedBox(width: 12),
            //         Expanded(child: Text('Joining room...')),
            //       ],
            //     ),
            //     backgroundColor: Colors.blue.withValues(alpha: 0.8),
            //     duration: const Duration(seconds: 2),
            //   ),
            // );
          } else if (state is AudioRoomsError) {
            debugPrint('🎯 Room error: ${state.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            if (state.errorCode == 'KICKED') {
              debugPrint(
                  '🚪 [AudioRoom] Kicked state detected, safely exiting room screen...');
              setState(() {
                _canPopScreen = true;
              });
              Navigator.of(context).pop();
            }
          } else if (state is ParticipantMovedToSeat) {
            debugPrint(
                '🪑 [UI] Participant moved to seat - forcing UI refresh');
            // Force UI refresh to update seat display immediately
            if (mounted) {
              setState(() {});
            }

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(state.toSeat == 0
            //         ? 'Left seat successfully'
            //         : 'Moved to seat ${state.toSeat}'),
            //     backgroundColor: Colors.green.withValues(alpha: 0.8),
            //     duration: const Duration(seconds: 2),
            //   ),
            // );
          } else if (state is ParticipantRemovedFromSeat) {
            debugPrint(
                '🪑 [UI] Participant removed from seat - forcing UI refresh');
            // Force UI refresh to update seat display immediately
            if (mounted) {
              setState(() {});
            }

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('Removed from seat ${state.seatNumber}'),
            //     backgroundColor: Colors.orange.withValues(alpha: 0.8),
            //     duration: const Duration(seconds: 2),
            //   ),
            // );
          }
        },
        child: PopScope(
          canPop: _canPopScreen,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (!didPop) {
              _showExitConfirmationBottomSheet();
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.black,
              body: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  /// Build custom header exactly like screenshot
  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room icon/avatar and title/member count area - Tappable for details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RoomMemberScreen(
                          roomId: _currentRoom.id,
                          currentUserId: _currentUser.userId,
                        ),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Room icon/avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: _currentRoom.imageUrl != null
                                  ? DecorationImage(
                                      image:
                                          NetworkImage(_currentRoom.imageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: _currentRoom.imageUrl == null
                                  ? Colors.red
                                  : null,
                            ),
                            child: _currentRoom.imageUrl == null
                                ? const Icon(
                                    Icons.group,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Room title and member count
                      // Room title and member count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Name + Level
                            Row(
                              children: [
                                Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: ShaderMask(
                                    shaderCallback: (Rect bounds) {
                                      return const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white,
                                          Colors.white,
                                          Colors.transparent
                                        ],
                                        stops: [0.0, 0.8, 1.0],
                                      ).createShader(bounds);
                                    },
                                    blendMode: BlendMode.dstIn,
                                    child: _currentRoom.name.length > 15
                                        ? SizedBox(
                                            height: 20,
                                            child: Marquee(
                                              text: _currentRoom.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              scrollAxis: Axis.horizontal,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              blankSpace: 20.0,
                                              velocity: 30.0,
                                              pauseAfterRound:
                                                  const Duration(seconds: 1),
                                            ),
                                          )
                                        : Text(
                                            _currentRoom.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.clip,
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 2),

                            // Row 2: ID
                            Row(
                              children: [
                                Flexible(
                                  child: Obx(() {
                                    final premiumRoomService =
                                        Get.put(PremiumRoomService());
                                    final customIdModel = premiumRoomService
                                        .streamRoomId(_currentRoom.id)
                                        .value;

                                    if (customIdModel != null &&
                                        !customIdModel.isExpired) {
                                      return AnimatedPremiumId(
                                          idStr: customIdModel.customId);
                                    }

                                    return Text(
                                      'ID: ${_currentRoom.id.length > 8 ? _currentRoom.id.substring(0, 8) : _currentRoom.id}',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }),
                                ),
                                _getDynamicRoomLevelBadgeUrl() != null
                                    ? CachedNetworkImage(
                                        imageUrl:
                                            _getDynamicRoomLevelBadgeUrl()!,
                                        width: 44,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.white24,
                                              width: 0.5),
                                        ),
                                        child: Text(
                                          'Lv.${AudioRoomV2.calculateRoomLevel(_currentRoom.totalRevenue, _roomLevelConfigData)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                if (!_currentRoom.joinedUserIds
                                        .contains(_currentUser.userId) &&
                                    !_currentRoom
                                        .isCreator(_currentUser.userId)) ...[
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('audio_rooms_v2')
                                            .doc(_currentRoom.id)
                                            .update({
                                          'joinedUserIds':
                                              FieldValue.arrayUnion(
                                                  [_currentUser.userId])
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '🎉 You are now an official member of this room!',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            backgroundColor: Color(0xFFD4AF37),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFFA500),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.black,
                                        size: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Ranking / Revenue (Below Avatar)
                GestureDetector(
                  onTap: _showRankingList,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF9C27B0), // Purple like screenshot
                          Color(0xFFBA68C8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 20,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatRevenue(_currentRoom.totalRevenue),
                          style: const TextStyle(
                            color: Color(0xFFFFE0B2),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dropdown/Settings button - Only for Host
                  if (_isCurrentUserHost) ...[
                    GestureDetector(
                      onTap: _showVoiceRoomCustomize,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Camera Flip and Off Buttons (Video Live Host Only)
                  if (_currentRoom.category == 'Live' &&
                      _isCurrentUserHost) ...[
                    // Camera Options Button (replaces flip button)
                    GestureDetector(
                      onTap: _showCameraOptionsBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Share button
                  GestureDetector(
                    onTap: _showShareBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Transform.scale(
                        scaleX: -1,
                        child: const Icon(
                          Icons.reply_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Close button
                  GestureDetector(
                    onTap: _handleLeaveRoom,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Viewer Count Badge
              Builder(builder: (context) {
                final firstOnlineMember = _currentRoom.participants.isNotEmpty
                    ? _currentRoom.participants.first
                    : null;
                final hasOnlineMember = firstOnlineMember != null;

                return Transform.translate(
                  offset: const Offset(
                      -3, 0), // Slight 3pt optical adjustment to the left
                  child: GestureDetector(
                    onTap: _showViewersList,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasOnlineMember)
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white24, width: 1.5),
                                ),
                                child: CachedCircleAvatar(
                                  imageUrl:
                                      firstOnlineMember.userImageUrl ?? '',
                                  radius: 10,
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0, right: 6.0),
                              child: Icon(
                                Icons.remove_red_eye_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          Text(
                            '${_currentRoom.participantCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRevenue(int revenue) {
    if (revenue >= 1000000000) {
      return '${(revenue / 1000000000).toStringAsFixed(1)}B';
    } else if (revenue >= 1000000) {
      return '${(revenue / 1000000).toStringAsFixed(1)}M';
    } else if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}K';
    }
    return revenue.toString();
  }

  /// Build main body with optimized background loading
  Widget _buildBody() {
    return Stack(
      children: [
        // Background with loading state
        _buildBackgroundWithLoading(),
        // Content overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping on background/seats
              FocusScope.of(context).unfocus();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Custom header
                    _buildCustomHeader(),

                    if (_currentRoom.isLudoActive)
                      LudoGameWidget(
                        room: _currentRoom,
                        isHost: _isCurrentUserHost,
                        repository: AudioRoomsRepository(),
                        currentUserId: _currentUser.userId,
                      )
                    else if (_currentRoom.activeYoutubeVideoId != null)
                      YoutubeSyncPlayer(
                        room: _currentRoom,
                        isHost: _isCurrentUserHost,
                        repository: AudioRoomsRepository(),
                        onClose: () {},
                        onSearch: _showYoutubeSheet,
                      ),

                    // PK Battle Overlay
                    PKBattleOverlay(
                      room: _currentRoom,
                      currentUserId: _currentUser.userId,
                      onSeatTap: (seatNumber) => _moveToSeat(seatNumber),
                    ),

                    if (_currentRoom.activeYoutubeVideoId == null &&
                        !_currentRoom.isLudoActive)
                      const SizedBox(height: 20),

                    // Participants grid (without chat)
                    Expanded(
                      child: _currentRoom.category == 'Live'
                          ? (_currentRoom.settings.isLiveMultipleMode
                              ? _buildLiveMultipleModeGrid()
                              : const SizedBox.expand())
                          : _buildParticipantsGrid(),
                    ),

                    const SizedBox(height: 80), // Space for controls
                  ],
                ),
              ),
            ),
          ),
        ), // Closes Positioned.fill

        // Floating Music Player
        if (_showMusicPlayer && _isCurrentUserHost) ...[
          // ... music player code is separate ...
        ],

        // Room Controls (Input + Chat) positioned manually to handle keyboard
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (ctx) {
              final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
              return Padding(
                padding:
                    EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomControls(
                      key: const ValueKey('room_controls'),
                      isMuted: _isCurrentUserMuted,
                      isMutedByAdmin:
                          _currentParticipant?.isMutedByAdmin ?? false,
                      isSpeakerOn: _isSpeakerOn,
                      isHost: _isCurrentUserHost,
                      isSpeaker: _isCurrentUserSpeaker,
                      isSeated: _currentParticipant?.isSeated ?? false,
                      onMuteToggle: _handleMuteToggle,
                      onSpeakerToggle: _handleSpeakerToggle,
                      onLeave: _handleLeaveRoom,
                      onRequestToSpeak:
                          _isCurrentUserSpeaker ? null : _handleRequestToSpeak,
                      chatMessages: _chatMessages,
                      participants: _currentRoom.participants,
                      totalSeats: _currentRoom.settings.roomMode.seatCount,
                      onSendMessage: _sendChatMessage,
                      roomId: _currentRoom.id,
                      currentUserId: _currentUser.userId,
                      currentUserName: _currentUser.fullname,
                      currentUserImageUrl: _currentUser.photoUrl,
                      currentUserLevelBadgeUrl: _currentUserLevelBadgeUrl,
                      selectedUserId:
                          _currentRoom.creatorId, // Always send gifts to host
                      selectedUserName: _currentRoom.creatorName, // Host name
                      selectedUserImageUrl:
                          _currentRoom.creatorImageUrl, // Host image
                      onMessageTap: _handleMessageTap,
                      isLive: _currentRoom.category == 'Live',
                      hasRequestedToJoin: _currentRoom.joinRequests
                          .contains(_currentUser.userId),
                      joinRequestsCount: _currentRoom.joinRequests.length,
                      onLiveMicTapped: _showLiveMicOptionsBottomSheet,
                      onJoinRequestTapped: _handleRequestToSpeak,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Room Event Portal Banners (Carousel) - MOVED HERE TO BE ON TOP OF ROOM CONTROLS
        Positioned(
          right: 12,
          bottom: 100, // Above the gift box in RoomControls
          child: Builder(builder: (ctx) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: const RoomEventPortalWidget(),
            );
          }),
        ),

        // Voting Overlay (Controller handles visibility based on state)
        VotingWidget(
          room: _currentRoom,
          currentUserId: _currentUser.userId,
          isHost: _isCurrentUserHost,
        ),

        // Roulette Overlay
        RouletteWidget(
          controller: Get.isRegistered<RouletteController>(
                  tag: 'roulette_${widget.room.id}')
              ? Get.find<RouletteController>(tag: 'roulette_${widget.room.id}')
              : Get.put(
                  RouletteController(widget.room.id,
                      isHost: _isCurrentUserHost),
                  tag: 'roulette_${widget.room.id}'),
        ),

        // Floating Music Player
        if (_showMusicPlayer || !_isCurrentUserHost)
          FloatingMusicPlayer(
            roomId: widget.room.id,
            isHost: _isCurrentUserHost,
            onClose: () {
              setState(() {
                _showMusicPlayer = false;
              });
            },
          ),

        // Gift animation overlay using StreamBuilder with auto-cleanup
        StreamBuilder<List<GiftTransaction>>(
          stream: _giftService.getGiftTransactions(widget.room.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint(
                  '❌ [AudioRoom] Gift transactions stream error: ${snapshot.error}');
              return const SizedBox.shrink();
            }

            if (!snapshot.hasData) {
              debugPrint('🎁 [AudioRoom] StreamBuilder: No data yet');
              return const SizedBox.shrink();
            }

            final allTransactions = snapshot.data!;
            // Filter only recent gifts (last 60 seconds) to handle major clock skew
            final now = DateTime.now();
            final recentTransactions = allTransactions.where((transaction) {
              final timeDiff = now.difference(transaction.timestamp).inSeconds;

              // Debug logging for every transaction received to help diagnose clock skew
              debugPrint('🎁 [GiftDebug] Room ID: ${widget.room.id}');
              debugPrint(
                  '🎁 [GiftDebug] Gift: ${transaction.giftName} from ${transaction.senderName}');
              debugPrint(
                  '🎁 [GiftDebug] TX Time: ${transaction.timestamp.toIso8601String()}');
              debugPrint('🎁 [GiftDebug] Your Time: ${now.toIso8601String()}');
              debugPrint(
                  '🎁 [GiftDebug] timeDiff (Now - TX): $timeDiff seconds');

              // Be extremely lenient: 60s in the past to 60s in the "future"
              return timeDiff.abs() <= 60;
            }).toList();

            debugPrint(
                '🎁 [AudioRoom] Filtered to ${recentTransactions.length} recent gift transactions');

            if (recentTransactions.isEmpty) {
              debugPrint(
                  '🎁 [AudioRoom] StreamBuilder: No recent transactions to display');
              return const SizedBox.shrink();
            }

            // Clean up truly old gifts only occasionally (older than 1 minute)
            _cleanupExtremelyOldGifts(allTransactions);

            // Show a simple debug indicator
            return Stack(
              children: [
                // Debug indicator (remove this in production)
                Positioned(
                  top: 50,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Recent Gifts: ${recentTransactions.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: GiftAnimationOverlay(
                    transactions: recentTransactions,
                    onAnimationComplete: () {
                      debugPrint('🎁 [AudioRoom] Gift animation completed');
                      // Auto-delete the displayed gifts
                      _deleteDisplayedGifts(recentTransactions);
                    },
                    onGiftFlightTriggered: _triggerGiftFlightAnimation,
                  ),
                ),
              ],
            );
          },
        ),

        // Entrance effect animation overlay
        StreamBuilder<List<EntranceEffect>>(
          stream: _entranceEffectService.getEntranceEffects(widget.room.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint(
                  '❌ [AudioRoom] Entrance effects stream error: ${snapshot.error}');
              return const SizedBox.shrink();
            }

            if (!snapshot.hasData) {
              debugPrint('🎬 [AudioRoom] StreamBuilder: No entrance data yet');
              return const SizedBox.shrink();
            }

            final allEffects = snapshot.data!;
            // Filter only recent effects (last 30 seconds to account for network delays)
            final now = DateTime.now();
            final recentEffects = allEffects.where((effect) {
              final timeDiff = now.difference(effect.timestamp).inSeconds;
              debugPrint('🎬 [EntranceDebug] Effect: ${effect.userName}');
              debugPrint('🎬 [EntranceDebug] Time diff: $timeDiff seconds');
              return timeDiff.abs() <= 30; // Increased from 10 to 30 seconds
            }).toList();

            debugPrint(
                '🎬 [AudioRoom] Filtered to ${recentEffects.length} recent entrance effects');

            if (recentEffects.isEmpty) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: EntranceEffectOverlay(
                effects: recentEffects,
                onAnimationComplete: () {
                  debugPrint('🎬 [AudioRoom] Entrance animation completed');
                  // Auto-delete the displayed entrance effects
                  _deleteDisplayedEntranceEffects(recentEffects);
                },
              ),
            );
          },
        ),

        // Flying PNG gifts layer
        _buildFlyingGiftsLayer(),
      ],
    );
  }

  /// Build flying PNG gifts layer
  Widget _buildFlyingGiftsLayer() {
    return Stack(
      children: _flyingGifts.map((item) {
        return FlyingGiftWidget(
          key: ValueKey(item.id),
          pngUrl: item.pngUrl,
          startOffset: item.startOffset,
          endOffset: item.endOffset,
          onComplete: () {
            if (mounted) {
              setState(() {
                _flyingGifts.removeWhere((g) => g.id == item.id);
              });
            }
          },
        );
      }).toList(),
    );
  }

  /// Trigger the flight path animation for a PNG gift thumbnail
  void _triggerGiftFlightAnimation(
      GiftTransaction transaction, List<String> receiverIds) {
    if (transaction.giftPngUrl.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    Offset startOffset = Offset(screenSize.width / 2, screenSize.height - 100);

    // Find sender's seat to start animation from their avatar
    final senderSeatNumber = _findUserSeatNumber(transaction.senderId);
    if (senderSeatNumber != null && _seatKeys.containsKey(senderSeatNumber)) {
      final key = _seatKeys[senderSeatNumber];
      final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final seatPosition = renderBox.localToGlobal(Offset.zero);
        final seatSize = renderBox.size;
        startOffset = Offset(
          seatPosition.dx + seatSize.width / 2,
          seatPosition.dy + seatSize.height / 2,
        );
      }
    }

    final List<FlyingGiftItem> newFlights = [];

    for (final receiverId in receiverIds) {
      // Find seat number of this receiver
      final seatNumber = _findUserSeatNumber(receiverId);
      late Offset endOffset;

      if (seatNumber != null && _seatKeys.containsKey(seatNumber)) {
        final key = _seatKeys[seatNumber];
        final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final seatPosition = renderBox.localToGlobal(Offset.zero);
          final seatSize = renderBox.size;
          // Target center of the seat profile avatar dynamically in real-time
          endOffset = Offset(
            seatPosition.dx + seatSize.width / 2,
            seatPosition.dy + seatSize.height / 2,
          );
        } else {
          endOffset = Offset(screenSize.width / 2, screenSize.height * 0.7);
        }
      } else {
        // Fallback: If user is not seated, default to seat 1 (usually host/admin)
        if (_seatKeys.containsKey(1)) {
          final key = _seatKeys[1];
          final renderBox =
              key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final seatPosition = renderBox.localToGlobal(Offset.zero);
            final seatSize = renderBox.size;
            endOffset = Offset(
              seatPosition.dx + seatSize.width / 2,
              seatPosition.dy + seatSize.height / 2,
            );
          } else {
            endOffset = Offset(screenSize.width / 2, screenSize.height * 0.2);
          }
        } else {
          endOffset = Offset(screenSize.width / 2, screenSize.height * 0.2);
        }
      }

      newFlights.add(
        FlyingGiftItem(
          id: '${transaction.id}_${receiverId}_${DateTime.now().microsecondsSinceEpoch}',
          pngUrl: transaction.giftPngUrl,
          startOffset: startOffset,
          endOffset: endOffset,
        ),
      );
    }

    if (newFlights.isNotEmpty && mounted) {
      setState(() {
        _flyingGifts.addAll(newFlights);
      });
    }
  }

  /// Locate the seat number assigned to the given userId
  int? _findUserSeatNumber(String userId) {
    try {
      final participant = _currentRoom.participants.firstWhere(
        (p) => p.userId == userId,
      );
      return participant.seatNumber;
    } catch (e) {
      return null;
    }
  }

  Widget _buildLiveMultipleModeGrid() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final seatNumber = index + 2; // Seats 2, 3, 4, 5
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildLiveMultipleModeSeat(seatNumber),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLiveMultipleModeSeat(int seatNumber) {
    AudioRoomParticipant? occupant;
    bool isOccupied = false;

    try {
      occupant = _currentRoom.participants.firstWhere(
        (p) => p.seatNumber == seatNumber,
      );
      isOccupied = true;
    } catch (e) {
      occupant = null;
      isOccupied = false;
    }

    return GestureDetector(
      onTap: () => _handleSeatTap(seatNumber, occupant),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0x664A148C), // Deep purple with opacity
          border: Border.all(color: Colors.white24, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background text (seat number)
            Positioned(
              top: 4,
              left: 4,
              child: Text(
                '$seatNumber',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),

            if (!isOccupied)
              const Icon(Icons.add, color: Colors.white54, size: 28)
            else ...[
              // Occupied video
              if (_agoraChannelJoined && AgoraService().engine != null)
                SizedBox.expand(
                  child: AgoraVideoView(
                    controller: _getVideoController(
                        _generateUid(occupant!.userId), AgoraService().engine!),
                  ),
                )
              else
                const SizedBox.expand(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),

              // User name at bottom
              Positioned(
                bottom: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    occupant!.userName,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_currentRoom.pkBattleState.isActive &&
        _currentRoom.pkBattleState.teamSize > 1) {
      return const SizedBox.shrink();
    }
    if (_currentRoom.activeYoutubeVideoId != null ||
        _currentRoom.isLudoActive) {
      return _buildYoutubeSeatsLayout();
    }

    return Column(
      children: [
        // Numbered seats grid (exactly like screenshot)
        _buildNumberedSeatsGrid(),

        const SizedBox(height: 30),
      ],
    );
  }

  /// Build a horizontal scrollable row of small seats when YouTube is playing
  Widget _buildYoutubeSeatsLayout() {
    final roomMode = _currentRoom.settings.roomMode;
    final totalSeats = roomMode.seatCount;

    return Container(
      height: 80, // Reduced height as seats are smaller
      margin: const EdgeInsets.only(top: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: totalSeats,
        itemBuilder: (context, index) {
          final currentSeat = index + 1;
          final isAdmin = _isSeatOccupiedByHost(currentSeat);

          return SizedBox(
            width: MediaQuery.of(context).size.width /
                10, // Force 10 items per screen width
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.scale(
                scale: 0.50, // Shrink significantly to fit 10 in a row
                alignment: Alignment.topCenter,
                child: _buildNumberedSeat(currentSeat, isAdmin: isAdmin),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build numbered seats grid based on room mode
  Widget _buildNumberedSeatsGrid() {
    final roomMode = _currentRoom.settings.roomMode;
    final seatCount = roomMode.seatCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: _buildDynamicSeatRows(seatCount),
      ),
    );
  }

  /// Build dynamic seat rows based on room mode
  List<Widget> _buildDynamicSeatRows(int totalSeats) {
    final roomMode = _currentRoom.settings.roomMode;

    // Special layouts for specific modes
    // Removed modes as per client request: CP, KTV, Immersive
    // if (roomMode == RoomMode.cp) {
    //   return _buildCoupleLayout();
    // } else if (roomMode == RoomMode.ktv) {
    //   return _buildKTVLayout();
    // } else
    if (roomMode == RoomMode.lite) {
      return _buildLiteLayout();
    } else if (roomMode == RoomMode.party) {
      return _buildPartyLayout();
    }

    // Default layout for other modes (multiMic uses default 5-per-row)
    List<Widget> rows = [];
    int currentSeat = 1;
    const int seatsPerRow = 5;

    while (currentSeat <= totalSeats) {
      List<Widget> seatsInRow = [];

      // Build seats for this row (up to 5 seats per row)
      for (int i = 0; i < seatsPerRow && currentSeat <= totalSeats; i++) {
        // Check if current seat is occupied by the host/admin
        final isAdmin = _isSeatOccupiedByHost(currentSeat);
        seatsInRow.add(
            Flexible(child: _buildNumberedSeat(currentSeat, isAdmin: isAdmin)));
        currentSeat++;
      }

      // Add the row with proper spacing
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: seatsInRow,
        ),
      );

      // Add spacing between rows (except for the last row)
      if (currentSeat <= totalSeats) {
        rows.add(const SizedBox(height: 20));
      }
    }

    return rows;
  }

  /// Build Lite layout (9 seats - 1 host top centered, 4+4 grid below)
  List<Widget> _buildLiteLayout() {
    return [
      // Row 1 - 1 host seat (centered on top)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _buildNumberedSeat(1, isAdmin: true)),
        ],
      ),

      const SizedBox(height: 16),

      // Row 2 - 4 seats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildNumberedSeat(2)),
          Flexible(child: _buildNumberedSeat(3)),
          Flexible(child: _buildNumberedSeat(4)),
          Flexible(child: _buildNumberedSeat(5)),
        ],
      ),

      const SizedBox(height: 16),

      // Row 3 - 4 seats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildNumberedSeat(6)),
          Flexible(child: _buildNumberedSeat(7)),
          Flexible(child: _buildNumberedSeat(8)),
          Flexible(child: _buildNumberedSeat(9)),
        ],
      ),
    ];
  }

  /// Build Party layout (12 seats - 2 at top, then rest below)
  List<Widget> _buildPartyLayout() {
    return [
      // Top row - 2 seats (centered)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _buildNumberedSeat(1, isAdmin: true)), // Admin seat
          const SizedBox(width: 20),
          Flexible(child: _buildNumberedSeat(2)),
        ],
      ),

      const SizedBox(height: 20),

      // Second row - 5 seats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildNumberedSeat(3)),
          Flexible(child: _buildNumberedSeat(4)),
          Flexible(child: _buildNumberedSeat(5)),
          Flexible(child: _buildNumberedSeat(6)),
          Flexible(child: _buildNumberedSeat(7)),
        ],
      ),

      const SizedBox(height: 20),

      // Third row - 5 seats
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildNumberedSeat(8)),
          Flexible(child: _buildNumberedSeat(9)),
          Flexible(child: _buildNumberedSeat(10)),
          Flexible(child: _buildNumberedSeat(11)),
          Flexible(child: _buildNumberedSeat(12)),
        ],
      ),
    ];
  }

  /// Build individual numbered seat
  Widget _buildNumberedSeat(int seatNumber, {bool isAdmin = false}) {
    // Check if this seat is occupied
    AudioRoomParticipant? occupant;
    bool isOccupied = false;

    // Hide seat 1 for Live category because the host is already the full screen background
    if (_currentRoom.category == 'Live' && seatNumber == 1) {
      return const SizedBox(
        width: 48.0 + 30, // same as normal seat to keep layout intact
        height: 1, // invisible
      );
    }

    // Check if this seat is locked
    final isLocked = _currentRoom.isSeatLocked(seatNumber);

    final bool hasCustomSeatDecor = _currentRoom.settings.seatDecorUrl != null;
    final bool isDashedPink =
        _currentRoom.settings.seatColorMode == SeatColorMode.dashedPink;
    final bool isDashedOrange =
        _currentRoom.settings.seatColorMode == SeatColorMode.dashedOrange;
    final bool useSeatModePNG = hasCustomSeatDecor ||
        (_currentRoom.settings.seatColorMode == SeatColorMode.purple ||
            _currentRoom.settings.seatColorMode == SeatColorMode.golden);
    final String seatModeAsset =
        _currentRoom.settings.seatColorMode == SeatColorMode.purple
            ? 'assets/images/seat_mode_pink.png'
            : 'assets/images/seat_mode_blue.png';

    // Find participant by seat number
    try {
      occupant = _currentRoom.participants.firstWhere(
        (p) => p.seatNumber == seatNumber,
      );
      isOccupied = true;
    } catch (e) {
      occupant = null;
      isOccupied = false;
    }

    const double size = 48.0;
    final seatKey = _seatKeys.putIfAbsent(seatNumber, () => GlobalKey());

    return GestureDetector(
      key: seatKey,
      onTap: () => _handleSeatTap(seatNumber, occupant),
      onLongPress: () => _handleSeatLongPress(seatNumber, occupant),
      child: SizedBox(
        width: size + 30,
        child: Column(
          children: [
            // Seat circle
            // Seat circle
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Background Seat Decor (shown for both empty and occupied seats)
                  if (useSeatModePNG)
                    if (hasCustomSeatDecor)
                      CachedNetworkImage(
                        imageUrl: (isLocked &&
                                !isOccupied &&
                                _currentRoom.settings.lockedSeatDecorUrl !=
                                    null)
                            ? _currentRoom.settings.lockedSeatDecorUrl!
                            : _currentRoom.settings.seatDecorUrl!,
                        width: size + 8,
                        height: size + 8,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Image.asset(
                          seatModeAsset,
                          width: size + 8,
                          height: size + 8,
                          fit: BoxFit.contain,
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          seatModeAsset,
                          width: size + 8,
                          height: size + 8,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Image.asset(
                        seatModeAsset,
                        width: size + 8,
                        height: size + 8,
                        fit: BoxFit.contain,
                      )
                  else if (!isOccupied)
                    if (isDashedPink || isDashedOrange)
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDashedPink ? Colors.pink : Colors.orange)
                              .withValues(alpha: 0.05),
                          border: Border.all(
                            color: isDashedPink ? Colors.pink : Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: isLocked
                                ? Colors.orange.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),

                  // 2. Avatar (if occupied) or Lock/Sofa icon (if empty)
                  if (isOccupied && occupant != null)
                    SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SpeakingRippleAnimation(
                            isSpeaking: occupant.isSpeaker && !occupant.isMuted,
                            volumeNotifier: _getVolumeNotifier(occupant.userId),
                            minRadius: occupant.frameId != null ? 38 : 25,
                            rippleColor: Colors.white.withValues(alpha: 0.5),
                            userId: occupant.userId,
                            child: Builder(
                              builder: (context) {
                                return CachedCircleAvatar(
                                  imageUrl: occupant?.userImageUrl ?? '',
                                  radius: size / 2,
                                  backgroundColor: Colors.grey[300],
                                  frameId: occupant?.frameId,
                                  userId: occupant?.userId,
                                  frameScale: 1.4,
                                  borderWidth: 0,
                                  padding: 0,
                                );
                              },
                            ),
                          ),
                          if (occupant.isMuted)
                            Positioned(
                              bottom: -4,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(200, 223, 10, 235),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 1),
                                ),
                                child: const Icon(
                                  Icons.mic_off,
                                  color: Colors.white,
                                  size: 7,
                                ),
                              ),
                            ),
                          if (occupant.activeEmojiUrl != null)
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(occupant.activeEmojiUrl!),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value * 1.8,
                                      child: occupant!.activeEmojiUrl!
                                              .startsWith('local_dice:')
                                          ? SpinningDiceWidget(
                                              targetNumber: int.parse(occupant
                                                  .activeEmojiUrl!
                                                  .split(':')[1]),
                                              size: size * 0.8,
                                            )
                                          : CachedNetworkImage(
                                              imageUrl:
                                                  occupant.activeEmojiUrl!,
                                              width: size * 0.8,
                                              height: size * 0.8,
                                              fit: BoxFit.contain,
                                              placeholder: (context, url) =>
                                                  const SizedBox(),
                                              errorWidget:
                                                  (context, url, error) {
                                                return const Icon(Icons.image,
                                                    color: Colors.amber,
                                                    size: 24);
                                              },
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                  // Empty seat foreground
                  if (!hasCustomSeatDecor)
                    (isDashedPink || isDashedOrange) && !isOccupied
                        ? (isLocked
                            ? Icon(
                                Icons.lock,
                                color:
                                    isDashedPink ? Colors.pink : Colors.orange,
                                size: 20,
                              )
                            : (isDashedPink
                                ? const Icon(
                                    Icons.music_note,
                                    color: Colors.pink,
                                    size: 28,
                                  )
                                : Image.asset(
                                    'assets/icons/sofa_ic.png',
                                    width: 28,
                                    height: 28,
                                    color: Colors.orange,
                                  )))
                        : (isLocked
                            ? Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              )
                            : Image.asset(
                                'assets/icons/sofa_ic.png',
                                width: 36,
                                height: 36,
                                color: Colors.white.withValues(alpha: 0.6),
                              ))
                  else if (isLocked &&
                      (!hasCustomSeatDecor ||
                          _currentRoom.settings.lockedSeatDecorUrl == null))
                    Container(
                      width: size + 8,
                      height: size + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // User name or seat label
            if (isOccupied && occupant != null)
              Container(
                constraints: BoxConstraints(maxWidth: size + 30),
                child: Text(
                  occupant.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                seatNumber.toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Removed _buildAdditionalRows - using _buildDynamicSeatRows instead

  /// Handle seat tap
  void _handleSeatTap(int seatNumber, AudioRoomParticipant? occupant) {
    try {
      // Check if seat is locked (allow host to bypass)
      if (_currentRoom.isSeatLocked(seatNumber) && !_isCurrentUserHost) {
        _showLockedSeatMessage(seatNumber);
        return;
      }

      if (occupant == null) {
        // Tapping empty seat
        if (_isCurrentUserHost ||
            _currentRoom.settings.adminIds.contains(_currentUser.userId)) {
          // Admin/Owner tapping empty seat - show options (Take Seat or Invite)
          _showEmptySeatAdminOptions(seatNumber);
        } else {
          // Normal user tapping empty seat - move to it
          _moveToSeat(seatNumber);
        }
      } else if (occupant.userId == _currentUser.userId) {
        // User tapping their own seat - show options
        _showUserSeatOptions(seatNumber);
      } else {
        // User tapping another participant - select for gift sending
        _selectUserForGift(occupant);
        _showParticipantBottomSheet(occupant);
      }
    } catch (e) {
      debugPrint('🪑 Error handling seat tap: $e');
    }
  }

  /// Show room details bottom sheet
  // ignore: unused_element
  void _showRoomDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Room Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Room Info Card
            _buildDetailItem(
              icon: Icons.meeting_room,
              label: 'Room Name',
              value: _currentRoom.name,
            ),
            Obx(() {
              final displayId =
                  Get.find<PremiumRoomService>().getDisplayId(_currentRoom.id);
              return _buildDetailItem(
                icon: Icons.fingerprint,
                label: 'Room ID',
                value: displayId,
                showCopy: true,
              );
            }),
            _buildDetailItem(
              icon: Icons.emoji_events_outlined,
              label: 'Room Level',
              value:
                  'Lv.${AudioRoomV2.calculateRoomLevel(_currentRoom.totalRevenue, _roomLevelConfigData)}',
            ),
            _buildDetailItem(
              icon: Icons.diamond_outlined,
              label: 'Room Sending',
              value: '${_currentRoom.totalRevenue}',
            ),
            _buildDetailItem(
              icon: Icons.person,
              label: 'Host',
              value: _currentRoom.creatorName,
            ),
            if (_currentRoom.description.isNotEmpty)
              _buildDetailItem(
                icon: Icons.description,
                label: 'Description',
                value: _currentRoom.description,
              ),
            if (_currentRoom.settings.announcement?.isNotEmpty ?? false)
              _buildDetailItem(
                icon: Icons.campaign,
                label: 'Announcement',
                value: _currentRoom.settings.announcement!,
              ),
            _buildDetailItem(
              icon: Icons.category,
              label: 'Mode',
              value: _currentRoom.settings.roomMode.displayName,
            ),

            const SizedBox(height: 24),
            // Bottom Action (optional)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    bool showCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00BCD4), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (showCopy)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('ID copied to clipboard')),
                          );
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Color(0xFF00BCD4),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showViewersList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int activeTabIndex = 0; // State for tabs inside bottom sheet

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_received_gifts')
                  .where('roomId', isEqualTo: _currentRoom.id)
                  .snapshots(),
              builder: (context, giftSnapshot) {
                final List<GiftTransaction> allTransactions = [];
                final Map<String, Map<String, String?>> userProfileCache = {};
                final Map<String, List<GiftTransaction>> transactionsBySender =
                    {};

                if (giftSnapshot.hasData && giftSnapshot.data != null) {
                  for (final doc in giftSnapshot.data!.docs) {
                    try {
                      final data = doc.data() as Map<String, dynamic>;
                      final tx =
                          GiftTransaction.fromJson({...data, 'id': doc.id});
                      allTransactions.add(tx);

                      userProfileCache[tx.senderId] = {
                        'name': tx.senderName,
                        'avatar': tx.senderImageUrl,
                        'frameId': null,
                      };
                    } catch (e) {
                      debugPrint('Error parsing gift transaction: $e');
                    }
                  }
                }

                // Cache active online participant details
                for (final p in _currentRoom.participants) {
                  userProfileCache[p.userId] = {
                    'name': p.userName,
                    'avatar': p.userImageUrl,
                    'frameId': p.frameId,
                  };
                }

                for (final tx in allTransactions) {
                  transactionsBySender
                      .putIfAbsent(tx.senderId, () => [])
                      .add(tx);
                }

                final now = DateTime.now();
                final last24h = now.subtract(const Duration(hours: 24));
                final last7days = now.subtract(const Duration(days: 7));

                // Helper to sum contribution
                int sumCredits(List<GiftTransaction> txs, DateTime? since) {
                  int total = 0;
                  for (final tx in txs) {
                    if (since == null || tx.timestamp.isAfter(since)) {
                      total += tx.credits;
                    }
                  }
                  return total;
                }

                // 1. ONLINE RANK (Online users ranked by 24h contribution)
                final List<Map<String, dynamic>> onlineRankList = [];
                final List<AudioRoomParticipant> onlineUsers =
                    List.from(_currentRoom.participants);

                onlineUsers.sort((a, b) {
                  final txA = transactionsBySender[a.userId] ?? [];
                  final txB = transactionsBySender[b.userId] ?? [];
                  final conA = sumCredits(txA, last24h);
                  final conB = sumCredits(txB, last24h);

                  if (conA != conB) {
                    return conB.compareTo(conA);
                  }
                  if (a.isHost && !b.isHost) return -1;
                  if (!a.isHost && b.isHost) return 1;
                  return a.userName.compareTo(b.userName);
                });

                int onlineRankCounter = 1;
                for (final u in onlineUsers) {
                  final txs = transactionsBySender[u.userId] ?? [];
                  final contribution = sumCredits(txs, last24h);
                  final rank = contribution > 0 ? onlineRankCounter++ : 0;

                  onlineRankList.add({
                    'userId': u.userId,
                    'userName': u.userName,
                    'userImageUrl': u.userImageUrl,
                    'frameId': u.frameId,
                    'contribution': contribution,
                    'rank': rank,
                  });
                }

                // 2. WEEKLY RANK (All contributors ranked by weekly contribution > 0)
                final List<Map<String, dynamic>> weeklyRankList = [];
                final List<String> weeklyContributors =
                    transactionsBySender.keys.where((userId) {
                  final txs = transactionsBySender[userId] ?? [];
                  return sumCredits(txs, last7days) > 0;
                }).toList();

                weeklyContributors.sort((a, b) {
                  final conA =
                      sumCredits(transactionsBySender[a] ?? [], last7days);
                  final conB =
                      sumCredits(transactionsBySender[b] ?? [], last7days);
                  return conB.compareTo(conA);
                });

                int weeklyRankCounter = 1;
                for (final userId in weeklyContributors) {
                  final cache = userProfileCache[userId] ?? {};
                  final con =
                      sumCredits(transactionsBySender[userId] ?? [], last7days);
                  weeklyRankList.add({
                    'userId': userId,
                    'userName': cache['name'] ?? 'User',
                    'userImageUrl': cache['avatar'] ?? '',
                    'frameId': cache['frameId'],
                    'contribution': con,
                    'rank': weeklyRankCounter++,
                  });
                }

                // 3. TOTAL RANK (All contributors ranked by lifetime contribution > 0)
                final List<Map<String, dynamic>> totalRankList = [];
                final List<String> totalContributors =
                    transactionsBySender.keys.where((userId) {
                  final txs = transactionsBySender[userId] ?? [];
                  return sumCredits(txs, null) > 0;
                }).toList();

                totalContributors.sort((a, b) {
                  final conA = sumCredits(transactionsBySender[a] ?? [], null);
                  final conB = sumCredits(transactionsBySender[b] ?? [], null);
                  return conB.compareTo(conA);
                });

                int totalRankCounter = 1;
                for (final userId in totalContributors) {
                  final cache = userProfileCache[userId] ?? {};
                  final con =
                      sumCredits(transactionsBySender[userId] ?? [], null);
                  totalRankList.add({
                    'userId': userId,
                    'userName': cache['name'] ?? 'User',
                    'userImageUrl': cache['avatar'] ?? '',
                    'frameId': cache['frameId'],
                    'contribution': con,
                    'rank': totalRankCounter++,
                  });
                }

                // Pick active lists
                List<Map<String, dynamic>> activeItems = [];
                Map<String, dynamic> myRankItem = {};

                if (activeTabIndex == 0) {
                  activeItems = onlineRankList;
                  myRankItem = onlineRankList.firstWhere(
                    (item) => item['userId'] == _currentUser.userId,
                    orElse: () => {
                      'userId': _currentUser.userId,
                      'userName': _currentUser.fullname,
                      'userImageUrl': _currentUser.photoUrl,
                      'frameId': _currentUser.customization?.selectedFrameId,
                      'contribution': 0,
                      'rank': 0,
                    },
                  );
                } else if (activeTabIndex == 1) {
                  activeItems = weeklyRankList;
                  myRankItem = weeklyRankList.firstWhere(
                    (item) => item['userId'] == _currentUser.userId,
                    orElse: () {
                      final myWeeklyCon = sumCredits(
                          transactionsBySender[_currentUser.userId] ?? [],
                          last7days);
                      return {
                        'userId': _currentUser.userId,
                        'userName': _currentUser.fullname,
                        'userImageUrl': _currentUser.photoUrl,
                        'frameId': _currentUser.customization?.selectedFrameId,
                        'contribution': myWeeklyCon,
                        'rank': 0,
                      };
                    },
                  );
                } else {
                  activeItems = totalRankList;
                  myRankItem = totalRankList.firstWhere(
                    (item) => item['userId'] == _currentUser.userId,
                    orElse: () {
                      final myTotalCon = sumCredits(
                          transactionsBySender[_currentUser.userId] ?? [],
                          null);
                      return {
                        'userId': _currentUser.userId,
                        'userName': _currentUser.fullname,
                        'userImageUrl': _currentUser.photoUrl,
                        'frameId': _currentUser.customization?.selectedFrameId,
                        'contribution': myTotalCon,
                        'rank': 0,
                      };
                    },
                  );
                }

                return Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Custom Tabs (Design closely matches provided screenshot)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTab('Online Rank', activeTabIndex == 0, () {
                              setStateModal(() {
                                activeTabIndex = 0;
                              });
                            }),
                            _buildTab('Weekly Rank', activeTabIndex == 1, () {
                              setStateModal(() {
                                activeTabIndex = 1;
                              });
                            }),
                            _buildTab('Total Rank', activeTabIndex == 2, () {
                              setStateModal(() {
                                activeTabIndex = 2;
                              });
                            }),
                          ],
                        ),
                      ),

                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),

                      // Description line with help icon
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                activeTabIndex == 0
                                    ? 'Ranked by the value of gifts contributed by online users'
                                    : activeTabIndex == 1
                                        ? 'Ranked by the value of weekly gifts contributed in this room'
                                        : 'Ranked by the value of lifetime gifts contributed in this room',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Ranking Rules',
                                        style: TextStyle(color: Colors.white)),
                                    content: const Text(
                                      'Online Rank lists active users in the room by their 24h contribution.\n\n'
                                      'Weekly Rank lists all room contributors by their weekly contribution.\n\n'
                                      'Total Rank lists all room contributors by their lifetime contribution.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK',
                                            style: TextStyle(
                                                color: Color(0xFF00BCD4))),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.help_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Ranked list view
                      Expanded(
                        child: activeItems.isEmpty
                            ? Center(
                                child: Text(
                                  'No contributions yet',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: activeItems.length,
                                itemBuilder: (context, index) {
                                  final item = activeItems[index];
                                  return _buildRankRow(item);
                                },
                              ),
                      ),

                      // My Rank sticky banner at bottom (exactly matching provided screenshot)
                      _buildMyRankBanner(myRankItem),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTab(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(
                    color: Color(0xFF00BCD4),
                    width: 2.0,
                  ),
                )
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF00BCD4) : Colors.grey,
            fontSize: 15,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFE0E0E0), Color(0xFF757575)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFB74D), Color(0xFFE65100)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '3',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return const SizedBox(
        width: 22,
        child: Text(
          '-',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  String _formatDiamonds(double value) {
    final int val = value.toInt();
    if (val >= 1000000000000) {
      return '${(val / 1000000000000).toStringAsFixed(1).replaceAll('.0', '')}T';
    }
    if (val >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
    }
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return val.toString();
  }

  Future<Map<String, String?>> _loadLevelImages(
      int? sendingLevel, int? receivingLevel) async {
    final result = <String, String?>{
      'sending': null,
      'receiving': null,
    };

    try {
      if (sendingLevel != null) {
        final sendDoc = await FirebaseFirestore.instance
            .collection('level_configurations')
            .doc('sending_config')
            .get();
        if (sendDoc.exists) {
          final levels = sendDoc.data()?['levels'] as List<dynamic>?;
          if (levels != null) {
            for (final lvl in levels) {
              if (lvl['levelNumber'] == sendingLevel) {
                result['sending'] = lvl['imageUrl'] as String?;
                break;
              }
            }
          }
        }
      }

      if (receivingLevel != null) {
        final receiveDoc = await FirebaseFirestore.instance
            .collection('level_configurations')
            .doc('receiving_config')
            .get();
        if (receiveDoc.exists) {
          final levels = receiveDoc.data()?['levels'] as List<dynamic>?;
          if (levels != null) {
            for (final lvl in levels) {
              if (lvl['levelNumber'] == receivingLevel) {
                result['receiving'] = lvl['imageUrl'] as String?;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading level images in _AudioRoomScreenState: $e');
    }

    return result;
  }

  Widget _buildRankRow(Map<String, dynamic> item, {bool isMyRank = false}) {
    final int rank = item['rank'] ?? 0;
    final double contribution = (item['contribution'] ?? 0).toDouble();
    final String name = item['userName'] ?? 'User';
    final String avatarUrl = item['userImageUrl'] ?? '';
    final String? frameId = item['frameId'];
    final String userId = item['userId'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).get(),
      builder: (context, userSnapshot) {
        final Map<String, dynamic>? uData =
            userSnapshot.data?.data() as Map<String, dynamic>?;
        final String displayName = uData?['fullname'] ?? name;
        final String displayAvatar = uData?['photoUrl'] ?? avatarUrl;

        final Map? sendingLevelMap = uData?['sendingLevel'] as Map?;
        final int sendLvl = (sendingLevelMap?['level'] as num?)?.toInt() ?? 1;

        final Map? receivingLevelMap = uData?['receivingLevel'] as Map?;
        final int receiveLvl =
            (receivingLevelMap?['level'] as num?)?.toInt() ?? 1;

        final Map? customizationMap = uData?['customization'] as Map?;
        final String? selectedNameplateId =
            customizationMap?['selectedNameplateId'] as String?;

        return FutureBuilder<Map<String, String?>>(
          future: _loadLevelImages(sendLvl, receiveLvl),
          builder: (context, levelSnapshot) {
            final sendImageUrl = levelSnapshot.data?['sending'];
            final receiveImageUrl = levelSnapshot.data?['receiving'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isMyRank ? const Color(0xFF1E1E1E) : Colors.transparent,
                border: isMyRank
                    ? const Border(
                        top: BorderSide(color: Colors.white10, width: 0.5))
                    : null,
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close rankings sheet
                  final tempParticipant = AudioRoomParticipant(
                    userId: userId,
                    userName: displayName,
                    userImageUrl: displayAvatar,
                    frameId: frameId,
                    joinedAt: DateTime.now(),
                  );
                  _showParticipantBottomSheet(tempParticipant);
                },
                child: Row(
                  children: [
                    // Rank Medal / Dash
                    Container(
                      width: 32,
                      alignment: Alignment.centerLeft,
                      child: _buildRankBadge(rank),
                    ),
                    const SizedBox(width: 8),

                    // Avatar
                    CachedCircleAvatar(
                      imageUrl: displayAvatar,
                      radius: 22,
                      frameId: frameId,
                      userId: userId,
                    ),
                    const SizedBox(width: 12),

                    // Username & Level badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMyRank ? 16 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (sendImageUrl != null &&
                                  sendImageUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: sendImageUrl,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  errorWidget: (context, url, err) =>
                                      const SizedBox.shrink(),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Send Lv.$sendLvl',
                                    style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              if (receiveImageUrl != null &&
                                  receiveImageUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: receiveImageUrl,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  errorWidget: (context, url, err) =>
                                      const SizedBox.shrink(),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA4C89)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Recv Lv.$receiveLvl',
                                    style: const TextStyle(
                                        color: Color(0xFFEA4C89),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (selectedNameplateId != null &&
                                  selectedNameplateId.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                FutureBuilder<String?>(
                                  future: NameplateHelper.getNameplateUrl(
                                      selectedNameplateId),
                                  builder: (context, snapshot) {
                                    final nameplateUrl = snapshot.data;
                                    if (nameplateUrl != null &&
                                        nameplateUrl.isNotEmpty) {
                                      return CachedNetworkImage(
                                        imageUrl: nameplateUrl,
                                        height: 18,
                                        fit: BoxFit.contain,
                                        errorWidget: (context, url, err) =>
                                            const SizedBox.shrink(),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Gifting diamond value (Only displayed if contribution > 0)
                    if (contribution > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DynamicDiamondIcon(
                            width: 16,
                            height: 16,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.diamond_outlined,
                              color: Color(0xFF00BCD4),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDiamonds(contribution),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyRankBanner(Map<String, dynamic> item) {
    return _buildRankRow(item, isMyRank: true);
  }

  void _handleMessageTap(EmojiChatMessage message) {
    try {
      if (message.messageType == EmojiMessageType.voteResult) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => VotingResultSheet(roomId: _currentRoom.id),
        );
        return;
      }
      // Find participant in the current room
      AudioRoomParticipant? targetParticipant;
      try {
        targetParticipant = _currentRoom.participants.firstWhere(
          (p) => p.userId == message.userId,
        );
      } catch (e) {
        // If not a participant in the list, create a temporary one for profile view
        targetParticipant = AudioRoomParticipant(
          userId: message.userId,
          userName: message.username,
          userImageUrl: message.userAvatar,
          joinedAt: message.timestamp,
        );
      }

      _showParticipantBottomSheet(targetParticipant);
    } catch (e) {
      debugPrint('💬 Error handling message tap: $e');
    }
  }

  /// Handle seat selection for gift sending (no longer needed - gifts go to host)
  void _selectUserForGift(AudioRoomParticipant participant) {
    // This method is kept for compatibility but no longer needed
    // since gifts are automatically sent to the host
  }

  /// Handle seat long press (host actions)
  void _handleSeatLongPress(int seatNumber, AudioRoomParticipant? occupant) {
    try {
      if (!_isCurrentUserHost) {
        // Only hosts can use long press actions
        return;
      }

      // Prevent host from long-pressing their own seat
      if (occupant?.userId == _currentUser.userId) {
        return;
      }

      // Special handling for admin seat (seat 1)

      // Show host management menu
      if (occupant == null) {
        _showEmptySeatMenu(seatNumber);
      } else {
        _showOccupiedSeatMenu(seatNumber, occupant);
      }
    } catch (e) {
      debugPrint('🪑 Error handling seat long press: $e');
    }
  }

  /// Show locked seat message
  void _showLockedSeatMessage(int seatNumber) {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Row(
    //       children: [
    //         const Icon(Icons.lock, color: Colors.white, size: 20),
    //         const SizedBox(width: 8),
    //         Text('Seat $seatNumber is locked by host'),
    //       ],
    //     ),
    //     backgroundColor: Colors.orange.withValues(alpha: 0.8),
    //     behavior: SnackBarBehavior.floating,
    //     margin: const EdgeInsets.all(16),
    //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    //     duration: const Duration(seconds: 2),
    //   ),
    // );
  }

  /// Show occupied seat message
  void _showOccupiedSeatMessage(int seatNumber) {
    final occupant = _currentRoom.getParticipantInSeat(seatNumber);
    final occupantName = occupant?.userName ?? 'Someone';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.person, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Seat $seatNumber is occupied by $occupantName'),
          ],
        ),
        backgroundColor: Colors.blue.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show admin seat takeover confirmation dialog
  void _showAdminSeatTakeoverDialog(
      int seatNumber, AudioRoomParticipant currentOccupant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Take Over Seat'),
          content: Text(
            'Seat $seatNumber is currently occupied by ${currentOccupant.userName}. '
            'As the room admin, you can take over this seat. The current occupant will be moved to the audience.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmAdminSeatTakeover(seatNumber);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Take Over'),
            ),
          ],
        );
      },
    );
  }

  /// Confirm admin seat takeover
  void _confirmAdminSeatTakeover(int seatNumber) {
    try {
      debugPrint('🪑 [UI] Admin confirming seat takeover for seat $seatNumber');

      // Find current seat of admin
      final currentParticipant = _currentParticipant;
      final currentSeat = currentParticipant?.seatNumber ?? 0;

      debugPrint(
          '🪑 [UI] Admin moving from seat $currentSeat to seat $seatNumber (takeover)');

      // Dispatch the move event
      widget.audioRoomsBloc.add(MoveParticipantToSeat(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        fromSeat: currentSeat,
        toSeat: seatNumber,
      ));
    } catch (e) {
      debugPrint('🪑 [UI] Error in admin seat takeover: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take over seat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Move current user to seat
  void _moveToSeat(int seatNumber) {
    try {
      debugPrint('🪑 [UI] Attempting to move to seat $seatNumber');
      debugPrint(
          '🪑 [UI] Seat locked: ${_currentRoom.isSeatLocked(seatNumber)}');
      debugPrint(
          '🪑 [UI] Seat occupied: ${_currentRoom.isSeatOccupied(seatNumber)}');
      debugPrint(
          '🪑 [UI] Can user move: ${_currentRoom.canUserMoveToSeat(_currentUser.userId, seatNumber)}');

      if (!_currentRoom.canUserMoveToSeat(_currentUser.userId, seatNumber)) {
        if (_currentRoom.isSeatLocked(seatNumber)) {
          debugPrint(
              '🪑 [UI] Seat $seatNumber is locked - showing lock message');
          _showLockedSeatMessage(seatNumber);
        } else if (_currentRoom.isSeatOccupied(seatNumber)) {
          debugPrint(
              '🪑 [UI] Seat $seatNumber is occupied - showing occupied message');
          _showOccupiedSeatMessage(seatNumber);
        } else {
          debugPrint('🪑 [UI] Seat $seatNumber unavailable for unknown reason');
          _showLockedSeatMessage(seatNumber);
        }
        return;
      }

      // Special case: Admin moving to occupied seat - show confirmation dialog
      final isAdmin = _currentRoom.isCreator(_currentUser.userId);
      final isOccupied = _currentRoom.isSeatOccupied(seatNumber);

      if (isAdmin && isOccupied) {
        final currentOccupant = _currentRoom.getParticipantInSeat(seatNumber);
        if (currentOccupant != null) {
          debugPrint(
              '🪑 [UI] Admin moving to occupied seat - showing confirmation');
          _showAdminSeatTakeoverDialog(seatNumber, currentOccupant);
          return;
        }
      }

      // Find current seat of user
      final currentParticipant = _currentParticipant;
      final currentSeat = currentParticipant?.seatNumber ?? 0;

      debugPrint('🪑 [UI] ===== MOVE REQUEST START =====');
      debugPrint(
          '🪑 [UI] Current participant: ${currentParticipant?.userName}');
      debugPrint(
          '🪑 [UI] Current participant seat: ${currentParticipant?.seatNumber}');
      debugPrint(
          '🪑 [UI] Moving user from seat $currentSeat to seat $seatNumber');

      // Debug: Check all participants and their seats
      debugPrint('🪑 [UI] All participants and their seats:');
      // for (final p in _currentRoom.participants) {
      //   debugPrint('🪑 [UI] - ${p.userName}: seat ${p.seatNumber}');
      // }

      widget.audioRoomsBloc.add(MoveParticipantToSeat(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        fromSeat: currentSeat,
        toSeat: seatNumber,
      ));

      // Fix: Persist admin mute status on rejoin
      // If the user was previously muted by admin (as a listener/participant),
      // ensure this status carries over to the new seat assignment.
      if (currentParticipant != null && currentParticipant.isMutedByAdmin) {
        debugPrint('🪑 [UI] User was muted by admin - re-applying mute status');
        // We need to wait slightly for the move to process or just send the update
        // The bloc might process these sequentially.
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.audioRoomsBloc.add(UpdateRoomParticipant(
            roomId: _currentRoom.id,
            userId: _currentUser.userId,
            updatedParticipant: currentParticipant.copyWith(
              seatNumber: seatNumber,
              isMutedByAdmin: true,
              isMuted: true,
            ),
          ));
        });
      }

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Moving to seat $seatNumber...'),
      //     backgroundColor: Colors.blue.withValues(alpha: 0.8),
      //     duration: const Duration(seconds: 1),
      //   ),
      // );
    } catch (e) {
      debugPrint('🪑 Error moving to seat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to move to seat'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
        ),
      );
    }
  }

  /// Show cute popup menu for empty seat (host only)
  void _showEmptySeatMenu(int seatNumber) {
    // SECURITY CHECK: Only host can see this menu
    if (!_isCurrentUserHost) return;

    final isLocked = _currentRoom.isSeatLocked(seatNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        seatNumber.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seat $seatNumber',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isLocked ? 'Locked' : 'Empty',
                        style: TextStyle(
                          color: isLocked ? Colors.orange : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu options
            if (isLocked) ...[
              _buildMenuOption(
                icon: Icons.lock_open,
                title: 'Unlock Seat',
                subtitle: 'Allow participants to sit here',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _toggleSeatLock(seatNumber, false);
                },
              ),
            ] else ...[
              _buildMenuOption(
                icon: Icons.lock,
                title: 'Lock Seat',
                subtitle: 'Prevent participants from sitting',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _toggleSeatLock(seatNumber, true);
                },
              ),
              _buildMenuOption(
                icon: Icons.person_add,
                title: 'Invite Someone',
                subtitle: 'Invite a listener to this seat',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _showInviteToSeatSheet(seatNumber);
                },
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Show cute popup menu for occupied seat (host only)
  void _showOccupiedSeatMenu(int seatNumber, AudioRoomParticipant occupant) {
    // SECURITY CHECK: Only host can see this menu
    if (!_isCurrentUserHost) return;

    // SECURITY CHECK: Admins cannot open menu for Creator or other Admins
    // Only the Creator has full access to everyone.
    final isCreator = _currentUser.userId == _currentRoom.creatorId;
    if (!isCreator) {
      // If I am just an Admin (not Creator), I cannot touch Creator or other Admins
      if (_currentRoom.isCreator(occupant.userId) || occupant.isHost) {
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title with user info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CachedCircleAvatar(
                    imageUrl: occupant.userImageUrl ?? '',
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          occupant.userName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        // Admin/Viewer Tag
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_currentRoom.isCreator(occupant.userId) ||
                                    occupant.isHost)
                                ? Colors.purple.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (_currentRoom.isCreator(occupant.userId) ||
                                      occupant.isHost)
                                  ? Colors.purple.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _currentRoom.isCreator(occupant.userId)
                                ? 'Owner'
                                : (occupant.isHost ? 'Admin' : 'Viewer'),
                            style: TextStyle(
                              fontSize: 10,
                              color: (_currentRoom.isCreator(occupant.userId) ||
                                      occupant.isHost)
                                  ? Colors.purple
                                  : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            Text(
                              'Seat $seatNumber',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                            if (_currentRoom.isCreator(occupant.userId) ||
                                occupant.isHost) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              Text(
                                  _currentRoom.isCreator(occupant.userId)
                                      ? ' Host'
                                      : ' Admin',
                                  style: const TextStyle(
                                      color: Colors.amber, fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu options
            _buildMenuOption(
              icon: Icons.chair_alt,
              title: 'Remove from Seat',
              subtitle: 'Move participant to listeners',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _removeParticipantFromSeat(seatNumber, occupant);
              },
            ),

            // Mute/Unmute
            _buildMenuOption(
              icon: occupant.isMutedByAdmin ? Icons.mic : Icons.mic_off,
              title: occupant.isMutedByAdmin ? 'Unmute' : 'Mute',
              subtitle: occupant.isMutedByAdmin
                  ? 'Allow participant to speak'
                  : 'Prevent participant from speaking',
              color: occupant.isMutedByAdmin ? Colors.green : Colors.red,
              onTap: () {
                Navigator.pop(context);
                _toggleParticipantMute(occupant);
              },
            ),

            // Make Admin (Only visible to Room Creator and if occupant is not already host)
            if (_currentUser.userId == _currentRoom.creatorId &&
                !occupant.isHost)
              _buildMenuOption(
                icon: Icons.shield,
                title: 'Make Admin',
                subtitle: 'Give moderation privileges',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _promoteToAdmin(occupant);
                },
              ),

            // Kick/Block
            _buildMenuOption(
              icon: Icons.exit_to_app,
              title: 'Kick from Room',
              subtitle: 'Remove participant from room',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showKickConfirmation(occupant);
              },
            ),

            _buildMenuOption(
              icon: Icons.block,
              title: 'Block Participant',
              subtitle: 'Block and prevent from rejoining',
              color: Colors.red[800]!,
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(occupant);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Build menu option widget
  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Toggle seat lock/unlock
  void _toggleSeatLock(int seatNumber, bool isLocked) {
    try {
      debugPrint('🪑 Toggling seat $seatNumber lock to $isLocked');

      widget.audioRoomsBloc.add(ToggleSeatLock(
        roomId: _currentRoom.id,
        hostId: _currentUser.userId,
        seatNumber: seatNumber,
        isLocked: isLocked,
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat $seatNumber ${isLocked ? 'locked' : 'unlocked'}'),
          backgroundColor: isLocked ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('🪑 Error toggling seat lock: $e');
    }
  }

  /// Remove participant from seat
  void _removeParticipantFromSeat(
      int seatNumber, AudioRoomParticipant participant) {
    try {
      debugPrint('🪑 Removing ${participant.userName} from seat $seatNumber');

      widget.audioRoomsBloc.add(RemoveParticipantFromSeat(
        roomId: _currentRoom.id,
        hostId: _currentUser.userId,
        participantId: participant.userId,
        seatNumber: seatNumber,
      ));

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('${participant.userName} removed from seat'),
      //     backgroundColor: Colors.orange,
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      debugPrint('🪑 Error removing participant from seat: $e');
    }
  }

  /// Promote a participant to admin
  void _promoteToAdmin(AudioRoomParticipant participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Admin?'),
        content: Text(
            'Are you sure you want to promote ${participant.userName} to Admin? They will have moderation privileges.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              final updatedParticipant = participant.copyWith(isHost: true);

              widget.audioRoomsBloc.add(UpdateRoomParticipant(
                roomId: _currentRoom.id,
                userId: _currentUser.userId,
                updatedParticipant: updatedParticipant,
              ));

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${participant.userName} is now an Admin'),
                  backgroundColor: Colors.purple,
                ),
              );
            },
            child: const Text('Make Admin'),
          ),
        ],
      ),
    );
  }

  /// Toggle participant mute status
  void _toggleParticipantMute(AudioRoomParticipant participant) {
    try {
      // Prevent admin from admin-muting themselves
      if (participant.userId == _currentUser.userId) {
        // Just use normal local toggle if they really want to mute themselves
        _handleMuteToggle();
        return;
      }

      // Logic:
      // 1. If currently Admin-Muted -> Unmute (remove restrictions)
      // 2. If NOT Admin-Muted (even if Self-Muted) -> Admin-Mute (apply restrictions)

      final bool isCurrentlyAdminMuted = participant.isMutedByAdmin;
      final bool newMuteState = !isCurrentlyAdminMuted;

      // If we are applying Admin Mute, we set both isMuted and isMutedByAdmin to true
      // If we are removing Admin Mute, we set both to false (giving user back control)

      final updatedParticipant = participant.copyWith(
        isMuted: newMuteState,
        isMutedByAdmin: newMuteState,
      );

      widget.audioRoomsBloc.add(UpdateRoomParticipant(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        updatedParticipant: updatedParticipant,
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${participant.userName} ${newMuteState ? 'muted by admin' : 'unmuted by admin'}'),
          backgroundColor: newMuteState ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('🪑 Error toggling participant mute: $e');
    }
  }

  /// Show kick confirmation dialog
  void _showKickConfirmation(AudioRoomParticipant participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kick Participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedCircleAvatar(
              imageUrl: participant.userImageUrl ?? '',
              radius: 30,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to kick ${participant.userName} from the room?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'They will be removed but can rejoin later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _kickParticipant(participant);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kick', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Show block confirmation dialog
  void _showBlockConfirmation(AudioRoomParticipant participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block Participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedCircleAvatar(
              imageUrl: participant.userImageUrl ?? '',
              radius: 30,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to block ${participant.userName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'They will be permanently blocked from this room and cannot rejoin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _blockParticipant(participant);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Kick participant from room
  void _kickParticipant(AudioRoomParticipant participant) {
    try {
      debugPrint('🚪 Kicking ${participant.userName} from room');

      widget.audioRoomsBloc.add(KickParticipant(
        roomId: _currentRoom.id,
        hostId: _currentUser.userId,
        participantId: participant.userId,
        reason: 'Removed by host',
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${participant.userName} has been kicked from the room'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('🚪 Error kicking participant: $e');
    }
  }

  /// Block participant from room
  void _blockParticipant(AudioRoomParticipant participant) {
    try {
      debugPrint('🚫 Blocking ${participant.userName} from room');

      widget.audioRoomsBloc.add(BlockParticipant(
        roomId: _currentRoom.id,
        hostId: _currentUser.userId,
        participantId: participant.userId,
        reason: 'Blocked by host',
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${participant.userName} has been blocked from the room'),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('🚫 Error blocking participant: $e');
    }
  }

  /// Show user's own seat options
  void _showUserSeatOptions(int seatNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CachedCircleAvatar(
                    imageUrl: _currentUser.photoUrl,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Seat',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Seat $seatNumber',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu options
            _buildMenuOption(
              icon: Icons.chair_alt,
              title: 'Leave Seat',
              subtitle: 'Move to listeners area',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _leaveSeat();
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Leave current seat
  void _leaveSeat() {
    try {
      final currentParticipant = _currentParticipant;
      if (currentParticipant?.seatNumber == null) return;

      debugPrint(
          '🪑 [UI] User leaving their own seat ${currentParticipant!.seatNumber}');

      // For self-removal, we'll use MoveParticipantToSeat with seat 0 (no seat)
      // This bypasses the host permission check since users can move themselves
      widget.audioRoomsBloc.add(MoveParticipantToSeat(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        fromSeat: currentParticipant.seatNumber!,
        toSeat: 0, // 0 means no seat (listener area)
      ));

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('You left your seat'),
      //     backgroundColor: Colors.blue,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      debugPrint('🪑 Error leaving seat: $e');
    }
  }

  void _showEmptySeatAdminOptions(int seatNumber) {
    final isLocked = _currentRoom.isSeatLocked(seatNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1724),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[700]!, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        seatNumber.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seat $seatNumber',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        isLocked ? 'Locked' : 'Empty',
                        style: TextStyle(
                          color: isLocked ? Colors.orange : Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Menu options
            _buildMenuOption(
              icon: Icons.chair,
              title: 'Take Seat',
              subtitle: 'Sit in this empty seat',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _moveToSeat(seatNumber);
              },
            ),
            _buildMenuOption(
              icon: Icons.person_add,
              title: 'Invite Someone',
              subtitle: 'Invite a user to this seat',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showInviteToSeatSheet(seatNumber);
              },
            ),
            if (isLocked) ...[
              _buildMenuOption(
                icon: Icons.lock_open,
                title: 'Unlock Seat',
                subtitle: 'Allow participants to sit here',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _toggleSeatLock(seatNumber, false);
                },
              ),
            ] else ...[
              _buildMenuOption(
                icon: Icons.lock,
                title: 'Lock Seat',
                subtitle: 'Prevent participants from sitting',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _toggleSeatLock(seatNumber, true);
                },
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showInviteToSeatSheet(int seatNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DefaultTabController(
              length: 3,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1724),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'Invite to Seat $seatNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // TabBar
                    const TabBar(
                      tabs: [
                        Tab(text: 'Online'),
                        Tab(text: 'Followers'),
                        Tab(text: 'Members'),
                      ],
                      labelColor: Colors.purpleAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.purpleAccent,
                    ),

                    // TabBarView
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildOnlineTabList(seatNumber, setSheetState),
                          _buildFollowersTabList(seatNumber, setSheetState),
                          _buildMembersTabList(seatNumber, setSheetState),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOnlineTabList(int seatNumber, StateSetter setSheetState) {
    final onlineListeners = _currentRoom.participants
        .where((p) => !p.isSeated && p.userId != _currentUser.userId)
        .toList();

    if (onlineListeners.isEmpty) {
      return const Center(
        child: Text(
          'No online audience found.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: onlineListeners.length,
      itemBuilder: (context, index) {
        final listener = onlineListeners[index];
        final isInvited = _invitedUserIds.contains(listener.userId);

        return ListTile(
          tileColor: Colors.transparent,
          leading: CachedCircleAvatar(
            imageUrl: listener.userImageUrl ?? '',
            radius: 20,
          ),
          title: Text(
            listener.userName,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: ElevatedButton(
            onPressed: isInvited
                ? null
                : () {
                    setSheetState(() {
                      _invitedUserIds.add(listener.userId);
                    });
                    _inviteToSeat(listener, seatNumber);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isInvited ? Colors.grey[800] : Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(isInvited ? 'Invited' : 'Invite'),
          ),
        );
      },
    );
  }

  Widget _buildFollowersTabList(int seatNumber, StateSetter setSheetState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(_currentUser.userId)
          .collection('followers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No followers found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final targetUserId = docs[index].id;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(targetUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userId = userSnapshot.data!.id;
                userData['userId'] = userId;
                final name = userData['fullname'] ?? userData['name'] ?? 'User';
                final avatarUrl =
                    userData['photoUrl'] ?? userData['imageUrl'] ?? '';
                final isInvited = _invitedUserIds.contains(userId);

                return ListTile(
                  tileColor: Colors.transparent,
                  leading: CachedCircleAvatar(
                    imageUrl: avatarUrl,
                    radius: 20,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: ElevatedButton(
                    onPressed: isInvited
                        ? null
                        : () {
                            setSheetState(() {
                              _invitedUserIds.add(userId);
                            });
                            _inviteToSeat(userData, seatNumber);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isInvited ? Colors.grey[800] : Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(isInvited ? 'Invited' : 'Invite'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTabList(int seatNumber, StateSetter setSheetState) {
    final memberIds = _currentRoom.joinedUserIds
        .where((uid) => uid != _currentUser.userId)
        .toList();

    if (memberIds.isEmpty) {
      return const Center(
        child: Text(
          'No other room members found.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: memberIds.length,
      itemBuilder: (context, index) {
        final targetUserId = memberIds[index];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(targetUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userId = userSnapshot.data!.id;
            userData['userId'] = userId;
            final name = userData['fullname'] ?? userData['name'] ?? 'User';
            final avatarUrl =
                userData['photoUrl'] ?? userData['imageUrl'] ?? '';
            final isInvited = _invitedUserIds.contains(userId);

            return ListTile(
              tileColor: Colors.transparent,
              leading: CachedCircleAvatar(
                imageUrl: avatarUrl,
                radius: 20,
              ),
              title: Text(
                name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: ElevatedButton(
                onPressed: isInvited
                    ? null
                    : () {
                        setSheetState(() {
                          _invitedUserIds.add(userId);
                        });
                        _inviteToSeat(userData, seatNumber);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isInvited ? Colors.grey[800] : Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(isInvited ? 'Invited' : 'Invite'),
              ),
            );
          },
        );
      },
    );
  }

  /// Show Ranking List (Top Gifters)
  void _showRankingList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .doc(_currentRoom.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final liveRoom = AudioRoomV2.fromFirestore(snapshot.data!);
          final allContributors = liveRoom.contributors.values.toList();

          // Daily Ranking
          final dailyContributors = allContributors
              .where((c) => c.dailyContribution > 0)
              .toList()
            ..sort(
                (a, b) => b.dailyContribution.compareTo(a.dailyContribution));

          // Weekly Ranking
          final weeklyContributors = allContributors
              .where((c) => c.weeklyContribution > 0)
              .toList()
            ..sort(
                (a, b) => b.weeklyContribution.compareTo(a.weeklyContribution));

          // Monthly Ranking
          final monthlyContributors = allContributors
              .where((c) => c.monthlyContribution > 0)
              .toList()
            ..sort((a, b) =>
                b.monthlyContribution.compareTo(a.monthlyContribution));

          // All Time Ranking
          final allTimeContributors = allContributors
              .where((c) => c.totalContribution > 0)
              .toList()
            ..sort(
                (a, b) => b.totalContribution.compareTo(a.totalContribution));

          return DefaultTabController(
            length: 4,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Builder(
                builder: (context) => Column(
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events,
                              color: Color(0xFFFFD700)),
                          const SizedBox(width: 8),
                          const Text(
                            'Contributor Ranking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Total Room Revenue Header (Always Visible)
                    GestureDetector(
                      onTap: () {
                        DefaultTabController.of(context).animateTo(3);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Total Room Revenue: ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              _formatRevenue(_currentRoom.totalRevenue),
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.diamond,
                                color: Color(0xFFFFD700), size: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tabs
                    const TabBar(
                      indicatorColor: Color(0xFFFFD700),
                      labelColor: Color(0xFFFFD700),
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: 'Daily'),
                        Tab(text: 'Weekly'),
                        Tab(text: 'Monthly'),
                        Tab(text: 'All Time'),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRankingListView(dailyContributors, 'daily'),
                          _buildRankingListView(weeklyContributors, 'weekly'),
                          _buildRankingListView(monthlyContributors, 'monthly'),
                          _buildRankingListView(
                              allTimeContributors, 'all time'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRankingListView(
      List<RoomContributor> contributors, String type) {
    if (contributors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No $type contributions yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: contributors.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final contributor = contributors[index];
        final rank = index + 1;

        // Top 3 Styling
        Color rankColor;
        IconData? rankIcon;

        if (rank == 1) {
          rankColor = const Color(0xFFFFD700); // Gold
          rankIcon = Icons.looks_one;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          rankIcon = Icons.looks_two;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          rankIcon = Icons.looks_3;
        } else {
          rankColor = Colors.white;
        }

        // Determine which score to show
        int score = 0;
        if (type == 'daily') {
          score = contributor.dailyContribution;
        } else if (type == 'weekly') {
          score = contributor.weeklyContribution;
        } else if (type == 'monthly') {
          score = contributor.monthlyContribution;
        } else {
          score = contributor.totalContribution;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: rank <= 3
                ? LinearGradient(
                    colors: [
                      rankColor.withValues(alpha: 0.2),
                      Colors.transparent
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: rank <= 3
                ? Border(
                    bottom: BorderSide(color: rankColor.withValues(alpha: 0.3)))
                : Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(
            children: [
              // Rank Number/Icon
              SizedBox(
                width: 30,
                child: rank <= 3
                    ? Icon(rankIcon, color: rankColor, size: 28)
                    : Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(width: 16),

              // Avatar
              Container(
                decoration: rank <= 3
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: rankColor, width: 2),
                        boxShadow: [
                            BoxShadow(
                              color: rankColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ])
                    : null,
                child: CachedCircleAvatar(
                  imageUrl: contributor.userAvatar ?? '',
                  radius: 20,
                  userId: contributor.userId,
                  frameScale: 1.5,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contributor.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatRevenue(score),
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.diamond, size: 12, color: rankColor),
                    ],
                  ),
                  Text(
                    'Diamonds',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Remove speaker from seat

  /// Invite listener to seat
  void _inviteToSeat(dynamic user, int seatNumber) async {
    try {
      String userId;
      String userName;

      if (user is AudioRoomParticipant) {
        userId = user.userId;
        userName = user.userName;
      } else if (user is Map) {
        userId = user['userId'] ?? '';
        userName = user['fullname'] ?? user['name'] ?? 'User';
      } else {
        return;
      }

      if (userId.isEmpty) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      final deviceToken = userDoc.data()?['deviceToken'] ?? '';

      if (deviceToken.isNotEmpty) {
        await PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'Room Invitation',
          body:
              '${_currentUser.fullname} invited you to join room "${_currentRoom.name}"',
          deviceToken: deviceToken,
          call: {
            'type': 'room_invite',
            'roomId': _currentRoom.id,
            'title': 'Room Invitation',
            'message':
                '${_currentUser.fullname} invited you to join room "${_currentRoom.name}"',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invited $userName to join room'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error inviting user to seat: $e');
    }
  }

  // Chat methods moved to RoomControls widget

  /// Send chat message
  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;

    widget.audioRoomsBloc.add(SendChatMessage(
      roomId: _currentRoom.id,
      userId: _currentUser.userId,
      username:
          _currentUser.fullname.isNotEmpty ? _currentUser.fullname : 'User',
      userAvatar:
          _currentUser.photoUrl.isNotEmpty ? _currentUser.photoUrl : null,
      message: message.trim(),
    ));

    // Text field clearing is now handled in RoomControls widget
  }

  /// Build speakers section

  /// Build listeners section

  /// Show VoiceRoom Customize sheet (slides from top, auto-sized)
  void _showVoiceRoomCustomize() {
    if (!_isCurrentUserHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Access Denied: Settings are only for Room Owners & Admins.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: const Offset(0, 0),
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                // Auto-size height based on content
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E88E5),
                      const Color(0xFF1565C0),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Only take needed space
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Text(
                              'Room Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content - Room Settings Horizontal List
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            if (_currentRoom
                                .isCreator(_currentUser.userId)) ...[
                              _buildSettingItem('Edit Room', Icons.edit),
                              const SizedBox(width: 20),
                              // YouTube Player
                              _buildSettingItem(
                                  'YouTube', Icons.video_collection),
                              const SizedBox(width: 20),
                              // Ludo Game
                              _buildSettingItem('Ludo Game', Icons.gamepad),
                              const SizedBox(width: 20),
                              // Voting Feature
                              _buildSettingItem('Voting', Icons.how_to_vote),
                              const SizedBox(width: 20),
                              // Custom Roulette Feature
                              _buildSettingItem('Roulette', Icons.casino),
                              const SizedBox(width: 20),
                              // Clear Chat option for host
                              _buildSettingItem(
                                  'Clear Chat', Icons.delete_sweep),
                              const SizedBox(width: 20),
                              // Admins List
                              _buildSettingItem('Admins', Icons.shield),
                              const SizedBox(width: 20),
                              // Seat Lock Option
                              _buildSettingItem('Seat Lock', Icons.lock),
                              const SizedBox(width: 20),
                              // PK Battle
                              _buildSettingItem(
                                  'PK Battle', Icons.sports_kabaddi),
                              const SizedBox(width: 20),
                              _buildSettingItem(
                                  'Music Player', Icons.music_note),
                              const SizedBox(width: 20),
                              // Live Multiple Mode (Live category only)
                              if (_currentRoom.category == 'Live') ...[
                                _buildSettingItem(
                                    'Live Mode', Icons.video_call),
                                const SizedBox(width: 20),
                              ],
                            ],
                            _buildSettingItem('Room Decor', Icons.format_paint),
                            const SizedBox(width: 20),
                            _buildSettingItem(
                                'Room Mode', Icons.dashboard_customize),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLiveModeSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14141F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Live Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('Single Host',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Only the host is visible',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: !_currentRoom.settings.isLiveMultipleMode
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.audioRoomsBloc.add(UpdateRoomSettings(
                    roomId: _currentRoom.id,
                    userId: _currentUser.userId,
                    settings: _currentRoom.settings
                        .copyWith(isLiveMultipleMode: false),
                  ));
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.group, color: Colors.blue),
                title: const Text('Multiple Hosts',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Host + 4 guests',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: _currentRoom.settings.isLiveMultipleMode
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.audioRoomsBloc.add(UpdateRoomSettings(
                    roomId: _currentRoom.id,
                    userId: _currentUser.userId,
                    settings: _currentRoom.settings
                        .copyWith(isLiveMultipleMode: true),
                  ));
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showSeatLockOptions() {
    final audioRoomsBloc = widget.audioRoomsBloc;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14141F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Seat Lock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.lock, color: Colors.red),
                title: const Text('Lock All Seats',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  audioRoomsBloc.add(
                    ToggleAllSeatsLock(
                      roomId: widget.room.id,
                      hostId: _currentUser.userId,
                      isLocked: true,
                    ),
                  );
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.lock_open, color: Colors.green),
                title: const Text('Unlock All Seats',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  audioRoomsBloc.add(
                    ToggleAllSeatsLock(
                      roomId: widget.room.id,
                      hostId: _currentUser.userId,
                      isLocked: false,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Build setting item
  void _showYoutubeSheet() {
    final hostParticipant = _currentRoom.participants
        .firstWhereOrNull((p) => p.userId == _currentRoom.creatorId);
    final isHostInSeat1 = hostParticipant != null &&
        hostParticipant.isSeated &&
        hostParticipant.seatNumber == 1;

    if (!isHostInSeat1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host must be in seat 1 to play YouTube video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YoutubeSelectionSheet(
        onVideoSelected: (videoId) {
          // Play video for the room
          final repo = AudioRoomsRepository();
          repo.updateYoutubeState(
            roomId: _currentRoom.id,
            videoId: videoId,
            isPlaying: true,
            syncPosition: 0,
          );
        },
      ),
    );
  }

  Widget _buildSettingItem(String title, IconData icon) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        if (title == 'Room Decor') {
          _showRoomDecorSheet();
        } else if (title == 'Room Mode') {
          _showSeatConfiguration();
        } else if (title == 'Edit Room') {
          _showEditRoomDialog();
        } else if (title == 'YouTube') {
          _showYoutubeSheet();
        } else if (title == 'Ludo Game') {
          if (!_currentRoom.isLudoActive) {
            LudoSetupBottomSheet.show(context, _currentRoom);
          }
        } else if (title == 'Voting') {
          if (!_currentRoom.isVotingActive) {
            VotingSetupSheet.show(context, _currentRoom, _currentUser.userId);
          }
        } else if (title == 'Roulette') {
          final rouletteController = Get.isRegistered<RouletteController>(
                  tag: 'roulette_${widget.room.id}')
              ? Get.find<RouletteController>(tag: 'roulette_${widget.room.id}')
              : Get.put(
                  RouletteController(widget.room.id,
                      isHost: _isCurrentUserHost),
                  tag: 'roulette_${widget.room.id}');
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                RouletteSelectionSheet(controller: rouletteController),
          );
        } else if (title == 'Clear Chat') {
          _showClearChatConfirmation();
        } else if (title == 'PK Battle') {
          _showPKTypeSelectionSheet();
        } else if (title == 'Music Player') {
          setState(() {
            _showMusicPlayer = true;
          });
        } else if (title == 'Admins') {
          _showAdminsListBottomSheet();
        } else if (title == 'Seat Lock') {
          _showSeatLockOptions();
        } else if (title == 'Live Mode') {
          _showLiveModeSettings();
        }
      },
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showPKTypeSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select PK Type',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.people,
                    color: Colors.blueAccent, size: 30),
                title: const Text('In-Room PK',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('PK between users in this room',
                    style: TextStyle(color: Colors.white70)),
                tileColor: Colors.white12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  _showPKConfigurationSheet();
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.public,
                    color: Colors.pinkAccent, size: 30),
                title: const Text('Room vs Room PK',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('PK against another audio room',
                    style: TextStyle(color: Colors.white70)),
                tileColor: Colors.white12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: RoomPKSettingsSheet(room: _currentRoom),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPKConfigurationSheet() {
    // Verify Seat 1
    final seat1Participant =
        _currentRoom.participants.cast<AudioRoomParticipant?>().firstWhere(
              (p) => p?.seatNumber == 1,
              orElse: () => null,
            );
    if (seat1Participant?.userId != _currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Only the user in Seat 1 can start or extend PK battles.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final pkState = _currentRoom.pkBattleState;
    if (pkState.isActive) {
      _showPKExtendSheet();
      return;
    }

    int selectedDuration = 5;
    int selectedTeamSize = 1;
    String? leftUserId;
    String? rightUserId;
    final seatedUsers =
        _currentRoom.participants.where((p) => p.isSeated).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('PK Battle Configuration',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('Duration',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 5, 10].map((duration) {
                      final isSelected = selectedDuration == duration;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedDuration = duration),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.pink : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.pinkAccent
                                    : Colors.transparent),
                          ),
                          child: Text('$duration min',
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Team Size',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 5, 7].map((size) {
                      final isSelected = selectedTeamSize == size;
                      return GestureDetector(
                        onTap: () => setState(() {
                          selectedTeamSize = size;
                          if (size != 1) {
                            leftUserId = null;
                            rightUserId = null;
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.blueAccent : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.lightBlueAccent
                                    : Colors.transparent),
                          ),
                          child: Text('${size}vs$size',
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedTeamSize == 1) ...[
                    const SizedBox(height: 24),
                    const Text('Select Users for 1v1',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    if (seatedUsers.length < 2)
                      const Text('Not enough users seated to start 1v1',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 13))
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: seatedUsers.length,
                          itemBuilder: (context, index) {
                            final u = seatedUsers[index];
                            final isLeft = leftUserId == u.userId;
                            final isRight = rightUserId == u.userId;
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isLeft) {
                                  leftUserId = null;
                                } else if (isRight) {
                                  rightUserId = null;
                                } else if (leftUserId == null) {
                                  leftUserId = u.userId;
                                } else if (rightUserId == null) {
                                  rightUserId = u.userId;
                                } else {
                                  rightUserId = u.userId;
                                } // replace right if both full
                              }),
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isLeft
                                      ? Colors.blueAccent.withValues(alpha: 0.2)
                                      : (isRight
                                          ? Colors.redAccent
                                              .withValues(alpha: 0.2)
                                          : Colors.white12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLeft
                                        ? Colors.blueAccent
                                        : (isRight
                                            ? Colors.redAccent
                                            : Colors.transparent),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                        radius: 20,
                                        backgroundImage: u.userImageUrl != null
                                            ? NetworkImage(u.userImageUrl!)
                                            : null,
                                        child: u.userImageUrl == null
                                            ? const Icon(Icons.person, size: 20)
                                            : null),
                                    const SizedBox(height: 8),
                                    Text(u.userName,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        isLeft
                                            ? 'Team A'
                                            : (isRight ? 'Team B' : 'Select'),
                                        style: TextStyle(
                                            color: isLeft
                                                ? Colors.blueAccent
                                                : (isRight
                                                    ? Colors.redAccent
                                                    : Colors.white54),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedTeamSize == 1 &&
                            (leftUserId == null || rightUserId == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please select two users for 1v1 PK.'),
                                  backgroundColor: Colors.red));
                          return;
                        }
                        Navigator.pop(context);

                        final newPkState = PKBattleState(
                          isActive: true,
                          durationMinutes: selectedDuration,
                          teamSize: selectedTeamSize,
                          startTime: DateTime.now(),
                          leftTeamScore: 0,
                          rightTeamScore: 0,
                          leftTeamUserIds:
                              leftUserId != null ? [leftUserId!] : [],
                          rightTeamUserIds:
                              rightUserId != null ? [rightUserId!] : [],
                        );

                        widget.audioRoomsBloc.add(UpdatePKBattleState(
                          roomId: _currentRoom.id,
                          userId: _currentUser.userId,
                          pkBattleState: newPkState,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25))),
                      child: const Text('Start PK Battle',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPKExtendSheet() {
    int additionalDuration = 5;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1724),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Extend PK Time',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 5, 10].map((duration) {
                      final isSelected = additionalDuration == duration;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => additionalDuration = duration),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.greenAccent
                                    : Colors.transparent),
                          ),
                          child: Text('+$duration min',
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        final currentState = _currentRoom.pkBattleState;
                        final newDuration =
                            currentState.durationMinutes + additionalDuration;

                        widget.audioRoomsBloc.add(UpdatePKBattleState(
                          roomId: _currentRoom.id,
                          userId: _currentUser.userId,
                          pkBattleState: currentState.copyWith(
                              durationMinutes: newDuration),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25))),
                      child: const Text('Extend Time',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show Clear Chat confirmation dialog
  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
            'Are you sure you want to delete ALL messages in this room? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              EmojiChatService.clearAllMessages(_currentRoom.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat history cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  /// Show edit room dialog
  void _showEditRoomDialog() {
    final nameController = TextEditingController(text: _currentRoom.name);
    final descriptionController =
        TextEditingController(text: _currentRoom.description);
    File? pickedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Edit Room', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        pickedImage = File(image.path);
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: pickedImage != null
                        ? FileImage(pickedImage!) as ImageProvider
                        : (_currentRoom.imageUrl != null
                            ? CachedNetworkImageProvider(_currentRoom.imageUrl!)
                            : null),
                    child:
                        (pickedImage == null && _currentRoom.imageUrl == null)
                            ? const Icon(Icons.add_a_photo, color: Colors.white)
                            : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Room Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    nameController.text != _currentRoom.name) {
                  widget.audioRoomsBloc.add(UpdateRoomName(
                    roomId: _currentRoom.id,
                    userId: _currentUser.userId,
                    newName: nameController.text,
                  ));
                }
                if (descriptionController.text.isNotEmpty &&
                    descriptionController.text != _currentRoom.description) {
                  // Dispatch update description event
                  widget.audioRoomsBloc.add(UpdateRoomDescription(
                    roomId: _currentRoom.id,
                    userId: _currentUser.userId,
                    newDescription: descriptionController.text,
                  ));
                }
                if (pickedImage != null) {
                  widget.audioRoomsBloc.add(UpdateRoomImage(
                    roomId: _currentRoom.id,
                    userId: _currentUser.userId,
                    imageFile: pickedImage!,
                  ));
                }
                Navigator.pop(context);
              },
              child: const Text('Save',
                  style: TextStyle(color: Color(0xFF00BCD4))),
            ),
          ],
        ),
      ),
    );
  }

  /// Show music settings

  // Announcement dialog removed - replaced with live comments

  /// Show cool room mode selector as full screen page
  void _showSeatConfiguration() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RoomModeSelectorPage(
          currentRoom: _currentRoom,
          audioRoomsBloc: widget.audioRoomsBloc,
          currentUser: _currentUser,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Cool slide up animation
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Room mode card methods moved to _RoomModeSelectorPage

  /// Get background image provider (handles both local files and network URLs)

  Widget _buildHostProfilePlaceholder() {
    return Container(
      color: const Color(0xFF1E1E2C), // Dark background when camera is off
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_currentRoom.creatorImageUrl != null &&
                _currentRoom.creatorImageUrl!.isNotEmpty)
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(_currentRoom.creatorImageUrl!),
              )
            else
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            if (_currentRoom.roomFrameUrl != null &&
                _currentRoom.roomFrameUrl!.isNotEmpty)
              SizedBox(
                width: 150,
                height: 150,
                child: Image.network(_currentRoom.roomFrameUrl!,
                    fit: BoxFit.cover),
              ),
          ],
        ),
      ),
    );
  }

  /// Build background with instant cached loading
  Widget _buildBackgroundWithLoading() {
    if (_currentRoom.category == 'Live') {
      final engine = AgoraService().engine;
      if (engine != null && _agoraChannelJoined) {
        if (_isCurrentUserHost) {
          if (!_isHostVideoEnabled) {
            return _buildHostProfilePlaceholder();
          }
          return SizedBox.expand(
            child: AgoraVideoView(
              controller: _getVideoController(0, engine),
            ),
          );
        } else {
          final hostUid = _generateUid(_currentRoom.creatorId);
          return Obx(() {
            final isCameraMuted =
                AgoraService().remoteUserVideoMuted[hostUid] ?? true;
            if (isCameraMuted) {
              return _buildHostProfilePlaceholder();
            }
            return SizedBox.expand(
              child: AgoraVideoView(
                controller: _getVideoController(hostUid, engine),
              ),
            );
          });
        }
      } else {
        return const Center(
            child: CircularProgressIndicator(color: Colors.white));
      }
    }

    final backgroundUrl = _currentRoom.settings.backgroundImageUrl;

    if (backgroundUrl != null && backgroundUrl.startsWith('http')) {
      // Use CachedNetworkImage for instant loading from cache
      return CachedNetworkImage(
        imageUrl: backgroundUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildAppThemeOrAssetFallback(),
        errorWidget: (context, url, error) => _buildAppThemeOrAssetFallback(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        memCacheWidth: 1080, // Optimize memory
        memCacheHeight: 1920,
      );
    } else if (backgroundUrl != null && backgroundUrl.startsWith('/')) {
      // Local file
      return Image.file(
        File(backgroundUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildAppThemeOrAssetFallback(),
      );
    } else {
      // Default background from AppThemeService (Admin Panel real-time theme) or default asset fallback
      return _buildAppThemeOrAssetFallback();
    }
  }

  /// Dynamic real-time fallback using AppThemeService from Admin Panel
  Widget _buildAppThemeOrAssetFallback() {
    if (Get.isRegistered<AppThemeService>()) {
      return Obx(() {
        final themeService = Get.find<AppThemeService>();
        final globalRoomBgUrl = themeService.getScreenBgUrl('room');
        final globalRoomColor = themeService.getScreenColor('room');

        if (globalRoomBgUrl != null && globalRoomBgUrl.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: globalRoomBgUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: globalRoomColor ?? const Color(0xFF16213E),
            ),
            errorWidget: (context, url, error) => Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/default_bg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            memCacheWidth: 1080,
            memCacheHeight: 1920,
          );
        } else if (globalRoomColor != null) {
          return Container(color: globalRoomColor);
        } else {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/default_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      });
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/default_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Show participant profile bottom sheet
  void _showParticipantBottomSheet(AudioRoomParticipant participant) {
    // final isCurrentUserHost = _isCurrentUserHost;
    final isParticipantHost =
        participant.isHost || _currentRoom.isCreator(participant.userId);
    // final isSelf = participant.userId == _currentUser.userId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<void>(
        future: () async {
          // Clear any existing status to ensure fresh data
          _followController.clearFollowStatus(participant.userId);
          // Load fresh status from server
          await _followController.loadFollowStatusFromServer(
            currentUserId: _currentUser.userId,
            targetUserId: participant.userId,
          );
        }(),
        builder: (context, snapshot) {
          return _participantProfileBottomSheet(
            participant: participant,
            isParticipantHost: isParticipantHost,
            currentUserId: _currentUser.userId,
            followController: _followController,
            onMessage: () => _handleMessageUser(participant),
            onSendGift: () => _showGiftSelection(participant),
          );
        },
      ),
    );
  }

  /// Participant Profile Bottom Sheet Widget
  Widget _participantProfileBottomSheet({
    required AudioRoomParticipant participant,
    required bool isParticipantHost,
    required String currentUserId,
    required FollowController followController,
    required VoidCallback onMessage,
    required VoidCallback onSendGift,
  }) {
    return _AnimatedProfileSheet(
      participant: participant,
      isParticipantHost: isParticipantHost,
      currentUserId: currentUserId,
      followController: followController,
      onMessage: onMessage,
      onSendGift: onSendGift,
      currentRoom: _currentRoom,
      getUserBadgeInfo: _getUserBadgeInfo,
      formatJoinTime: _formatJoinTime,
      buildStatusBadge: _buildStatusBadge,
      audioRoomsBloc: widget.audioRoomsBloc,
    );
  }

  /// Build status badge
  /// Fetch user's equipped badge info
  Future<Map<String, dynamic>?> _getUserBadgeInfo(String userId) async {
    try {
      debugPrint('🎖️ [Badge] Fetching badge for userId: $userId');

      // Fetch user document
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('🎖️ [Badge] User document not found');
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedBadgeId = customization?['selectedBadgeId'];

      debugPrint('🎖️ [Badge] selectedBadgeId: $selectedBadgeId');

      if (selectedBadgeId == null || selectedBadgeId.isEmpty) {
        debugPrint('🎖️ [Badge] No badge equipped');
        return null;
      }

      // Fetch badge details from store
      final badgeDoc = await FirebaseFirestore.instance
          .collection('market_items')
          .doc(selectedBadgeId)
          .get();

      if (!badgeDoc.exists) {
        debugPrint('🎖️ [Badge] Badge not found in store');
        return null;
      }

      final badgeData = badgeDoc.data();
      final badgeInfo = {
        'id': selectedBadgeId,
        'name': badgeData?['name'] ?? 'Badge',
        'imageUrl': badgeData?['imageUrl'] ?? badgeData?['image'],
      };

      debugPrint('🎖️ [Badge] Found badge: ${badgeInfo['name']}');
      return badgeInfo;
    } catch (e) {
      debugPrint('❌ [Badge] Error fetching badge info: $e');
      return null;
    }
  }

  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Format join time
  String _formatJoinTime(DateTime joinTime) {
    final now = DateTime.now();
    final difference = now.difference(joinTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Show gift selection for specific participant
  void _showGiftSelection(AudioRoomParticipant participant) {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => GiftSelectionBottomSheet(
          roomId: _currentRoom.id,
          senderId: _currentUser.userId,
          senderName: _currentUser.fullname,
          senderImageUrl: _currentUser.photoUrl,
          receiverId: participant.userId,
          receiverName: participant.userName,
          receiverImageUrl: participant.userImageUrl,
          participants: _currentRoom.participants,
        ),
      );
    } catch (e) {
      debugPrint('Error showing gift selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open gift selection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle messaging user
  void _handleMessageUser(AudioRoomParticipant participant) {
    try {
      // Create a User object from participant data
      final user = User(
        userId: participant.userId,
        fullname: participant.userName,
        photoUrl: participant.userImageUrl ?? '',
        email: '', // Not available in participant data
        number: '', // Not available in participant data
        isOnline: true, // Assume online since they're in the room
        lastActive: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Navigate to message screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MessageScreen(
            isGroup: false,
            user: user,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to message screen: $e');
      _showErrorSnackBar('Failed to open chat');
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show Admins List Bottom Sheet
  void _showAdminsListBottomSheet() {
    final admins = _currentRoom.participants
        .where((p) => p.isHost && p.userId != _currentRoom.creatorId)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Admins',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${admins.length} Admins',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // List of Admins
            if (admins.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('No admins yet'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: admins.length,
                itemBuilder: (context, index) {
                  final admin = admins[index];
                  return ListTile(
                    tileColor: Colors.transparent,
                    leading: CachedCircleAvatar(
                      imageUrl: admin.userImageUrl ?? '',
                      radius: 20,
                    ),
                    title: Text(admin.userName),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        // Demote logic
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Admin?'),
                            content: Text(
                                'Are you sure you want to remove ${admin.userName} from admins?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                  Navigator.pop(
                                      context); // Close sheet (optional, maybe keep it open?)
                                  // Re-open sheet logic is tricky, let's close it for simplicity or user can reopen

                                  final updatedParticipant =
                                      admin.copyWith(isHost: false);

                                  widget.audioRoomsBloc
                                      .add(UpdateRoomParticipant(
                                    roomId: _currentRoom.id,
                                    userId: _currentUser.userId,
                                    updatedParticipant: updatedParticipant,
                                  ));

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${admin.userName} removed from admins'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Remove'),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showShareBottomSheet() {
    // Check if ChatController is registered, if not register it
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController());
    }

    final ChatController chatController = Get.find<ChatController>();
    final searchController = TextEditingController();

    // We'll use a stateful builder for search results and list updates inside bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final String searchText =
                searchController.text.trim().toLowerCase();

            // Filter chats by search query
            final List<chat_model.Chat> filteredChats =
                chatController.chats.where((chat) {
              if (chat.receiver == null) return false;
              return chat.receiver!.fullname.toLowerCase().contains(searchText);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B26), // Premium dark background
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  // Top Notch indicator
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Share Room',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invite friends to join this voice room',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Copy Link Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        final link =
                            DeepLinkService.generateRoomLink(_currentRoom.id);
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room link copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(
                            context); // Optional: close sheet after copy
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded,
                                color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Copy Link',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Users List
                  Expanded(
                    child: filteredChats.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.forum_outlined,
                                    color: Colors.white.withValues(alpha: 0.2),
                                    size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No chats found',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = filteredChats[index];
                              final user = chat.receiver;
                              if (user == null) return const SizedBox.shrink();

                              final isInvited =
                                  _invitedUserIds.contains(user.userId);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.03)),
                                ),
                                child: Row(
                                  children: [
                                    // User Avatar
                                    CachedCircleAvatar(
                                      imageUrl: user.photoUrl,
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    // User info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.fullname,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.fullname
                                                .replaceAll(' ', '')
                                                .toLowerCase(),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Action Button
                                    GestureDetector(
                                      onTap: isInvited
                                          ? null
                                          : () async {
                                              setSheetState(() {
                                                _invitedUserIds
                                                    .add(user.userId);
                                              });

                                              final roomShare = RoomShare(
                                                roomId: _currentRoom.id,
                                                roomName: _currentRoom.name,
                                                roomImage:
                                                    _currentRoom.imageUrl ??
                                                        _currentRoom
                                                            .creatorImageUrl ??
                                                        '',
                                                description: _currentRoom
                                                        .description.isNotEmpty
                                                    ? _currentRoom.description
                                                    : 'Come join my Voice Room!',
                                              );

                                              final msg = message_model.Message(
                                                msgId: AppHelper.generateID,
                                                senderId: _currentUser.userId,
                                                type: message_model
                                                    .MessageType.roomShare,
                                                textMsg:
                                                    'Shared a Voice Room: ${_currentRoom.name}',
                                                roomShare: roomShare,
                                              );

                                              await MessageApi.sendMessage(
                                                message: msg,
                                                receiver: user,
                                              );
                                            },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: isInvited
                                              ? null
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFFE91E63),
                                                    Color(0xFFFF4081)
                                                  ],
                                                ),
                                          color: isInvited
                                              ? const Color(0xFF2E7D32)
                                                  .withValues(alpha: 0.2)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: isInvited
                                              ? Border.all(
                                                  color:
                                                      const Color(0xFF81C784))
                                              : null,
                                        ),
                                        child: Text(
                                          isInvited ? 'Invited' : 'Invite',
                                          style: TextStyle(
                                            color: isInvited
                                                ? const Color(0xFF81C784)
                                                : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Room mode selector moved to separate file: room_mode_selector.dart

/// Animated participant profile bottom sheet
class _AnimatedProfileSheet extends StatefulWidget {
  final AudioRoomParticipant participant;
  final bool isParticipantHost;
  final String currentUserId;
  final FollowController followController;
  final VoidCallback onMessage;
  final VoidCallback onSendGift;
  final AudioRoomV2 currentRoom;
  final Future<Map<String, dynamic>?> Function(String) getUserBadgeInfo;
  final String Function(DateTime) formatJoinTime;
  final Widget Function(String, Color, IconData) buildStatusBadge;
  final AudioRoomsBloc audioRoomsBloc;

  const _AnimatedProfileSheet({
    required this.participant,
    required this.isParticipantHost,
    required this.currentUserId,
    required this.followController,
    required this.onMessage,
    required this.onSendGift,
    required this.currentRoom,
    required this.getUserBadgeInfo,
    required this.formatJoinTime,
    required this.buildStatusBadge,
    required this.audioRoomsBloc,
  });

  @override
  State<_AnimatedProfileSheet> createState() => _AnimatedProfileSheetState();
}

class _AnimatedProfileSheetState extends State<_AnimatedProfileSheet>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _avatarScale;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _buttonsFade;

  Stream<Map<String, dynamic>> _getFriendshipStatusStream() {
    final currentId = widget.currentUserId;
    final targetId = widget.participant.userId;

    final contactStream = FirebaseFirestore.instance
        .collection('Users')
        .doc(currentId)
        .collection('Contacts')
        .doc(targetId)
        .snapshots();

    final sentRequestStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${currentId}_$targetId')
        .snapshots();

    final receivedRequestStream = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc('${targetId}_$currentId')
        .snapshots();

    return rx.Rx.combineLatest3<DocumentSnapshot, DocumentSnapshot,
        DocumentSnapshot, Map<String, dynamic>>(
      contactStream,
      sentRequestStream,
      receivedRequestStream,
      (contactSnap, sentSnap, receivedSnap) {
        return {
          'isFriend': contactSnap.exists,
          'sentPending': sentSnap.exists &&
              (sentSnap.data() as Map<String, dynamic>?)?['status'] ==
                  'pending',
          'receivedPending': receivedSnap.exists &&
              (receivedSnap.data() as Map<String, dynamic>?)?['status'] ==
                  'pending',
        };
      },
    );
  }

  Future<void> _sendFriendRequest() async {
    try {
      final currentId = widget.currentUserId;
      final targetId = widget.participant.userId;

      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${currentId}_$targetId')
          .set({
        'senderId': currentId,
        'receiverId': targetId,
        'senderName': AuthController.instance.currentUser.fullname,
        'senderImageUrl': AuthController.instance.currentUser.photoUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Friend request sent to ${widget.participant.userName}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> _acceptFriendRequest() async {
    try {
      final currentId = widget.currentUserId;
      final targetId = widget.participant.userId;

      // 1. Add as contact on both sides
      await ContactApi.addContact(userId: targetId, showMsg: false);

      // 2. Mark friend request as accepted
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${targetId}_$currentId')
          .update({'status': 'accepted'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'You are now friends with ${widget.participant.userName}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
    }
  }

  Future<void> _rejectFriendRequest() async {
    try {
      final currentId = widget.currentUserId;
      final targetId = widget.participant.userId;

      // Delete the request
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${targetId}_$currentId')
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Friend request from ${widget.participant.userName} rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _loadProfileSkin();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, String?>> _loadLevelImages(
      int? sendingLevel, int? receivingLevel) async {
    final result = <String, String?>{
      'sending': null,
      'receiving': null,
    };

    try {
      if (sendingLevel != null) {
        final sendDoc = await FirebaseFirestore.instance
            .collection('level_configurations')
            .doc('sending_config')
            .get();
        if (sendDoc.exists) {
          final levels = sendDoc.data()?['levels'] as List<dynamic>?;
          if (levels != null) {
            for (final lvl in levels) {
              if (lvl['levelNumber'] == sendingLevel) {
                result['sending'] = lvl['imageUrl'] as String?;
                break;
              }
            }
          }
        }
      }

      if (receivingLevel != null) {
        final receiveDoc = await FirebaseFirestore.instance
            .collection('level_configurations')
            .doc('receiving_config')
            .get();
        if (receiveDoc.exists) {
          final levels = receiveDoc.data()?['levels'] as List<dynamic>?;
          if (levels != null) {
            for (final lvl in levels) {
              if (lvl['levelNumber'] == receivingLevel) {
                result['receiving'] = lvl['imageUrl'] as String?;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading level images: $e');
    }

    return result;
  }

  Widget _buildLevelImageBadge(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: 20,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        height: 20,
        width: 20,
        color: Colors.transparent,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }

  // How far the avatar overflows above the sheet
  static const double _avatarRadius = 48.0;
  static const double _avatarOverlap = 20.0;

  void _showModerationSheet(BuildContext context, AudioRoomParticipant p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Get fresh status of participant from current room
            final currentP = widget.currentRoom.participants
                    .where((part) => part.userId == p.userId)
                    .firstOrNull ??
                p;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1724),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'Moderation: ${currentP.userName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    if (currentP.isSeated)
                      ListTile(
                        tileColor: Colors.transparent,
                        leading: const Icon(Icons.logout,
                            color: Colors.orangeAccent),
                        title: const Text('Kick from seat',
                            style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          widget.audioRoomsBloc.add(RemoveParticipantFromSeat(
                            roomId: widget.currentRoom.id,
                            hostId: widget.currentUserId,
                            participantId: currentP.userId,
                            seatNumber: currentP.seatNumber ?? 0,
                          ));
                        },
                      ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: Icon(
                        currentP.isMutedByAdmin ? Icons.mic : Icons.mic_off,
                        color:
                            currentP.isMutedByAdmin ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        currentP.isMutedByAdmin ? 'Unmute' : 'Mute',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setSheetState(() {
                          widget.audioRoomsBloc.add(ToggleAdminMute(
                            roomId: widget.currentRoom.id,
                            participantId: currentP.userId,
                            mutedByAdmin: !currentP.isMutedByAdmin,
                          ));
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.exit_to_app,
                          color: Colors.redAccent),
                      title: const Text('Remove from room',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(KickParticipant(
                          roomId: widget.currentRoom.id,
                          hostId: widget.currentUserId,
                          participantId: currentP.userId,
                          reason: 'Removed by admin',
                        ));
                      },
                    ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: const Text('Block user from room',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(BlockParticipant(
                          roomId: widget.currentRoom.id,
                          hostId: widget.currentUserId,
                          participantId: currentP.userId,
                          reason: 'Blocked by admin',
                        ));
                      },
                    ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: Icon(
                        currentP.isMessagingBlocked
                            ? Icons.chat
                            : Icons.speaker_notes_off,
                        color: currentP.isMessagingBlocked
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                      title: Text(
                        currentP.isMessagingBlocked
                            ? 'Unblock Messaging'
                            : 'Block Messaging',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setSheetState(() {
                          widget.audioRoomsBloc.add(ToggleMessagingBlock(
                            roomId: widget.currentRoom.id,
                            participantId: currentP.userId,
                            isBlocked: !currentP.isMessagingBlocked,
                          ));
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: Icon(
                        currentP.isSeatBlocked ? Icons.chair : Icons.chair_alt,
                        color: currentP.isSeatBlocked
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                      title: Text(
                        currentP.isSeatBlocked
                            ? 'Unblock Seat Access'
                            : 'Block Seat Access',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setSheetState(() {
                          widget.audioRoomsBloc.add(ToggleSeatBlock(
                            roomId: widget.currentRoom.id,
                            participantId: currentP.userId,
                            isBlocked: !currentP.isSeatBlocked,
                          ));
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _profileSkinUrl; // SVG/image background for this participant's sheet

  /// Loads the participant's selected Profile Skin from Firestore.
  /// Fetches customization.selectedBackgroundThemeId → then resolves the
  /// file URL from the market_items (store) catalog.
  Future<void> _loadProfileSkin() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.participant.userId)
          .get();

      final data = userDoc.data();
      if (data == null) return;

      final customization = data['customization'] as Map<String, dynamic>?;
      final themeId = customization?['selectedBackgroundThemeId'] as String?;
      if (themeId == null || themeId.isEmpty) return;

      // Resolve the skin's file URL from the store catalog
      final storeDoc = await FirebaseFirestore.instance
          .collection('market_items')
          .doc(themeId)
          .get();

      if (!storeDoc.exists) return;
      final storeData = storeDoc.data()!;
      final url = storeData['fileUrl'] as String? ??
          storeData['thumbnailUrl'] as String? ??
          storeData['imageUrl'] as String? ??
          storeData['svgUrl'] as String?;

      if (url != null && url.isNotEmpty && mounted) {
        setState(() => _profileSkinUrl = url);
      }
    } catch (e) {
      debugPrint('❌ Error loading profile skin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final bool isOwnerOwnProfile = p.userId == widget.currentRoom.creatorId &&
        widget.currentUserId == widget.currentRoom.creatorId;

    const Color textColor = Color(0xFF1F1F24);
    const Color subTextColor = Color(0xFF75757F);
    final Color borderColor = Colors.black.withValues(alpha: 0.1);
    final Color pillBgColor = Colors.black.withValues(alpha: 0.05);
    final Color handleBarColor = Colors.black.withValues(alpha: 0.15);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Sheet body – pushed down to make room for the avatar overlap
        Container(
          margin: EdgeInsets.only(top: _avatarOverlap),
          // Use ClipRRect so the skin image respects the border radius
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Stack(
            children: [
              if (_profileSkinUrl != null)
                Positioned.fill(
                  child: _profileSkinUrl!.toLowerCase().endsWith('.svg')
                      ? SvgPicture.network(
                          _profileSkinUrl!,
                          fit: BoxFit.cover,
                          placeholderBuilder: (_) => Container(
                            color: Colors.white,
                          ),
                        )
                      : _profileSkinUrl!.toLowerCase().contains('.mp4')
                          ? _SkinVideoPlayer(url: _profileSkinUrl!)
                          : _profileSkinUrl!.toLowerCase().contains('.svga')
                              ? SVGAEasyPlayer(
                                  resUrl: _profileSkinUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _profileSkinUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white,
                                  ),
                                ),
                ),
              // Settings Button for Admin/Owner
              if ((widget.currentUserId == widget.currentRoom.creatorId ||
                      widget.currentRoom.settings.adminIds
                          .contains(widget.currentUserId)) &&
                  widget.participant.userId != widget.currentUserId)
                Positioned(
                  top: 12,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: textColor),
                    onPressed: () {
                      Navigator.pop(context);
                      _showModerationSheet(context, widget.participant);
                    },
                  ),
                ),
              // ── Sheet content ────────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleBarColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Space for the avatar + frame that sits above
                  SizedBox(height: _avatarRadius - _avatarOverlap + 55),

                  // Name, ID, badges - slide up + fade
                  SlideTransition(
                    position: _slideUp,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Column(
                        children: [
                          // Name (Tap to open full profile)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // close bottom sheet
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfilePageForRoom(
                                    userID: p.userId,
                                    userName: p.userName,
                                    userImage: p.userImageUrl ?? '',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              p.userName,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // User Info Row (ID and Followers)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Users')
                                .doc(p.userId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final userData = snapshot.data?.data()
                                  as Map<String, dynamic>?;
                              final searchId = userData?['searchId'] ?? '...';
                              final followersCount =
                                  userData?['followers'] ?? 0;
                              final agencyName = userData?['agencyName'];

                              return Column(
                                children: [
                                  // ID & Followers Horizontal Premium Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: pillBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ID ${searchId?.toString().isNotEmpty == true ? searchId : p.userId}',
                                          style: const TextStyle(
                                            color: textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            final idToCopy = searchId
                                                        ?.toString()
                                                        .isNotEmpty ==
                                                    true
                                                ? searchId.toString()
                                                : p.userId;
                                            Clipboard.setData(
                                                ClipboardData(text: idToCopy));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('ID Copied'),
                                                backgroundColor: Colors.black87,
                                                duration: Duration(
                                                    milliseconds: 1000),
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.copy,
                                            color: subTextColor,
                                            size: 13,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            '|',
                                            style: TextStyle(
                                              color: subTextColor.withValues(
                                                  alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Followers $followersCount',
                                          style: const TextStyle(
                                            color: textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  FutureBuilder<Map<String, String?>>(
                                    future: _loadLevelImages(
                                      (userData?['sendingLevel']
                                          as Map?)?['level'] as int?,
                                      (userData?['receivingLevel']
                                          as Map?)?['level'] as int?,
                                    ),
                                    builder: (context, levelSnapshot) {
                                      final sendImageUrl =
                                          levelSnapshot.data?['sending'];
                                      final receiveImageUrl =
                                          levelSnapshot.data?['receiving'];
                                      final customizationMap =
                                          userData?['customization'] as Map?;
                                      final selectedNameplateId =
                                          customizationMap?[
                                              'selectedNameplateId'] as String?;

                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (sendImageUrl != null)
                                            _buildLevelImageBadge(sendImageUrl),
                                          if (sendImageUrl != null &&
                                              receiveImageUrl != null)
                                            const SizedBox(width: 16),
                                          if (receiveImageUrl != null)
                                            _buildLevelImageBadge(
                                                receiveImageUrl),
                                          if (selectedNameplateId != null &&
                                              selectedNameplateId
                                                  .isNotEmpty) ...[
                                            if (sendImageUrl != null ||
                                                receiveImageUrl != null)
                                              const SizedBox(width: 16),
                                            FutureBuilder<String?>(
                                              future: NameplateHelper
                                                  .getNameplateUrl(
                                                      selectedNameplateId),
                                              builder: (context, snapshot) {
                                                final nameplateUrl =
                                                    snapshot.data;
                                                if (nameplateUrl != null &&
                                                    nameplateUrl.isNotEmpty) {
                                                  return ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: CachedNetworkImage(
                                                      imageUrl: nameplateUrl,
                                                      height: 36,
                                                      fit: BoxFit.contain,
                                                      placeholder:
                                                          (context, url) =>
                                                              Container(
                                                        width: 36,
                                                        height: 36,
                                                        color: Colors.white12,
                                                        child: const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          const SizedBox
                                                              .shrink(),
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ],
                                          if (sendImageUrl == null &&
                                              receiveImageUrl == null &&
                                              (selectedNameplateId == null ||
                                                  selectedNameplateId.isEmpty))
                                            Text(
                                              'Level badges unavailable',
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Status Badges (Level, Agency, Host Status, and Official Badge)
                                  FutureBuilder<Map<String, dynamic>?>(
                                    future: widget.getUserBadgeInfo(p.userId),
                                    builder: (context, badgeSnapshot) {
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          // Agency Badge
                                          if (agencyName != null &&
                                              agencyName.toString().isNotEmpty)
                                            widget.buildStatusBadge(
                                              agencyName.toString(),
                                              const Color(0xFF00BCD4),
                                              Icons.business,
                                            ),

                                          // Official Badge (e.g. imChat Official)
                                          if (badgeSnapshot.hasData &&
                                              badgeSnapshot.data != null)
                                            widget.buildStatusBadge(
                                              badgeSnapshot.data!['name'] ??
                                                  'Official',
                                              Colors.orange,
                                              Icons.military_tech,
                                            ),

                                          // Host Status Badge (Owner/Admin)
                                          if (widget.isParticipantHost)
                                            widget.buildStatusBadge(
                                              widget.currentRoom
                                                      .isCreator(p.userId)
                                                  ? 'Owner'
                                                  : 'Admin',
                                              widget.currentRoom
                                                      .isCreator(p.userId)
                                                  ? Colors.amber
                                                  : Colors.purple,
                                              widget.currentRoom
                                                      .isCreator(p.userId)
                                                  ? Icons.workspace_premium
                                                  : Icons.shield,
                                            ),

                                          // Viewer Status
                                          if (!widget.isParticipantHost &&
                                              !p.isSpeaker)
                                            widget.buildStatusBadge(
                                                'Viewer',
                                                Colors.grey,
                                                Icons.remove_red_eye),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons - fade in last
                  FadeTransition(
                    opacity: _buttonsFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Gift button with gradient
                          SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFFE91E63)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: widget.onSendGift,
                                icon: const Icon(Icons.card_giftcard,
                                    color: Colors.white),
                                label: const Text(
                                  'Send Gift',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Follow / Message row (Only shown if NOT viewing own profile)
                          if (p.userId != widget.currentUserId) ...[
                            const SizedBox(height: 12),
                            StreamBuilder<Map<String, dynamic>>(
                              stream: _getFriendshipStatusStream(),
                              builder: (context, snapshot) {
                                final data = snapshot.data ??
                                    {
                                      'isFriend': false,
                                      'sentPending': false,
                                      'receivedPending': false,
                                    };

                                final bool isFriend = data['isFriend'] ?? false;
                                final bool sentPending =
                                    data['sentPending'] ?? false;
                                final bool receivedPending =
                                    data['receivedPending'] ?? false;

                                return Row(
                                  children: [
                                    // Follow button
                                    Expanded(
                                      child: FollowButton(
                                        currentUserId: widget.currentUserId,
                                        targetUserId: p.userId,
                                        targetUserName: p.userName,
                                        followController:
                                            widget.followController,
                                        initialFollowStatus: widget
                                            .followController
                                            .isFollowing(p.userId),
                                        textColor: const Color(0xFF6C63FF),
                                        borderColor: const Color(0xFF6C63FF)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Chat / Add Friend action button
                                    Expanded(
                                      child: () {
                                        if (isFriend) {
                                          // Already Friends: Show Message button
                                          return OutlinedButton.icon(
                                            onPressed: widget.onMessage,
                                            icon: const Icon(
                                                Icons.chat_bubble_outline,
                                                color: Color(0xFF6C63FF),
                                                size: 18),
                                            label: const Text(
                                              'Message',
                                              style: TextStyle(
                                                  color: Color(0xFF6C63FF)),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: const Color(0xFF6C63FF)
                                                      .withValues(alpha: 0.4)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          );
                                        } else if (sentPending) {
                                          // Sent request is pending: Show disabled Pending button
                                          return OutlinedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(
                                                Icons.hourglass_empty,
                                                color: Colors.grey,
                                                size: 18),
                                            label: const Text(
                                              'Pending',
                                              style:
                                                  TextStyle(color: Colors.grey),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: Colors.grey),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          );
                                        } else if (receivedPending) {
                                          // Received request is pending: Show Accept and Reject buttons
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _acceptFriendRequest(),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  child: const Text('Accept',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _rejectFriendRequest(),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                        color: Colors.red),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 12),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  child: const Text('Reject',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          // Not friends and no pending requests: Show ADD+ button
                                          return ElevatedButton.icon(
                                            onPressed: () =>
                                                _sendFriendRequest(),
                                            icon: const Icon(Icons.person_add,
                                                color: Colors.white, size: 18),
                                            label: const Text(
                                              'ADD+',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF6C63FF),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          );
                                        }
                                      }(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ), // Column
            ], // Stack.children
          ), // Stack
        ),

        // Avatar floating above the sheet — tap to open full profile
        Positioned(
          top: 0,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context); // close bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePageForRoom(
                    userID: p.userId,
                    userName: p.userName,
                    userImage: p.userImageUrl ?? '',
                  ),
                ),
              );
            },
            child: ScaleTransition(
              scale: _avatarScale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isParticipantHost
                              ? Colors.amber
                              : const Color(0xFF6C63FF))
                          .withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CachedCircleAvatar(
                      imageUrl: p.userImageUrl ?? '',
                      radius: _avatarRadius,
                      backgroundColor: Colors.grey[300],
                      frameId: p.frameId,
                      userId: p.userId,
                      frameScale: 1.4,
                      borderWidth: 0,
                      padding: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UserGiftingStatsWidget extends StatelessWidget {
  final List<GiftTransaction> transactions;

  const UserGiftingStatsWidget({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));
    final last7days = now.subtract(const Duration(days: 7));

    int total24h = 0;
    int totalWeekly = 0;
    int totalLifetime = 0;

    for (final tx in transactions) {
      totalLifetime += tx.credits;
      if (tx.timestamp.isAfter(last24h)) {
        total24h += tx.credits;
      }
      if (tx.timestamp.isAfter(last7days)) {
        totalWeekly += tx.credits;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatItem('24h', total24h, const Color(0xFFFF9800)),
          _buildDivider(),
          _buildStatItem('Weekly', totalWeekly, const Color(0xFFE91E63)),
          _buildDivider(),
          _buildStatItem('Lifetime', totalLifetime, const Color(0xFF00BCD4)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value > 999 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 2),
        const Icon(
          Icons.diamond_outlined,
          color: Color(0xFF00BCD4),
          size: 10,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 12,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _SkinVideoPlayer extends StatefulWidget {
  final String url;
  const _SkinVideoPlayer({required this.url});

  @override
  State<_SkinVideoPlayer> createState() => _SkinVideoPlayerState();
}

class _SkinVideoPlayerState extends State<_SkinVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller!.setLooping(true);
          _controller!.play();
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return Container(color: Colors.white);
  }
}

class AnimatedPremiumId extends StatefulWidget {
  final String idStr;
  const AnimatedPremiumId({super.key, required this.idStr});

  @override
  State<AnimatedPremiumId> createState() => _AnimatedPremiumIdState();
}

class _AnimatedPremiumIdState extends State<AnimatedPremiumId>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Color> colors;
    final len = widget.idStr.length;
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(widget.idStr);

    if (hasLetters) {
      colors = [
        Colors.blueAccent,
        Colors.lightBlueAccent,
        Colors.cyan,
        Colors.blueAccent
      ];
    } else if (len <= 2) {
      colors = [Colors.amber, Colors.orange, Colors.yellow, Colors.amber];
    } else if (len <= 4) {
      colors = [
        Colors.purpleAccent,
        Colors.deepPurple,
        Colors.pinkAccent,
        Colors.purpleAccent
      ];
    } else if (len <= 6) {
      colors = [Colors.blue, Colors.lightBlue, Colors.cyan, Colors.blue];
    } else {
      // Normal 7-8 digits (fallback if somehow animated)
      return Text('ID: ${widget.idStr}',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 11));
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: colors,
                stops: const [0.0, 0.3, 0.7, 1.0],
                transform: GradientRotation(_controller.value * 2 * 3.14159),
              ).createShader(bounds);
            },
            child: Text(
              'ID: ${widget.idStr}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.white54, blurRadius: 4)],
              ),
            ),
          );
        },
      ),
    );
  }
}
