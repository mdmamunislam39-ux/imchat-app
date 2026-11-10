// ignore_for_file: deprecated_member_use
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/widgets/spinning_dice_widget.dart';
import 'package:chat_messenger/services/premium_room_service.dart';
import 'package:chat_messenger/models/premium_room_id_model.dart';
import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_mode_selector.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/screens/room/badge_wall_page.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:chat_messenger/helpers/country_helper.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/live_ended_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:chat_messenger/models/chat.dart' as chat_model;
import 'package:chat_messenger/models/message.dart' as message_model;
import 'package:chat_messenger/api/message_api.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/room_share.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/golden_seat_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_controls.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_animation_overlay.dart';
import 'package:chat_messenger/widgets/coin_shower_widget.dart';
import 'package:chat_messenger/widgets/lucky_win_banner.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_selection_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/waiting_list_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_pk_settings_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/html5_game_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_effects_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_room_settings_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_call_manage_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/create_lucky_bag_sheet.dart';
import 'package:chat_messenger/models/video_pk_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/services/video_pk_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_pk_split_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_pk_animation_overlay.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/video_pk_sheet.dart';
import 'widgets/room_decor_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_floating_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_global_banner.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_big_packet_dialog.dart';
import 'package:chat_messenger/services/lucky_bag_service.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
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
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gift_combo_button.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_event_portal_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/top_exposure_header_pill.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/top_exposure_center_banner.dart';
import 'package:chat_messenger/services/push_notification_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/youtube_sync_player.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo_game_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom_game_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_setup_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/youtube_selection_sheet.dart';

import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/animated_notification.dart';
import 'package:chat_messenger/screens/messages/message_screen.dart';
import 'package:chat_messenger/models/agora_models.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/speaking_ripple_animation.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/room_pk_repository.dart';
import 'package:chat_messenger/models/room_pk_match.dart';
import 'dart:io';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/floating_music_player.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _relationshipsSub;
  List<Map<String, dynamic>> _activeRoomRelationships = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendshipLevelsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _coupleLevelsSub;
  Map<int, String> _friendshipLevelImages = {};
  Map<int, String> _coupleLevelImages = {};
  bool _isCurrentUserHost = false;
  bool get _isCurrentUserHostOrAdmin {
    if (_isCurrentUserHost) return true;
    if (_currentRoom.creatorId == _currentUser.userId) return true;
    if (_currentRoom.settings.adminIds.contains(_currentUser.userId)) {
      return true;
    }
    try {
      final me = _currentRoom.participants.firstWhere(
        (p) => p.userId == _currentUser.userId,
      );
      return me.isHost;
    } catch (_) {
      return false;
    }
  }

  bool _isMuted = true;
  bool _isSpeakerOn = true;
  bool _isMinimizing = false; // Track if user is minimizing vs leaving
  final Set<String> _invitedUserIds = {};

  // Chat related variables
  final GlobalKey<RoomControlsState> _roomControlsKey =
      GlobalKey<RoomControlsState>();
  StreamSubscription<List<EmojiChatMessage>>? _chatSubscription;

  // Video controllers cache & effects
  final Map<int, VideoViewController> _videoControllers = {};
  late final VideoEffectsController _videoEffectsController =
      VideoEffectsController();

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
  StreamSubscription<DocumentSnapshot>? _micInviteSubscription;
  bool _isMicInviteDialogShowing = false;
  late final DateTime
      _joinTime; // Track when user joined to filter old messages

  // Live Video Room PK variables (Exclusive to Live Video Rooms)
  final VideoPkService _videoPkService = VideoPkService();
  StreamSubscription<VideoPkBattleModel?>? _videoPkBattleSub;
  StreamSubscription<List<VideoPkInvitationModel>>? _videoPkInviteSub;
  VideoPkBattleModel? _activeVideoBattle;
  VideoPkAnimationPhase _videoAnimationPhase = VideoPkAnimationPhase.none;
  bool _isOpponentAudioMuted = false;
  String? _lastShownVideoInviteId;
  final Set<String> _processedPkTxIds = {};

  // Agora related variables
  bool _agoraChannelJoined = false;
  List<AgoraUser> _agoraUsers = [];
  int? _agoraUid;

  // Gift related
  final GiftService _giftService = GiftService();
  Timer? _giftCleanupTimer;
  final Map<int, GlobalKey> _seatKeys = {};
  final ValueNotifier<List<FlyingGiftItem>> _flyingGiftsNotifier =
      ValueNotifier<List<FlyingGiftItem>>([]);
  StreamSubscription<List<GiftTransaction>>? _roomGiftTransactionsSub;
  final Map<String, int> _userReceivedGiftsMap = {};

  // Entrance effect related
  final EntranceEffectService _entranceEffectService = EntranceEffectService();

  // Follow related
  late final FollowController _followController;

  // Real-time Frame Update Subscription
  StreamSubscription<String>? _frameSubscription;
  // Static cached level configurations
  static List<dynamic>? _cachedSendingLevels;
  static Map<int, String>? _cachedFriendshipLevelImages;
  static Map<int, String>? _cachedCoupleLevelImages;

  // Live stream session statistics
  int _sessionInitialRevenue = 0;
  int _sessionGiftsCount = 0;
  final Set<String> _sessionViewers = {};

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
    debugPrint('Ã°Å¸Å½Â¯ [AudioRoom] ===== INIT STATE STARTED =====');

    // Reset minimizing flag when screen is created/restored
    _isMinimizing = false;
    debugPrint(
        'Ã°Å¸âÂ¼ [AudioRoom] Screen initialized, minimizing flag reset');

    // Add lifecycle observer for background audio handling
    WidgetsBinding.instance.addObserver(this);

    // End wakelock to keep CPU running
    WakelockPlus.enable();

    // Initialize follow controller
    _followController = FollowController();
    _currentRoom = widget.room;

    // Set join time Ã¢â¬â restore original if coming back from minimize, otherwise use now
    if (widget.isRestoring) {
      final minimizedController = _getMinimizedController();
      _joinTime = minimizedController.originalJoinTime ??
          DateTime.now().subtract(const Duration(seconds: 5));
      debugPrint(
          'Ã°Å¸âÂ¼ [AudioRoom] Restored original join time: $_joinTime');
    } else {
      _joinTime = DateTime.now();
    }

    // Initialize live session tracking
    _sessionInitialRevenue = widget.room.totalRevenue;
    _sessionGiftsCount = 0;
    _sessionViewers.clear();
    if (widget.room.joinedUserIds.isNotEmpty) {
      _sessionViewers.addAll(widget.room.joinedUserIds);
    }

    // Get current user with null safety
    try {
      _currentUser = AuthController.instance.currentUser;
      debugPrint(
        'Ã°Å¸Å½Â¯ Current user loaded: ${_currentUser.userId} - ${_currentUser.fullname}',
      );
      // Load current user's level badge
      _loadConfigs();
      _isCurrentUserHost = _currentUser.userId == widget.room.creatorId;
      if (_isCurrentUserHost) {
        _isMuted = false;
      }
      final rouletteTag = 'roulette_${widget.room.id}';
      if (!Get.isRegistered<RouletteController>(tag: rouletteTag)) {
        Get.put(
          RouletteController(widget.room.id, isHost: _isCurrentUserHost),
          tag: rouletteTag,
        );
      }
    } catch (e) {
      debugPrint('Ã°Å¸Å½Â¯ Error getting current user: $e');
      // Handle null user case - navigate back safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    // Debug participant list
    debugPrint(
        'Ã°Å¸Å½Â¯ Room participants: ${_currentRoom.participants.length}');
    for (var participant in _currentRoom.participants) {
      debugPrint(
        'Ã°Å¸Å½Â¯ Participant: ${participant.userId} - ${participant.userName}',
      );
    }

    // Safety check: don't use a closed BLoC
    if (widget.audioRoomsBloc.isClosed) {
      debugPrint(
          'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢ Å BLoC is closed, cannot initialize room');
      // Navigating back safely if the BLoC is closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    // Safety check: verify if user is blocked or kicked from this room
    if (_currentRoom.isUserBlocked(_currentUser.userId) ||
        _currentRoom.isUserKickedRecently(_currentUser.userId)) {
      final message = _currentRoom.isUserBlocked(_currentUser.userId)
          ? 'You are blocked from entering this room.'
          : 'You have been removed from this room and cannot join for 24 hours.';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _canPopScreen = true;
          });
          _getMinimizedController().clearMinimizedRoom();
          AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    // Check if current user is a participant
    if (!_currentRoom.isParticipant(_currentUser.userId)) {
      // Automatically join the room if user is not a participant
      widget.audioRoomsBloc.add(
        JoinAudioRoom(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          userName: _currentUser.fullname,
          userImageUrl: _currentUser.photoUrl,
          userFrameId: _currentUser.customization?.selectedFrameId,
        ),
      );
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
        'Ã°Å¸âÂ¼ [AudioRoom] Skipping join message - restoring from minimized state',
      );
    }

    // Start listening to room updates
    widget.audioRoomsBloc.add(ListenToRoomUpdates(roomId: widget.room.id));

    // Start listening to chat messages
    _startChatListener();

    // Start listening to Lucky Win events
    _startLuckyWinListener();

    // Start listening to PK Invites if host
    if (_isCurrentUserHost) {
      if (_currentRoom.category == 'Live') {
        _startVideoPKListeners();
      } else {
        _startPKInviteListener();
      }
    } else if (_currentRoom.category == 'Live') {
      _startVideoPKBattleListener();
    }

    // Start listening to mic invites for current user
    _startMicInviteListener();

    // Gift transactions will be handled by StreamBuilder in the UI
    debugPrint(
      'Ã°Å¸Å½  [AudioRoom] Gift transactions will be handled by StreamBuilder',
    );

    // Start periodic cleanup of old gifts
    _startGiftCleanupTimer();

    // Start auto-delete chat timer (only runs if host)
    _startAutoDeleteTimer();

    // Listen to real-time frame updates
    _frameSubscription = AuthController.instance.currentFrameUrl.listen((url) {
      debugPrint(
          'Ã°Å¸âÂ¼Ã¯Â¸  [AudioRoom] Frame updated to: $url, rebuilding UI...');
      if (mounted) {
        final newFrameId =
            AuthController.instance.currentUser.customization?.selectedFrameId;
        final pIdx = _currentRoom.participants
            .indexWhere((p) => p.userId == _currentUser.userId);
        if (pIdx != -1) {
          if (_currentRoom.participants[pIdx].frameId != newFrameId) {
            final updated =
                _currentRoom.participants[pIdx].copyWith(frameId: newFrameId);
            setState(() {
              _currentRoom.participants[pIdx] = updated;
            });
            AudioRoomsRepository()
                .updateParticipantFrameId(
                  roomId: _currentRoom.id,
                  userId: _currentUser.userId,
                  frameId: newFrameId,
                )
                .catchError(
                    (e) => debugPrint('Error updating participant frame: $e'));
          }
        }
      }
    });

    // Automatic center popup listener for active Lucky Bags
    _initLuckyBagAutoPopupListener();

    // Listen to room gift transactions for Pro Mode seat counters (24h 10PM-10PM cycle)
    _initGiftTransactionsListener();

    // Proactively preload active room gifts and animations in background
    _giftService.firestore
        .collection('gift')
        .get(const GetOptions(source: Source.cache))
        .then((snap) {
      final urls = <String>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['svgaUrl'] is String &&
            (data['svgaUrl'] as String).trim().isNotEmpty) {
          urls.add((data['svgaUrl'] as String).trim());
        }
        if (data['pngUrl'] is String &&
            (data['pngUrl'] as String).trim().isNotEmpty) {
          urls.add((data['pngUrl'] as String).trim());
        }
      }
      if (urls.isNotEmpty) {
        FastAssetCache.preloadBatch(urls);
      }
    }).catchError((_) {});
    _scheduleDailyResetTimer();

    debugPrint('ð¯ [AudioRoom] ===== INIT STATE COMPLETE =====');
  }

  String _selectedProChatTab = 'all'; // 'all', 'chat', 'gifts'
  Timer? _dailyResetTimer;

  void _scheduleDailyResetTimer() {
    _dailyResetTimer?.cancel();
    final now = DateTime.now();
    final cycleStart = RankingHelper.daily22CycleStart;
    final next22 = cycleStart.add(const Duration(days: 1));
    final durationUntil22 = next22.difference(now);
    _dailyResetTimer = Timer(
        durationUntil22 > Duration.zero
            ? durationUntil22
            : const Duration(seconds: 1), () {
      if (!mounted) return;
      _initGiftTransactionsListener();
      _scheduleDailyResetTimer();
    });
  }

  void _initGiftTransactionsListener() {
    _roomGiftTransactionsSub?.cancel();
    _roomGiftTransactionsSub =
        _giftService.getGiftTransactions(widget.room.id).listen((transactions) {
      if (!mounted) return;
      final cycleStart = RankingHelper.daily22CycleStart;
      final Map<String, int> received = {};
      int sessionGifts = 0;
      for (final tx in transactions) {
        if (tx.timestamp.isAfter(_joinTime.subtract(const Duration(seconds: 2)))) {
          sessionGifts += (tx.quantity > 0 ? tx.quantity : 1);
        }
        if (tx.receiverId.isNotEmpty && tx.timestamp.isAfter(cycleStart)) {
          final amount = tx.beansToReceiver;
          received[tx.receiverId] = (received[tx.receiverId] ?? 0) + amount;
        }

        // Live Video Room PK Battle scoring
        if (_currentRoom.category == 'Live' &&
            _activeVideoBattle != null &&
            _activeVideoBattle!.isActive &&
            _activeVideoBattle!.startedAt != null &&
            !_processedPkTxIds.contains(tx.id)) {
          if (tx.timestamp.isAfter(_activeVideoBattle!.startedAt!)) {
            _processedPkTxIds.add(tx.id);
            if (tx.receiverId == _activeVideoBattle!.host1Id ||
                tx.receiverId == _activeVideoBattle!.host2Id) {
              _videoPkService.recordGiftScore(
                battleId: _activeVideoBattle!.id,
                targetHostId: tx.receiverId,
                userId: tx.senderId,
                userName: tx.senderName,
                userPhoto: tx.senderImageUrl,
                giftDiamonds: tx.beansToReceiver,
              );
            }
          }
        }
      }
      setState(() {
        _sessionGiftsCount = sessionGifts;
        _userReceivedGiftsMap.clear();
        _userReceivedGiftsMap.addAll(received);
      });
    });
  }

  int _getUserReceivedGiftDiamonds(String userId) {
    final fromDoc = _currentRoom.dailyUserReceivedBeans[userId] ?? 0;
    final fromTx = _userReceivedGiftsMap[userId] ?? 0;
    return fromDoc > fromTx ? fromDoc : fromTx;
  }

  String _formatProGiftCount(int amount) {
    if (amount >= 1000000) {
      double m = amount / 1000000.0;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : (m * 10 % 1 == 0 ? 1 : 2))}M';
    } else if (amount >= 1000) {
      double k = amount / 1000.0;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : (k * 10 % 1 == 0 ? 1 : 2))}K';
    }
    return '$amount';
  }

  Widget _buildProSeatGiftBadge(int giftCount) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite,
            color: Color(0xFFFF4081),
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            _formatProGiftCount(giftCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Pro Mode Filter Tabs (All, Chat, Gifts)
  Widget _buildProModeFilterTabs() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          _buildProTabItem('All', 'all'),
          const SizedBox(width: 16),
          _buildProTabItem('Chat', 'chat'),
          const SizedBox(width: 16),
          _buildProTabItem('Gifts', 'gifts'),
        ],
      ),
    );
  }

  Widget _buildProTabItem(String label, String key) {
    final isSelected = _selectedProChatTab == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedProChatTab = key;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 18 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  StreamSubscription<LuckyBagModel?>? _luckyBagAutoPopupSub;
  String? _lastAutoPoppedBagId;

  void _initLuckyBagAutoPopupListener() {
    _luckyBagAutoPopupSub?.cancel();
    _luckyBagAutoPopupSub =
        LuckyBagService.streamActiveLuckyBag(_currentRoom.id).listen((bag) {
      if (bag != null && bag.isActive && _lastAutoPoppedBagId != bag.id) {
        _lastAutoPoppedBagId = bag.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            LuckyBagBigPacketDialog.show(
              context,
              roomId: _currentRoom.id,
              bag: bag,
              currentUserId: _currentUser.userId,
              currentUserName: _currentUser.fullname,
              currentUserAvatar: _currentUser.photoUrl,
            );
          }
        });
      }
    });
  }

  /// Start periodic auto-delete chat timer (runs every 1 minute)
  void _startAutoDeleteTimer() {
    _autoDeleteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isCurrentUserHost) {
        debugPrint(
          'Ã°Å¸Â§Â¹ [AudioRoom] Running periodic chat cleanup ( > 30 mins )...',
        );
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
      _currentRoom.totalRevenue,
      _roomLevelConfigData,
    );
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
                'Ã°Å¸Å½Â¯ Loaded current user level badge URL inside _AudioRoomScreenState from cache: $_currentUserLevelBadgeUrl',
              );
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

      _startRelationshipsListener();
    } catch (e) {
      debugPrint(
        'Ã¢ Å Error loading level configurations in _AudioRoomScreenState: $e',
      );
    }
  }

  Future<void> _startRelationshipsListener() async {
    // 1. Static cache check for friendship levels (static data, no need for continuous snapshot streaming)
    if (_cachedFriendshipLevelImages != null) {
      _friendshipLevelImages = _cachedFriendshipLevelImages!;
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('relationshipLevels')
            .get();
        final Map<int, String> map = {};
        for (var doc in snap.docs) {
          final data = doc.data();
          final rawLevel = data['level'];
          int lvl = 1;
          if (rawLevel is int) {
            lvl = rawLevel;
          } else if (rawLevel is String) {
            lvl = int.tryParse(rawLevel) ?? 1;
          } else if (rawLevel is num) {
            lvl = rawLevel.toInt();
          }
          final String? img =
              data['badgeUrl'] as String? ?? data['imageUrl'] as String?;
          if (img != null && img.isNotEmpty) {
            map[lvl] = img;
          }
        }
        _cachedFriendshipLevelImages = map;
        if (mounted) {
          setState(() {
            _friendshipLevelImages = map;
          });
        }
      } catch (e) {
        debugPrint('Ã¢ Å Error loading friendship levels: $e');
      }
    }

    // 2. Static cache check for couple levels
    if (_cachedCoupleLevelImages != null) {
      _coupleLevelImages = _cachedCoupleLevelImages!;
    } else {
      try {
        final snap =
            await FirebaseFirestore.instance.collection('couple_levels').get();
        final Map<int, String> map = {};
        for (var doc in snap.docs) {
          final data = doc.data();
          final rawLevel = data['level'];
          int lvl = 1;
          if (rawLevel is int) {
            lvl = rawLevel;
          } else if (rawLevel is String) {
            lvl = int.tryParse(rawLevel) ?? 1;
          } else if (rawLevel is num) {
            lvl = rawLevel.toInt();
          }
          final String? img =
              data['badgeUrl'] as String? ?? data['imageUrl'] as String?;
          if (img != null && img.isNotEmpty) {
            map[lvl] = img;
          }
        }
        _cachedCoupleLevelImages = map;
        if (mounted) {
          setState(() {
            _coupleLevelImages = map;
          });
        }
      } catch (e) {
        debugPrint('Ã¢ Å Error loading couple levels: $e');
      }
    }

    // 3. Relationships check: one-time fetch to avoid continuous global snapshots listener
    _relationshipsSub?.cancel();
    _relationshipsSub = null;
    FirebaseFirestore.instance
        .collection('relationships')
        .where('status', isEqualTo: 'accepted')
        .limit(30)
        .get()
        .then((snapshot) {
      if (mounted) {
        final List<Map<String, dynamic>> list = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          list.add(data);
        }
        if (_activeRoomRelationships.length != list.length) {
          setState(() {
            _activeRoomRelationships = list;
          });
        } else {
          _activeRoomRelationships = list;
        }
        debugPrint(
          '🎯 [Intimacy] Loaded active room relationships: ${_activeRoomRelationships.length}',
        );
      }
    }).catchError((e) {
      debugPrint('Error loading room relationships: $e');
    });
  }

  /// Start listening for Live Room Video PK battles and invitations (Live Video rooms only)
  void _startVideoPKListeners() {
    if (_currentRoom.category != 'Live') return;
    _startVideoPKBattleListener();

    _videoPkInviteSub?.cancel();
    _videoPkInviteSub = _videoPkService
        .streamIncomingInvitations(_currentUser.userId, _currentRoom.id)
        .listen((invites) {
      if (!mounted) return;
      if (_currentRoom.category != 'Live') return;
      for (final invite in invites) {
        if (_lastShownVideoInviteId == invite.id) continue;
        _lastShownVideoInviteId = invite.id;
        _showVideoPkInviteDialog(invite);
      }
    });
  }

  void _startVideoPKBattleListener() {
    if (_currentRoom.category != 'Live') return;
    _videoPkBattleSub?.cancel();
    _videoPkBattleSub = _videoPkService
        .streamActiveBattle(_currentRoom.id)
        .listen((battle) {
      if (!mounted) return;
      if (_currentRoom.category != 'Live') return;
      final wasActive = _activeVideoBattle != null;
      setState(() {
        _activeVideoBattle = battle;
      });

      if (battle != null && !wasActive) {
        _processedPkTxIds.clear();
        _triggerVideoPkPhase(VideoPkAnimationPhase.countdown);
      } else if (battle != null && battle.isEnded && wasActive) {
        _triggerVideoPkPhase(VideoPkAnimationPhase.winner);
      }
    });
  }

  void _triggerVideoPkPhase(VideoPkAnimationPhase phase) {
    setState(() {
      _videoAnimationPhase = phase;
    });
  }

  void _showVideoPkInviteDialog(VideoPkInvitationModel invite) {
    if (_currentRoom.category != 'Live') {
      _videoPkService.rejectInvitation(invite.id);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => VideoPkInvitationDialog(
        invitation: invite,
        onAccept: () async {
          Navigator.of(ctx).pop();
          try {
            await _videoPkService.acceptInvitation(invite.id);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to accept PK challenge: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
        onReject: () async {
          Navigator.of(ctx).pop();
          await _videoPkService.rejectInvitation(invite.id);
        },
      ),
    );
  }

  void _openVideoPkSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VideoPkSheet(
        currentRoomId: _currentRoom.id,
        currentHostId: _currentUser.userId,
        currentHostName: _currentUser.fullname.isNotEmpty ? _currentUser.fullname : 'Host',
        currentHostPhotoUrl: _currentUser.photoUrl,
      ),
    );
  }

  void _confirmEndVideoPk(String battleId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD946EF), width: 1.5),
        ),
        title: const Text(
          'End PK Battle?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to end the current PK battle for both rooms?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _videoPkService.endPkBattle(battleId, _currentUser.userId);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to end PK battle: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('End PK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPkHostPlaceholder(String? photoUrl, String name) {
    return Container(
      color: const Color(0xFF161129),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: ClipOval(
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.white54,
                        ),
                      )
                    : const Icon(Icons.person, size: 30, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPkSection() {
    final battle = _activeVideoBattle!;
    final engine = AgoraService().engine;
    final isHost1 = _currentUser.userId == battle.host1Id;
    final isHost2 = _currentUser.userId == battle.host2Id;

    // Left Video (Host 1)
    Widget leftVideo;
    if (isHost1) {
      leftVideo = _isHostVideoEnabled && engine != null
          ? VideoFilterColorOverlay(
              controller: _videoEffectsController,
              child: AgoraVideoView(controller: _getVideoController(0, engine)),
            )
          : _buildPkHostPlaceholder(battle.host1Photo, battle.host1Name);
    } else {
      final host1Uid = _generateUid(battle.host1Id);
      leftVideo = engine != null
          ? AgoraVideoView(controller: _getVideoController(host1Uid, engine))
          : _buildPkHostPlaceholder(battle.host1Photo, battle.host1Name);
    }

    // Right Video (Host 2)
    Widget rightVideo;
    if (isHost2) {
      rightVideo = _isHostVideoEnabled && engine != null
          ? VideoFilterColorOverlay(
              controller: _videoEffectsController,
              child: AgoraVideoView(controller: _getVideoController(0, engine)),
            )
          : _buildPkHostPlaceholder(battle.host2Photo, battle.host2Name);
    } else {
      final host2Uid = _generateUid(battle.host2Id);
      rightVideo = engine != null
          ? AgoraVideoView(controller: _getVideoController(host2Uid, engine))
          : _buildPkHostPlaceholder(battle.host2Photo, battle.host2Name);
    }

    return VideoPkSplitScreen(
      pkBattle: battle,
      isCurrentRoomHost1: _currentRoom.id == battle.room1Id,
      leftVideoView: leftVideo,
      rightVideoView: rightVideo,
      isHost: _isCurrentUserHost,
      onToggleMuteOpponent: (isMuted) {
        setState(() {
          _isOpponentAudioMuted = isMuted;
        });
        final opponentId = isHost1 ? battle.host2Id : battle.host1Id;
        final opponentUid = _generateUid(opponentId);
        AgoraService().engine?.muteRemoteAudioStream(
              uid: opponentUid,
              mute: _isOpponentAudioMuted,
            );
      },
      onEndPk: () => _confirmEndVideoPk(battle.id),
      onBattleTimeExpired: () {
        if (_isCurrentUserHost) {
          _videoPkService.startPunishment(battle.id);
        }
      },
      onPunishmentTimeExpired: () {
        if (_isCurrentUserHost) {
          _videoPkService.endPkBattle(battle.id);
        }
      },
    );
  }

  void _startPKInviteListener() {
    if (_currentRoom.category == 'Live') return;
    _pkInviteSubscription = _pkRepository
        .listenToIncomingInvites(_currentRoom.id)
        .listen((invites) {
      if (!mounted) return;
      if (_currentRoom.category == 'Live') return;
      for (var invite in invites) {
        if (!_invitedUserIds.contains(invite.id)) {
          _invitedUserIds.add(invite.id);
          _showPKInviteDialog(invite);
        }
      }
    });
  }

  void _showPKInviteDialog(RoomPKInvite invite) {
    if (_currentRoom.category == 'Live') {
      _pkRepository.rejectInvite(invite.id);
      return;
    }
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
              backgroundImage: CachedNetworkImageProvider(
                invite.senderRoomImageUrl,
              ),
            ),
            const SizedBox(height: 10),
            Text('${invite.senderRoomName} has challenged you to a PK battle!'),
            const SizedBox(height: 5),
            Text(
              'Duration: ${invite.durationMinutes} mins',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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

  void _startMicInviteListener() {
    _micInviteSubscription?.cancel();
    _micInviteSubscription = FirebaseFirestore.instance
        .collection('audio_rooms_v2')
        .doc(_currentRoom.id)
        .collection('mic_invites')
        .doc(_currentUser.userId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      if (data['status'] == 'pending') {
        if (_currentParticipant?.isSeated == true &&
            (_currentParticipant?.seatNumber ?? 0) > 0) {
          // Already seated, remove invite
          doc.reference.delete();
          return;
        }

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp) {
          final diff = DateTime.now().difference(createdAt.toDate());
          if (diff.inMinutes > 2) {
            // Stale invite, delete and ignore
            doc.reference.delete();
            return;
          }
        }
        _showMicInviteDialog(data);
      }
    }, onError: (e) {
      debugPrint('Error listening to mic invites: $e');
    });
  }

  void _showMicInviteDialog(Map<String, dynamic> inviteData) {
    if (_isMicInviteDialogShowing) return;
    _isMicInviteDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.of(dialogContext).pop();
            _isMicInviteDialogShowing = false;
            _handleRejectMicInvite();
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Tips',
                    style: TextStyle(
                      color: Color(0xFF1F1F24),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Invite you to the mic',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              _isMicInviteDialogShowing = false;
                              await _handleRejectMicInvite();
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFFE0E0E0),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Take Mic Button
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              _isMicInviteDialogShowing = false;
                              await _handleAcceptMicInvite(inviteData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text(
                              'Take Mic',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
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
          ),
        );
      },
    ).then((_) {
      _isMicInviteDialogShowing = false;
    });
  }

  Future<void> _handleRejectMicInvite() async {
    try {
      await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(_currentRoom.id)
          .collection('mic_invites')
          .doc(_currentUser.userId)
          .delete();
    } catch (e) {
      debugPrint('Error rejecting mic invite: $e');
    }
  }

  Future<void> _handleAcceptMicInvite(Map<String, dynamic> inviteData) async {
    try {
      // First, delete the mic invite so it cannot be accepted twice
      await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(_currentRoom.id)
          .collection('mic_invites')
          .doc(_currentUser.userId)
          .delete();

      int targetSeat = (inviteData['seatNumber'] as num?)?.toInt() ?? 0;
      bool canTakeSpecifiedSeat = false;

      if (targetSeat > 0) {
        canTakeSpecifiedSeat =
            _currentRoom.canUserMoveToSeat(_currentUser.userId, targetSeat) &&
                !_currentRoom.isSeatOccupied(targetSeat) &&
                !_currentRoom.isSeatLocked(targetSeat);
      }

      if (!canTakeSpecifiedSeat) {
        // Find first available unlocked, unoccupied seat that the user can move to
        targetSeat = 0;
        final totalSeats = _currentRoom.settings.seatConfiguration.length;
        for (int s = 1; s <= totalSeats; s++) {
          if (_currentRoom.canUserMoveToSeat(_currentUser.userId, s) &&
              !_currentRoom.isSeatOccupied(s) &&
              !_currentRoom.isSeatLocked(s)) {
            targetSeat = s;
            break;
          }
        }
      }

      if (targetSeat > 0) {
        _moveToSeat(targetSeat);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No empty seat available at the moment.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error accepting mic invite: $e');
    }
  }

  final Map<String, Timer> _activeEmojiTimers = {};

  void _triggerSeatEmoji(String userId, String emojiUrl) {
    if (!mounted || emojiUrl.isEmpty) return;
    final pIdx =
        _currentRoom.participants.indexWhere((p) => p.userId == userId);
    if (pIdx != -1) {
      final participant = _currentRoom.participants[pIdx];
      // Only display above avatar if participant is seated or is host
      if (participant.isSeated ||
          participant.seatNumber != null ||
          participant.isHost) {
        if (participant.activeEmojiUrl != emojiUrl) {
          setState(() {
            _currentRoom.participants[pIdx] =
                participant.copyWith(activeEmojiUrl: emojiUrl);
          });
        }
        _activeEmojiTimers[userId]?.cancel();
        _activeEmojiTimers[userId] =
            Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            final currIdx =
                _currentRoom.participants.indexWhere((p) => p.userId == userId);
            if (currIdx != -1 &&
                _currentRoom.participants[currIdx].activeEmojiUrl == emojiUrl) {
              setState(() {
                _currentRoom.participants[currIdx] = _currentRoom
                    .participants[currIdx]
                    .copyWith(clearActiveEmoji: true);
              });
            }
          }
        });
      }
    }
  }

  /// Start listening to chat messages
  void _startChatListener() {
    // Use the emoji chat message stream for full emoji support
    _chatSubscription =
        EmojiChatService.getEmojiChatMessagesStream(_currentRoom.id).listen(
      (messages) {
        if (!mounted) {
          debugPrint(
            'Ã°Å¸âÂ¬ [AudioRoom] [$hashCode] Ã¢Å¡Â Ã¯Â¸  Listener fired after dispose! Skipping.',
          );
          return;
        }

        // Filter messages to hide history before join for both Firestore & VPS modes
        // When user leaves and joins the room again, previous messages will not be displayed
        final List<EmojiChatMessage> newMessages = messages.where((msg) {
          return msg.timestamp.isAfter(
            _joinTime.subtract(const Duration(seconds: 5)),
          );
        }).toList();

        debugPrint(
          'Ã°Å¸âÂ¬ [AudioRoom] [$hashCode] Received ${messages.length} messages, filtered to ${newMessages.length}',
        );

        final allMessages = [...newMessages];
        allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Trigger seat avatar emoji reaction for recent emoji messages
        final now = DateTime.now();
        for (final msg in allMessages) {
          if (msg.messageType == EmojiMessageType.emoji ||
              msg.emojiItem != null) {
            final emojiUrl = msg.emojiItem?.emojiUrl ?? '';
            if (emojiUrl.isNotEmpty) {
              final age = now.difference(msg.timestamp).inSeconds;
              if (age.abs() <= 20) {
                _triggerSeatEmoji(msg.userId, emojiUrl);
              }
            }
          }
        }

        // Update local emoji messages directly
        setState(() {
          _chatMessages = allMessages;
        });
      },
      onError: (error) {
        debugPrint('Ã°Å¸âÂ¬ Error listening to chat messages: $error');
      },
    );
  }

  StreamSubscription<QuerySnapshot>? _luckyWinSubscription;
  Map<String, dynamic>? _currentLuckyWin;
  bool _showCoinShower = false;

  /// Start listening to Lucky Win events in real-time
  void _startLuckyWinListener() {
    _luckyWinSubscription?.cancel();
    _luckyWinSubscription = FirebaseFirestore.instance
        .collection('audio_rooms_v2')
        .doc(_currentRoom.id)
        .collection('lucky_wins')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate()).inSeconds;
          if (diff < 15) {
            if (mounted) {
              setState(() {
                _currentLuckyWin = data;
                _showCoinShower = true;
              });
            }
          }
        }
      }
    });
  }

  /// Delete displayed entrance effects from Firestore
  Future<void> _deleteDisplayedEntranceEffects(
    List<EntranceEffect> effects,
  ) async {
    try {
      for (final effect in effects) {
        await _entranceEffectService.deleteEntranceEffect(
          widget.room.id,
          effect.effectId,
        );
      }
      debugPrint(
        'Ã°Å¸ââÃ¯Â¸  [AudioRoom] Deleted ${effects.length} entrance effects from Firestore',
      );
    } catch (e) {
      debugPrint('Ã¢ Å [AudioRoom] Error deleting entrance effects: $e');
    }
  }

  /// Start periodic cleanup timer for old gifts
  void _startGiftCleanupTimer() {
    _giftCleanupTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isCurrentUserHost) return;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('gift_transactions')
            .where('roomId', isEqualTo: widget.room.id)
            .get();

        final now = DateTime.now();
        final oldDocs = snap.docs.where((doc) {
          final ts = doc.data()['timestamp'];
          if (ts is Timestamp) {
            return now.difference(ts.toDate()).inSeconds > 60;
          }
          return false;
        }).toList();

        if (oldDocs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in oldDocs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          debugPrint(
              'Ã°Å¸Â§Â¹ [AudioRoom] Background timer cleaned up ${oldDocs.length} old gift docs');
        }
      } catch (e) {
        debugPrint('Ã¢Å¡Â Ã¯Â¸  [AudioRoom] Periodic gift cleanup error: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('Ã°Å¸ââ [AudioRoom] App lifecycle changed to: $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint(
          'Ã°Å¸ââ [AudioRoom] App resumed - refreshing audio session...');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_agoraChannelJoined) {
          try {
            AgoraService().engine?.setDefaultAudioRouteToSpeakerphone(true);
            AgoraService().engine?.setEnableSpeakerphone(_isSpeakerOn);
          } catch (e) {
            debugPrint(
                'Ã¢Å¡Â Ã¯Â¸  [AudioRoom] Error restoring speaker on resume: $e');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Disable WakeLock safely if not minimizing
    if (!_isMinimizing) {
      try {
        WakelockPlus.disable();
      } catch (e) {
        debugPrint('Error disabling Wakelock: $e');
      }
    }

    // Cancel timers safely
    try {
      _videoEffectsController.dispose();
      _flyingGiftsNotifier.dispose();
      _giftCleanupTimer?.cancel();
      _dailyResetTimer?.cancel();
      _pkInviteSubscription?.cancel();
      _micInviteSubscription?.cancel();
      _autoDeleteTimer?.cancel();
      _offlineTimer?.cancel();
    } catch (e) {
      debugPrint('Error canceling timers: $e');
    }

    // Clean up subscriptions safely
    try {
      _chatSubscription?.cancel();
      _luckyWinSubscription?.cancel();
      _frameSubscription?.cancel();
      _roomConfigSub?.cancel();
      _relationshipsSub?.cancel();
      _friendshipLevelsSub?.cancel();
      _coupleLevelsSub?.cancel();
      _roomGiftTransactionsSub?.cancel();
      _videoPkBattleSub?.cancel();
      _videoPkInviteSub?.cancel();
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
        tag: 'roulette_${widget.room.id}',
      )) {
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

      try {
        if (_agoraChannelJoined) {
          widget.audioRoomsBloc
              .add(LeaveAgoraChannel(channelName: _currentRoom.id));
          debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Leaving Agora channel (actual leave: ${_currentRoom.id})');
        } else {
          AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
        }
        widget.audioRoomsBloc.add(const StopListeningToRoomUpdates());
      } catch (e) {
        debugPrint('Error adding leave events to bloc: $e');
        AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
      }

      if (AgoraService().currentChannelId == null ||
          AgoraService().currentChannelId == _currentRoom.id) {
        try {
          BackgroundService().stopService();
        } catch (_) {}
      }

      _agoraChannelJoined = false;
      _agoraUid = null;
    } else {
      debugPrint(
        'Ã°Å¸âÂ½ [AudioRoom] Dispose called but minimizing - keeping connections alive',
      );
    }

    try {
      _videoControllers.clear();
      super.dispose();
    } catch (e) {
      debugPrint('Error in super.dispose: $e');
    }
  }

  bool _isRoomEndedDialogShowing = false;

  /// Show dialog when the live stream has been closed / ended
  void _showRoomEndedDialog() {
    if (_isRoomEndedDialogShowing || !mounted) return;
    _isRoomEndedDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1E142B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'This room is closed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'The host has ended the live stream.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Confirm ending live stream for host
  void _showEndLiveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E142B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.pinkAccent.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'End Live Stream?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to end your live stream? All participants and viewers will be disconnected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          _handleActualLeave(fromBottomSheet: false);
                        },
                        child: const Text(
                          'End Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    );
  }

  /// Handle leaving the room with beautiful bottom sheet or end confirmation
  void _handleLeaveRoom() {
    if (_isCurrentUserHost && _currentRoom.category == 'Live') {
      _showEndLiveConfirmationDialog();
    } else {
      _showExitConfirmationBottomSheet();
    }
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
      'Talk Show',
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
                  0xFF111111,
                ), // Dark background matching screenshot
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
                                    child: _buildCategoryChip(
                                      category,
                                      isSelected: selectedCategory == category,
                                    ),
                                  ),
                                );
                              }),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    trendingRoomsFuture =
                                        AudioRoomsRepository().getAllRooms();
                                  });
                                },
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white70,
                                  size: 24,
                                ),
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
                                    color: Colors.blueAccent,
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Failed to load rooms.',
                                        style: TextStyle(color: Colors.white70),
                                      ),
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
                                          backgroundColor: Colors.pinkAccent,
                                        ),
                                        child: const Text(
                                          'Try Again',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final allRooms = snapshot.data ?? [];
                              final popularRooms = allRooms
                                  .where(
                                    (r) =>
                                        r.id != widget.room.id &&
                                        (selectedCategory == 'All' ||
                                            r.category == selectedCategory),
                                  )
                                  .toList();
                              popularRooms.sort(
                                (a, b) => b.participantCount.compareTo(
                                  a.participantCount,
                                ),
                              );

                              if (popularRooms.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No trending rooms right now.',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: popularRooms.length,
                                itemBuilder: (context, index) {
                                  final room = popularRooms[index];
                                  return ModernRoomCard(
                                    room: room,
                                    onTap: () {
                                      _confirmSwitchToRoom(room);
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
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
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

  /// Show premium confirmation dialog when switching to another room from exit sheet
  void _confirmSwitchToRoom(AudioRoomV2 targetRoom) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF1E142B), // Harmonious premium dark background
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
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                const Text(
                  'Leave & Join Room?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  "Do you want to completely leave '${_currentRoom.name}' and join '${targetRoom.name}'?",
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
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
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(dialogContext)
                                .pop(); // Close confirmation dialog
                            Navigator.of(context)
                                .pop(); // Close exit bottom sheet

                            // 1. Cleanly leave current room completely
                            setState(() {
                              _canPopScreen = true;
                            });
                            _getMinimizedController().clearMinimizedRoom();

                            widget.audioRoomsBloc.add(
                              LeaveAgoraChannel(channelName: _currentRoom.id),
                            );
                            widget.audioRoomsBloc.add(
                              LeaveAudioRoom(
                                roomId: _currentRoom.id,
                                userId: _currentUser.userId,
                              ),
                            );

                            await AgoraService().leaveChannelAndRelease(
                                channelName: _currentRoom.id);
                            await Future.delayed(
                                const Duration(milliseconds: 150));

                            // 2. Initialize new room BLoC and join cleanly like explore flow
                            final newBloc = AudioRoomsBloc(
                              repository: AudioRoomsRepository(),
                            );
                            final currentUser =
                                AuthController.instance.currentUser;

                            if (!targetRoom.isParticipant(currentUser.userId)) {
                              newBloc.add(
                                JoinAudioRoom(
                                  roomId: targetRoom.id,
                                  userId: currentUser.userId,
                                  userName: currentUser.fullname,
                                  userImageUrl: currentUser.photoUrl,
                                  userFrameId: currentUser
                                      .customization?.selectedFrameId,
                                ),
                              );
                            }

                            Get.off(
                              () => AudioRoomScreen(
                                room: targetRoom,
                                audioRoomsBloc: newBloc,
                              ),
                              preventDuplicates: false,
                            );
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
    );
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
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
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
        'Ã¢Å¡Â Ã¯Â¸  [AudioRoom] MinimizedRoomController not found, initializing...',
      );
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
    minimizedController.minimizeRoom(
      _currentRoom,
      bloc: widget.audioRoomsBloc,
      joinTime: _joinTime,
    );

    // IMPORTANT: Do NOT leave Agora channel - keep audio connection active!
    // Do NOT stop listening to room updates - keep getting real-time updates

    debugPrint('Ã°Å¸âÂ½ [AudioRoom] Room minimized: ${_currentRoom.name}');
    debugPrint(
        'Ã°Å¸âÂ½ [AudioRoom] Agora channel kept active for minimized room');

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
      debugPrint('Ã°Å¸ââ [AudioRoom] Reloading room list after minimize');
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

    try {
      BackgroundService().stopService();
    } catch (_) {}

    // If ending a live video room and PK battle is running, terminate battle
    if (_currentRoom.category == 'Live' && _activeVideoBattle != null) {
      _videoPkService.endPkBattle(
        _activeVideoBattle!.id,
        _currentUser.userId,
      );
    }

    if (_isCurrentUserHost && _currentRoom.category == 'Live') {
      try {
        FirebaseFirestore.instance
            .collection('audio_rooms_v2')
            .doc(_currentRoom.id)
            .update({
          'isActive': false,
          'participants': [],
          'joinedUserIds': [],
          'liveSessionDiamonds': 0,
          'liveSessionGifts': 0,
          'updatedAt': Timestamp.now(),
        }).catchError((_) {});
      } catch (_) {}
    }

    // Leave the room
    widget.audioRoomsBloc.add(
      LeaveAudioRoom(roomId: _currentRoom.id, userId: _currentUser.userId),
    );

    // Wait for the next frame so PopScope is updated before popping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_isCurrentUserHost && _currentRoom.category == 'Live') {
          final int duration =
              DateTime.now().difference(_joinTime).inMinutes;
          final int users = _sessionViewers.isNotEmpty
              ? _sessionViewers.length
              : (_currentRoom.joinedUserIds.isNotEmpty
                  ? _currentRoom.joinedUserIds.length
                  : 1);
          final int diamonds = (_currentRoom.totalRevenue >= _sessionInitialRevenue)
              ? (_currentRoom.totalRevenue - _sessionInitialRevenue)
              : 0;
          final int gifts = _sessionGiftsCount;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LiveEndedSummaryScreen(
                durationMinutes: duration,
                totalUsers: users,
                totalDiamonds: diamonds,
                totalGifts: gifts,
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

    debugPrint('Ã°Å¸ââ¹ [AudioRoom] User left room: ${_currentRoom.name}');
  }

  /// Handle grab top seat / gift selection
  void _grabTopSeat() {
    final hostParticipant = _currentRoom.participants.firstWhere(
      (p) => p.userId == _currentRoom.creatorId,
      orElse: () => AudioRoomParticipant(
        userId: _currentRoom.creatorId,
        userName: _currentRoom.creatorName,
        userImageUrl: _currentRoom.creatorImageUrl,
        isHost: true,
        joinedAt: DateTime.now(),
      ),
    );
    _showGiftSelection(hostParticipant);
  }

  /// Handle mute/unmute
  void _handleMuteToggle() {
    debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸Å½â¢Ã¯Â¸  Microphone toggle requested...');
    debugPrint(
      'Ã°Å¸Å½Â¤ [AudioRoom]   - Current state: ${_isMuted ? "MUTED" : "UNMUTED"}',
    );
    debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom]   - Agora connected: $_agoraChannelJoined');
    debugPrint(
      'Ã°Å¸Å½Â¤ [AudioRoom]   - Is seated: ${_currentParticipant?.isSeated ?? false}',
    );

    // Check if participant is seated on a seat
    final bool canUserUseMic = _currentParticipant != null &&
        (_currentParticipant!.isSeated ||
            _currentParticipant!.isSpeaker ||
            (_currentParticipant!.seatNumber != null &&
                _currentParticipant!.seatNumber! >= 0));

    if (!canUserUseMic) {
      debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢ Å Cannot toggle mic - participant is not seated',
      );
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

    final bool targetMute = !_isMuted;

    if (mounted) {
      setState(() {
        _isMuted = targetMute;
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    if (_agoraChannelJoined) {
      // Use Agora for explicit mute/unmute
      debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÂ§ Sending SetMicrophoneMute($targetMute) event to Agora...',
      );
      widget.audioRoomsBloc.add(SetMicrophoneMute(muted: targetMute));
    } else {
      // Fallback to local state if Agora not connected
      debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Å¡Â Ã¯Â¸  Agora not connected, using local state fallback',
      );

      // Update participant's mute status in the room
      if (_currentParticipant != null) {
        final updatedParticipant = _currentParticipant!.copyWith(
          isMuted: _isMuted,
        );
        widget.audioRoomsBloc.add(
          UpdateRoomParticipant(
            roomId: _currentRoom.id,
            userId: _currentUser.userId,
            updatedParticipant: updatedParticipant,
          ),
        );
        debugPrint(
          'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸â  Updated participant mute status in room (local): $_isMuted',
        );
      }

      debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÂ± Local state updated: ${_isMuted ? "MUTED" : "UNMUTED"}',
      );
    }
  }

  /// Handle speaker toggle
  void _handleSpeakerToggle() {
    debugPrint('Ã°Å¸âÅ  [AudioRoom] Ã°Å¸âÅ  Speaker toggle requested...');
    debugPrint(
      'Ã°Å¸âÅ  [AudioRoom]   - Current state: ${_isSpeakerOn ? "ON" : "OFF"}',
    );
    debugPrint(
        'Ã°Å¸âÅ  [AudioRoom]   - Agora connected: $_agoraChannelJoined');

    if (_agoraChannelJoined) {
      // Use Agora for speaker toggle
      debugPrint(
          'Ã°Å¸âÅ  [AudioRoom] Ã°Å¸âÂ§ Sending ToggleSpeaker event to Agora...');
      widget.audioRoomsBloc.add(const ToggleSpeaker());
    } else {
      // Fallback to local state if Agora not connected
      debugPrint(
        'Ã°Å¸âÅ  [AudioRoom] Ã¢Å¡Â Ã¯Â¸  Agora not connected, using local state fallback',
      );
      if (mounted) {
        setState(() {
          _isSpeakerOn = !_isSpeakerOn;
        });
        WidgetsBinding.instance.scheduleFrame();
      }
      debugPrint(
        'Ã°Å¸âÅ  [AudioRoom] Ã°Å¸âÂ± Local state updated: ${_isSpeakerOn ? "ON" : "OFF"}',
      );
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
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 20
                    : MediaQuery.of(context).padding.bottom + 20,
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
                    leading: const Icon(
                      Icons.flip_camera_ios_rounded,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Switch Camera',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      AgoraService().switchCamera();
                      Navigator.pop(
                        context,
                      ); // Optional: close bottom sheet after switching
                    },
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 5),
                  // Camera On/Off Toggle
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: Colors.pinkAccent,
                    title: const Text(
                      'Enable Camera',
                      style: TextStyle(color: Colors.white),
                    ),
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
                    title: const Text(
                      'Beauty Camera',
                      style: TextStyle(color: Colors.white),
                    ),
                    secondary: const Icon(
                      Icons.face_retouching_natural,
                      color: Colors.white,
                    ),
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
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
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
            child: Text(
              (value * 100).toInt().toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
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
                      title: const Text(
                        'Waiting List',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showWaitingListBottomSheet(
                          context,
                          _currentRoom.id,
                          widget.audioRoomsBloc,
                        );
                      },
                    ),
                  if (_isCurrentUserHost)
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.block, color: Colors.white),
                      title: const Text(
                        'Mute All Users',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(
                          ToggleAdminMute(
                            roomId: _currentRoom.id,
                            participantId: 'ALL',
                            mutedByAdmin: true,
                          ),
                        );
                      },
                    ),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(
                      localRoomMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    title: Text(
                      localRoomMuted
                          ? 'Unmute Room Speaker'
                          : 'Mute Room Speaker',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      setModalState(() {
                        localRoomMuted = !localRoomMuted;
                      });
                      _handleRoomMuteToggle();
                    },
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    leading: Icon(
                      localUserMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                    title: Text(
                      localUserMuted ? 'Unmute Microphone' : 'Mute Microphone',
                      style: const TextStyle(color: Colors.white),
                    ),
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
    widget.audioRoomsBloc.add(
      SendJoinRequest(roomId: _currentRoom.id, userId: _currentUser.userId),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join request sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Show Video Beauty & Retouch Sheet (Khan_Live style)
  void _showBeautySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BeautyEffectSheet(
        controller: _videoEffectsController,
      ),
    );
  }

  /// Show Video Background Effect Sheet (Virtual background / Blur / Wallpaper)
  void _showBackgroundSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackgroundEffectSheet(
        controller: _videoEffectsController,
      ),
    );
  }

  /// Show Video Call Guest Management Sheet (Pending requests & Active Call Guests)
  void _showManageGuestsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VideoCallManageSheet(
        room: _currentRoom,
        audioRoomsBloc: widget.audioRoomsBloc,
      ),
    );
  }

  /// Show Video Room Settings Sheet (Glassmorphic grid matching Khan_Live)
  void _showVideoRoomSettingsSheet() {
    final isSeatedGuest = !_isCurrentUserHost &&
        (_currentParticipant?.isSeated == true ||
            _currentParticipant?.seatNumber != null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VideoRoomSettingsSheet(
        isHost: _isCurrentUserHost,
        isSeatedGuest: isSeatedGuest,
        isMuted: _isCurrentUserMuted,
        isCameraOff: !_isHostVideoEnabled,
        isSpeakerMuted: !_isSpeakerOn,
        joinRequestsCount: _currentRoom.joinRequests.length,
        onOpenBeauty: _showBeautySheet,
        onOpenBackground: _showBackgroundSheet,
        onFlipCamera: () => AgoraService().switchCamera(),
        onToggleMic: _handleMuteToggle,
        onToggleCamera: () {
          setState(() {
            _isHostVideoEnabled = !_isHostVideoEnabled;
          });
          if (_isHostVideoEnabled) {
            AgoraService().enableVideo();
          } else {
            AgoraService().disableVideo();
          }
        },
        onToggleSpeaker: _handleSpeakerToggle,
        onOpenManageGuests: _showManageGuestsSheet,
        onEditRoomInfo: _showAnnouncementDialog,
        onLeaveCall: () {
          if (_currentParticipant?.seatNumber != null) {
            _confirmMoveToAudience(_currentParticipant!.seatNumber!);
          }
        },
        onOpenPKBattle: _openVideoPkSheet,
        onOpenLuckyBag: () {
          CreateLuckyBagBottomSheet.show(
            context,
            roomId: _currentRoom.id,
            senderId: _currentUser.userId,
            senderName: _currentUser.fullname,
            senderAvatar: _currentUser.photoUrl,
          );
        },
      ),
    );
  }

  /// Confirmation dialog to leave call seat and return to audience
  void _confirmMoveToAudience(int seatNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131722),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Leave Call Seat?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will leave the call seat and return to the audience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _leaveSeat();
                      },
                      child: const Text('Leave',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Self seat options for a seated guest caller
  void _showMySeatCallSheet(AudioRoomParticipant participant) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF131722).withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CachedCircleAvatar(
                    imageUrl: participant.userImageUrl ?? '',
                    radius: 23,
                    borderColor: const Color(0xFFD946EF),
                    borderWidth: 1.5,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Call Seat #${participant.seatNumber}',
                          style: const TextStyle(
                            color: Color(0xFFD946EF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCurrentUserMuted
                            ? const Color(0xFF10B981)
                            : Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleMuteToggle();
                      },
                      icon: Icon(
                        _isCurrentUserMuted ? Icons.mic : Icons.mic_off,
                        size: 18,
                      ),
                      label: Text(
                        _isCurrentUserMuted ? 'Unmute' : 'Mute',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFEF4444).withOpacity(0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: Color(0xFFEF4444), width: 1),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (participant.seatNumber != null) {
                          _confirmMoveToAudience(participant.seatNumber!);
                        }
                      },
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: const Text(
                        'Leave Call',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Remote moderation sheet when host taps on a seated call guest
  void _showGuestSeatActionSheet(AudioRoomParticipant participant) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF131722).withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CachedCircleAvatar(
                    imageUrl: participant.userImageUrl ?? '',
                    radius: 23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Call Seat #${participant.seatNumber}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    participant.isMutedByAdmin ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  participant.isMutedByAdmin
                      ? 'Unmute Guest Mic'
                      : 'Mute Guest Mic',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.audioRoomsBloc.add(
                    ToggleAdminMute(
                      roomId: _currentRoom.id,
                      participantId: participant.userId,
                      mutedByAdmin: !participant.isMutedByAdmin,
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Disconnect from Call (Move to Audience)',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (participant.seatNumber != null) {
                    widget.audioRoomsBloc.add(
                      MoveParticipantToSeat(
                        roomId: _currentRoom.id,
                        userId: participant.userId,
                        fromSeat: participant.seatNumber!,
                        toSeat: -1,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${participant.userName} removed from call seat'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'View Profile',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showParticipantBottomSheet(participant);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle Call Join Request tap from RoomControls bottom bar
  void _handleCallJoinRequest() {
    if (_isCurrentUserHost) {
      _showManageGuestsSheet();
      return;
    }

    if (_currentParticipant?.isSeated == true ||
        _currentParticipant?.seatNumber != null) {
      if (_currentParticipant?.seatNumber != null) {
        _confirmMoveToAudience(_currentParticipant!.seatNumber!);
      }
      return;
    }

    final hasRequested =
        _currentRoom.joinRequests.contains(_currentUser.userId);
    if (hasRequested) {
      widget.audioRoomsBloc.add(
        RejectJoinRequest(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      widget.audioRoomsBloc.add(
        SendJoinRequest(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request sent to host!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Floating circular guest seats on the right side of video room (Khan_Live style)
  Widget _buildLiveCircularGuestSeats() {
    final seatedGuests = _currentRoom.participants
        .where((p) => p.isSeated && p.seatNumber != null && p.seatNumber! > 1)
        .toList()
      ..sort((a, b) => a.seatNumber!.compareTo(b.seatNumber!));

    return Positioned(
      right: 12,
      top: 175,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Active Call Guests
            for (final guest in seatedGuests) ...[
              _buildSingleGuestSeat(guest),
              const SizedBox(height: 10),
            ],

            // If current user is host, show + button to manage call guests
            if (_isCurrentUserHost)
              GestureDetector(
                onTap: _showManageGuestsSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD946EF).withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD946EF).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_call,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (_currentRoom.joinRequests.isNotEmpty)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Center(
                            child: Text(
                              '${_currentRoom.joinRequests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleGuestSeat(AudioRoomParticipant guest) {
    final isMe = guest.userId == _currentUser.userId;
    final guestUid = _generateUid(guest.userId);
    final engine = AgoraService().engine;
    final isSpeaking = !guest.isMuted;

    return GestureDetector(
      onTap: () {
        if (isMe) {
          _showMySeatCallSheet(guest);
        } else if (_isCurrentUserHost) {
          _showGuestSeatActionSheet(guest);
        } else {
          _showParticipantBottomSheet(guest);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD946EF).withOpacity(0.8),
                width: isSpeaking ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSpeaking
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : Colors.black38,
                  blurRadius: 8,
                  spreadRadius: isSpeaking ? 2 : 1,
                ),
              ],
            ),
            child: ClipOval(
              child: Builder(
                builder: (_) {
                  if (engine != null && _agoraChannelJoined) {
                    if (isMe && _isHostVideoEnabled) {
                      return AgoraVideoView(
                        controller: _getVideoController(0, engine),
                      );
                    }
                    final isMuted =
                        AgoraService().remoteUserVideoMuted[guestUid] ?? true;
                    if (!isMuted) {
                      return AgoraVideoView(
                        controller: _getVideoController(guestUid, engine),
                      );
                    }
                  }
                  return CachedCircleAvatar(
                    imageUrl: guest.userImageUrl ?? '',
                    radius: 26,
                  );
                },
              ),
            ),
          ),
          // Seat number badge (top-left)
          Positioned(
            top: -2,
            left: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFD946EF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${guest.seatNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Mic status badge (bottom-right)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: guest.isMuted
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Icon(
                guest.isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Initialize Agora for the audio room
  void _initializeAgoraForRoom() {
    // Safety check: don't add events to a closed BLoC
    if (widget.audioRoomsBloc.isClosed) {
      debugPrint(
          'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢ Å Cannot initialize Agora: BLoC is closed');
      return;
    }

    // Generate a unique non-zero deterministic UID for this user
    _agoraUid = generateAgoraUid(_currentUser.userId);

    // Initialize Agora only - join will happen in BlocListener
    widget.audioRoomsBloc.add(
      InitializeAgora(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        userName: _currentUser.fullname,
        userImageUrl: _currentUser.photoUrl,
        audioQuality: AudioQuality.high,
        isVideo: widget.room.category == 'Live',
      ),
    );
  }

  /// Join Agora channel
  void _joinAgoraChannel() {
    if (_agoraUid == null) {
      debugPrint('Ã°Å¸Å½Â¤ [AudioRoom] Ã¢ Å Cannot join channel: UID is null');
      return;
    }

    if (_agoraChannelJoined &&
        AgoraService().isConnected &&
        AgoraService().currentChannelId == _currentRoom.id) {
      debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Å¡Â Ã¯Â¸  Already joined Agora channel ${_currentRoom.id}, skipping duplicate join',
      );
      return;
    }

    debugPrint(
        'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸Å¡Âª Attempting to join Agora channel...');
    debugPrint('Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ââ¹ Join Info:');
    debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - Channel: ${_currentRoom.id}');
    debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - UID: $_agoraUid');
    debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - User: ${_currentUser.fullname}');

    // Get current participant's seat and mute status
    final currentParticipant = _currentParticipant;

    final bool isSeated = (currentParticipant?.isSeated ?? false) ||
        (currentParticipant?.seatNumber != null &&
            currentParticipant!.seatNumber! >= 0);

    final bool isMuted =
        isSeated ? (currentParticipant?.isMutedByAdmin == true) : true;
    if (isSeated && currentParticipant?.isMutedByAdmin != true) {
      _isMuted = false;
    }

    debugPrint(
      'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÂ§ Participant mute status: $isMuted (isSeated: $isSeated, participant: ${currentParticipant?.userName}, seat: ${currentParticipant?.seatNumber})',
    );

    widget.audioRoomsBloc.add(
      JoinAgoraChannel(
        channelName: _currentRoom.id,
        uid: _agoraUid!,
        userId: _currentUser.userId,
        userName: _currentUser.fullname,
        userImageUrl: _currentUser.photoUrl,
        isMuted: isMuted,
        isVideo: _currentRoom.category == 'Live',
        isSeated: isSeated,
      ),
    );
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
        debugPrint('Ã°Å¸Å½Â¯ Current user or participants list is empty');
        return null;
      }

      return _currentRoom.participants.firstWhere(
        (p) => p.userId == _currentUser.userId,
      );
    } catch (e) {
      debugPrint('Ã°Å¸Å½Â¯ Current user not found in participants: $e');
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
    return generateAgoraUid(userId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.audioRoomsBloc,
      child: BlocListener<AudioRoomsBloc, AudioRoomsState>(
        listener: (context, state) {
          // Handle room ended state
          if (state is AudioRoomsError && state.errorCode == 'ROOM_ENDED') {
            debugPrint(
              '🚪 [UI] Room ended. Stopping video and showing room closed dialog...',
            );
            setState(() {
              _canPopScreen = true;
              _agoraChannelJoined = false;
            });
            _videoControllers.clear();
            try {
              AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
            } catch (_) {}
            _showRoomEndedDialog();
            return;
          }

          // Handle kicked/blocked state
          if (state is AudioRoomsError && state.errorCode == 'KICKED') {
            debugPrint(
              '🚪 [UI] User has been kicked or blocked. Popping screen...',
            );
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
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ââ Agora is initializing...');
          } else if (state is AgoraInitialized) {
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Åâ¦ Agora initialized successfully');
            // Auto-join channel after initialization
            _joinAgoraChannel();
          } else if (state is AgoraInitializationFailed) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Agora initialization failed: ${state.error}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Audio initialization failed: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is AgoraChannelJoining) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ââ Joining Agora channel: ${state.channelName}...',
            );
          } else if (state is AgoraChannelJoined) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Åâ¦ Successfully joined Agora channel: ${state.channelName}',
            );
            debugPrint('Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÅ  Channel Info:');
            debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - UID: ${state.uid}');
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom]   - Connection State: ${state.connectionState}',
            );
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom]   - Users in channel: ${state.users.length}',
            );
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom]   - Microphone muted: ${state.isMuted}');
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom]   - Speaker on: ${state.isSpeakerOn}');
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom]   - Audio quality: ${state.audioQuality}',
            );

            setState(() {
              _agoraChannelJoined = true;
              _agoraUsers = state.users;
              _isMuted = state.isMuted;
              _isSpeakerOn = state.isSpeakerOn;
            });

            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('Ã°Å¸Å½Â¤ Connected to audio room!'),
            //     backgroundColor: Colors.green,
            //     duration: Duration(seconds: 2),
            //   ),
            // );
          } else if (state is AgoraChannelJoinFailed) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Failed to join Agora channel: ${state.error}',
            );
            // Seamless automatic retry after 1.5 seconds if not yet joined
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted &&
                  !_agoraChannelJoined &&
                  !widget.audioRoomsBloc.isClosed) {
                debugPrint(
                    'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ââ Auto-retrying Agora join channel...');
                _joinAgoraChannel();
              }
            });
          } else if (state is MicrophoneToggled) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸Å½â¢Ã¯Â¸  Microphone toggled: ${state.isMuted ? "Ã°Å¸ââ¡ MUTED" : "Ã°Å¸Å½Â¤ UNMUTED"}',
            );
            setState(() {
              _isMuted = state.isMuted;
            });
            WidgetsBinding.instance.scheduleFrame();

            // Update participant's mute status in the room
            if (_currentParticipant != null) {
              final updatedParticipant = _currentParticipant!.copyWith(
                isMuted: state.isMuted,
              );
              widget.audioRoomsBloc.add(
                UpdateRoomParticipant(
                  roomId: _currentRoom.id,
                  userId: _currentUser.userId,
                  updatedParticipant: updatedParticipant,
                ),
              );
              debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸â  Updated participant mute status in room: ${state.isMuted}',
              );
            }
          } else if (state is RoomMuteToggled) {
            debugPrint(
              'Ã°Å¸ââ¡ [AudioRoom] Ã°Å¸ââ¡ Room mute toggled: ${state.isRoomMuted ? "Ã°Å¸ââ¡ MUTED" : "Ã°Å¸âÅ  UNMUTED"}',
            );
            setState(() {
              _isRoomMuted = state.isRoomMuted;
            });
            WidgetsBinding.instance.scheduleFrame();

            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(state.isMuted ? 'Ã°Å¸ââ¡ Microphone muted' : 'Ã°Å¸Å½Â¤ Microphone unmuted'),
            //     backgroundColor: state.isMuted ? Colors.orange : Colors.green,
            //     duration: const Duration(seconds: 1),
            //   ),
            // );
          } else if (state is SpeakerToggled) {
            debugPrint(
              'Ã°Å¸âÅ  [AudioRoom] Ã°Å¸âÅ  Speaker toggled: ${state.isSpeakerOn ? "Ã°Å¸âÅ  ON" : "Ã°Å¸ââ¡ OFF"}',
            );
            setState(() {
              _isSpeakerOn = state.isSpeakerOn;
            });
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(state.isSpeakerOn ? 'Ã°Å¸âÅ  Speaker on' : 'Ã°Å¸ââ¡ Speaker off'),
            //     backgroundColor: state.isSpeakerOn ? Colors.green : Colors.orange,
            //     duration: const Duration(seconds: 1),
            //   ),
            // );
          } else if (state is AgoraUserUpdated) {
            debugPrint(
              'ð¤ [AudioRoom] Agora user updated: ${state.user.userName} (${state.action})',
            );
            if (state.action == 'joined') {
              debugPrint(
                'ð¤ [AudioRoom] ð¢ Remote user JOINED Agora channel: ${state.user.userName} (UID: ${state.user.uid})',
              );
            } else if (state.action == 'left') {
              debugPrint(
                'ð¤ [AudioRoom] ð´ Remote user LEFT Agora channel: ${state.user.userName} (UID: ${state.user.uid})',
              );
            }

            // Update the user in our local list
            setState(() {
              if (state.action == 'joined') {
                final index = _agoraUsers.indexWhere(
                  (u) => u.uid == state.user.uid,
                );
                if (index != -1) {
                  _agoraUsers[index] = state.user;
                } else {
                  _agoraUsers.add(state.user);
                }
              } else if (state.action == 'left') {
                _agoraUsers.removeWhere((u) => u.uid == state.user.uid);
              } else if (state.action == 'muted' || state.action == 'unmuted') {
                final index = _agoraUsers.indexWhere(
                  (u) => u.uid == state.user.uid,
                );
                if (index != -1) {
                  _agoraUsers[index] = state.user;
                }
                final participantIndex = _currentRoom.participants.indexWhere(
                  (p) =>
                      (state.user.userId.isNotEmpty &&
                          p.userId == state.user.userId) ||
                      generateAgoraUid(p.userId) == state.user.uid ||
                      (p.userId.hashCode.abs() % 1000000) == state.user.uid,
                );
                if (participantIndex != -1) {
                  final isMutedNow = state.action == 'muted';
                  final updatedList = List<AudioRoomParticipant>.from(
                      _currentRoom.participants);
                  updatedList[participantIndex] =
                      updatedList[participantIndex].copyWith(
                    isMuted: isMutedNow,
                  );
                  _currentRoom =
                      _currentRoom.copyWith(participants: updatedList);

                  // If muted, clear volume immediately so ripple stops instantly
                  if (isMutedNow) {
                    _userVolumeNotifiers[updatedList[participantIndex].userId]
                        ?.value = 0.0;
                  }
                }
              }
            });
          } else if (state is AgoraConnectionUpdated) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ÅÂ Connection state changed: ${state.state}',
            );
          } else if (state is AudioVolumeUpdated) {
            final activeSpeakingUserIds = <String>{};

            state.userVolumes.forEach((uid, volume) {
              try {
                final isLocalUser = (uid == 0) ||
                    (uid == _agoraUid) ||
                    (uid == generateAgoraUid(_currentUser.userId)) ||
                    (uid == _currentUser.userId.hashCode.abs() % 1000000) ||
                    (uid.toString() == _currentUser.userId);

                String? targetUserId;
                if (isLocalUser) {
                  targetUserId = _currentUser.userId;
                } else {
                  // 1. Check room participants first by Agora UID hash (matches seat occupant)
                  final p = _currentRoom.participants.firstWhereOrNull(
                    (p) =>
                        generateAgoraUid(p.userId) == uid ||
                        (p.userId.hashCode.abs() % 1000000) == uid ||
                        p.userId == uid.toString(),
                  );
                  if (p != null) {
                    targetUserId = p.userId;
                  } else if (generateAgoraUid(_currentRoom.creatorId) == uid ||
                      (_currentRoom.creatorId.hashCode.abs() % 1000000) ==
                          uid ||
                      _currentRoom.creatorId == uid.toString()) {
                    targetUserId = _currentRoom.creatorId;
                  } else {
                    // 2. Fallback to active Agora users map if resolved
                    final agoraUser =
                        _agoraUsers.firstWhereOrNull((u) => u.uid == uid);
                    if (agoraUser != null &&
                        agoraUser.userId.isNotEmpty &&
                        !agoraUser.userId.startsWith('user_')) {
                      targetUserId = agoraUser.userId;
                    } else {
                      // 3. Fallback to AgoraService remote users map
                      final remoteUser =
                          widget.audioRoomsBloc.agoraService.remoteUsers[uid];
                      if (remoteUser != null &&
                          remoteUser.userId.isNotEmpty &&
                          !remoteUser.userId.startsWith('user_')) {
                        targetUserId = remoteUser.userId;
                      }
                    }
                  }
                }

                if (targetUserId != null) {
                  bool isActuallyMuted = false;
                  if (targetUserId == _currentUser.userId) {
                    isActuallyMuted = _isCurrentUserMuted;
                  } else {
                    final p = _currentRoom.participants
                        .firstWhereOrNull((p) => p.userId == targetUserId);
                    final isMutedByAdmin = p?.isMutedByAdmin == true;
                    // If Agora detects actual incoming audio from remote user, they are speaking and unmuted
                    if (volume > 1 && !isMutedByAdmin) {
                      isActuallyMuted = false;
                      if (p != null && p.isMuted) {
                        final idx = _currentRoom.participants.indexOf(p);
                        if (idx != -1) {
                          final updatedList = List<AudioRoomParticipant>.from(
                              _currentRoom.participants);
                          updatedList[idx] = p.copyWith(isMuted: false);
                          _currentRoom =
                              _currentRoom.copyWith(participants: updatedList);
                        }
                      }
                    } else {
                      isActuallyMuted = isMutedByAdmin || (p?.isMuted == true);
                    }
                  }

                  // Boost normalized volume for clear, vibrant mic waves when speaking
                  // When user is muted, volume is strictly 0.0 (no mic ripple when muted)
                  final normalizedVol = (isActuallyMuted || volume <= 1)
                      ? 0.0
                      : (volume / 100.0).clamp(0.15, 1.0);

                  if (normalizedVol > 0.0) {
                    activeSpeakingUserIds.add(targetUserId);
                  }

                  final notifier = _getVolumeNotifier(targetUserId);
                  notifier.value = normalizedVol;
                }
              } catch (e) {
                // Ignore errors
              }
            });

            // Reset volume notifier to 0.0 for users who stopped speaking
            _userVolumeNotifiers.forEach((userId, notifier) {
              if (!activeSpeakingUserIds.contains(userId) &&
                  notifier.value != 0.0) {
                notifier.value = 0.0;
              }
            });
          } else if (state is NetworkQualityUpdated) {
            // debugPrint('Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÂ¶ Network quality: ${state.quality}');
          } else if (state is AgoraStatsUpdated) {
            // debugPrint('Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸âÅ  Agora Stats:');
            // debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - Duration: ${state.stats.duration}s');
            // debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - Users: ${state.stats.userCount}');
            // debugPrint('Ã°Å¸Å½Â¤ [AudioRoom]   - CPU Usage: ${state.stats.cpuTotalUsage}%');
            if (state.stats.txBytes > 0) {
              debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom]   - TX: ${state.stats.txBytes} bytes (${state.stats.txKBitRate} kbps)',
              );
            }
            if (state.stats.rxBytes > 0) {
              debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom]   - RX: ${state.stats.rxBytes} bytes (${state.stats.rxKBitRate} kbps)',
              );
            }
          } else if (state is TokenPrivilegeWillExpire) {
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Å¡Â Ã¯Â¸Â Token will expire soon, renewing...');
          } else if (state is TokenRenewed) {
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢Åâ¦ Token renewed successfully');
          } else if (state is AgoraError) {
            debugPrint(
              'Ã°Å¸Å½Â¤ [AudioRoom] Ã¢ÂÅ Agora Error: ${state.message} (Code: ${state.code})',
            );
            if (state.code == 'MIC_PERMISSION_DENIED' ||
                state.code == 'NOT_SEATED' ||
                state.code == 'MUTED_BY_ADMIN' ||
                state.code == 'TOGGLE_MIC_FAILED' ||
                state.code == 'SET_MIC_FAILED') {
              if (mounted) {
                setState(() {
                  _isMuted = true;
                });
                WidgetsBinding.instance.scheduleFrame();
              }
            }
          } else if (state is AgoraChannelLeft) {
            debugPrint(
                'Ã°Å¸Å½Â¤ [AudioRoom] Ã°Å¸ââ¹ Left Agora channel successfully');
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

            _currentRoom = newRoom;

            // Track live session unique viewers
            for (final p in newRoom.participants) {
              _sessionViewers.add(p.userId);
            }
            if (newRoom.joinedUserIds.isNotEmpty) {
              _sessionViewers.addAll(newRoom.joinedUserIds);
            }

            if (mounted) {
              setState(() {});
              WidgetsBinding.instance.scheduleFrame();
            }

            if (!newRoom.isActive && !_isCurrentUserHost && newRoom.category == 'Live') {
              debugPrint('🚪 [UI] Live room is inactive. Stopping video and showing room closed dialog...');
              setState(() {
                _canPopScreen = true;
                _agoraChannelJoined = false;
              });
              _videoControllers.clear();
              try {
                AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
              } catch (_) {}
              _showRoomEndedDialog();
              return;
            }

            if (newRoom.activeYoutubeVideoId != null) {
              final hostParticipant = newRoom.participants.firstWhereOrNull(
                (p) => p.userId == newRoom.creatorId,
              );
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

            // Auto-close Carrom if Seat 1 (Host seat) becomes empty
            if (newRoom.isCarromActive) {
              final seat1Participant = newRoom.participants.firstWhereOrNull(
                (p) => p.isSeated && p.seatNumber == 1,
              );
              final isSeat1Occupied = seat1Participant != null;

              if (!isSeat1Occupied) {
                final isHostInRoom = newRoom.participants.any(
                  (p) => p.userId == newRoom.creatorId,
                );
                final shouldCloseCarrom =
                    (isHostInRoom && _isCurrentUserHost) ||
                        (!isHostInRoom &&
                            newRoom.participants.isNotEmpty &&
                            newRoom.participants.first.userId ==
                                _currentUser.userId);

                if (shouldCloseCarrom) {
                  AudioRoomsRepository().updateCarromState(
                    roomId: newRoom.id,
                    isActive: false,
                  );
                }
              }
            }

            // --- NOTIFICATIONS LOGIC ---

            // 1. Find Current User in both states
            final oldMe = oldRoom.participants.firstWhereOrNull(
              (p) => p.userId == _currentUser.userId,
            );
            final newMe = newRoom.participants.firstWhereOrNull(
              (p) => p.userId == _currentUser.userId,
            );

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

            // Handle background image changes
            if (oldBackgroundUrl != newBackgroundUrl) {
              if (newBackgroundUrl != null &&
                  newBackgroundUrl.startsWith('http')) {
                // Preload new background image for smooth transition
                DefaultCacheManager()
                    .getSingleFile(newBackgroundUrl)
                    .catchError((error) {
                  debugPrint(
                    'Ã°Å¸âÂ¼Ã¯Â¸Â Failed to preload updated background: $error',
                  );
                  throw error;
                });
              }
            }
          } else if (state is AudioRoomLeft) {
            debugPrint(
                'Ã°Å¸Å½Â¯ Successfully left room (screen already popped)');
            // Removed Navigator.of(context).pop() to fix double-pop white screen bug
          } else if (state is AudioRoomJoined) {
            debugPrint(
              'Ã°Å¸Å½Â¯ User successfully joined room from within room screen',
            );
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
              '🎯 Failed to join room from within room screen: ${state.message}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            // Safely exit without minimizing
            setState(() {
              _canPopScreen = true;
            });
            _getMinimizedController().clearMinimizedRoom();
            AgoraService().leaveChannelAndRelease(channelName: _currentRoom.id);
            Navigator.of(context).pop();
          } else if (state is JoiningAudioRoom) {
            // Show immediate feedback - no debug prints for speed
          } else if (state is AudioRoomsError) {
            debugPrint('🎯 Room error: ${state.message}');
            final lowerMsg = state.message.toLowerCase();
            final bool isTechnicalError = lowerMsg.contains('livekit') ||
                lowerMsg.contains('firestore') ||
                lowerMsg.contains('firebase') ||
                lowerMsg.contains('agora') ||
                lowerMsg.contains('exception') ||
                lowerMsg.contains('socket') ||
                lowerMsg.contains('failed to connect') ||
                lowerMsg.contains('timed out');
            if (!isTechnicalError && state.message.trim().isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            if (state.errorCode == 'KICKED') {
              debugPrint(
                '🚪 [AudioRoom] Kicked state detected, safely exiting room screen...',
              );
              setState(() {
                _canPopScreen = true;
              });
              _getMinimizedController().clearMinimizedRoom();
              AgoraService()
                  .leaveChannelAndRelease(channelName: _currentRoom.id);
              Navigator.of(context).pop();
            }
          } else if (state is ParticipantMovedToSeat) {
            debugPrint(
              'ðª [UI] Participant moved to seat - forcing UI refresh',
            );
            if (state.userId == _currentUser.userId) {
              if (state.toSeat >= 0) {
                // Moving onto a seat: unmuted by default unless muted by admin
                final bool isMutedByAdmin =
                    _currentParticipant?.isMutedByAdmin == true;
                _isMuted = isMutedByAdmin;
              } else {
                // Leaving seat: muted
                _isMuted = true;
              }
            }
            // Update _currentRoom participants in-memory immediately
            final updatedParticipants = _currentRoom.participants.map((p) {
              if (p.userId == state.userId) {
                if (state.toSeat >= 0) {
                  return p.copyWith(
                    seatNumber: state.toSeat,
                    isSeated: true,
                    isSpeaker: true,
                    isMuted: state.userId == _currentUser.userId
                        ? _isMuted
                        : (p.isMutedByAdmin ? true : false),
                  );
                } else {
                  return p.copyWith(
                    clearSeatNumber: true,
                    isSeated: false,
                    isSpeaker: false,
                    isMuted: true,
                  );
                }
              }
              return p;
            }).toList();
            _currentRoom =
                _currentRoom.copyWith(participants: updatedParticipants);
            // Force UI refresh to update seat display immediately
            if (mounted) {
              setState(() {});
              WidgetsBinding.instance.scheduleFrame();
            }
          } else if (state is ParticipantRemovedFromSeat) {
            debugPrint(
              'ðª [UI] Participant removed from seat - forcing UI refresh',
            );
            final updatedParticipants = _currentRoom.participants.map((p) {
              if (p.userId == state.participantId) {
                return p.copyWith(
                  clearSeatNumber: true,
                  isSeated: false,
                  isSpeaker: false,
                  isMuted: true,
                );
              }
              return p;
            }).toList();
            _currentRoom =
                _currentRoom.copyWith(participants: updatedParticipants);
            if (state.participantId == _currentUser.userId) {
              _isMuted = true;
            }
            // Force UI refresh to update seat display immediately
            if (mounted) {
              setState(() {});
              WidgetsBinding.instance.scheduleFrame();
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
              if (_isCurrentUserHost && _currentRoom.category == 'Live') {
                _showEndLiveConfirmationDialog();
              } else {
                // Pressing the back button/gesture automatically minimizes the room
                _handleMinimize();
              }
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

  /// Handle joining the room member club via the top bar + button
  Future<void> _handleJoinRoomClub() async {
    try {
      final DocumentReference roomRef = FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(_currentRoom.id);

      await roomRef.update({
        'joinedUserIds': FieldValue.arrayUnion([_currentUser.userId])
      });

      if (mounted) {
        setState(() {
          if (!_currentRoom.joinedUserIds.contains(_currentUser.userId)) {
            _currentRoom = _currentRoom.copyWith(
              joinedUserIds: [
                ..._currentRoom.joinedUserIds,
                _currentUser.userId
              ],
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ã°Å¸Å½â° You joined this room member club!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0288D1),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error joining room member club: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to join room: $e',
              style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Small circular blue '+' button to join room members
  Widget _buildJoinRoomClubButton() {
    return GestureDetector(
      onTap: _handleJoinRoomClub,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF29B6F6),
              Color(0xFF0288D1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0288D1).withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 13,
          ),
        ),
      ),
    );
  }

  /// Build custom header exactly like screenshot
  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==========================================
          // SERIAL 1 (Top Row): Room Info <---> Action Buttons
          // ==========================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Room Icon + Name + ID + Level Badge + Join '+' Button
              Expanded(
                child: _currentRoom.category == 'Live'
                    ? StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Users')
                            .doc(_currentRoom.creatorId)
                            .snapshots(),
                        builder: (context, userSnap) {
                          Map<String, dynamic>? userData;
                          if (userSnap.hasData &&
                              userSnap.data?.exists == true) {
                            userData = userSnap.data!.data()
                                as Map<String, dynamic>?;
                          }
                          final String hostSearchId =
                              (userData?['searchId'] ?? '').toString().trim();
                          final String hostAvatar =
                              (userData?['photoUrl'] ?? '').toString().trim();
                          final String hostName =
                              (userData?['fullname'] ?? '').toString().trim();
                          final String displayId = hostSearchId.isNotEmpty
                              ? hostSearchId
                              : _currentRoom.creatorId;
                          final String avatarUrl = hostAvatar.isNotEmpty
                              ? hostAvatar
                              : (_currentRoom.imageUrl ?? '');

                          return GestureDetector(
                            onTap: () {
                              AudioRoomParticipant? hostParticipant;
                              for (final p in _currentRoom.participants) {
                                if (p.userId == _currentRoom.creatorId) {
                                  hostParticipant = p;
                                  break;
                                }
                              }
                              if (hostParticipant == null) {
                                hostParticipant = AudioRoomParticipant(
                                  userId: _currentRoom.creatorId,
                                  userName: hostName.isNotEmpty
                                      ? hostName
                                      : _currentRoom.creatorName,
                                  userImageUrl: avatarUrl.isNotEmpty
                                      ? avatarUrl
                                      : (_currentRoom.creatorImageUrl ??
                                          _currentRoom.imageUrl),
                                  joinedAt: DateTime.now(),
                                  isHost: true,
                                  isSpeaker: true,
                                  isSeated: true,
                                  seatNumber: 1,
                                );
                              }
                              _showParticipantBottomSheet(hostParticipant);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                // Room / Host Avatar
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: avatarUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(avatarUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color:
                                        avatarUrl.isEmpty ? Colors.red : null,
                                  ),
                                  child: avatarUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),

                                // Room Title and ID
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currentRoom.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          UserIdBadgeWidget(
                                            searchId: displayId,
                                            badgeHeight: 18,
                                            showCopyIcon: false,
                                          ),
                                          const SizedBox(width: 4),
                                          _getDynamicRoomLevelBadgeUrl() != null
                                              ? CachedNetworkImage(
                                                  imageUrl:
                                                      _getDynamicRoomLevelBadgeUrl()!,
                                                  width: 36,
                                                  height: 20,
                                                  fit: BoxFit.contain,
                                                )
                                              : Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.blue.withValues(
                                                      alpha: 0.6,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                    border: Border.all(
                                                      color: Colors.white24,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Lv.${AudioRoomV2.calculateRoomLevel(_currentRoom.totalRevenue, _roomLevelConfigData)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Inter',
                                                    ),
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
                        },
                      )
                    : GestureDetector(
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
                          children: [
                            // Room Avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: _currentRoom.imageUrl != null &&
                                        _currentRoom.imageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            _currentRoom.imageUrl!),
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
                                      size: 20,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),

                            // Room Title and ID
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentRoom.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('premium_room_ids')
                                              .doc(_currentRoom.id)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData &&
                                                snapshot.data!.exists &&
                                                snapshot.data!.data() != null) {
                                              final model =
                                                  PremiumRoomIdModel.fromMap(
                                                snapshot.data!.data()
                                                    as Map<String, dynamic>,
                                                snapshot.data!.id,
                                              );
                                              if (!model.isExpired &&
                                                  model.customId.isNotEmpty) {
                                                return AnimatedPremiumId(
                                                  idStr: model.customId,
                                                );
                                              }
                                            }

                                            return Text(
                                              'ID: ${_currentRoom.id.length > 8 ? _currentRoom.id.substring(0, 8) : _currentRoom.id}',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontSize: 10,
                                                fontFamily: 'Inter',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _getDynamicRoomLevelBadgeUrl() != null
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  _getDynamicRoomLevelBadgeUrl()!,
                                              width: 36,
                                              height: 20,
                                              fit: BoxFit.contain,
                                            )
                                          : Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  4,
                                                ),
                                                border: Border.all(
                                                  color: Colors.white24,
                                                  width: 0.5,
                                                ),
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

                                      // Plus button if user is not in joined members
                                      StreamBuilder<DocumentSnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('audio_rooms_v2')
                                            .doc(_currentRoom.id)
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          List<dynamic> joinedUserIds =
                                              _currentRoom.joinedUserIds;
                                          String creatorId =
                                              _currentRoom.creatorId;
                                          if (snapshot.hasData &&
                                              snapshot.data?.exists == true) {
                                            final data = snapshot.data!.data()
                                                as Map<String, dynamic>?;
                                            if (data != null) {
                                              joinedUserIds =
                                                  (data['joinedUserIds']
                                                          as List<dynamic>?) ??
                                                      joinedUserIds;
                                              creatorId = (data['creatorId']
                                                      as String?) ??
                                                  creatorId;
                                            }
                                          }

                                          final bool isMember = joinedUserIds
                                                  .contains(
                                                      _currentUser.userId) ||
                                              creatorId == _currentUser.userId;

                                          if (isMember) {
                                            return const SizedBox.shrink();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                left: 4.0),
                                            child: _buildJoinRoomClubButton(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(width: 8),

              // Right: Action Buttons (..., flip, share, close)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCurrentUserHostOrAdmin) ...[
                    GestureDetector(
                      onTap: _showVoiceRoomCustomize,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  GestureDetector(
                    onTap: (_currentRoom.isGroupRoom || _currentRoom.isPrivate)
                        ? () {
                            Get.snackbar(
                              'Private Room',
                              'Private Group Room: Only group members can join.',
                              backgroundColor: Colors.black87,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        : _showShareBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child:
                          (_currentRoom.isGroupRoom || _currentRoom.isPrivate)
                              ? const Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Transform.scale(
                                  scaleX: -1,
                                  child: const Icon(
                                    Icons.reply_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _handleLeaveRoom,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ==========================================
          // SERIAL 2 (Bottom Row): Revenue Badge <---> Online Users & Grab the Top
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Revenue / Ranking Badge
              GestureDetector(
                onTap: _showRankingList,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF9C27B0),
                        Color(0xFFBA68C8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRevenue(_currentRoom.totalRevenue),
                        style: const TextStyle(
                          color: Color(0xFFFFE0B2),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 3),
                      const DynamicDiamondIcon(
                        width: 12,
                        height: 12,
                      ),
                    ],
                  ),
                ),
              ),

              // Right: Online Users Badge + Grab the Top Pill (side-by-side)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Online Users Widget (Matches screenshot: overlapping avatars + crown + count badge + arrow)
                    _buildOnlineMembersHeader(),

                    const SizedBox(width: 4),

                    // Grab the Top Header Pill
                    Flexible(
                      child: TopExposureHeaderPill(
                        currentRoomId: _currentRoom.id,
                        audioRoomsBloc: widget.audioRoomsBloc,
                        onGrabTheTopTap: () {
                          final hostParticipant =
                              _currentRoom.participants.firstWhere(
                            (p) => p.userId == _currentRoom.creatorId,
                            orElse: () => AudioRoomParticipant(
                              userId: _currentRoom.creatorId,
                              userName: _currentRoom.creatorName,
                              userImageUrl: _currentRoom.creatorImageUrl,
                              isHost: true,
                              joinedAt: DateTime.now(),
                            ),
                          );
                          _showGiftSelection(hostParticipant);
                        },
                      ),
                    ),
                  ],
                ),
              ),
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

  /// Build Online Members Header Widget (overlapping avatars + count badge + arrow)
  /// Sorted identically to the Online Rank modal (top 24h contributor first, host priority, etc.)
  Widget _buildOnlineMembersHeader() {
    final count = _currentRoom.participantCount;
    const double overlapStep = 18.0;
    const double avatarSize = 26.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showViewersList,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_received_gifts')
            .where('roomId', isEqualTo: _currentRoom.id)
            .snapshots(),
        builder: (context, giftSnapshot) {
          final Map<String, List<GiftTransaction>> transactionsBySender = {};

          if (giftSnapshot.hasData && giftSnapshot.data != null) {
            for (final doc in giftSnapshot.data!.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final tx = GiftTransaction.fromJson({
                  ...data,
                  'id': doc.id,
                });
                transactionsBySender.putIfAbsent(tx.senderId, () => []).add(tx);
              } catch (_) {}
            }
          }

          final now = DateTime.now();
          final last24h = now.subtract(const Duration(hours: 24));

          int sumCredits(List<GiftTransaction> txs, DateTime? since) {
            int total = 0;
            for (final tx in txs) {
              if (since == null || tx.timestamp.isAfter(since)) {
                total += tx.credits;
              }
            }
            return total;
          }

          final List<AudioRoomParticipant> sortedOnlineUsers = List.from(
            _currentRoom.participants,
          );

          sortedOnlineUsers.sort((a, b) {
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

          final displayParticipants = sortedOnlineUsers.take(3).toList();
          final int avatarCount =
              displayParticipants.isEmpty ? 1 : displayParticipants.length;
          final double stackWidth = (avatarCount * overlapStep) + avatarSize;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: stackWidth,
                height: avatarSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (displayParticipants.isNotEmpty)
                      ...List.generate(displayParticipants.length, (index) {
                        final participant = displayParticipants[index];

                        return Positioned(
                          left: index * overlapStep,
                          top: 0,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: participant.userImageUrl ?? '',
                                width: avatarSize,
                                height: avatarSize,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.white24,
                                  child: const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white24,
                                  child: const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                    else
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white12,
                            border: Border.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                    // Purple count circle badge
                    Positioned(
                      left: avatarCount * overlapStep,
                      top: 0,
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF38265E),
                          border: Border.all(
                            color:
                                const Color(0xFF675296).withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build main body with optimized background loading
  Widget _buildBody() {
    return Stack(
      children: [
        // Background with loading state
        RepaintBoundary(
          child: _buildBackgroundWithLoading(),
        ),
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
                  colors: _currentRoom.category == 'Live'
                      ? const [
                          Colors.transparent,
                          Colors.transparent,
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Custom header
                    RepaintBoundary(
                      child: _buildCustomHeader(),
                    ),

                    // Live Room Video PK Split Screen
                    if (_currentRoom.category == 'Live' &&
                        _activeVideoBattle != null &&
                        (_activeVideoBattle!.isActive ||
                            _activeVideoBattle!.isPunishment))
                      _buildVideoPkSection(),

                    if (_currentRoom.isLudoActive)
                      LudoGameWidget(
                        room: _currentRoom,
                        isHost: _isCurrentUserHostOrAdmin ||
                            (_currentParticipant?.seatNumber == 1),
                        repository: AudioRoomsRepository(),
                        currentUserId: _currentUser.userId,
                      )
                    else if (_currentRoom.isCarromActive)
                      CarromGameWidget(
                        room: _currentRoom,
                        isHost: _isCurrentUserHostOrAdmin ||
                            (_currentParticipant?.seatNumber == 1),
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

                    // PK Battle Overlay (Voice / Audio rooms only)
                    if (_currentRoom.category != 'Live')
                      PKBattleOverlay(
                        room: _currentRoom,
                        currentUserId: _currentUser.userId,
                        onSeatTap: (seatNumber) => _moveToSeat(seatNumber),
                      ),

                    if (_currentRoom.activeYoutubeVideoId == null &&
                        !_currentRoom.isLudoActive &&
                        !_currentRoom.isCarromActive &&
                        !(_currentRoom.category == 'Live' &&
                            _activeVideoBattle != null &&
                            (_activeVideoBattle!.isActive ||
                                _activeVideoBattle!.isPunishment)))
                      const SizedBox(height: 20),

                    // Participants grid (without chat)
                    Expanded(
                      child: _currentRoom.category == 'Live'
                          ? (_activeVideoBattle != null &&
                                  (_activeVideoBattle!.isActive ||
                                      _activeVideoBattle!.isPunishment)
                              ? const SizedBox.shrink()
                              : (_currentRoom.settings.isLiveMultipleMode
                                  ? _buildLiveMultipleModeGrid()
                                  : const SizedBox.expand()))
                          : _buildParticipantsGrid(),
                    ),

                    const SizedBox(height: 80), // Space for controls
                  ],
                ),
              ),
            ),
          ),
        ), // Closes Positioned.fill
        // Video Room Floating Circular Guest Seats (Right side, matching Khan_Live)
        if (_currentRoom.category == 'Live') _buildLiveCircularGuestSeats(),

        // Floating Music Player
        if (_showMusicPlayer && _isCurrentUserHostOrAdmin) ...[
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
                padding: EdgeInsets.only(
                  bottom: bottomInset > 0 ? bottomInset : 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: RoomControls(
                        key: _roomControlsKey,
                        isMuted: _isCurrentUserMuted,
                        isMutedByAdmin:
                            _currentParticipant?.isMutedByAdmin ?? false,
                        isSpeakerOn: _isSpeakerOn,
                        isHost: _isCurrentUserHost,
                        isSpeaker: _isCurrentUserSpeaker,
                        isSeated: _isCurrentUserHost ||
                            _isCurrentUserSpeaker ||
                            (_currentParticipant?.isSeated ?? false) ||
                            (_currentParticipant?.seatNumber != null),
                        onMuteToggle: _handleMuteToggle,
                        onGrabTopSeat: _grabTopSeat,
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
                        creatorId: _currentRoom.creatorId,
                        adminIds: _currentRoom.settings.adminIds,
                        onMessageTap: _handleMessageTap,
                        isLive: _currentRoom.category == 'Live',
                        hasRequestedToJoin: _currentRoom.joinRequests.contains(
                          _currentUser.userId,
                        ),
                        joinRequestsCount: _currentRoom.joinRequests.length,
                        onLiveMicTapped: _showManageGuestsSheet,
                        onJoinRequestTapped: _handleCallJoinRequest,
                        isGameActive: _currentRoom.isCarromActive ||
                            _currentRoom.isLudoActive ||
                            _currentRoom.activeYoutubeVideoId != null,
                        isPKActive: _currentRoom.pkBattleState.isActive,
                        isProMode: _currentRoom.settings.roomLayoutType == 'pro',
                        selectedChatTab: _selectedProChatTab,
                        announcement: _currentRoom.settings.announcement,
                        onEditAnnouncement: _showAnnouncementDialog,
                        onOpenVideoRoomSettings: _showVideoRoomSettingsSheet,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Room Event Portal Banners (Carousel)
        Positioned(
          right: 12,
          bottom: 100,
          child: Builder(
            builder: (ctx) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: const RoomEventPortalWidget(),
              );
            },
          ),
        ),

        // Voting Overlay
        VotingWidget(
          room: _currentRoom,
          currentUserId: _currentUser.userId,
          isHost: _isCurrentUserHost,
        ),

        // Floating Active Lucky Bag Overlay Widget
        LuckyBagFloatingWidget(
          roomId: _currentRoom.id,
          currentUserId: _currentUser.userId,
          currentUserName: _currentUser.fullname,
          currentUserAvatar: _currentUser.photoUrl,
        ),

        // Lucky Gift Winner Banner & Coin Shower Particle Animation Overlay
        if (_showCoinShower)
          CoinShowerWidget(
            onCompleted: () {
              if (mounted) {
                setState(() {
                  _showCoinShower = false;
                });
              }
            },
          ),

        // Center Floating Top Exposure Banner Overlay
        Positioned(
          top: MediaQuery.of(context).size.height * 0.28,
          left: 0,
          right: 0,
          child: TopExposureCenterBanner(
            currentRoomId: _currentRoom.id,
            audioRoomsBloc: widget.audioRoomsBloc,
          ),
        ),

        // Top Global Broadcast Banner for Lucky Bags across all rooms
        Positioned(
          top: 45,
          left: 0,
          right: 0,
          child: LuckyBagGlobalBanner(
            currentRoomId: _currentRoom.id,
            audioRoomsBloc: widget.audioRoomsBloc,
          ),
        ),

        if (_currentLuckyWin != null)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: LuckyWinBanner(
              senderName: _currentLuckyWin!['senderName'] ?? 'Lucky Winner',
              senderAvatar: _currentLuckyWin!['senderAvatar'],
              giftName: _currentLuckyWin!['giftName'] ?? 'Gift',
              multiplier: _currentLuckyWin!['multiplier'] ?? 2,
              wonDiamonds: _currentLuckyWin!['wonDiamonds'] ?? 0,
              onDismiss: () {
                if (mounted) {
                  setState(() {
                    _currentLuckyWin = null;
                  });
                }
              },
            ),
          ),

        // Roulette Overlay
        RouletteWidget(
          controller: Get.isRegistered<RouletteController>(
            tag: 'roulette_${widget.room.id}',
          )
              ? Get.find<RouletteController>(tag: 'roulette_${widget.room.id}')
              : Get.put(
                  RouletteController(
                    widget.room.id,
                    isHost: _isCurrentUserHostOrAdmin,
                  ),
                  tag: 'roulette_${widget.room.id}',
                ),
        ),

        // Floating Music Player
        if (_showMusicPlayer)
          FloatingMusicPlayer(
            roomId: widget.room.id,
            isHost: _isCurrentUserHostOrAdmin,
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
                  'Ã¢ÂÅ [AudioRoom] Gift transactions stream error: ${snapshot.error}');
              return const SizedBox.shrink();
            }

            final allTransactions = snapshot.data ?? [];
            final now = DateTime.now();
            final recentTransactions = allTransactions.where((transaction) {
              final timeDiff = now.difference(transaction.timestamp).inSeconds;
              return timeDiff.abs() <= 60;
            }).toList();

            return Positioned.fill(
              child: GiftAnimationOverlay(
                transactions: recentTransactions,
                onTransactionFinished: (completedTx) {
                  debugPrint(
                      'Ã°Å¸Å½Â [AudioRoom] Gift animation completed for tx: ${completedTx.id}');
                },
                onGiftFlightTriggered: _triggerGiftFlightAnimation,
              ),
            );
          },
        ),

        // Floating Gift Combo Button at bottom-right corner
        Positioned(
          right: 16,
          bottom: 85,
          child: const GiftComboButton(),
        ),

        // Entrance effect animation overlay
        StreamBuilder<List<EntranceEffect>>(
          stream: _entranceEffectService.getEntranceEffects(widget.room.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint(
                'Ã¢ÂÅ [AudioRoom] Entrance effects stream error: ${snapshot.error}',
              );
              return const SizedBox.shrink();
            }

            if (!snapshot.hasData) {
              debugPrint(
                  'Ã°Å¸Å½Â¬ [AudioRoom] StreamBuilder: No entrance data yet');
              return const SizedBox.shrink();
            }

            final allEffects = snapshot.data!;
            // Filter only recent effects (last 30 seconds to account for network delays)
            final now = DateTime.now();
            final recentEffects = allEffects.where((effect) {
              final timeDiff = now.difference(effect.timestamp).inSeconds;
              debugPrint('Ã°Å¸Å½Â¬ [EntranceDebug] Effect: ${effect.userName}');
              debugPrint(
                  'Ã°Å¸Å½Â¬ [EntranceDebug] Time diff: $timeDiff seconds');
              return timeDiff.abs() <= 30; // Increased from 10 to 30 seconds
            }).toList();

            debugPrint(
              'Ã°Å¸Å½Â¬ [AudioRoom] Filtered to ${recentEffects.length} recent entrance effects',
            );

            if (recentEffects.isEmpty) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: EntranceEffectOverlay(
                effects: recentEffects,
                onAnimationComplete: () {
                  debugPrint(
                      'Ã°Å¸Å½Â¬ [AudioRoom] Entrance animation completed');
                  // Auto-delete the displayed entrance effects
                  _deleteDisplayedEntranceEffects(recentEffects);
                },
              ),
            );
          },
        ),

        // Flying PNG gifts layer
        _buildFlyingGiftsLayer(),

        // Live Room Video PK Animation Overlay (Countdown, Opening, Winner)
        if (_currentRoom.category == 'Live' &&
            _videoAnimationPhase != VideoPkAnimationPhase.none)
          Positioned.fill(
            child: VideoPkAnimationOverlay(
              phase: _videoAnimationPhase,
              winnerName: _activeVideoBattle?.winnerId == _activeVideoBattle?.host1Id
                  ? _activeVideoBattle?.host1Name
                  : _activeVideoBattle?.host2Name,
              winnerPhotoUrl: _activeVideoBattle?.winnerId == _activeVideoBattle?.host1Id
                  ? _activeVideoBattle?.host1Photo
                  : _activeVideoBattle?.host2Photo,
              onCountdownComplete: () {
                _triggerVideoPkPhase(VideoPkAnimationPhase.opening);
              },
              onOpeningComplete: () {
                _triggerVideoPkPhase(VideoPkAnimationPhase.none);
              },
              onWinnerComplete: () {
                _triggerVideoPkPhase(VideoPkAnimationPhase.none);
              },
            ),
          ),
      ],
    );
  }

  /// Build flying PNG gifts layer
  Widget _buildFlyingGiftsLayer() {
    return ValueListenableBuilder<List<FlyingGiftItem>>(
      valueListenable: _flyingGiftsNotifier,
      builder: (context, flyingGifts, _) {
        return Stack(
          children: flyingGifts.map((item) {
            return FlyingGiftWidget(
              key: ValueKey(item.id),
              pngUrl: item.pngUrl,
              startOffset: item.startOffset,
              endOffset: item.endOffset,
              onComplete: () {
                _flyingGiftsNotifier.value = _flyingGiftsNotifier.value
                    .where((g) => g.id != item.id)
                    .toList();
              },
            );
          }).toList(),
        );
      },
    );
  }

  /// Trigger the flight path animation for a PNG gift thumbnail
  void _triggerGiftFlightAnimation(
    GiftTransaction transaction,
    List<String> receiverIds,
  ) {
    if (transaction.giftPngUrl.isEmpty) return;

    final screenSize = MediaQuery.of(context).size;
    Offset startOffset = Offset(screenSize.width / 2, screenSize.height - 100);

    try {
      final senderSeatNumber = _findUserSeatNumber(transaction.senderId);
      if (senderSeatNumber != null && _seatKeys.containsKey(senderSeatNumber)) {
        final key = _seatKeys[senderSeatNumber];
        final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          final seatPosition = renderBox.localToGlobal(Offset.zero);
          final seatSize = renderBox.size;
          startOffset = Offset(
            seatPosition.dx + seatSize.width / 2,
            seatPosition.dy + seatSize.height / 2,
          );
        }
      }
    } catch (_) {}

    final List<FlyingGiftItem> newFlights = [];

    for (final receiverId in receiverIds) {
      final seatNumber = _findUserSeatNumber(receiverId);
      late Offset endOffset;

      try {
        if (seatNumber != null && _seatKeys.containsKey(seatNumber)) {
          final key = _seatKeys[seatNumber];
          final renderBox =
              key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize && renderBox.attached) {
            final seatPosition = renderBox.localToGlobal(Offset.zero);
            final seatSize = renderBox.size;
            endOffset = Offset(
              seatPosition.dx + seatSize.width / 2,
              seatPosition.dy + seatSize.height / 2,
            );
          } else {
            endOffset = Offset(screenSize.width / 2, screenSize.height * 0.7);
          }
        } else if (_seatKeys.containsKey(1)) {
          final key = _seatKeys[1];
          final renderBox =
              key?.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize && renderBox.attached) {
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
      } catch (_) {
        endOffset = Offset(screenSize.width / 2, screenSize.height * 0.5);
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

    if (newFlights.isNotEmpty) {
      _flyingGiftsNotifier.value = [
        ..._flyingGiftsNotifier.value,
        ...newFlights,
      ];
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
                      _generateUid(occupant!.userId),
                      AgoraService().engine!,
                    ),
                  ),
                )
              else
                const SizedBox.expand(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),

              // User name at bottom
              Positioned(
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
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
        _currentRoom.isLudoActive ||
        _currentRoom.isCarromActive) {
      return _buildYoutubeSeatsLayout();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numbered seats grid (exactly like screenshot)
        _buildNumberedSeatsGrid(),

        // Show All / Chat / Gifts filter tabs fixed right under seats
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildProModeFilterTabs(),
        ),

        const SizedBox(height: 6),
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
      child: Column(children: _buildDynamicSeatRows(seatCount)),
    );
  }

  String? _getIdFromRef(dynamic ref) {
    if (ref == null) return null;
    if (ref is DocumentReference) {
      return ref.id;
    }
    final refStr = ref.toString();
    if (refStr.contains('/')) {
      return refStr.split('/').last;
    }
    return refStr;
  }

  Map<String, dynamic>? _getRelationshipBetweenSeats(int seatA, int seatB) {
    AudioRoomParticipant? occupantA;
    AudioRoomParticipant? occupantB;
    for (var p in _currentRoom.participants) {
      if (p.seatNumber == seatA) occupantA = p;
      if (p.seatNumber == seatB) occupantB = p;
    }
    if (occupantA == null || occupantB == null) return null;
    final uidA = occupantA.userId;
    final uidB = occupantB.userId;
    for (var rel in _activeRoomRelationships) {
      final r1Id = _getIdFromRef(rel['user1Ref']);
      final r2Id = _getIdFromRef(rel['user2Ref']);
      if (r1Id == null || r2Id == null) continue;

      if ((r1Id == uidA && r2Id == uidB) || (r1Id == uidB && r2Id == uidA)) {
        return rel;
      }
    }
    return null;
  }

  Widget _buildSeatConnectorBadge(Map<String, dynamic> rel) {
    final type = rel['relationshipType']?.toString().toLowerCase() ?? 'friend';
    final rawLevel = rel['currentLevel'];
    int level = 1;
    if (rawLevel is int) {
      level = rawLevel;
    } else if (rawLevel is String) {
      level = int.tryParse(rawLevel) ?? 1;
    } else if (rawLevel is num) {
      level = rawLevel.toInt();
    }
    final isCouple = type == 'couple';

    final String? customImageUrl =
        isCouple ? _coupleLevelImages[level] : _friendshipLevelImages[level];

    if (customImageUrl != null && customImageUrl.isNotEmpty) {
      if (customImageUrl.toLowerCase().contains('.svga')) {
        return SizedBox(
          width: 32,
          height: 32,
          child: SVGAEasyPlayer(resUrl: customImageUrl),
        );
      }

      return CachedNetworkImage(
        imageUrl: customImageUrl,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        placeholder: (context, url) => const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.2,
            color: Colors.purpleAccent,
          ),
        ),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRowWithConnectors(
    List<int> seatNumbers, {
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    List<Widget> children = [];
    for (int i = 0; i < seatNumbers.length; i++) {
      final seatNumber = seatNumbers[i];
      final isAdmin = _isSeatOccupiedByHost(seatNumber);

      Map<String, dynamic>? rightRelationship;
      if (i < seatNumbers.length - 1) {
        final nextSeat = seatNumbers[i + 1];
        rightRelationship = _getRelationshipBetweenSeats(seatNumber, nextSeat);
      }

      children.add(
        Flexible(
          child: _buildNumberedSeat(
            seatNumber,
            isAdmin: isAdmin,
            rightRelationship: rightRelationship,
          ),
        ),
      );
    }
    return Row(mainAxisAlignment: alignment, children: children);
  }

  /// Build dynamic seat rows based on room mode
  List<Widget> _buildDynamicSeatRows(int totalSeats) {
    final roomMode = _currentRoom.settings.roomMode;
    if (roomMode == RoomMode.lite) {
      return _buildLiteLayout();
    } else if (roomMode == RoomMode.party) {
      return _buildPartyLayout();
    }

    List<Widget> rows = [];
    int currentSeat = 1;
    const int seatsPerRow = 5;

    while (currentSeat <= totalSeats) {
      List<int> seatsInRow = [];
      for (int i = 0; i < seatsPerRow && currentSeat <= totalSeats; i++) {
        seatsInRow.add(currentSeat);
        currentSeat++;
      }
      rows.add(_buildRowWithConnectors(seatsInRow));
      if (currentSeat <= totalSeats) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return rows;
  }

  /// Build Lite layout (9 seats - 1 host top centered, 4+4 grid below)
  List<Widget> _buildLiteLayout() {
    return [
      _buildRowWithConnectors([1], alignment: MainAxisAlignment.center),
      const SizedBox(height: 12),
      _buildRowWithConnectors([2, 3, 4, 5]),
      const SizedBox(height: 12),
      _buildRowWithConnectors([6, 7, 8, 9]),
    ];
  }

  /// Build Party layout (12 seats - 2 at top, then rest below)
  List<Widget> _buildPartyLayout() {
    return [
      _buildRowWithConnectors([1, 2], alignment: MainAxisAlignment.center),
      const SizedBox(height: 12),
      _buildRowWithConnectors([3, 4, 5, 6, 7]),
      const SizedBox(height: 12),
      _buildRowWithConnectors([8, 9, 10, 11, 12]),
    ];
  }

  /// Fallback seat decoration widget when custom PNG asset is missing
  Widget _buildSeatFallbackWidget(double dimension, SeatColorMode mode) {
    Color borderColor;
    Color bgColor;
    if (mode == SeatColorMode.purple || mode == SeatColorMode.dashedPink) {
      borderColor = Colors.purpleAccent;
      bgColor = Colors.purple.withValues(alpha: 0.1);
    } else if (mode == SeatColorMode.golden) {
      borderColor = Colors.amber;
      bgColor = Colors.amber.withValues(alpha: 0.1);
    } else if (mode == SeatColorMode.dashedOrange) {
      borderColor = Colors.orangeAccent;
      bgColor = Colors.orange.withValues(alpha: 0.1);
    } else {
      borderColor = Colors.blueAccent;
      bgColor = Colors.blue.withValues(alpha: 0.1);
    }

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
    );
  }

  /// Helper to parse hex color strings for seat animations
  Color _parseHexColor(String hexString) {
    try {
      final hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF00FFE0);
  }

  /// Build individual numbered seat
  Widget _buildNumberedSeat(
    int seatNumber, {
    bool isAdmin = false,
    Map<String, dynamic>? rightRelationship,
  }) {
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

    final String? seatSpecificDecorUrl = (seatNumber == 1 &&
            _currentRoom.settings.hostSeatDecorUrl != null &&
            _currentRoom.settings.hostSeatDecorUrl!.trim().isNotEmpty)
        ? _currentRoom.settings.hostSeatDecorUrl
        : (isLocked &&
                !isOccupied &&
                _currentRoom.settings.lockedSeatDecorUrl != null &&
                _currentRoom.settings.lockedSeatDecorUrl!.trim().isNotEmpty)
            ? _currentRoom.settings.lockedSeatDecorUrl
            : (_currentRoom.settings.seatDecorUrl != null &&
                    _currentRoom.settings.seatDecorUrl!.trim().isNotEmpty)
                ? _currentRoom.settings.seatDecorUrl
                : (seatNumber == 1 &&
                        _currentRoom.settings.seatDecorUrl != null &&
                        _currentRoom.settings.seatDecorUrl!.trim().isNotEmpty)
                    ? _currentRoom.settings.seatDecorUrl
                    : null;

    final bool hasCustomSeatDecor =
        seatSpecificDecorUrl != null && seatSpecificDecorUrl.trim().isNotEmpty;
    final bool isGoldenMode =
        _currentRoom.settings.seatColorMode == SeatColorMode.golden;
    final bool isPurpleMode =
        _currentRoom.settings.seatColorMode == SeatColorMode.purple;
    final bool isCyberEmeraldMode =
        _currentRoom.settings.seatColorMode == SeatColorMode.cyberEmerald;
    final bool isDashedPink =
        _currentRoom.settings.seatColorMode == SeatColorMode.dashedPink;
    final bool isDashedOrange =
        _currentRoom.settings.seatColorMode == SeatColorMode.dashedOrange;

    final bool isSeatAnimated = _currentRoom.settings.isSeatAnimated;
    final String animationType =
        _currentRoom.settings.seatAnimationType ?? 'beamSweep';
    final double animationSpeed = _currentRoom.settings.seatAnimationSpeed;
    final Color animationColor =
        _parseHexColor(_currentRoom.settings.seatAnimationColor ?? '#FFD700');

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

    final bool isOccupantMuted = (occupant == null)
        ? false
        : (occupant.userId == _currentUser.userId
            ? _isCurrentUserMuted
            : (occupant.isMutedByAdmin || occupant.isMuted));

    return RepaintBoundary(
      child: GestureDetector(
        key: seatKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleSeatTap(seatNumber, occupant),
        onLongPress: () => _handleSeatLongPress(seatNumber, occupant),
        child: SizedBox(
          width: size + 30,
          child: Column(
            children: [
              // Seat circle
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Background Seat Decor with Dynamic Real-Time Animation
                    AnimatedSeatDecorWidget(
                      size: size + 8,
                      isAnimated: isSeatAnimated,
                      animationType: animationType,
                      animationSpeed: animationSpeed,
                      glowColor: animationColor,
                      child: hasCustomSeatDecor
                          ? CachedNetworkImage(
                              imageUrl: seatSpecificDecorUrl,
                              width: size + 8,
                              height: size + 8,
                              fit: BoxFit.contain,
                              placeholder: (context, url) =>
                                  _buildSeatFallbackWidget(
                                size + 8,
                                _currentRoom.settings.seatColorMode,
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildSeatFallbackWidget(
                                size + 8,
                                _currentRoom.settings.seatColorMode,
                              ),
                            )
                          : (!isOccupied
                              ? (isPurpleMode
                                  ? NeonPurpleGlassOrbWidget(
                                      size: size + 6,
                                      isLocked: isLocked,
                                    )
                                  : (isGoldenMode
                                      ? GoldenGlassOrbWidget(
                                          size: size + 6,
                                          isLocked: isLocked,
                                        )
                                      : (isCyberEmeraldMode
                                          ? CyberEmeraldDiamondOrbWidget(
                                              size: size + 6,
                                              isLocked: isLocked,
                                            )
                                          : (isDashedPink || isDashedOrange
                                              ? Container(
                                                  width: size,
                                                  height: size,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: (isDashedPink
                                                            ? Colors.pink
                                                            : Colors.orange)
                                                        .withValues(
                                                            alpha: 0.05),
                                                    border: Border.all(
                                                      color: isDashedPink
                                                          ? Colors.pink
                                                          : Colors.orange,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: size + 4,
                                                  height: size + 4,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.16),
                                                    border: Border.all(
                                                      color: isLocked
                                                          ? Colors.white
                                                              .withValues(
                                                                  alpha: 0.45)
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha: 0.35),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                )))))
                              : const SizedBox.shrink()),
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
                              key: ValueKey(
                                  'speaking_ripple_${occupant.userId}_$seatNumber'),
                              isSpeaking: !isOccupantMuted,
                              volumeNotifier:
                                  _getVolumeNotifier(occupant.userId),
                              minRadius: size / 2,
                              rippleColor: const Color(0xFF00FF7F)
                                  .withValues(alpha: 0.8),
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
                            ValueListenableBuilder<double>(
                              valueListenable:
                                  _getVolumeNotifier(occupant.userId),
                              builder: (context, currentVol, _) {
                                final bool showMuted =
                                    isOccupantMuted && currentVol <= 0.02;
                                if (!showMuted) return const SizedBox.shrink();
                                return Positioned(
                                  bottom: -4,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        200,
                                        223,
                                        10,
                                        235,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mic_off,
                                      color: Colors.white,
                                      size: 7,
                                    ),
                                  ),
                                );
                              },
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
                                        child: (occupant!.activeEmojiUrl!
                                                    .startsWith(
                                                        'local_dice:') ||
                                                occupant.activeEmojiUrl ==
                                                    'local_dice_action')
                                            ? SpinningDiceWidget(
                                                targetNumber: occupant
                                                        .activeEmojiUrl!
                                                        .contains(':')
                                                    ? (int.tryParse(occupant
                                                            .activeEmojiUrl!
                                                            .split(':')[1]) ??
                                                        6)
                                                    : 6,
                                                size: size * 0.8,
                                                diceStyle: 'classic',
                                              )
                                            : (occupant.activeEmojiUrl!
                                                        .startsWith(
                                                            'local_blue_dice:') ||
                                                    occupant.activeEmojiUrl ==
                                                        'local_blue_dice_action')
                                                ? SpinningDiceWidget(
                                                    targetNumber: occupant
                                                            .activeEmojiUrl!
                                                            .contains(':')
                                                        ? (int.tryParse(occupant
                                                                .activeEmojiUrl!
                                                                .split(
                                                                    ':')[1]) ??
                                                            6)
                                                        : 6,
                                                    size: size * 0.8,
                                                    diceStyle: 'blue',
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: occupant
                                                        .activeEmojiUrl!,
                                                    width: size * 0.8,
                                                    height: size * 0.8,
                                                    fit: BoxFit.contain,
                                                    placeholder:
                                                        (context, url) =>
                                                            const SizedBox(),
                                                    errorWidget:
                                                        (context, url, error) {
                                                      return const Icon(
                                                        Icons.image,
                                                        color: Colors.amber,
                                                        size: 24,
                                                      );
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
                    else if (!isOccupied && !hasCustomSeatDecor)
                      if (isPurpleMode)
                        (isLocked
                            ? const GoldenLockIcon(
                                key: ValueKey('lock_purple'),
                                width: 26,
                                height: 29,
                                isNeonPurple: true)
                            : (seatNumber == 1
                                ? const GoldenHomeIcon(
                                    key: ValueKey('home_purple'),
                                    width: 28,
                                    height: 28,
                                    isNeonPurple: true)
                                : const GoldenSofaIcon(
                                    key: ValueKey('sofa_purple'),
                                    width: 30,
                                    height: 27,
                                    isNeonPurple: true)))
                      else if (isGoldenMode)
                        (isLocked
                            ? const GoldenLockIcon(
                                key: ValueKey('lock_golden'),
                                width: 26,
                                height: 29)
                            : (seatNumber == 1
                                ? const GoldenHomeIcon(
                                    key: ValueKey('home_golden'),
                                    width: 28,
                                    height: 28)
                                : const GoldenSofaIcon(
                                    key: ValueKey('sofa_golden'),
                                    width: 30,
                                    height: 27)))
                      else if (isCyberEmeraldMode)
                        (isLocked
                            ? const Icon(Icons.lock,
                                color: Color(0xFF00FFE0), size: 22)
                            : (seatNumber == 1
                                ? const Icon(Icons.home_rounded,
                                    color: Color(0xFF00FFE0), size: 24)
                                : Image.asset(
                                    'assets/icons/sofa_ic.webp',
                                    width: 28,
                                    height: 28,
                                    color: const Color(0xFF00FFE0),
                                  )))
                      else if (isDashedPink)
                        (isLocked
                            ? const Icon(Icons.lock,
                                color: Colors.pink, size: 20)
                            : const Icon(Icons.music_note,
                                color: Colors.pink, size: 28))
                      else if (isDashedOrange)
                        (isLocked
                            ? const Icon(Icons.lock,
                                color: Colors.orange, size: 20)
                            : Image.asset(
                                'assets/icons/sofa_ic.webp',
                                width: 28,
                                height: 28,
                                color: Colors.orange,
                              ))
                      else
                        // Classic frosted mode
                        (isLocked
                            ? Icon(
                                Icons.lock_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 26,
                              )
                            : (seatNumber == 1
                                ? Icon(
                                    Icons.home_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 28,
                                  )
                                : Icon(
                                    Icons.mic_rounded,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    size: 26,
                                  )))
                    else if (isLocked &&
                        hasCustomSeatDecor &&
                        (_currentRoom.settings.lockedSeatDecorUrl == null ||
                            _currentRoom.settings.lockedSeatDecorUrl!
                                .trim()
                                .isEmpty ||
                            _currentRoom.settings.lockedSeatDecorUrl ==
                                _currentRoom.settings.seatDecorUrl))
                      Container(
                        width: size + 8,
                        height: size + 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 20,
                        ),
                      ),
                    if (rightRelationship != null)
                      Positioned(
                        right: -27,
                        child: _buildSeatConnectorBadge(rightRelationship),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // User name or seat label
              if (isOccupied && occupant != null) ...[
                Builder(
                  builder: (context) {
                    final validOccupant = occupant;
                    if (validOccupant == null) return const SizedBox.shrink();

                    final bool isSeatOwner =
                        _currentRoom.creatorId.isNotEmpty &&
                            validOccupant.userId == _currentRoom.creatorId;
                    final bool isSeatAdmin = !isSeatOwner &&
                        ((_currentRoom.settings.adminIds.any((id) =>
                                id.toString() == validOccupant.userId)) ||
                            validOccupant.isHost);

                    return Container(
                      constraints: BoxConstraints(maxWidth: size + 30),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isSeatOwner) ...[
                            const Icon(
                              Icons.person,
                              color:
                                  Color(0xFFFFD700), // Gold icon for Room Owner
                              size: 13.0,
                            ),
                            const SizedBox(width: 2.0),
                          ] else if (isSeatAdmin) ...[
                            const Icon(
                              Icons.person,
                              color:
                                  Color(0xFF2196F3), // Blue icon for Room Admin
                              size: 13.0,
                            ),
                            const SizedBox(width: 2.0),
                          ],
                          Flexible(
                            child: AnimatedSvipName.fromUserId(
                              userId: validOccupant.userId,
                              defaultName: validOccupant.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_currentRoom.settings.roomLayoutType == 'pro')
                  _buildProSeatGiftBadge(
                      _getUserReceivedGiftDiamonds(occupant.userId)),
              ] else ...[
                Text(
                  (_currentRoom.settings.roomLayoutType == 'pro')
                      ? '$seatNumber'
                      : ((isGoldenMode || isPurpleMode || isCyberEmeraldMode)
                          ? (seatNumber == 1 ? 'Host' : 'No.$seatNumber')
                          : ((_currentRoom.settings.roomMode == RoomMode.lite ||
                                  _currentRoom.settings.roomMode.seatCount == 9)
                              ? (seatNumber == 1
                                  ? 'Owner'
                                  : 'No.${seatNumber - 1}')
                              : (seatNumber == 1 ? 'Host' : 'No.$seatNumber'))),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (_currentRoom.settings.roomLayoutType == 'pro')
                  _buildProSeatGiftBadge(0),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Removed _buildAdditionalRows - using _buildDynamicSeatRows instead

  /// Handle seat tap
  void _handleSeatTap(int seatNumber, AudioRoomParticipant? occupant) {
    try {
      // Check if seat is locked (allow host/admin to bypass)
      if (_currentRoom.isSeatLocked(seatNumber) && !_isCurrentUserHostOrAdmin) {
        _showLockedSeatMessage(seatNumber);
        return;
      }

      if (occupant == null) {
        // Tapping empty seat
        if (_isCurrentUserHostOrAdmin) {
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
      debugPrint('Ã°Å¸Âªâ Error handling seat tap: $e');
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
              final displayId = PremiumRoomService.instance.getDisplayId(
                _currentRoom.id,
              );
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
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
                              content: Text('ID copied to clipboard'),
                            ),
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
                      final tx = GiftTransaction.fromJson({
                        ...data,
                        'id': doc.id,
                      });
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
                final List<AudioRoomParticipant> onlineUsers = List.from(
                  _currentRoom.participants,
                );

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
                  final conA = sumCredits(
                    transactionsBySender[a] ?? [],
                    last7days,
                  );
                  final conB = sumCredits(
                    transactionsBySender[b] ?? [],
                    last7days,
                  );
                  return conB.compareTo(conA);
                });

                int weeklyRankCounter = 1;
                for (final userId in weeklyContributors) {
                  final cache = userProfileCache[userId] ?? {};
                  final con = sumCredits(
                    transactionsBySender[userId] ?? [],
                    last7days,
                  );
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
                  final con = sumCredits(
                    transactionsBySender[userId] ?? [],
                    null,
                  );
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
                        last7days,
                      );
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
                        null,
                      );
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                          horizontal: 24,
                          vertical: 12,
                        ),
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
                                    title: const Text(
                                      'Ranking Rules',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'Online Rank lists active users in the room by their 24h contribution.\n\n'
                                      'Weekly Rank lists all room contributors by their weekly contribution.\n\n'
                                      'Total Rank lists all room contributors by their lifetime contribution.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(
                                            color: Color(0xFF00BCD4),
                                          ),
                                        ),
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
                      Container(
                        color: const Color(0xFF1E1E1E),
                        child: SafeArea(
                          top: false,
                          child: _buildMyRankBanner(myRankItem),
                        ),
                      ),
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
                  bottom: BorderSide(color: Color(0xFF00BCD4), width: 2.0),
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
    int? sendingLevel,
    int? receivingLevel,
  ) async {
    final result = <String, String?>{'sending': null, 'receiving': null};

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
      debugPrint(
          'Ã¢ÂÅ Error loading level images in _AudioRoomScreenState: $e');
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
        List<String> selectedNameplateIds = [];
        if (customizationMap?['selectedNameplateIds'] != null) {
          selectedNameplateIds =
              (customizationMap!['selectedNameplateIds'] as List)
                  .whereType<String>()
                  .toList();
        } else if (customizationMap?['selectedNameplateId'] != null &&
            (customizationMap!['selectedNameplateId'] as String).isNotEmpty) {
          selectedNameplateIds = [
            customizationMap['selectedNameplateId'] as String,
          ];
        }

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
                        top: BorderSide(color: Colors.white10, width: 0.5),
                      )
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // 1. VIP / Store Nameplates FIRST (before user levels)
                              if (selectedNameplateIds.isNotEmpty) ...[
                                FutureBuilder<List<String>>(
                                  future: NameplateHelper.getNameplateUrls(
                                    selectedNameplateIds,
                                  ),
                                  builder: (context, snapshot) {
                                    final urls = snapshot.data ?? [];
                                    if (urls.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    // 5 per row
                                    final rows = <List<String>>[];
                                    for (int i = 0; i < urls.length; i += 5) {
                                      rows.add(
                                        urls.sublist(
                                          i,
                                          (i + 5).clamp(0, urls.length),
                                        ),
                                      );
                                    }
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: rows
                                          .map(
                                            (rowItems) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: rowItems
                                                    .map(
                                                      (url) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          right: 3,
                                                        ),
                                                        child: SizedBox(
                                                          height: 16,
                                                          child:
                                                              UniversalAssetWidget(
                                                            url: url,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                              // 2. Sending Level Badge
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
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Send Lv.$sendLvl',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 3. Receiving Level Badge
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
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEA4C89,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Recv Lv.$receiveLvl',
                                    style: const TextStyle(
                                      color: Color(0xFFEA4C89),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
      debugPrint('Ã°Å¸âÂ¬ Error handling message tap: $e');
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
      debugPrint('Ã°Å¸Âªâ Error handling seat long press: $e');
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
    int seatNumber,
    AudioRoomParticipant currentOccupant,
  ) {
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
      debugPrint(
          'Ã°Å¸Âªâ [UI] Admin confirming seat takeover for seat $seatNumber');

      // Find current seat of admin
      final currentParticipant = _currentParticipant;
      final currentSeat = (currentParticipant?.seatNumber != null &&
              currentParticipant!.seatNumber! > 0)
          ? currentParticipant.seatNumber!
          : -1;

      debugPrint(
        'Ã°Å¸Âªâ [UI] Admin moving from seat $currentSeat to seat $seatNumber (takeover)',
      );

      // Dispatch the move event
      widget.audioRoomsBloc.add(
        MoveParticipantToSeat(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          fromSeat: currentSeat,
          toSeat: seatNumber,
        ),
      );
    } catch (e) {
      debugPrint('Ã°Å¸Âªâ [UI] Error in admin seat takeover: $e');
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
      debugPrint('Ã°Å¸Âªâ [UI] Attempting to move to seat $seatNumber');
      debugPrint(
        'Ã°Å¸Âªâ [UI] Seat locked: ${_currentRoom.isSeatLocked(seatNumber)}',
      );
      debugPrint(
        'Ã°Å¸Âªâ [UI] Seat occupied: ${_currentRoom.isSeatOccupied(seatNumber)}',
      );
      debugPrint(
        'Ã°Å¸Âªâ [UI] Can user move: ${_currentRoom.canUserMoveToSeat(_currentUser.userId, seatNumber)}',
      );

      if (!_currentRoom.canUserMoveToSeat(_currentUser.userId, seatNumber)) {
        final bool isUserCreatorOrAdmin =
            _currentRoom.isCreator(_currentUser.userId) ||
                _currentRoom.settings.adminIds.contains(_currentUser.userId);
        if (seatNumber == 1 && !isUserCreatorOrAdmin) {
          debugPrint('Ã°Å¸Âªâ [UI] Seat 1 is reserved for Host/Admin only');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Seat 1 is reserved for Room Host and Admins only.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (_currentRoom.isSeatLocked(seatNumber)) {
          debugPrint(
            'Ã°Å¸Âªâ [UI] Seat $seatNumber is locked - showing lock message',
          );
          _showLockedSeatMessage(seatNumber);
        } else if (_currentRoom.isSeatOccupied(seatNumber)) {
          debugPrint(
            'Ã°Å¸Âªâ [UI] Seat $seatNumber is occupied - showing occupied message',
          );
          _showOccupiedSeatMessage(seatNumber);
        } else {
          debugPrint(
              'Ã°Å¸Âªâ [UI] Seat $seatNumber unavailable for unknown reason');
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
            'Ã°Å¸Âªâ [UI] Admin moving to occupied seat - showing confirmation',
          );
          _showAdminSeatTakeoverDialog(seatNumber, currentOccupant);
          return;
        }
      }

      // Find current seat of user
      final currentParticipant = _currentParticipant;
      final currentSeat = (currentParticipant?.seatNumber != null &&
              currentParticipant!.seatNumber! > 0)
          ? currentParticipant.seatNumber!
          : -1;

      debugPrint('Ã°Å¸Âªâ [UI] ===== MOVE REQUEST START =====');
      debugPrint(
        'Ã°Å¸Âªâ [UI] Current participant: ${currentParticipant?.userName}',
      );
      debugPrint(
        'Ã°Å¸Âªâ [UI] Current participant seat: ${currentParticipant?.seatNumber}',
      );
      debugPrint(
        'Ã°Å¸Âªâ [UI] Moving user from seat $currentSeat to seat $seatNumber',
      );

      // Debug: Check all participants and their seats
      debugPrint('Ã°Å¸Âªâ [UI] All participants and their seats:');
      // for (final p in _currentRoom.participants) {
      //   debugPrint('Ã°Å¸Âªâ [UI] - ${p.userName}: seat ${p.seatNumber}');
      // }

      widget.audioRoomsBloc.add(
        MoveParticipantToSeat(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          fromSeat: currentSeat,
          toSeat: seatNumber,
        ),
      );

      // Fix: Persist admin mute status on rejoin
      // If the user was previously muted by admin (as a listener/participant),
      // ensure this status carries over to the new seat assignment.
      if (currentParticipant != null && currentParticipant.isMutedByAdmin) {
        debugPrint(
            'Ã°Å¸Âªâ [UI] User was muted by admin - re-applying mute status');
        // We need to wait slightly for the move to process or just send the update
        // The bloc might process these sequentially.
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.audioRoomsBloc.add(
            UpdateRoomParticipant(
              roomId: _currentRoom.id,
              userId: _currentUser.userId,
              updatedParticipant: currentParticipant.copyWith(
                seatNumber: seatNumber,
                isMutedByAdmin: true,
                isMuted: true,
              ),
            ),
          );
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
      debugPrint('Ã°Å¸Âªâ Error moving to seat: $e');
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

    _showEmptySeatAdminOptions(seatNumber);
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
      if (_currentRoom.isCreator(occupant.userId) ||
          occupant.isHost ||
          _currentRoom.settings.adminIds.contains(occupant.userId)) {
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
        child: SafeArea(
          top: false,
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Admin/Viewer Tag
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (_currentRoom.isCreator(occupant.userId) ||
                                      occupant.isHost)
                                  ? Colors.purple.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    (_currentRoom.isCreator(occupant.userId) ||
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
                                color:
                                    (_currentRoom.isCreator(occupant.userId) ||
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
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (_currentRoom.isCreator(occupant.userId) ||
                                  occupant.isHost) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                Text(
                                  _currentRoom.isCreator(occupant.userId)
                                      ? ' Host'
                                      : ' Admin',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
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
                icon: (occupant.isMutedByAdmin || occupant.isMuted)
                    ? Icons.mic
                    : Icons.mic_off,
                title: (occupant.isMutedByAdmin || occupant.isMuted)
                    ? 'Unmute'
                    : 'Mute',
                subtitle: (occupant.isMutedByAdmin || occupant.isMuted)
                    ? 'Allow participant to speak'
                    : 'Prevent participant from speaking',
                color: (occupant.isMutedByAdmin || occupant.isMuted)
                    ? Colors.green
                    : Colors.red,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 22),
                ),
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
                        color: Color(0xFF1F1F24),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle seat lock/unlock
  void _toggleSeatLock(int seatNumber, bool isLocked) {
    try {
      debugPrint('Ã°Å¸Âªâ Toggling seat $seatNumber lock to $isLocked');

      widget.audioRoomsBloc.add(
        ToggleSeatLock(
          roomId: _currentRoom.id,
          hostId: _currentUser.userId,
          seatNumber: seatNumber,
          isLocked: isLocked,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat $seatNumber ${isLocked ? 'locked' : 'unlocked'}'),
          backgroundColor: isLocked ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Ã°Å¸Âªâ Error toggling seat lock: $e');
    }
  }

  /// Remove participant from seat
  void _removeParticipantFromSeat(
    int seatNumber,
    AudioRoomParticipant participant,
  ) {
    try {
      debugPrint(
          'Ã°Å¸Âªâ Removing ${participant.userName} from seat $seatNumber');

      widget.audioRoomsBloc.add(
        RemoveParticipantFromSeat(
          roomId: _currentRoom.id,
          hostId: _currentUser.userId,
          participantId: participant.userId,
          seatNumber: seatNumber,
        ),
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('${participant.userName} removed from seat'),
      //     backgroundColor: Colors.orange,
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      debugPrint('Ã°Å¸Âªâ Error removing participant from seat: $e');
    }
  }

  /// Promote a participant to admin
  void _promoteToAdmin(AudioRoomParticipant participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Admin?'),
        content: Text(
          'Are you sure you want to promote ${participant.userName} to Admin? They will have moderation privileges.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              final updatedParticipant = participant.copyWith(isHost: true);

              widget.audioRoomsBloc.add(
                UpdateRoomParticipant(
                  roomId: _currentRoom.id,
                  userId: _currentUser.userId,
                  updatedParticipant: updatedParticipant,
                ),
              );

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

      widget.audioRoomsBloc.add(
        UpdateRoomParticipant(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          updatedParticipant: updatedParticipant,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${participant.userName} ${newMuteState ? 'muted by admin' : 'unmuted by admin'}',
          ),
          backgroundColor: newMuteState ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Ã°Å¸Âªâ Error toggling participant mute: $e');
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
      debugPrint('Ã°Å¸Å¡Âª Kicking ${participant.userName} from room');

      widget.audioRoomsBloc.add(
        KickParticipant(
          roomId: _currentRoom.id,
          hostId: _currentUser.userId,
          participantId: participant.userId,
          reason: 'Removed by host',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${participant.userName} has been kicked from the room',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Ã°Å¸Å¡Âª Error kicking participant: $e');
    }
  }

  /// Block participant from room
  void _blockParticipant(AudioRoomParticipant participant) {
    try {
      debugPrint('Ã°Å¸Å¡Â« Blocking ${participant.userName} from room');

      widget.audioRoomsBloc.add(
        BlockParticipant(
          roomId: _currentRoom.id,
          hostId: _currentUser.userId,
          participantId: participant.userId,
          reason: 'Blocked by host',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${participant.userName} has been blocked from the room',
          ),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Ã°Å¸Å¡Â« Error blocking participant: $e');
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
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

              // Title - User Profile Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CachedCircleAvatar(
                      imageUrl: _currentUser.photoUrl,
                      radius: 22,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser.fullname.isNotEmpty
                              ? _currentUser.fullname
                              : 'My Profile',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F1F24),
                          ),
                        ),
                        Text(
                          'Seat $seatNumber',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Option 1: View Profile
              _buildMenuOption(
                icon: Icons.person_outline_rounded,
                title: 'View Profile',
                subtitle: 'View your profile details',
                color: const Color(0xFF6C63FF),
                onTap: () {
                  Navigator.pop(context);
                  final selfParticipant = _currentParticipant ??
                      AudioRoomParticipant(
                        userId: _currentUser.userId,
                        userName: _currentUser.fullname,
                        userImageUrl: _currentUser.photoUrl,
                        seatNumber: seatNumber,
                        joinedAt: DateTime.now(),
                      );
                  _showParticipantBottomSheet(selfParticipant);
                },
              ),

              // Option 2: Leave Seat
              _buildMenuOption(
                icon: Icons.chair_alt_rounded,
                title: 'Leave Seat',
                subtitle: 'Move to listeners area',
                color: Colors.orangeAccent[700]!,
                onTap: () {
                  Navigator.pop(context);
                  _leaveSeat();
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
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
        'Ã°Å¸Âªâ [UI] User leaving their own seat ${currentParticipant!.seatNumber}',
      );

      // If user on host seat (seat 1) leaves their seat, auto-close active Carrom or Ludo game
      if (currentParticipant.seatNumber == 1) {
        if (_currentRoom.isCarromActive) {
          AudioRoomsRepository().updateCarromState(
            roomId: _currentRoom.id,
            isActive: false,
          );
        }
        if (_currentRoom.isLudoActive) {
          AudioRoomsRepository().updateLudoState(
            roomId: _currentRoom.id,
            isActive: false,
          );
        }
      }

      // For self-removal, we'll use MoveParticipantToSeat with seat -1 (leaving all seats)
      // This bypasses the host permission check since users can move themselves
      widget.audioRoomsBloc.add(
        MoveParticipantToSeat(
          roomId: _currentRoom.id,
          userId: _currentUser.userId,
          fromSeat: currentParticipant.seatNumber!,
          toSeat: -1, // -1 means no seat (listener area)
        ),
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('You left your seat'),
      //     backgroundColor: Colors.blue,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      debugPrint('Ã°Å¸Âªâ Error leaving seat: $e');
    }
  }

  void _showEmptySeatAdminOptions(int seatNumber) {
    final isLocked = _currentRoom.isSeatLocked(seatNumber);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 190,
              decoration: BoxDecoration(
                color: const Color(0xFF22262E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCompactSeatOption(
                    icon: const Icon(
                      Icons.chair_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                    title: 'Take Mic',
                    onTap: () {
                      Navigator.pop(context);
                      _moveToSeat(seatNumber);
                    },
                  ),
                  _buildCompactSeatOption(
                    icon: SizedBox(
                      width: 22,
                      height: 22,
                      child: Stack(
                        children: [
                          const Positioned(
                            left: 0,
                            top: 0,
                            child: Icon(
                              Icons.chair_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF22262E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: 'Invite Speaker',
                    onTap: () {
                      Navigator.pop(context);
                      _showInviteToSeatSheet(seatNumber);
                    },
                  ),
                  _buildCompactSeatOption(
                    icon: Icon(
                      isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                      color: Colors.white,
                      size: 21,
                    ),
                    title: isLocked ? 'Unlock Mic' : 'Lock Mic',
                    onTap: () {
                      Navigator.pop(context);
                      _toggleSeatLock(seatNumber, !isLocked);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactSeatOption({
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(child: icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
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
                        horizontal: 20,
                        vertical: 8,
                      ),
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
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) {
                        setSheetState(() {
                          _invitedUserIds.remove(listener.userId);
                        });
                      }
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isInvited ? Colors.grey[800] : Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                  leading: CachedCircleAvatar(imageUrl: avatarUrl, radius: 20),
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
                            Future.delayed(const Duration(seconds: 4), () {
                              if (mounted) {
                                setSheetState(() {
                                  _invitedUserIds.remove(userId);
                                });
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isInvited ? Colors.grey[800] : Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
              leading: CachedCircleAvatar(imageUrl: avatarUrl, radius: 20),
              title: Text(name, style: const TextStyle(color: Colors.white)),
              trailing: ElevatedButton(
                onPressed: isInvited
                    ? null
                    : () {
                        setSheetState(() {
                          _invitedUserIds.add(userId);
                        });
                        _inviteToSeat(userData, seatNumber);
                        Future.delayed(const Duration(seconds: 4), () {
                          if (mounted) {
                            setSheetState(() {
                              _invitedUserIds.remove(userId);
                            });
                          }
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isInvited ? Colors.grey[800] : Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
          final dailyContributors =
              allContributors.where((c) => c.dailyContribution > 0).toList()
                ..sort(
                  (a, b) => b.dailyContribution.compareTo(a.dailyContribution),
                );

          // Weekly Ranking
          final weeklyContributors = allContributors
              .where((c) => c.weeklyContribution > 0)
              .toList()
            ..sort(
              (a, b) => b.weeklyContribution.compareTo(a.weeklyContribution),
            );

          // Monthly Ranking
          final monthlyContributors = allContributors
              .where((c) => c.monthlyContribution > 0)
              .toList()
            ..sort(
              (a, b) => b.monthlyContribution.compareTo(a.monthlyContribution),
            );

          // All Time Ranking
          final allTimeContributors =
              allContributors.where((c) => c.totalContribution > 0).toList()
                ..sort(
                  (a, b) => b.totalContribution.compareTo(a.totalContribution),
                );

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
                          const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFFFD700),
                          ),
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
                          horizontal: 20,
                          vertical: 0,
                        ),
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
                              _formatRevenue(liveRoom.totalRevenue),
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const DynamicDiamondIcon(
                              width: 16,
                              height: 16,
                            ),
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
                            allTimeContributors,
                            'all time',
                          ),
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
    List<RoomContributor> contributors,
    String type,
  ) {
    if (contributors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No $type contributions yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
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
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: rank <= 3
                ? Border(
                    bottom: BorderSide(color: rankColor.withValues(alpha: 0.3)),
                  )
                : Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
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
                          ),
                        ],
                      )
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
                      const DynamicDiamondIcon(width: 14, height: 14),
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

      // 1. Write mic invitation to Firestore in real-time
      await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .doc(_currentRoom.id)
          .collection('mic_invites')
          .doc(userId)
          .set({
        'roomId': _currentRoom.id,
        'targetUserId': userId,
        'targetUserName': userName,
        'inviterId': _currentUser.userId,
        'inviterName': _currentUser.fullname,
        'inviterImageUrl': _currentUser.photoUrl,
        'seatNumber': seatNumber,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Send push notification in case the user needs a ping
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      final deviceToken = userDoc.data()?['deviceToken'] ?? '';

      if (deviceToken.isNotEmpty) {
        await PushNotificationService.sendNotification(
          type: NotificationType.message,
          title: 'Mic Invitation',
          body:
              '${_currentUser.fullname} invited you to the mic in "${_currentRoom.name}"',
          deviceToken: deviceToken,
          call: {
            'type': 'mic_invite',
            'roomId': _currentRoom.id,
            'title': 'Mic Invitation',
            'message':
                '${_currentUser.fullname} invited you to the mic in "${_currentRoom.name}"',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invited $userName to the mic'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
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

    widget.audioRoomsBloc.add(
      SendChatMessage(
        roomId: _currentRoom.id,
        userId: _currentUser.userId,
        username:
            _currentUser.fullname.isNotEmpty ? _currentUser.fullname : 'User',
        userAvatar:
            _currentUser.photoUrl.isNotEmpty ? _currentUser.photoUrl : null,
        message: message.trim(),
      ),
    );

    // Text field clearing is now handled in RoomControls widget
  }

  /// Build speakers section

  /// Build listeners section

  /// Show VoiceRoom Customize sheet (slides from top, auto-sized)
  void _showVoiceRoomCustomize() {
    if (!_isCurrentUserHostOrAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Settings are only for Room Owners & Admins.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: const Offset(0, 0),
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(
                        0xFA0F1F38,
                      ), // Elegant deep dark navy with high opacity
                      Color(
                        0xFA08101E,
                      ), // Elegant midnight black with high opacity
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'VoiceRoom Customize',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_up,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 1. & 2. Dynamic Room Mode & Room Game Sections with Real-Time Firestore Sync
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('config')
                            .doc('room_games')
                            .snapshots(),
                        builder: (context, configSnapshot) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('room_games')
                                .snapshots(),
                            builder: (context, roomGamesSnapshot) {
                              final Map<String, dynamic> configMap =
                                  (configSnapshot.hasData &&
                                          configSnapshot.data!.exists)
                                      ? (configSnapshot.data!.data()
                                              as Map<String, dynamic>? ??
                                          {})
                                      : {};

                              final Map<String, Map<String, dynamic>>
                                  roomGamesMap = {};
                              final List<DocumentSnapshot> customRoomGameDocs =
                                  [];
                              final Set<String> builtInKeys = {
                                'ludo',
                                'carrom',
                                'youtube',
                                'vote_pro',
                                'dice',
                                'custom_roulette',
                                'pk_battle',
                              };

                              if (roomGamesSnapshot.hasData) {
                                for (final doc
                                    in roomGamesSnapshot.data!.docs) {
                                  final data =
                                      (doc.data() as Map<String, dynamic>?) ??
                                          {};
                                  final docId = doc.id.toLowerCase();
                                  roomGamesMap[docId] = data;
                                  final gameCode = (data['gameCode'] ?? doc.id)
                                      .toString()
                                      .toLowerCase();
                                  if (!builtInKeys.contains(docId) &&
                                      !builtInKeys.contains(gameCode)) {
                                    customRoomGameDocs.add(doc);
                                  }
                                }
                              }

                              // Helper to check if built-in game is active
                              bool isGameActive(String key) {
                                if (roomGamesMap.containsKey(key)) {
                                  final d = roomGamesMap[key]!;
                                  if (d['isActive'] == false ||
                                      d['isActive'] == 0 ||
                                      d['isActive'] == 'false') {
                                    return false;
                                  }
                                  if (d['isEnabled'] == false ||
                                      d['isEnabled'] == 0 ||
                                      d['isEnabled'] == 'false') {
                                    return false;
                                  }
                                  final s = (d['status'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  if (s == 'inactive' ||
                                      s == 'disabled' ||
                                      s == 'hidden') {
                                    return false;
                                  }
                                }
                                if (configMap.containsKey(key)) {
                                  final val = configMap[key];
                                  if (val is Map) {
                                    final a = val['isActive'] ??
                                        val['isEnabled'] ??
                                        val['active'];
                                    if (a == false ||
                                        a == 0 ||
                                        a == 'false' ||
                                        a == '0') {
                                      return false;
                                    }
                                    final s = (val['status'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    if (s == 'inactive' ||
                                        s == 'disabled' ||
                                        s == 'hidden') {
                                      return false;
                                    }
                                  } else if (val is bool) {
                                    if (!val) return false;
                                  }
                                }
                                if (configMap.containsKey('${key}_active')) {
                                  final f = configMap['${key}_active'];
                                  if (f == false ||
                                      f == 0 ||
                                      f == 'false' ||
                                      f == '0') {
                                    return false;
                                  }
                                }
                                return true;
                              }

                              // 1. Build Room Mode list
                              final List<Widget> modeItems = [];
                              if (isGameActive('ludo')) {
                                modeItems.add(
                                  _buildCustomizeItem(
                                      'Ludo', Icons.gamepad, 'mode'),
                                );
                              }
                              if (isGameActive('carrom')) {
                                modeItems.add(
                                  _buildCustomizeItem(
                                    'Carrom',
                                    Icons.blur_circular,
                                    'mode',
                                  ),
                                );
                              }
                              if (isGameActive('youtube')) {
                                modeItems.add(
                                  _buildCustomizeItem(
                                    'YouTube',
                                    Icons.video_collection,
                                    'mode',
                                  ),
                                );
                              }

                              // Custom room modes from room_games
                              for (final doc in customRoomGameDocs) {
                                final data =
                                    (doc.data() as Map<String, dynamic>?) ?? {};
                                final cat = (data['category'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (cat != 'mode' && cat != 'room_mode')
                                  continue;

                                if (data['isActive'] == false ||
                                    data['isActive'] == 0 ||
                                    data['isActive'] == 'false') {
                                  continue;
                                }
                                if (data['isEnabled'] == false ||
                                    data['isEnabled'] == 0 ||
                                    data['isEnabled'] == 'false') {
                                  continue;
                                }
                                final s = (data['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (s == 'inactive' ||
                                    s == 'disabled' ||
                                    s == 'hidden') {
                                  continue;
                                }

                                final name = (data['name'] ??
                                        data['title'] ??
                                        'Custom Mode')
                                    .toString();
                                final thumb = (data['thumbnailUrl'] ??
                                        data['picture'] ??
                                        data['icon'] ??
                                        '')
                                    .toString();
                                final url = (data['gameUrl'] ??
                                        data['url'] ??
                                        data['link'] ??
                                        data['webViewUrl'] ??
                                        '')
                                    .toString()
                                    .trim();

                                modeItems.add(
                                  _buildCustomizeItem(
                                    name,
                                    Icons.sports_esports_rounded,
                                    'mode',
                                    customThumbnailUrl:
                                        thumb.isNotEmpty ? thumb : null,
                                    onCustomTap: () {
                                      if (url.isNotEmpty) {
                                        Html5GameSheet.show(
                                          context,
                                          url: url,
                                          title: name,
                                          isInAudioRoom: true,
                                          roomId: _currentRoom.id,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('$name launched'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              }

                              // 2. Build Room Game list
                              final List<Widget> gameItems = [];
                              if (isGameActive('ludo')) {
                                gameItems.add(
                                  _buildCustomizeItem(
                                    'Ludo Champion',
                                    Icons.casino,
                                    'game',
                                  ),
                                );
                              }
                              if (isGameActive('vote_pro')) {
                                gameItems.add(
                                  _buildCustomizeItem(
                                    'Vote Pro',
                                    Icons.how_to_vote,
                                    'game',
                                  ),
                                );
                              }
                              if (isGameActive('dice')) {
                                gameItems.add(
                                  _buildCustomizeItem(
                                      'Dice', Icons.casino, 'game'),
                                );
                              }
                              if (isGameActive('custom_roulette')) {
                                gameItems.add(
                                  _buildCustomizeItem(
                                    'Custom Roulette',
                                    Icons.circle_notifications,
                                    'game',
                                  ),
                                );
                              }
                              if (isGameActive('pk_battle')) {
                                gameItems.add(
                                  _buildCustomizeItem(
                                    'PK Battle',
                                    Icons.sports_kabaddi,
                                    'game',
                                  ),
                                );
                              }

                              // Custom room games from room_games
                              for (final doc in customRoomGameDocs) {
                                final data =
                                    (doc.data() as Map<String, dynamic>?) ?? {};
                                final cat = (data['category'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (cat == 'mode' || cat == 'room_mode')
                                  continue;

                                if (data['isActive'] == false ||
                                    data['isActive'] == 0 ||
                                    data['isActive'] == 'false') {
                                  continue;
                                }
                                if (data['isEnabled'] == false ||
                                    data['isEnabled'] == 0 ||
                                    data['isEnabled'] == 'false') {
                                  continue;
                                }
                                final s = (data['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (s == 'inactive' ||
                                    s == 'disabled' ||
                                    s == 'hidden') {
                                  continue;
                                }

                                final name = (data['name'] ??
                                        data['title'] ??
                                        'Custom Game')
                                    .toString();
                                final thumb = (data['thumbnailUrl'] ??
                                        data['picture'] ??
                                        data['icon'] ??
                                        '')
                                    .toString();
                                final url = (data['gameUrl'] ??
                                        data['url'] ??
                                        data['link'] ??
                                        data['webViewUrl'] ??
                                        '')
                                    .toString()
                                    .trim();

                                gameItems.add(
                                  _buildCustomizeItem(
                                    name,
                                    Icons.casino_rounded,
                                    'game',
                                    customThumbnailUrl:
                                        thumb.isNotEmpty ? thumb : null,
                                    onCustomTap: () {
                                      if (url.isNotEmpty) {
                                        Html5GameSheet.show(
                                          context,
                                          url: url,
                                          title: name,
                                          isInAudioRoom: true,
                                          roomId: _currentRoom.id,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('$name launched'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              }

                              // Layout horizontal spaced items
                              final List<Widget> modeWidgets = [];
                              for (int i = 0; i < modeItems.length; i++) {
                                if (i > 0) {
                                  modeWidgets.add(const SizedBox(width: 15));
                                }
                                modeWidgets.add(modeItems[i]);
                              }

                              final List<Widget> gameWidgets = [];
                              for (int i = 0; i < gameItems.length; i++) {
                                if (i > 0) {
                                  gameWidgets.add(const SizedBox(width: 15));
                                }
                                gameWidgets.add(gameItems[i]);
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (modeItems.isNotEmpty) ...[
                                    _buildSectionHeader('Room Mode'),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 95,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        children: modeWidgets,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                  if (gameItems.isNotEmpty) ...[
                                    _buildSectionHeader('Room Game'),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 95,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        children: gameWidgets,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      ),

                      // 3. Room Settings Row
                      _buildSectionHeader('Room Settings'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 95,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildCustomizeItem(
                              'Music',
                              Icons.music_note,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Decor',
                              Icons.format_paint,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Announcement',
                              Icons.campaign,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Switch Mode',
                              Icons.rocket_launch,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Room Mode',
                              Icons.dashboard_customize_rounded,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Lock Mic',
                              Icons.lock,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Mute Mic',
                              Icons.mic_off,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Ban Comment',
                              Icons.speaker_notes_off,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Clear Chat',
                              Icons.delete_sweep,
                              'settings',
                            ),
                            const SizedBox(width: 15),
                            _buildCustomizeItem(
                              'Admins',
                              Icons.shield,
                              'settings',
                            ),
                            if (_currentRoom.category == 'Live') ...[
                              const SizedBox(width: 15),
                              _buildCustomizeItem(
                                'Live Mode',
                                Icons.video_call,
                                'settings',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
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
        return Material(
          color: const Color(0xFF14141F),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
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
                title: const Text(
                  'Single Host',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Only the host is visible',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: !_currentRoom.settings.isLiveMultipleMode
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.audioRoomsBloc.add(
                    UpdateRoomSettings(
                      roomId: _currentRoom.id,
                      userId: _currentUser.userId,
                      settings: _currentRoom.settings.copyWith(
                        isLiveMultipleMode: false,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(Icons.group, color: Colors.blue),
                title: const Text(
                  'Multiple Hosts',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Host + 4 guests',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: _currentRoom.settings.isLiveMultipleMode
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  widget.audioRoomsBloc.add(
                    UpdateRoomSettings(
                      roomId: _currentRoom.id,
                      userId: _currentUser.userId,
                      settings: _currentRoom.settings.copyWith(
                        isLiveMultipleMode: true,
                      ),
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

  void _showSeatLockOptions() {
    final audioRoomsBloc = widget.audioRoomsBloc;
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) {
        return Center(
          child: Material(
            color: const Color(0xFF22252D),
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            shadowColor: Colors.black45,
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock (All)
                  InkWell(
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Lock (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Unlock (All)
                  InkWell(
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
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Unlock (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMuteMicOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) {
        return Center(
          child: Material(
            color: const Color(0xFF22252D),
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            shadowColor: Colors.black45,
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mute (All)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.audioRoomsBloc.add(
                        ToggleAllMicsMute(
                          roomId: widget.room.id,
                          hostId: _currentUser.userId,
                          muteAll: true,
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mic_off_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Mute (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Unmute (All)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.audioRoomsBloc.add(
                        ToggleAllMicsMute(
                          roomId: widget.room.id,
                          hostId: _currentUser.userId,
                          muteAll: false,
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Unmute (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBanCommentOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) {
        return Center(
          child: Material(
            color: const Color(0xFF22252D),
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            shadowColor: Colors.black45,
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ban (All)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.audioRoomsBloc.add(
                        ToggleAllCommentsBan(
                          roomId: widget.room.id,
                          hostId: _currentUser.userId,
                          banAll: true,
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.speaker_notes_off_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Ban (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Unban (All)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.audioRoomsBloc.add(
                        ToggleAllCommentsBan(
                          roomId: widget.room.id,
                          hostId: _currentUser.userId,
                          banAll: false,
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Unban (All)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build setting item
  void _showYoutubeSheet() {
    final hostParticipant = _currentRoom.participants.firstWhereOrNull(
      (p) => p.userId == _currentRoom.creatorId,
    );
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

  String _getSettingKey(String title) {
    switch (title) {
      case 'Edit Room':
        return 'edit_room';
      case 'YouTube':
        return 'youtube';
      case 'Ludo Game':
        return 'ludo_game';
      case 'Carrom Game':
        return 'carrom_game';
      case 'Voting':
        return 'voting';
      case 'Roulette':
        return 'roulette';
      case 'Clear Chat':
        return 'clear_chat';
      case 'Admins':
        return 'admins';
      case 'Seat Lock':
        return 'seat_lock';
      case 'PK Battle':
        return 'pk_battle';
      case 'Music Player':
        return 'music_player';
      case 'Live Mode':
        return 'live_mode';
      case 'Room Decor':
        return 'room_decor';
      case 'Room Mode':
        return 'room_mode';
      case 'Mute Mic':
        return 'mute_mic';
      case 'Ban Comment':
        return 'ban_comment';
      default:
        return title.toLowerCase().replaceAll(' ', '_');
    }
  }

  String? _getCustomIconUrl(AppThemeService themeService, String settingKey) {
    // 1. Try direct lookup in RxMap
    if (themeService.roomSettingsIcons.containsKey(settingKey)) {
      return themeService.roomSettingsIcons[settingKey];
    }

    // 2. Try fallbacks for naming format discrepancies between admin panel & sheet keys
    String? fallbackKey;
    switch (settingKey) {
      case 'music':
        fallbackKey = 'music_player';
        break;
      case 'music_player':
        fallbackKey = 'music';
        break;
      case 'decor':
        fallbackKey = 'room_decor';
        break;
      case 'room_decor':
        fallbackKey = 'decor';
        break;
      case 'announcement':
        fallbackKey = 'edit_room';
        break;
      case 'edit_room':
        fallbackKey = 'announcement';
        break;
      case 'switch_mode':
        fallbackKey = 'room_mode';
        break;
      case 'room_mode':
        fallbackKey = 'switch_mode';
        break;
      case 'ludo':
        fallbackKey = 'ludo_game';
        break;
      case 'ludo_game':
        fallbackKey = 'ludo';
        break;
      case 'carrom':
        fallbackKey = 'carrom_game';
        break;
      case 'carrom_game':
        fallbackKey = 'carrom';
        break;
      case 'vote_pro':
        fallbackKey = 'voting';
        break;
      case 'voting':
        fallbackKey = 'vote_pro';
        break;
      case 'custom_roulette':
        fallbackKey = 'roulette';
        break;
      case 'roulette':
        fallbackKey = 'custom_roulette';
        break;
      case 'lock_mic':
        fallbackKey = 'seat_lock';
        break;
      case 'seat_lock':
        fallbackKey = 'lock_mic';
        break;
      case 'mute_mic':
        fallbackKey = 'mute_all';
        break;
      case 'mute_all':
        fallbackKey = 'mute_mic';
        break;
      case 'ban_comment':
        fallbackKey = 'comment_ban';
        break;
      case 'comment_ban':
        fallbackKey = 'ban_comment';
        break;
    }

    if (fallbackKey != null &&
        themeService.roomSettingsIcons.containsKey(fallbackKey)) {
      return themeService.roomSettingsIcons[fallbackKey];
    }

    return null;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizeItem(
    String title,
    IconData defaultIcon,
    String category, {
    String? customThumbnailUrl,
    VoidCallback? onCustomTap,
  }) {
    // Map the title to key for theme custom icons
    String settingKey = '';
    if (title == 'Music') {
      settingKey = _getSettingKey('Music Player');
    } else if (title == 'Decor') {
      settingKey = _getSettingKey('Room Decor');
    } else if (title == 'Announcement') {
      settingKey = _getSettingKey('Edit Room');
    } else if (title == 'Switch Mode') {
      settingKey = _getSettingKey('Room Mode');
    } else {
      settingKey = _getSettingKey(title);
    }

    return GestureDetector(
      onTap: () {
        // First dismiss the customize dialog
        Navigator.of(context).pop();

        if (onCustomTap != null) {
          onCustomTap();
          return;
        }

        // Execute action based on title
        if (title == 'Ludo Champion' ||
            title == 'Ludo' ||
            title == 'Ludo Game' ||
            title == 'ludugame-1') {
          if (!_currentRoom.isLudoActive) {
            LudoSetupBottomSheet.show(context, _currentRoom);
          }
        } else if (title == 'Carrom') {
          if (!_currentRoom.isCarromActive) {
            CarromSetupBottomSheet.show(context, _currentRoom);
          }
        } else if (title == 'Vote Pro') {
          if (!_currentRoom.isVotingActive) {
            VotingSetupSheet.show(context, _currentRoom, _currentUser.userId);
          }
        } else if (title == 'Custom Roulette') {
          final rouletteController = Get.isRegistered<RouletteController>(
            tag: 'roulette_${widget.room.id}',
          )
              ? Get.find<RouletteController>(tag: 'roulette_${widget.room.id}')
              : Get.put(
                  RouletteController(
                    widget.room.id,
                    isHost: _isCurrentUserHostOrAdmin,
                  ),
                  tag: 'roulette_${widget.room.id}',
                );
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                RouletteSelectionSheet(controller: rouletteController),
          );
        } else if (title == 'Dice') {
          // Send local dice roll!
          final rolledNumber = Random().nextInt(6) + 1;
          EmojiChatService.sendDiceMessage(
            roomId: _currentRoom.id,
            userId: _currentUser.userId,
            username: _currentUser.fullname.isNotEmpty
                ? _currentUser.fullname
                : 'User',
            userAvatar:
                _currentUser.photoUrl.isNotEmpty ? _currentUser.photoUrl : null,
            rolledNumber: rolledNumber,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rolled a $rolledNumber!'),
              duration: const Duration(seconds: 1),
            ),
          );
        } else if (title == 'PK Battle') {
          _showPKTypeSelectionSheet();
        } else if (title == 'Music') {
          setState(() {
            _showMusicPlayer = true;
          });
        } else if (title == 'Decor') {
          _showRoomDecorSheet();
        } else if (title == 'Announcement') {
          _showAnnouncementDialog();
        } else if (title == 'Switch Mode') {
          _showSeatConfiguration();
        } else if (title == 'Room Mode') {
          _showRoomModeSelectionSheet();
        } else if (title == 'Lock Mic') {
          _showSeatLockOptions();
        } else if (title == 'Mute Mic') {
          _showMuteMicOptions();
        } else if (title == 'Ban Comment') {
          _showBanCommentOptions();
        } else if (title == 'Clear Chat') {
          _showClearChatConfirmation();
        } else if (title == 'Admins') {
          _showAdminsListBottomSheet();
        } else if (title == 'YouTube') {
          _showYoutubeSheet();
        } else if (title == 'Live Mode') {
          _showLiveModeSettings();
        } else {
          // Carrom, Jackaroo, Football, King Game, Password Box, Lucky Wheel, Mora, etc.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title is coming soon!'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      },
      child: SizedBox(
        width: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              String? themeIconUrl;
              if (Get.isRegistered<AppThemeService>()) {
                final themeService = Get.find<AppThemeService>();
                themeIconUrl = _getCustomIconUrl(themeService, settingKey);
              }

              final effectiveIconUrl =
                  (customThumbnailUrl != null && customThumbnailUrl.isNotEmpty)
                      ? customThumbnailUrl
                      : themeIconUrl;

              // Determine icon container styling
              Widget iconWidget;
              if (effectiveIconUrl != null && effectiveIconUrl.isNotEmpty) {
                iconWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    key: ValueKey(effectiveIconUrl),
                    imageUrl: effectiveIconUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        _buildFallbackIcon(defaultIcon, category, title),
                  ),
                );
              } else {
                iconWidget = _buildFallbackIcon(defaultIcon, category, title);
              }

              return iconWidget;
            }),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLudoBoardIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildLudoQuadrant(const Color(0xFFE53935))),
                const SizedBox(width: 3),
                Expanded(child: _buildLudoQuadrant(const Color(0xFF43A047))),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildLudoQuadrant(const Color(0xFF1E88E5))),
                const SizedBox(width: 3),
                Expanded(child: _buildLudoQuadrant(const Color(0xFFFFB300))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLudoQuadrant(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(IconData icon, String category, String title) {
    if (category == 'settings') {
      // Circular border with slight opacity background (just like standard settings in screenshot)
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      );
    } else {
      // Custom authentic 4-color Ludo board icon matching VoiceRoom Customize screenshot
      if (title == 'Ludo' || title == 'Ludo Game') {
        return _buildLudoBoardIcon();
      }

      // Colorful gradient background for game/mode icons to look highly premium and 3D-ish
      Gradient gradient;
      switch (title) {
        case 'Ludo':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
          );
          break;
        case 'YouTube':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF0000), Color(0xFF7F0000)],
          );
          break;
        case 'Carrom':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE65C00), Color(0xFFF9D423)],
          );
          break;
        case 'Jackaroo':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          );
          break;
        case 'Football':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          );
          break;
        case 'King Game':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
          );
          break;
        case 'Password Box':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
          );
          break;
        case 'Vote Pro':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF8C00), Color(0xFFFF0080)],
          );
          break;
        case 'Lucky Wheel':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF000FF), Color(0xFF7B00FF)],
          );
          break;
        case 'Dice':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
          );
          break;
        case 'Mora':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
          );
          break;
        case 'Custom Roulette':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D976C), Color(0xFF93F9B9)],
          );
          break;
        case 'PK Battle':
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
          );
          break;
        default:
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4B6CB7), Color(0xFF182848)],
          );
      }

      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      );
    }
  }

  void _showPKTypeSelectionSheet() {
    if (_currentRoom.category == 'Live') {
      _openVideoPkSheet();
      return;
    }

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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select PK Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.people,
                  color: Colors.blueAccent,
                  size: 30,
                ),
                title: const Text(
                  'In-Room PK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'PK between users in this room',
                  style: TextStyle(color: Colors.white70),
                ),
                tileColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPKConfigurationSheet();
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.public,
                  color: Colors.pinkAccent,
                  size: 30,
                ),
                title: const Text(
                  'Room vs Room PK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'PK against another audio room',
                  style: TextStyle(color: Colors.white70),
                ),
                tileColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom > 0
                            ? MediaQuery.of(context).viewInsets.bottom
                            : MediaQuery.of(context).padding.bottom,
                      ),
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
    final seat1Participant = _currentRoom.participants
        .cast<AudioRoomParticipant?>()
        .firstWhere((p) => p?.seatNumber == 1, orElse: () => null);
    if (seat1Participant?.userId != _currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only the user in Seat 1 can start or extend PK battles.',
          ),
          backgroundColor: Colors.red,
        ),
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
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 24
                    : MediaQuery.of(context).padding.bottom + 24,
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PK Battle Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Duration',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.pink : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.pinkAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '$duration min',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Team Size',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.blueAccent : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.lightBlueAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${size}vs$size',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedTeamSize == 1) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Select Users for 1v1',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (seatedUsers.length < 2)
                      const Text(
                        'Not enough users seated to start 1v1',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      )
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
                                          ? Colors.redAccent.withValues(
                                              alpha: 0.2,
                                            )
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
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      u.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                                'Please select two users for 1v1 PK.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
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

                        widget.audioRoomsBloc.add(
                          UpdatePKBattleState(
                            roomId: _currentRoom.id,
                            userId: _currentUser.userId,
                            pkBattleState: newPkState,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Start PK Battle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PK Battle Controls',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Extend Time',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 5, 10].map((duration) {
                      final isSelected = additionalDuration == duration;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => additionalDuration = duration),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.greenAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '+$duration min',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);

                              final currentState = _currentRoom.pkBattleState;
                              final newDuration = currentState.durationMinutes +
                                  additionalDuration;

                              widget.audioRoomsBloc.add(
                                UpdatePKBattleState(
                                  roomId: _currentRoom.id,
                                  userId: _currentUser.userId,
                                  pkBattleState: currentState.copyWith(
                                    durationMinutes: newDuration,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.add_alarm,
                                color: Colors.white, size: 18),
                            label: const Text(
                              'Extend Time',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _showConfirmEndPKDialogFromRoomScreen();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.stop_circle_outlined,
                                color: Colors.white, size: 18),
                            label: const Text(
                              'End PK Battle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
            );
          },
        );
      },
    );
  }

  void _showConfirmEndPKDialogFromRoomScreen() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End PK Battle?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to end the PK battle early? Whichever team has earned more points will win.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final currentState = _currentRoom.pkBattleState;
              if (!currentState.isActive) return;

              final endedState = currentState.copyWith(
                durationMinutes: 0,
                startTime: DateTime.now().subtract(const Duration(minutes: 10)),
              );

              widget.audioRoomsBloc.add(
                UpdatePKBattleState(
                  roomId: _currentRoom.id,
                  userId: _currentUser.userId,
                  pkBattleState: endedState,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('End PK',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Show Clear Chat confirmation dialog
  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'Are you sure you want to delete ALL messages in this room? This cannot be undone.',
        ),
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

  void _showAnnouncementDialog() {
    final announcementController = TextEditingController(
      text: _currentRoom.settings.announcement ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Room Announcement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: announcementController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter announcement here...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newAnnouncement = announcementController.text.trim();
              Navigator.pop(context);
              widget.audioRoomsBloc.add(
                UpdateRoomAnnouncement(
                  roomId: _currentRoom.id,
                  userId: _currentUser.userId,
                  announcement:
                      newAnnouncement.isEmpty ? null : newAnnouncement,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Announcement updated successfully!'),
                  backgroundColor: Colors.purpleAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
              Tween(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Show Room Mode selection bottom sheet (Pro Mode, Party Mode, Event Mode)
  void _showRoomModeSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final currentLayout = _currentRoom.settings.roomLayoutType;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF14141F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Room Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Pro Mode Option
                    _buildRoomModeOptionCard(
                      title: 'Pro Mode',
                      subtitle:
                          'Seat gift counters & filtered chat tabs (All/Chat/Gifts)',
                      icon: Icons.workspace_premium_rounded,
                      iconGradient: const [
                        Color(0xFFFF007A),
                        Color(0xFFFF5252)
                      ],
                      isSelected: currentLayout == 'pro',
                      isComingSoon: false,
                      badgeText: 'PRO',
                      badgeColor: Colors.pinkAccent,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentLayout != 'pro') {
                          widget.audioRoomsBloc.add(
                            UpdateRoomSettings(
                              roomId: _currentRoom.id,
                              userId: _currentUser.userId,
                              settings: _currentRoom.settings.copyWith(
                                roomLayoutType: 'pro',
                              ),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Switched to Pro Mode'),
                              backgroundColor: Color(0xFFFF007A),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. Party Mode Option (Current default)
                    _buildRoomModeOptionCard(
                      title: 'Party Mode',
                      subtitle:
                          'Standard audio room layout with live animations',
                      icon: Icons.celebration_rounded,
                      iconGradient: const [
                        Color(0xFF00BCD4),
                        Color(0xFF00E5FF)
                      ],
                      isSelected: currentLayout == 'party',
                      isComingSoon: false,
                      badgeText: 'DEFAULT',
                      badgeColor: Colors.cyan,
                      onTap: () {
                        Navigator.pop(context);
                        if (currentLayout != 'party') {
                          widget.audioRoomsBloc.add(
                            UpdateRoomSettings(
                              roomId: _currentRoom.id,
                              userId: _currentUser.userId,
                              settings: _currentRoom.settings.copyWith(
                                roomLayoutType: 'party',
                              ),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Switched to Party Mode'),
                              backgroundColor: Color(0xFF00BCD4),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // 3. Event Mode Option (Coming Soon)
                    _buildRoomModeOptionCard(
                      title: 'Event Mode',
                      subtitle:
                          'Special concert and tournament event stage layout',
                      icon: Icons.event_available_rounded,
                      iconGradient: const [
                        Color(0xFFFF9800),
                        Color(0xFFFFC107)
                      ],
                      isSelected: currentLayout == 'event',
                      isComingSoon: true,
                      badgeText: 'COMING SOON',
                      badgeColor: Colors.amber,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event Mode is coming soon!'),
                            backgroundColor: Colors.amber,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoomModeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> iconGradient,
    required bool isSelected,
    required bool isComingSoon,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? badgeColor.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? badgeColor.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container with gradient
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),

                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Selected Checkmark or Arrow
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else if (isComingSoon)
                  const Icon(
                    Icons.lock_clock,
                    color: Colors.white38,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
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
                child: Image.network(
                  _currentRoom.roomFrameUrl!,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build background with instant cached loading
  Widget _buildBackgroundWithLoading() {
    if (_currentRoom.category == 'Live') {
      if (_activeVideoBattle != null &&
          (_activeVideoBattle!.isActive || _activeVideoBattle!.isPunishment)) {
        return Container(color: const Color(0xFF0F0B1E));
      }

      final engine = AgoraService().engine;
      if (engine != null && _agoraChannelJoined) {
        if (_isCurrentUserHost) {
          if (!_isHostVideoEnabled) {
            return _buildHostProfilePlaceholder();
          }
          return SizedBox.expand(
            child: VideoFilterColorOverlay(
              controller: _videoEffectsController,
              child: AgoraVideoView(controller: _getVideoController(0, engine)),
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
          child: CircularProgressIndicator(color: Colors.white),
        );
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
        errorBuilder: (context, error, stackTrace) =>
            _buildAppThemeOrAssetFallback(),
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
            placeholder: (context, url) =>
                Container(color: globalRoomColor ?? const Color(0xFF16213E)),
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
      builder: (context) {
        _followController.clearFollowStatus(participant.userId);
        _followController.loadFollowStatusFromServer(
          currentUserId: _currentUser.userId,
          targetUserId: participant.userId,
        );
        return _participantProfileBottomSheet(
          participant: participant,
          isParticipantHost: isParticipantHost,
          currentUserId: _currentUser.userId,
          followController: _followController,
          onMessage: () => _handleMessageUser(participant),
          onMention: (username) => _handleMentionUser(username),
          onSendGift: () {
            Navigator.pop(context);
            _showGiftSelection(participant);
          },
          onInviteToMic: (p) => _inviteToSeat(p, 0),
        );
      },
    );
  }

  void _handleMentionUser(String username) {
    _roomControlsKey.currentState?.mentionUser(username);
  }

  /// Participant Profile Bottom Sheet Widget
  Widget _participantProfileBottomSheet({
    required AudioRoomParticipant participant,
    required bool isParticipantHost,
    required String currentUserId,
    required FollowController followController,
    required VoidCallback onMessage,
    required VoidCallback onSendGift,
    void Function(AudioRoomParticipant)? onInviteToMic,
    void Function(String)? onMention,
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
      onInviteToMic: onInviteToMic,
      onMention: onMention,
    );
  }

  /// Build status badge
  /// Fetch user's equipped badge info
  Future<Map<String, dynamic>?> _getUserBadgeInfo(String userId) async {
    try {
      debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] Fetching badge for userId: $userId');

      // Fetch user document
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] User document not found');
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedBadgeId = customization?['selectedBadgeId'];

      debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] selectedBadgeId: $selectedBadgeId');

      if (selectedBadgeId == null || selectedBadgeId.isEmpty) {
        debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] No badge equipped');
        return null;
      }

      // Fetch badge details from store
      final badgeDoc = await FirebaseFirestore.instance
          .collection('market_items')
          .doc(selectedBadgeId)
          .get();

      if (!badgeDoc.exists) {
        debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] Badge not found in store');
        return null;
      }

      final badgeData = badgeDoc.data();
      final badgeInfo = {
        'id': selectedBadgeId,
        'name': badgeData?['name'] ?? 'Badge',
        'imageUrl': badgeData?['imageUrl'] ?? badgeData?['image'],
      };

      debugPrint('Ã°Å¸Å½âÃ¯Â¸Â [Badge] Found badge: ${badgeInfo['name']}');
      return badgeInfo;
    } catch (e) {
      debugPrint('Ã¢ÂÅ [Badge] Error fetching badge info: $e');
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
          builder: (context) => MessageScreen(isGroup: false, user: user),
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Show Admins List Bottom Sheet
  void _showAdminsListBottomSheet() {
    final adminIds = _currentRoom.settings.adminIds
        .where((id) => id != _currentRoom.creatorId)
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${adminIds.length} Admins',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // List of Admins
            if (adminIds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('No admins yet'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: adminIds.length,
                itemBuilder: (context, index) {
                  final adminId = adminIds[index];

                  // Find if they are in the participants list (active inside the room)
                  AudioRoomParticipant? activeAdmin;
                  for (final p in _currentRoom.participants) {
                    if (p.userId == adminId) {
                      activeAdmin = p;
                      break;
                    }
                  }

                  if (activeAdmin != null) {
                    return _buildAdminRowWidget(
                      context: context,
                      userId: adminId,
                      name: activeAdmin.userName,
                      imageUrl: activeAdmin.userImageUrl ?? '',
                      isActiveInRoom: true,
                    );
                  } else {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('Users')
                          .doc(adminId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: 50,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final Map<String, dynamic>? uData =
                            snapshot.data?.data() as Map<String, dynamic>?;
                        final String fullname = uData?['fullname'] ?? 'User';
                        final String userImageUrl = uData?['photoUrl'] ?? '';

                        return _buildAdminRowWidget(
                          context: context,
                          userId: adminId,
                          name: fullname,
                          imageUrl: userImageUrl,
                          isActiveInRoom: false,
                        );
                      },
                    );
                  }
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminRowWidget({
    required BuildContext context,
    required String userId,
    required String name,
    required String imageUrl,
    required bool isActiveInRoom,
  }) {
    return ListTile(
      leading: CachedCircleAvatar(imageUrl: imageUrl, radius: 20),
      title: Row(
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!isActiveInRoom) ...[
            const SizedBox(width: 8),
            Text(
              '(Offline)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
      trailing: (_currentUser.userId == _currentRoom.creatorId)
          ? TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                // Demote logic
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Admin?'),
                    content: Text(
                      'Are you sure you want to remove $name from admins?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Close sheet

                          try {
                            final DocumentReference roomRef = FirebaseFirestore
                                .instance
                                .collection('audio_rooms_v2')
                                .doc(_currentRoom.id);

                            // 1. Remove from settings.adminIds
                            final List<dynamic> updatedAdminIds = List.from(
                              _currentRoom.settings.adminIds,
                            );
                            updatedAdminIds.remove(userId);

                            // 2. Update isHost field in active participants list if they are in the room
                            List<dynamic> updatedParticipants = _currentRoom
                                .participants
                                .map((p) => p.toJson())
                                .toList();
                            for (var p in updatedParticipants) {
                              if (p is Map && p['userId'] == userId) {
                                p['isHost'] = false;
                              }
                            }

                            await roomRef.update({
                              'settings.adminIds': updatedAdminIds,
                              'participants': updatedParticipants,
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name removed from admins'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error removing admin: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Remove'),
            )
          : null,
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
              return chat.receiver!.fullname.toLowerCase().contains(
                    searchText,
                  );
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B26), // Premium dark background
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Actions: Copy Link & Share via Apps
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Copy Link Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final link = DeepLinkService.generateRoomLink(
                                _currentRoom.id,
                              );
                              Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Room link copied to clipboard'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Copy Link',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Share via other apps
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final link = DeepLinkService.generateRoomLink(
                                _currentRoom.id,
                              );
                              Navigator.pop(context);
                              SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      'Join my voice room "${_currentRoom.name}" on imChat:\n$link',
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.share_rounded,
                                    color: Colors.blueAccent,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Share via...',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
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
                                Icon(
                                  Icons.forum_outlined,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  size: 48,
                                ),
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
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = filteredChats[index];
                              final user = chat.receiver;
                              if (user == null) return const SizedBox.shrink();

                              final isInvited = _invitedUserIds.contains(
                                user.userId,
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.03),
                                  ),
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
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
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
                                                _invitedUserIds.add(
                                                  user.userId,
                                                );
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
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: isInvited
                                              ? null
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFFE91E63),
                                                    Color(0xFFFF4081),
                                                  ],
                                                ),
                                          color: isInvited
                                              ? const Color(
                                                  0xFF2E7D32,
                                                ).withValues(alpha: 0.2)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: isInvited
                                              ? Border.all(
                                                  color: const Color(
                                                    0xFF81C784,
                                                  ),
                                                )
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
  final void Function(AudioRoomParticipant)? onInviteToMic;
  final void Function(String)? onMention;

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
    this.onInviteToMic,
    this.onMention,
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

  DocumentSnapshot? _lastDocSnapshot;
  Future<Map<String, dynamic>>? _badgeFuture;

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
        contactStream, sentRequestStream, receivedRequestStream, (
      contactSnap,
      sentSnap,
      receivedSnap,
    ) {
      return {
        'isFriend': contactSnap.exists,
        'sentPending': sentSnap.exists &&
            (sentSnap.data() as Map<String, dynamic>?)?['status'] == 'pending',
        'receivedPending': receivedSnap.exists &&
            (receivedSnap.data() as Map<String, dynamic>?)?['status'] ==
                'pending',
      };
    });
  }

  Future<void> _sendFriendRequest() async {
    try {
      final targetId = widget.participant.userId;

      await ContactApi.sendFriendRequest(
        targetUserId: targetId,
        roomTitle: widget.currentRoom.name,
        roomId: widget.currentRoom.id,
        showMsg: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent to ${widget.participant.userName}!',
            ),
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
      final targetId = widget.participant.userId;

      await ContactApi.acceptFriendRequest(
        senderId: targetId,
        showMsg: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are now friends with ${widget.participant.userName}!',
            ),
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
      final targetId = widget.participant.userId;

      await ContactApi.rejectFriendRequest(
        senderId: targetId,
        showMsg: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request from ${widget.participant.userName} rejected.',
            ),
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

    _slideUp =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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

  Future<Map<String, dynamic>> _getBadgeFuture(DocumentSnapshot? doc) {
    if (_badgeFuture != null && _lastDocSnapshot == doc) {
      return _badgeFuture!;
    }
    _lastDocSnapshot = doc;
    final userData = doc?.data() as Map<String, dynamic>?;
    _badgeFuture = () async {
      final customizationMap = userData?['customization'] as Map?;
      List<String> nameplateIds = [];
      if (customizationMap?['selectedNameplateIds'] != null) {
        nameplateIds = (customizationMap!['selectedNameplateIds'] as List)
            .whereType<String>()
            .toList();
      } else if (customizationMap?['selectedNameplateId'] != null &&
          (customizationMap!['selectedNameplateId'] as String).isNotEmpty) {
        nameplateIds = [customizationMap['selectedNameplateId'] as String];
      }
      final levelImages = await _loadLevelImages(
        (userData?['sendingLevel'] as Map?)?['level'] as int?,
        (userData?['receivingLevel'] as Map?)?['level'] as int?,
      );

      bool isPositionNameplate(
          String id, Map<String, dynamic>? itemDetails, String url) {
        final idLower = id.toLowerCase();
        final urlLower = url.toLowerCase();
        final name = (itemDetails?['name'] ??
                itemDetails?['title'] ??
                itemDetails?['storeItemName'] ??
                '')
            .toString()
            .toLowerCase();
        final subCat = (itemDetails?['subCategory'] ??
                itemDetails?['badgeSubCategory'] ??
                itemDetails?['category'] ??
                '')
            .toString()
            .toLowerCase();
        final tag = (itemDetails?['tag'] ?? itemDetails?['badgeTag'] ?? '')
            .toString()
            .toLowerCase();

        final bool isVipOrSvip = idLower.startsWith('vip_') ||
            idLower.startsWith('svip_') ||
            idLower.contains('svip') ||
            idLower.contains('vip') ||
            name.contains('svip') ||
            name.contains('vip') ||
            subCat.contains('svip') ||
            subCat.contains('vip');

        if (isVipOrSvip) {
          return false;
        }

        // ONLY 3 auto-positions: agency, host, seller
        final positionKeywords = [
          'seller',
          'saller',
          'সেলার',
          'agency',
          'এজেন্সি',
          'host',
          'হোস্ট',
        ];

        for (final kw in positionKeywords) {
          if (idLower.contains(kw) ||
              name.contains(kw) ||
              subCat.contains(kw) ||
              tag.contains(kw) ||
              urlLower.contains(kw)) {
            return true;
          }
        }
        return false;
      }

      final List<String> vipNameplateUrls = [];
      final List<String> positionNameplateUrls = [];
      final List<String> otherNameplateUrls = [];

      // 1. Fetch all equipped nameplate URLs
      List<String> allEquippedUrls = [];
      if (nameplateIds.isNotEmpty) {
        allEquippedUrls = await NameplateHelper.getNameplateUrls(nameplateIds);
      }
      if (allEquippedUrls.isEmpty) {
        final single = customizationMap?['selectedNameplate'] ??
            customizationMap?['selectedNameplateUrl'];
        if (single is String && single.isNotEmpty) {
          allEquippedUrls = [single];
        } else {
          final fallbackUrls = await NameplateHelper.getNameplateUrlsFromUserId(
              widget.participant.userId);
          if (fallbackUrls.isNotEmpty) {
            allEquippedUrls = fallbackUrls;
          }
        }
      }

      // 2. Classify: VIP -> vip line, Agency/Host/Seller -> position line, ALL other equipped/assigned/event nameplates -> other line below
      for (int i = 0; i < allEquippedUrls.length; i++) {
        final url = allEquippedUrls[i];
        final id = (i < nameplateIds.length) ? nameplateIds[i] : '';
        Map<String, dynamic>? details;
        if (id.isNotEmpty) {
          details = await StoreService().getStoreItemDetails(id);
        }
        final idLower = id.toLowerCase();
        final urlLower = url.toLowerCase();
        final name = (details?['name'] ?? details?['title'] ?? '')
            .toString()
            .toLowerCase();
        final subCat = (details?['subCategory'] ?? '').toString().toLowerCase();

        final bool isVip = idLower.startsWith('vip_') ||
            idLower.startsWith('svip_') ||
            idLower.contains('svip') ||
            idLower.contains('vip') ||
            name.contains('svip') ||
            name.contains('vip') ||
            subCat.contains('svip') ||
            subCat.contains('vip') ||
            urlLower.contains('svip') ||
            urlLower.contains('vip');

        if (isVip) {
          if (!vipNameplateUrls.contains(url)) {
            vipNameplateUrls.add(url);
          }
        } else if (isPositionNameplate(id, details, url)) {
          if (!positionNameplateUrls.contains(url)) {
            positionNameplateUrls.add(url);
          }
        } else {
          if (!otherNameplateUrls.contains(url)) {
            otherNameplateUrls.add(url);
          }
        }
      }

      // 3. Check user_store_items strictly for auto-assigned positions (Agency, Host, Seller)
      try {
        final posSnap = await FirebaseFirestore.instance
            .collection('user_store_items')
            .where('userId', isEqualTo: widget.participant.userId)
            .where('itemType', isEqualTo: 'nameplate')
            .get();
        for (final doc in posSnap.docs) {
          final data = doc.data();
          final storeItemId = (data['storeItemId'] ?? doc.id).toString();
          String url = (data['imageUrl'] ??
                  data['fileUrl'] ??
                  data['thumbnailUrl'] ??
                  '')
              .toString();
          if (url.isEmpty) {
            url = await NameplateHelper.getNameplateUrl(storeItemId) ?? '';
          }
          if (url.isNotEmpty && isPositionNameplate(storeItemId, data, url)) {
            if (!positionNameplateUrls.contains(url)) {
              positionNameplateUrls.add(url);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching user position nameplates: $e');
      }

      final badgeUrls =
          await _loadUserBadgeUrls(widget.participant.userId, userData);
      return {
        'sendImageUrl': levelImages['sending'],
        'receiveImageUrl': levelImages['receiving'],
        'vipNameplateUrls': vipNameplateUrls,
        'positionNameplateUrls': positionNameplateUrls,
        'otherNameplateUrls': otherNameplateUrls,
        'badgeUrls': badgeUrls,
      };
    }();
    return _badgeFuture!;
  }

  Future<List<String>> _loadUserBadgeUrls(
      String userId, Map<String, dynamic>? userData) async {
    final List<Map<String, dynamic>> badgeList = [];
    try {
      String extractMediaUrl(Map<String, dynamic> data) {
        for (final key in [
          'imageUrl',
          'thumbnailUrl',
          'fileUrl',
          'badgeUrl',
          'badgeMediaUrl',
          'iconUrl',
          'pngUrl',
          'image',
          'url',
          'mediaUrl',
          'assetUrl',
          'badge',
          'photoUrl',
        ]) {
          final val = data[key];
          if (val != null && val.toString().trim().isNotEmpty) {
            return val.toString().trim();
          }
        }
        return '';
      }

      int getBadgeTier(Map<String, dynamic> item) {
        final name =
            (item['name'] ?? item['storeItemName'] ?? item['title'] ?? '')
                .toString()
                .toLowerCase();
        final cat = (item['subCategory'] ??
                item['category'] ??
                item['badgeSubCategory'] ??
                '')
            .toString()
            .toLowerCase();
        final id =
            (item['storeItemId'] ?? item['id'] ?? '').toString().toLowerCase();
        final tag =
            (item['tag'] ?? item['badgeTag'] ?? '').toString().toLowerCase();

        final bool isOfficialOrVerif = (cat == 'verification' &&
                !cat.contains('svip') &&
                !cat.contains('vip')) ||
            cat.contains('official') ||
            name.contains('official') ||
            name.contains('verif') ||
            name.contains('assistant') ||
            name.contains('admin') ||
            name.contains('moderator') ||
            name.contains('staff') ||
            name.contains('ভেরিফাই') ||
            name.contains('অফিসিয়াল') ||
            id.contains('official') ||
            id.contains('verif') ||
            tag.contains('official') ||
            tag.contains('verif');

        final bool isVip = name.contains('svip') ||
            name.contains('vip') ||
            name.contains('premium') ||
            name.contains('member') ||
            name.contains('এসভিআইপি') ||
            name.contains('ভিআইপি') ||
            cat.contains('svip') ||
            cat.contains('vip') ||
            cat.contains('premium') ||
            cat.contains('member') ||
            id.contains('svip') ||
            id.contains('vip') ||
            tag.contains('vip') ||
            tag.contains('svip');

        if (isOfficialOrVerif && !isVip) return 3;
        if (isVip) return 2;
        if (isOfficialOrVerif) return 3;
        return 1;
      }

      int getVerifyLevel(Map<String, dynamic> item) {
        for (final key in [
          'verifyLevel',
          'verificationLevel',
          'officialLevel',
          'badgeLevel',
          'levelNum',
          'level'
        ]) {
          final val = item[key];
          if (val is num && val > 0) return val.toInt();
          if (val is String && val.isNotEmpty) {
            final parsed = int.tryParse(val);
            if (parsed != null && parsed > 0) return parsed;
          }
        }
        final int tier = getBadgeTier(item);
        if (tier == 3) return 2;
        if (tier == 2) return 1;
        return 0;
      }

      final customization = userData?['customization'] as Map<String, dynamic>?;
      final List<dynamic> ownedBadges = customization?['ownedBadges'] ?? [];

      // 1. Process customization['ownedBadges']
      for (final item in ownedBadges) {
        if (item is String && item.isNotEmpty) {
          if (item.startsWith('http') || item.startsWith('assets/')) {
            if (!badgeList.any((b) => b['url'] == item)) {
              badgeList.add({
                'url': item,
                'name': 'Badge',
                'verifyLevel': 1,
                'tier': 2,
              });
            }
          } else {
            try {
              final mDoc = await FirebaseFirestore.instance
                  .collection('market_items')
                  .doc(item)
                  .get();
              if (mDoc.exists && mDoc.data() != null) {
                final data = mDoc.data()!;
                final u = extractMediaUrl(data);
                if (u.isNotEmpty && !badgeList.any((b) => b['url'] == u)) {
                  badgeList.add({
                    'url': u,
                    'name': data['name'] ?? '',
                    'subCategory': data['subCategory'] ?? '',
                    'verifyLevel':
                        data['verifyLevel'] ?? data['verificationLevel'] ?? 0,
                    'tier': getBadgeTier(data),
                    'order': data['order'] ?? data['sortOrder'] ?? 0,
                  });
                }
              } else {
                final oDoc = await FirebaseFirestore.instance
                    .collection('official_items')
                    .doc(item)
                    .get();
                if (oDoc.exists && oDoc.data() != null) {
                  final data = oDoc.data()!;
                  final u = extractMediaUrl(data);
                  if (u.isNotEmpty && !badgeList.any((b) => b['url'] == u)) {
                    badgeList.add({
                      'url': u,
                      'name': data['name'] ?? '',
                      'subCategory': data['subCategory'] ?? '',
                      'verifyLevel':
                          data['verifyLevel'] ?? data['verificationLevel'] ?? 0,
                      'tier': getBadgeTier(data),
                      'order': data['order'] ?? data['sortOrder'] ?? 0,
                    });
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      // 2. Query user_store_items collection
      try {
        final snap = await FirebaseFirestore.instance
            .collection('user_store_items')
            .where('userId', isEqualTo: userId)
            .limit(50)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final type =
              (data['itemType'] ?? data['type'] ?? '').toString().toLowerCase();
          if (type == 'badge') {
            final expiresAt = data['expiresAt'];
            if (expiresAt is Timestamp &&
                expiresAt.toDate().isBefore(DateTime.now())) {
              continue;
            }
            String url = extractMediaUrl(data);
            Map<String, dynamic> itemMeta = Map<String, dynamic>.from(data);
            if (url.isEmpty) {
              final storeItemId = (data['storeItemId'] ?? '').toString();
              if (storeItemId.isNotEmpty) {
                try {
                  final mDoc = await FirebaseFirestore.instance
                      .collection('market_items')
                      .doc(storeItemId)
                      .get();
                  if (mDoc.exists && mDoc.data() != null) {
                    itemMeta.addAll(mDoc.data()!);
                    url = extractMediaUrl(mDoc.data()!);
                  } else {
                    final oDoc = await FirebaseFirestore.instance
                        .collection('official_items')
                        .doc(storeItemId)
                        .get();
                    if (oDoc.exists && oDoc.data() != null) {
                      itemMeta.addAll(oDoc.data()!);
                      url = extractMediaUrl(oDoc.data()!);
                    }
                  }
                } catch (_) {}
              }
            }
            if (url.isNotEmpty && !badgeList.any((b) => b['url'] == url)) {
              badgeList.add({
                'url': url,
                'name': itemMeta['name'] ?? itemMeta['storeItemName'] ?? '',
                'subCategory': itemMeta['badgeSubCategory'] ??
                    itemMeta['subCategory'] ??
                    itemMeta['category'] ??
                    '',
                'verifyLevel': itemMeta['verifyLevel'] ??
                    itemMeta['verificationLevel'] ??
                    0,
                'tier': getBadgeTier(itemMeta),
                'order': itemMeta['order'] ?? itemMeta['sortOrder'] ?? 0,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching user_store_items badges: $e');
      }

      // 3. Fallback to SVIP badge if user has one
      final svipBadge = userData?['svipBadge'] ??
          customization?['svipBadge'] ??
          userData?['svip']?['badgeUrl'];
      if (svipBadge is String &&
          svipBadge.isNotEmpty &&
          !badgeList.any((b) => b['url'] == svipBadge)) {
        badgeList.add({
          'url': svipBadge,
          'name': 'SVIP Badge',
          'verifyLevel': 1,
          'tier': 2,
        });
      }

      // Sort badges (Verification / Official > VIP/SVIP > other)
      badgeList.sort((a, b) {
        final tierA = a['tier'] as int? ?? 1;
        final tierB = b['tier'] as int? ?? 1;
        if (tierB != tierA) return tierB.compareTo(tierA);

        final vA = getVerifyLevel(a);
        final vB = getVerifyLevel(b);
        if (vB != vA) return vB.compareTo(vA);

        final ordA = a['order'];
        final ordB = b['order'];
        if (ordA is num && ordB is num && ordA != ordB)
          return ordA.compareTo(ordB);

        return 0;
      });
    } catch (e) {
      debugPrint('Error loading badges: $e');
    }
    return badgeList.map((b) => b['url'] as String).toList();
  }

  Future<Map<String, String?>> _loadLevelImages(
    int? sendingLevel,
    int? receivingLevel,
  ) async {
    final result = <String, String?>{'sending': null, 'receiving': null};

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
      debugPrint('Error loading level images: $e');
    }

    return result;
  }

  Widget _buildLevelImageBadge(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: 16,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        height: 16,
        width: 16,
        color: Colors.transparent,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }

  Widget _buildRoleBadge(AudioRoomParticipant p) {
    final bool isRoomCreator = widget.currentRoom.isCreator(p.userId);
    final bool isAdmin =
        widget.currentRoom.settings.adminIds.contains(p.userId) ||
            widget.isParticipantHost;
    final bool isSpeaker = p.isSpeaker ||
        widget.currentRoom.participants
            .any((part) => part.userId == p.userId && part.isSpeaker);
    final bool isMember =
        isSpeaker || widget.currentRoom.joinedUserIds.contains(p.userId);

    String roleText = 'Viewer';
    Color roleColor = const Color(0xFF29B6F6);

    if (isRoomCreator) {
      roleText = 'Owner';
      roleColor = const Color(0xFFFF5722);
    } else if (isAdmin) {
      roleText = 'Admin';
      roleColor = const Color(0xFF9C27B0);
    } else if (isMember) {
      roleText = 'Member';
      roleColor = const Color(0xFF4CAF50);
    } else {
      roleText = 'Viewer';
      roleColor = const Color(0xFF29B6F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: roleColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        roleText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // How far the avatar overflows above the sheet
  static const double _avatarRadius = 48.0;
  static const double _avatarOverlap = 20.0;

  void _showModerationSheet(BuildContext context, AudioRoomParticipant p) {
    final bool isCurrentOwner =
        widget.currentUserId == widget.currentRoom.creatorId;
    final bool isTargetAdminOrOwner = widget.currentRoom.isCreator(p.userId) ||
        widget.currentRoom.creatorId == p.userId ||
        widget.currentRoom.settings.adminIds.contains(p.userId) ||
        p.isHost ||
        widget.isParticipantHost;

    if (!isCurrentOwner && isTargetAdminOrOwner) {
      return;
    }

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
                        horizontal: 20,
                        vertical: 8,
                      ),
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
                        leading: const Icon(
                          Icons.logout,
                          color: Colors.orangeAccent,
                        ),
                        title: const Text(
                          'Kick from seat',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.audioRoomsBloc.add(
                            RemoveParticipantFromSeat(
                              roomId: widget.currentRoom.id,
                              hostId: widget.currentUserId,
                              participantId: currentP.userId,
                              seatNumber: currentP.seatNumber ?? 0,
                            ),
                          );
                        },
                      )
                    else
                      ListTile(
                        leading: const Icon(
                          Icons.mic,
                          color: Color(0xFFFFC107),
                        ),
                        title: const Text(
                          'Invite to Mic',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onInviteToMic?.call(currentP);
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        (currentP.isMutedByAdmin || currentP.isMuted)
                            ? Icons.mic
                            : Icons.mic_off,
                        color: (currentP.isMutedByAdmin || currentP.isMuted)
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(
                        (currentP.isMutedByAdmin || currentP.isMuted)
                            ? 'Unmute'
                            : 'Mute',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setSheetState(() {
                          widget.audioRoomsBloc.add(
                            ToggleAdminMute(
                              roomId: widget.currentRoom.id,
                              participantId: currentP.userId,
                              mutedByAdmin: !currentP.isMutedByAdmin,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                    ),
                    if (widget.currentUserId ==
                        widget.currentRoom.creatorId) ...[
                      if (widget.currentRoom.settings.adminIds.contains(
                        currentP.userId,
                      ))
                        ListTile(
                          leading: const Icon(
                            Icons.shield_outlined,
                            color: Colors.orangeAccent,
                          ),
                          title: const Text(
                            'Dismiss Admin Role',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Close moderation sheet
                            // Demote logic
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove Admin?'),
                                content: Text(
                                  'Are you sure you want to remove ${currentP.userName} from admins?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // Close dialog

                                      try {
                                        final DocumentReference roomRef =
                                            FirebaseFirestore.instance
                                                .collection('audio_rooms_v2')
                                                .doc(widget.currentRoom.id);

                                        // 1. Remove from settings.adminIds
                                        final List<dynamic> updatedAdminIds =
                                            List.from(
                                          widget.currentRoom.settings.adminIds,
                                        );
                                        updatedAdminIds.remove(currentP.userId);

                                        // 2. Update isHost field in active participants list if they are in the room
                                        List<dynamic> updatedParticipants =
                                            widget.currentRoom.participants
                                                .map((p) => p.toJson())
                                                .toList();
                                        for (var p in updatedParticipants) {
                                          if (p is Map &&
                                              p['userId'] == currentP.userId) {
                                            p['isHost'] = false;
                                          }
                                        }

                                        await roomRef.update({
                                          'settings.adminIds': updatedAdminIds,
                                          'participants': updatedParticipants,
                                        });

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${currentP.userName} removed from admins',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error removing admin: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        ListTile(
                          leading: const Icon(
                            Icons.shield,
                            color: Colors.purpleAccent,
                          ),
                          title: const Text(
                            'Make Admin',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Close moderation sheet
                            // Promote logic
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Make Admin?'),
                                content: Text(
                                  'Are you sure you want to promote ${currentP.userName} to Admin? They will have moderation privileges.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // Close dialog

                                      try {
                                        final DocumentReference roomRef =
                                            FirebaseFirestore.instance
                                                .collection('audio_rooms_v2')
                                                .doc(widget.currentRoom.id);

                                        // 1. Add to settings.adminIds
                                        final List<dynamic> updatedAdminIds =
                                            List.from(
                                          widget.currentRoom.settings.adminIds,
                                        );
                                        if (!updatedAdminIds.contains(
                                          currentP.userId,
                                        )) {
                                          updatedAdminIds.add(currentP.userId);
                                        }

                                        // 2. Update isHost field in active participants list if they are in the room
                                        List<dynamic> updatedParticipants =
                                            widget.currentRoom.participants
                                                .map((p) => p.toJson())
                                                .toList();
                                        for (var p in updatedParticipants) {
                                          if (p is Map &&
                                              p['userId'] == currentP.userId) {
                                            p['isHost'] = true;
                                          }
                                        }

                                        await roomRef.update({
                                          'settings.adminIds': updatedAdminIds,
                                          'participants': updatedParticipants,
                                        });

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${currentP.userName} is now an Admin',
                                            ),
                                            backgroundColor: Colors.purple,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error making admin: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Make Admin'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    ListTile(
                      leading: const Icon(
                        Icons.exit_to_app,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Remove from room',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(
                          KickParticipant(
                            roomId: widget.currentRoom.id,
                            hostId: widget.currentUserId,
                            participantId: currentP.userId,
                            reason: 'Removed by admin',
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: const Text(
                        'Block user from room',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.audioRoomsBloc.add(
                          BlockParticipant(
                            roomId: widget.currentRoom.id,
                            hostId: widget.currentUserId,
                            participantId: currentP.userId,
                            reason: 'Blocked by admin',
                          ),
                        );
                      },
                    ),
                    ListTile(
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
                          widget.audioRoomsBloc.add(
                            ToggleMessagingBlock(
                              roomId: widget.currentRoom.id,
                              participantId: currentP.userId,
                              isBlocked: !currentP.isMessagingBlocked,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
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
                          widget.audioRoomsBloc.add(
                            ToggleSeatBlock(
                              roomId: widget.currentRoom.id,
                              participantId: currentP.userId,
                              isBlocked: !currentP.isSeatBlocked,
                            ),
                          );
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
  /// Fetches customization.selectedBackgroundThemeId Ã¢â â then resolves the
  /// file URL from StoreService, market_items catalog, or user_store_items.
  Future<void> _loadProfileSkin() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.participant.userId)
          .get();

      final data = userDoc.data();
      if (data == null) return;

      final customization = data['customization'] as Map<String, dynamic>?;

      // Check direct background theme / skin URLs first
      if (customization?['selectedBackgroundThemeUrl'] != null &&
          (customization!['selectedBackgroundThemeUrl'] as String).isNotEmpty) {
        if (mounted)
          setState(() => _profileSkinUrl =
              customization['selectedBackgroundThemeUrl'] as String);
        return;
      }
      if (customization?['selectedProfileSkinUrl'] != null &&
          (customization!['selectedProfileSkinUrl'] as String).isNotEmpty) {
        if (mounted)
          setState(() => _profileSkinUrl =
              customization['selectedProfileSkinUrl'] as String);
        return;
      }
      if (customization?['selectedRoomProfileBackgroundUrl'] != null &&
          (customization!['selectedRoomProfileBackgroundUrl'] as String)
              .isNotEmpty) {
        if (mounted)
          setState(() => _profileSkinUrl =
              customization['selectedRoomProfileBackgroundUrl'] as String);
        return;
      }

      final themeId = (customization?['selectedBackgroundThemeId'] ??
          customization?['selectedBackgroundTheme'] ??
          customization?['selectedProfileSkinId'] ??
          customization?['selectedRoomProfileBackgroundId'] ??
          customization?['selectedCardSkinId'] ??
          customization?['shortProfileThemeId']) as String?;

      if (themeId == null || themeId.isEmpty) return;

      if (themeId.startsWith('http://') ||
          themeId.startsWith('https://') ||
          themeId.startsWith('assets/')) {
        if (mounted) setState(() => _profileSkinUrl = themeId);
        return;
      }

      // 1. Try StoreService (supports market_items, VIP, SVIP configs)
      final details = await StoreService().getStoreItemDetails(themeId);
      String? url = details?['fileUrl'] ??
          details?['thumbnailUrl'] ??
          details?['imageUrl'] ??
          details?['svgUrl'];

      // 2. Fallback to market_items directly if not found
      if (url == null || url.isEmpty) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('market_items')
            .doc(themeId)
            .get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data()!;
          url = storeData['fileUrl'] as String? ??
              storeData['thumbnailUrl'] as String? ??
              storeData['imageUrl'] as String? ??
              storeData['svgUrl'] as String?;
        }
      }

      // 3. Fallback to user_store_items
      if (url == null || url.isEmpty) {
        final userStoreDoc = await FirebaseFirestore.instance
            .collection('user_store_items')
            .doc('${widget.participant.userId}_$themeId')
            .get();
        if (userStoreDoc.exists) {
          final uData = userStoreDoc.data()!;
          url = uData['fileUrl'] as String? ??
              uData['thumbnailUrl'] as String? ??
              uData['imageUrl'] as String? ??
              uData['image'] as String?;
        }
      }

      if (url != null && url.isNotEmpty && mounted) {
        setState(() => _profileSkinUrl = url);
      }
    } catch (e) {
      debugPrint('Error loading profile skin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final bool hasSkin = _profileSkinUrl != null && _profileSkinUrl!.isNotEmpty;
    final String skinUrlLower = (_profileSkinUrl ?? '').toLowerCase();
    final bool isVideoSkin = hasSkin &&
        (skinUrlLower.endsWith('.mp4') ||
            skinUrlLower.contains('.mp4?') ||
            skinUrlLower.contains('.webm') ||
            skinUrlLower.contains('.mov'));

    final double headerTopOffset =
        isVideoSkin ? (_avatarOverlap + 54) : (_avatarOverlap + 14);

    final Color textColor = hasSkin ? Colors.white : const Color(0xFF1F1F24);
    final Color subTextColor =
        hasSkin ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF75757F);
    final Color borderColor = hasSkin
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);
    final Color pillBgColor = hasSkin
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.05);
    final Color handleBarColor = hasSkin
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.15);

    final bool isCurrentOwner =
        widget.currentUserId == widget.currentRoom.creatorId;
    final bool isCurrentAdmin =
        widget.currentRoom.settings.adminIds.contains(widget.currentUserId);

    final bool isTargetOwner = widget.currentRoom.isCreator(p.userId) ||
        widget.currentRoom.creatorId == p.userId;
    final bool isTargetAdmin =
        widget.currentRoom.settings.adminIds.contains(p.userId) ||
            p.isHost ||
            widget.isParticipantHost;
    final bool isTargetSelf = p.userId == widget.currentUserId;

    final bool canInviteToMic =
        !isTargetSelf && !p.isSeated && (isCurrentOwner || isCurrentAdmin);
    final bool canModerate = !isTargetSelf &&
        (isCurrentOwner ||
            (isCurrentAdmin && !isTargetOwner && !isTargetAdmin));

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 1. Full Room Profile Skin / Background Theme that sits at the very background & overflows transparently above (for MP4 videos)
        if (isVideoSkin)
          Positioned.fill(
            top: -45,
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: UniversalAssetWidget(
                key: ValueKey(_profileSkinUrl),
                url: _profileSkinUrl!,
                fit: BoxFit.fill,
                isAlphaVideo: true,
                looping: true,
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          ),

        // 2. Sheet base body container (card content) - rendered ON TOP of the background skin
        Container(
          margin: const EdgeInsets.only(top: _avatarOverlap),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isVideoSkin
                ? Colors.transparent
                : (hasSkin
                    ? const Color(0xFF131722).withValues(alpha: 0.95)
                    : Colors.white),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: isVideoSkin
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          child: Column(
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
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(p.userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final userData =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      final searchId =
                          userData?['searchId']?.toString().isNotEmpty == true
                              ? userData!['searchId'].toString()
                              : p.userId;
                      final rawFollowers = userData?['followers'] ??
                          userData?['followersCount'] ??
                          userData?['followers_count'];
                      final int followersCount = rawFollowers is num
                          ? rawFollowers.toInt()
                          : (rawFollowers is String
                              ? int.tryParse(rawFollowers) ?? 0
                              : 0);
                      final agencyName = userData?['agencyName'];
                      final bool isVerified = userData?['isVerified'] == true;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Name, Verified Badge, Gender/Age, Country Flag Row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                child: AnimatedSvipName.fromUserId(
                                  userId: p.userId,
                                  defaultName: p.userName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  color: Colors.blue,
                                  size: 18,
                                ),
                              ],
                              // Gender & Age Pill
                              Builder(builder: (context) {
                                final gender =
                                    (userData?['gender'] ?? '').toString();
                                final birthday =
                                    (userData?['birthday'] ?? '').toString();
                                final bool isBoy =
                                    gender.toLowerCase() == 'boy' ||
                                        gender.toLowerCase() == 'male' ||
                                        gender.isEmpty;
                                int age = 18;
                                if (birthday.isNotEmpty) {
                                  try {
                                    final parts = birthday.split('-');
                                    if (parts.isNotEmpty) {
                                      final year = int.tryParse(parts[0]);
                                      if (year != null) {
                                        age = DateTime.now().year - year;
                                      }
                                    }
                                  } catch (_) {}
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isBoy
                                          ? const Color(0xFF42A5F5)
                                          : const Color(0xFFEC407A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isBoy ? Icons.male : Icons.female,
                                          color: Colors.white,
                                          size: 11,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$age',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              // Country Pill
                              Builder(builder: (context) {
                                final country =
                                    (userData?['country'] ?? 'BD').toString();
                                final countryData =
                                    CountryHelper.getCountryDataByNameOrCode(
                                        country);
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pillBgColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${countryData.code} ${countryData.flag}',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 2. ID and Followers Row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              UserIdBadgeWidget(
                                searchId: searchId,
                                badgeHeight: 25,
                                showCopyIcon: false,
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: searchId),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID Copied'),
                                      backgroundColor: Colors.black87,
                                      duration: Duration(milliseconds: 1000),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.copy,
                                  color: subTextColor,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Followers $followersCount',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // 3. Levels, Roles, and Badges Wall
                          FutureBuilder<Map<String, dynamic>>(
                            future: _getBadgeFuture(snapshot.data),
                            builder: (context, badgeSnapshot) {
                              final bData = badgeSnapshot.data;
                              final sendImageUrl =
                                  bData?['sendImageUrl'] as String?;
                              final receiveImageUrl =
                                  bData?['receiveImageUrl'] as String?;
                              final List<String> vipNameplateUrls =
                                  (bData?['vipNameplateUrls']
                                          as List<String>?) ??
                                      [];
                              final List<String> positionNameplateUrls =
                                  (bData?['positionNameplateUrls']
                                          as List<String>?) ??
                                      [];
                              final List<String> otherNameplateUrls =
                                  (bData?['otherNameplateUrls']
                                          as List<String>?) ??
                                      [];
                              final List<String> badgeUrls =
                                  (bData?['badgeUrls'] as List<String>?) ?? [];

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 1. VIP, Sending Lv, Receiving Lv, and Position Nameplates (Upper Serial)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      // 1. VIP Nameplate FIRST
                                      if (vipNameplateUrls.isNotEmpty)
                                        ...vipNameplateUrls
                                            .map((npUrl) => SizedBox(
                                                  height: 18,
                                                  child: UniversalAssetWidget(
                                                    url: npUrl,
                                                    fit: BoxFit.contain,
                                                  ),
                                                )),
                                      // 2. Sending Level
                                      if (sendImageUrl != null)
                                        _buildLevelImageBadge(sendImageUrl),
                                      // 3. Receiving Level
                                      if (receiveImageUrl != null)
                                        _buildLevelImageBadge(receiveImageUrl),
                                      // 4. Position Nameplates (Agency, Host, Seller)
                                      if (positionNameplateUrls.isNotEmpty)
                                        ...positionNameplateUrls
                                            .map((npUrl) => SizedBox(
                                                  height: 18,
                                                  child: UniversalAssetWidget(
                                                    url: npUrl,
                                                    fit: BoxFit.contain,
                                                  ),
                                                )),
                                    ],
                                  ),

                                  // 2. All other nameplates (Lower Serial)
                                  if (otherNameplateUrls.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: otherNameplateUrls
                                          .map((npUrl) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 2),
                                                child: SizedBox(
                                                  height: 22,
                                                  child: UniversalAssetWidget(
                                                    url: npUrl,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  // Badges / Medals Wall Row
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BadgeWallPage(
                                            userID: p.userId,
                                            userName: p.userName,
                                            badgeItems: const [],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: pillBgColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (badgeUrls.isNotEmpty)
                                            ...badgeUrls.take(5).map((url) =>
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 3),
                                                  child: SizedBox(
                                                    width: 36,
                                                    height: 36,
                                                    child: UniversalAssetWidget(
                                                      url: url,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ))
                                          else ...[
                                            const Icon(
                                                Icons.military_tech_rounded,
                                                color: Colors.amber,
                                                size: 22),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Badge Wall',
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.chevron_right,
                                            color: subTextColor.withValues(
                                                alpha: 0.6),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons - fade in last
              FadeTransition(
                opacity: _buttonsFade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: p.userId == widget.currentUserId
                      ? // Own profile: single wide Send Gift button
                      SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6C63FF),
                                  Color(0xFFE91E63),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: widget.onSendGift,
                              icon: const Icon(
                                Icons.card_giftcard,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Send Gift to Room',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        )
                      : // Other user: 3 horizontal buttons side-by-side: [ Follow ] [ Send Gift ] [ Message ]
                      Row(
                          children: [
                            // 1. Follow button (Left)
                            Expanded(
                              flex: 3,
                              child: FollowButton(
                                currentUserId: widget.currentUserId,
                                targetUserId: p.userId,
                                targetUserName: p.userName,
                                followController: widget.followController,
                                initialFollowStatus: widget.followController
                                    .isFollowing(p.userId),
                                textColor: hasSkin
                                    ? Colors.white
                                    : const Color(0xFF6C63FF),
                                borderColor: borderColor,
                                backgroundColor: pillBgColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                borderRadius: BorderRadius.circular(14),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. Send Gift button (Center)
                            Expanded(
                              flex: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFFE91E63),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: widget.onSendGift,
                                  icon: const Icon(
                                    Icons.card_giftcard,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Send Gift',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. Message button (Right)
                            Expanded(
                              flex: 3,
                              child: OutlinedButton.icon(
                                onPressed: widget.onMessage,
                                icon: Icon(
                                  Icons.chat_bubble_outline,
                                  color: hasSkin
                                      ? Colors.white
                                      : const Color(0xFF6C63FF),
                                  size: 16,
                                ),
                                label: Text(
                                  'Message',
                                  style: TextStyle(
                                    color: hasSkin
                                        ? Colors.white
                                        : const Color(0xFF6C63FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: pillBgColor,
                                  side: BorderSide(
                                    color: borderColor,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),

        // 2.5 SVGA / Image room profile skin overlay over the solid container
        if (!isVideoSkin && hasSkin)
          Positioned.fill(
            top: -45,
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: UniversalAssetWidget(
                key: ValueKey(_profileSkinUrl),
                url: _profileSkinUrl!,
                fit: BoxFit.fill,
                isAlphaVideo: false,
                looping: true,
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          ),

        // 3. Top-Left Header: Mention Button & Role Badge (Owner, Admin, Member, Viewer)
        Positioned(
          top: headerTopOffset,
          left: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.participant.userId != widget.currentUserId) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.alternate_email, color: textColor, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onMention?.call(widget.participant.userName);
                  },
                ),
                const SizedBox(width: 8),
              ],
              _buildRoleBadge(p),
            ],
          ),
        ),

        // 4. Top-Right Header Actions (Invite to Mic button + Settings button)
        if (widget.participant.userId != widget.currentUserId)
          Positioned(
            top: headerTopOffset,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Invite to Mic Button
                if (canInviteToMic)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onInviteToMic?.call(p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF9800).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.mic, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Invite',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Settings Button for Admin/Owner
                if (canModerate) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.settings, color: textColor, size: 22),
                    onPressed: () {
                      Navigator.pop(context);
                      _showModerationSheet(context, widget.participant);
                    },
                  ),
                ],
              ],
            ),
          ),

        // 5. Avatar floating above the sheet inside the golden wing frame – tap to open full profile
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

  const UserGiftingStatsWidget({super.key, required this.transactions});

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
        const DynamicDiamondIcon(width: 10, height: 10),
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
        Colors.blueAccent,
      ];
    } else if (len <= 2) {
      colors = [Colors.amber, Colors.orange, Colors.yellow, Colors.amber];
    } else if (len <= 4) {
      colors = [
        Colors.purpleAccent,
        Colors.deepPurple,
        Colors.pinkAccent,
        Colors.purpleAccent,
      ];
    } else if (len <= 6) {
      colors = [Colors.blue, Colors.lightBlue, Colors.cyan, Colors.blue];
    } else {
      // Normal 7-8 digits (fallback if somehow animated)
      return Text(
        'ID: ${widget.idStr}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      );
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
