import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/services/daily_checkin_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/create_room_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_list.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_top_rankings_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_id_search_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/banner_carousel.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/services/social_affinity_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/helpers/country_helper.dart';
import 'package:chat_messenger/api/user_api.dart';

/// Audio Rooms v2 Screen - Main page for audio rooms
class AudioRoomsV2Screen extends StatefulWidget {
  final bool showAppBar;
  const AudioRoomsV2Screen({super.key, this.showAppBar = true});

  @override
  State<AudioRoomsV2Screen> createState() => _AudioRoomsV2ScreenState();
}

class _AudioRoomsV2ScreenState extends State<AudioRoomsV2Screen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AudioRoomsBloc _audioRoomsBloc;
  User? _currentUser;
  String _selectedCategory = 'Trending';
  String _selectedCountryCode = 'ALL'; // 'ALL' or 2-letter ISO code (e.g., 'BD', 'IN', 'SA')
  final Map<String, String> _creatorCountryCache = {}; // creatorId -> countryCode

  // Cache the last loaded rooms so room-stream states don't wipe the list
  AudioRoomsLoaded? _cachedLoadedState;
  late Worker _settingsWorker;
  bool _isNavigatingToRoom = false;
  Timer? _trendingCycleTimer;

  @override
  void initState() {
    super.initState();
    final settingsService = Get.find<GlobalSettingsService>();
    final int initialLength = settingsService.isLiveVideoRoomEnabled.value ? 4 : 3;
    _tabController = TabController(length: initialLength, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    
    _settingsWorker = ever(settingsService.isLiveVideoRoomEnabled, (bool isEnabled) {
      if (mounted) {
        final newLength = isEnabled ? 4 : 3;
        if (_tabController.length != newLength) {
          final oldIndex = _tabController.index;
          _tabController.dispose();
          _tabController = TabController(
            length: newLength, 
            vsync: this, 
            initialIndex: oldIndex >= newLength ? newLength - 1 : oldIndex
          );
          _tabController.addListener(() {
            if (mounted) setState(() {});
          });
          setState(() {});
        }
      }
    });
    _currentUser = AuthController.instance.currentUser;
    if (_currentUser != null) {
      SocialAffinityService().init(_currentUser!.userId);
    }

    // Initialize BLoC
    _audioRoomsBloc = AudioRoomsBloc(
      repository: AudioRoomsRepository(),
    );

    // Load initial data
    _loadInitialData();

    // 2-minute periodic refresh timer to smoothly climb rooms with high active user counts to the top
    _trendingCycleTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        debugPrint('🔄 [AudioRoomsV2Screen] 2-minute live user trending refresh triggered');
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DailyCheckInService.checkAndShowCheckIn(context);
    });
  }

  @override
  void dispose() {
    _trendingCycleTimer?.cancel();
    _settingsWorker.dispose();
    _tabController.dispose();

    // Don't close the BLoC if there's a minimized room - it's still needed
    final hasMinimizedRoom = Get.isRegistered<MinimizedRoomController>() &&
        Get.find<MinimizedRoomController>().hasMinimizedRoom;

    if (!hasMinimizedRoom) {
      _audioRoomsBloc.stopListeningToAllRooms();
      _audioRoomsBloc.close();
    } else {
      debugPrint(
          '🔽 [AudioRoomsV2Screen] Skipping BLoC close - minimized room active');
    }
    super.dispose();
  }

  /// Load initial data
  void _loadInitialData() {
    // Start real-time stream for all rooms
    _audioRoomsBloc.startListeningToAllRooms();
    
    // Fallback load data for current user if needed, though stream should handle it
    _audioRoomsBloc.add(const LoadAudioRooms());
    if (_currentUser != null) {
      _audioRoomsBloc.add(LoadUserAudioRooms(userId: _currentUser!.userId));
    }
  }

  /// Handle pull to refresh
  Future<void> _handleRefresh() async {
    // Clear cache and force refresh from server
    await _audioRoomsBloc.clearCacheAndRefresh();

    // Wait a bit to ensure refresh completes
    await Future.delayed(const Duration(milliseconds: 500));
  }



  /// Handle room tap
  void _handleRoomTap(AudioRoomV2 room) {
    if (_isNavigatingToRoom) {
      debugPrint('🎯 Already navigating to room, ignoring duplicate tap');
      return;
    }
    _isNavigatingToRoom = true;
    try {
      if (_currentUser == null) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar('Please log in to view rooms');
        return;
      }

      if (room.isUserBlocked(_currentUser!.userId)) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar('You are blocked from entering this room.');
        return;
      }

      if (room.isUserKickedRecently(_currentUser!.userId)) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar(
            'You have been removed from this room and cannot join for 24 hours.');
        return;
      }

      MinimizedRoomController.checkAndProceed(
        context: context,
        targetRoom: room,
        onProceed: () {
          debugPrint('🎯 Navigating directly to room for instant join...');
          _navigateToRoom(room);
        },
        onCancel: () {
          _isNavigatingToRoom = false;
        },
      );
    } catch (e) {
      _isNavigatingToRoom = false;
      debugPrint('🎯 Error in _handleRoomTap: $e');
      _showErrorSnackBar('Failed to access room. Please try again.');
    }
  }

  /// Handle join room
  void _handleJoinRoom(AudioRoomV2 room) {
    if (_isNavigatingToRoom) {
      debugPrint('🎯 Already navigating to room, ignoring duplicate join');
      return;
    }
    _isNavigatingToRoom = true;
    try {
      if (_currentUser == null) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar('Please log in to join a room');
        return;
      }

      if (room.isUserBlocked(_currentUser!.userId)) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar('You are blocked from entering this room.');
        return;
      }

      if (room.isUserKickedRecently(_currentUser!.userId)) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar(
            'You have been removed from this room and cannot join for 24 hours.');
        return;
      }

      if (room.isFull) {
        _isNavigatingToRoom = false;
        _showErrorSnackBar('Room is full');
        return;
      }

      MinimizedRoomController.checkAndProceed(
        context: context,
        targetRoom: room,
        onProceed: () {
          debugPrint('🎯 Navigating directly to room for instant join...');
          _navigateToRoom(room);
        },
        onCancel: () {
          _isNavigatingToRoom = false;
        },
      );
    } catch (e) {
      _isNavigatingToRoom = false;
      debugPrint('🎯 Error in _handleJoinRoom: $e');
      _showErrorSnackBar('Failed to join room. Please try again.');
    }
  }

  /// Navigate to room screen
  void _navigateToRoom(AudioRoomV2 room) async {
    try {
      final minimizedController = Get.isRegistered<MinimizedRoomController>()
          ? Get.find<MinimizedRoomController>()
          : null;

      final AudioRoomsBloc roomBloc = (minimizedController != null &&
              minimizedController.minimizedRoom?.id == room.id &&
              minimizedController.audioRoomsBloc != null &&
              !minimizedController.audioRoomsBloc!.isClosed)
          ? minimizedController.audioRoomsBloc!
          : AudioRoomsBloc(repository: AudioRoomsRepository());

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudioRoomScreen(
            room: room,
            audioRoomsBloc: roomBloc,
          ),
        ),
      );
      // Reload rooms list when returning (e.g. after minimizing or exiting a room)
      _loadInitialData();
    } catch (e) {
      debugPrint('🎯 Error navigating to room: $e');
      _showErrorSnackBar('Failed to open room. Please try again.');
    } finally {
      _isNavigatingToRoom = false;
    }
  }



  /// Show create room bottom sheet
  void _showCreateRoomBottomSheet() {
    if (_currentUser == null) {
      _showErrorSnackBar('Please log in to create a room');
      return;
    }

    final state = _audioRoomsBloc.state;
    if (state is AudioRoomsLoaded) {
      String? targetCategory;
      if (_tabController.index == 2) targetCategory = 'Audio';
      if (_tabController.index == 3) targetCategory = 'Live';

      if (targetCategory != null) {
        AudioRoomV2? existingRoom;
        for (final room in state.userRooms) {
          if (room.creatorId == _currentUser!.userId) {
            final isRoomLive = room.category == 'Live';
            if ((targetCategory == 'Live') == isRoomLive) {
              existingRoom = room;
              break;
            }
          }
        }

        if (existingRoom != null) {
          debugPrint('🏠 [AudioRooms] Found existing $targetCategory room. Resuming directly...');
          _audioRoomsBloc.add(ResumeAudioRoom(room: existingRoom));
          _navigateToRoom(existingRoom);
          return;
        }
      }
    }

    // Get fresh user data
    final currentUser = AuthController.instance.currentUser;

    showCreateRoomBottomSheet(
      context: context,
      currentUser: currentUser,
      audioRoomsBloc: _audioRoomsBloc,
      onRoomCreatedAndNavigate: (room) {
        // Navigate directly to the created room
        _navigateToRoom(room);
      },
      onRoomCreated: () {
        // Fallback: Refresh data after room creation
        _handleRefresh();
      },
    );
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

  /// Show loading snackbar
  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _audioRoomsBloc,
      child: PopScope(
        canPop: _tabController.index == 1,
        onPopInvoked: (bool didPop) {
          if (didPop) return;
          _tabController.animateTo(1);
        },
        child: Obx(() {
          final themeService = Get.find<AppThemeService>();
          
          final String? bgUrl = themeService.getScreenBgUrl('room');
          final Color? bgColor = themeService.getScreenColor('room');
          final bool isLightBg = bgColor != null && bgColor.computeLuminance() > 0.5;

          final Color primaryTextColor = themeService.getScreenTextColor('room') ??
              (isLightBg ? Colors.black87 : Colors.white);
          final Color secondaryTextColor =
              themeService.getScreenSecondaryTextColor('room') ??
                  (isLightBg ? Colors.black54 : Colors.white70);

          final effectiveBgUrl = bgUrl;
          final effectiveBgColor = bgColor;

          return Container(
            decoration: (effectiveBgUrl != null && effectiveBgUrl.isNotEmpty)
                ? BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(effectiveBgUrl),
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: primaryTextColor,
                  displayColor: primaryTextColor,
                ),
              ),
              child: Scaffold(
                backgroundColor: (effectiveBgUrl != null && effectiveBgUrl.isNotEmpty)
                    ? Colors.transparent
                    : (effectiveBgColor ?? const Color(0xFF120C1C)),
                appBar: widget.showAppBar
                    ? _buildAppBar(primaryTextColor, secondaryTextColor, isLightBg)
                    : null,
                body: _buildBody(primaryTextColor, secondaryTextColor, isLightBg),
                floatingActionButton: _buildFloatingActionButton(),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar(
    Color primaryTextColor,
    Color secondaryTextColor,
    bool isLightBg,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          _buildTopNavTab(
            'mine'.tr,
            0,
            isActive: _tabController.index == 0,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            isLightBg: isLightBg,
          ),
          _buildTopNavTab(
            'all'.tr,
            1,
            isActive: _tabController.index == 1,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            isLightBg: isLightBg,
          ),
          _buildTopNavTab(
            'party'.tr,
            2,
            isActive: _tabController.index == 2,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            isLightBg: isLightBg,
          ),
          _buildTopNavTab(
            'live'.tr,
            3,
            isActive: _tabController.index == 3,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            isLightBg: isLightBg,
          ),
        ],
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.note_alt_outlined, color: Colors.orangeAccent),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.workspace_premium, color: Colors.amber),
          onPressed: () {},
        ),
        // Top Rankings icon
        Obx(() => IconButton(
          tooltip: 'Top Rankings',
          iconSize: 46,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: _buildDynamicHeaderIcon(
            customUrl: Get.find<AppThemeService>().trophyIconUrl.value,
            fallbackIcon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 40),
            size: 46,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoomTopRankingsScreen(audioRoomsBloc: _audioRoomsBloc),
            ),
          ),
        )),
        // Room ID Search icon
        Obx(() => IconButton(
          tooltip: 'Search by Room ID',
          iconSize: 42,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: _buildDynamicHeaderIcon(
            customUrl: Get.find<AppThemeService>().searchIconUrl.value,
            fallbackIcon: Icon(IconlyLight.search, color: secondaryTextColor, size: 36),
            size: 42,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoomIdSearchScreen(audioRoomsBloc: _audioRoomsBloc),
            ),
          ),
        )),
      ],
    );
  }
  Widget _buildDynamicHeaderIcon({
    required String customUrl,
    required Widget fallbackIcon,
    double size = 24,
  }) {
    final String trimmed = customUrl.trim();
    if (trimmed.isNotEmpty) {
      final lower = trimmed.toLowerCase();
      if (lower.contains('.svga')) {
        return SizedBox(
          width: size,
          height: size,
          child: SVGAEasyPlayer(resUrl: trimmed),
        );
      }
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallbackIcon,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return fallbackIcon;
          },
        ),
      );
    }
    return fallbackIcon;
  }

  Widget _buildTopNavTab(
    String label,
    int index, {
    bool isActive = false,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    bool isLightBg = false,
  }) {
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? primaryTextColor : secondaryTextColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 18,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: isLightBg ? Colors.blueAccent : primaryTextColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody([Color primaryTextColor = Colors.white, Color secondaryTextColor = Colors.white70, bool isLightBg = false]) {
    return BlocConsumer<AudioRoomsBloc, AudioRoomsState>(
      listener: (context, state) {
        // Cache loaded state so room-stream emissions don't wipe the list
        if (state is AudioRoomsLoaded) {
          _cachedLoadedState = state;
        }

        if (state is AudioRoomJoined) {
          debugPrint('🎯 Room joined successfully');
        } else if (state is AudioRoomJoinFailed) {
          debugPrint('🎯 Room join failed: ${state.message}');
          _showErrorSnackBar(state.message);
        } else if (state is AudioRoomCreationFailed) {
          debugPrint('🎯 Room creation failed: ${state.message}');
          _showErrorSnackBar(state.message);
        } else if (state is AudioRoomsError) {
          debugPrint('🎯 Audio rooms error: ${state.message}');
          _showErrorSnackBar(state.message);
        } else if (state is JoiningAudioRoom) {
          debugPrint('🎯 Joining room: ${state.roomId}');
          _showLoadingSnackBar('Joining room...');
        } else if (state is CreatingAudioRoom) {
          debugPrint('🎯 Creating room...');
          _showLoadingSnackBar('Creating room...');
        }
      },
      builder: (context, state) {
        // Use cached loaded state as fallback when BLoC emits
        // room-specific states (AudioRoomUpdated, AgoraChannelJoined, etc.)
        // that the list tabs don't handle.
        final effectiveState = (state is AudioRoomsLoaded ||
                state is AudioRoomsLoading ||
                state is AudioRoomsError)
            ? state
            : _cachedLoadedState ?? state;

        return Column(
          children: [
            if (!widget.showAppBar)
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    _buildTopNavTab(
                      'Mine',
                      0,
                      isActive: _tabController.index == 0,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isLightBg: isLightBg,
                    ),
                    _buildTopNavTab(
                      'All',
                      1,
                      isActive: _tabController.index == 1,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isLightBg: isLightBg,
                    ),
                    _buildTopNavTab(
                      'Party',
                      2,
                      isActive: _tabController.index == 2,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isLightBg: isLightBg,
                    ),
                    if (Get.find<GlobalSettingsService>().isLiveVideoRoomEnabled.value)
                      _buildTopNavTab(
                        'Live',
                        3,
                        isActive: _tabController.index == 3,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        isLightBg: isLightBg,
                      ),
                    const Spacer(),
                    // Top Rankings icon
                    Obx(() => IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      constraints: const BoxConstraints(),
                      tooltip: 'Top Rankings',
                      iconSize: 46,
                      icon: _buildDynamicHeaderIcon(
                        customUrl: Get.find<AppThemeService>().trophyIconUrl.value,
                        fallbackIcon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 40),
                        size: 46,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomTopRankingsScreen(audioRoomsBloc: _audioRoomsBloc),
                        ),
                      ),
                    )),
                    const SizedBox(width: 4),
                    // Room ID Search icon
                    Obx(() => IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      constraints: const BoxConstraints(),
                      tooltip: 'Search by Room ID',
                      iconSize: 42,
                      icon: _buildDynamicHeaderIcon(
                        customUrl: Get.find<AppThemeService>().searchIconUrl.value,
                        fallbackIcon: Icon(
                          IconlyLight.search,
                          color: secondaryTextColor,
                          size: 36,
                        ),
                        size: 42,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomIdSearchScreen(audioRoomsBloc: _audioRoomsBloc),
                        ),
                      ),
                    )),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // My Rooms tab (Mine)
                    _buildMyRoomsTab(effectiveState),
                    // All Rooms tab
                    _buildAllRoomsTab(effectiveState),
                    // Party tab (Audio Only)
                    _buildPartyTab(effectiveState),
                    // Live tab (Video Only)
                    if (Get.find<GlobalSettingsService>().isLiveVideoRoomEnabled.value)
                      _buildLiveTab(effectiveState),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getRoomCountryCode(AudioRoomV2 room) {
    if (room.countryCode != null && room.countryCode!.isNotEmpty) {
      return CountryHelper.detectCountryCodeFromPhoneOrUser(countryStr: room.countryCode);
    }
    if (room.creatorCountry != null && room.creatorCountry!.isNotEmpty) {
      return CountryHelper.detectCountryCodeFromPhoneOrUser(countryStr: room.creatorCountry);
    }
    if (room.creatorPhone != null && room.creatorPhone!.isNotEmpty) {
      return CountryHelper.detectCountryCodeFromPhoneOrUser(phone: room.creatorPhone);
    }
    if (_creatorCountryCache.containsKey(room.creatorId)) {
      return _creatorCountryCache[room.creatorId]!;
    }
    if (_currentUser != null && _currentUser!.userId == room.creatorId) {
      final code = CountryHelper.detectCountryCodeFromPhoneOrUser(
        phone: _currentUser!.number,
        countryStr: _currentUser!.country,
      );
      _creatorCountryCache[room.creatorId] = code;
      return code;
    }
    return 'BD';
  }

  void _preloadCreatorCountries(List<AudioRoomV2> rooms) {
    for (final room in rooms) {
      if (room.creatorId.isEmpty) continue;
      if (_creatorCountryCache.containsKey(room.creatorId)) continue;
      if (_currentUser != null && _currentUser!.userId == room.creatorId) continue;

      // Mark as pending to avoid redundant calls
      _creatorCountryCache[room.creatorId] = room.countryCode ?? 'BD';

      UserApi.getUser(room.creatorId).then((user) {
        if (user != null) {
          final code = CountryHelper.detectCountryCodeFromPhoneOrUser(
            phone: user.number,
            countryStr: user.country,
          );
          _creatorCountryCache[room.creatorId] = code;
        }
      }).catchError((_) {});
    }
  }

  void _showCountryPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CountryPickerSheetWidget(
          selectedCountryCode: _selectedCountryCode,
          onSelectCountry: (code) {
            setState(() {
              _selectedCountryCode = code;
              _selectedCategory = 'All Rooms';
            });
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  /// Build All Rooms tab (Audio + Video)
  Widget _buildAllRoomsTab(AudioRoomsState state) {
    final headerWidget = Column(
      children: [
        const BannerCarousel(),
        _buildCategoryFilterRow(),
      ],
    );

    if (state is AudioRoomsLoading) {
      return RoomList(
        rooms: const [],
        title: 'All Rooms',
        showTitle: false,
        isLoading: true,
        isGrid: true,
        headerWidget: headerWidget,
      );
    }

    if (state is AudioRoomsLoaded) {
      final allRooms = state.isSearching ? state.searchResults : state.popularRooms;
      _preloadCreatorCountries(allRooms);
      List<AudioRoomV2> filteredRooms;
      if (_selectedCategory == 'Trending' || _selectedCategory == 'Trending 🔥') {
        final affinity = SocialAffinityService();
        filteredRooms = List<AudioRoomV2>.from(allRooms)..sort((a, b) {
          final aPinned = a.isCurrentlyPinned;
          final bPinned = b.isCurrentlyPinned;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;

          final scoreA = affinity.calculateBoostedScore(
            a.trendingScore,
            a.creatorId,
            participantIds: a.participants.map((p) => p.userId).toList(),
            participantCount: a.onlineCount > 0 ? a.onlineCount : a.participants.length,
            seatedCount: a.activeSpeakers > 0 ? a.activeSpeakers : a.participants.where((p) => p.isSeated || p.isSpeaker).length,
            uniqueJoiners10m: a.uniqueJoiners10m,
            giftCoins10m: a.giftCoins10m > 0 ? a.giftCoins10m : a.recentGiftsDiamonds,
            likes10m: a.likes10m,
            messages10m: a.messages10m,
            growthRate: a.growthRate,
            avgStayTime: a.avgStayTime,
            itemUniqueId: a.id,
          );
          final scoreB = affinity.calculateBoostedScore(
            b.trendingScore,
            b.creatorId,
            participantIds: b.participants.map((p) => p.userId).toList(),
            participantCount: b.onlineCount > 0 ? b.onlineCount : b.participants.length,
            seatedCount: b.activeSpeakers > 0 ? b.activeSpeakers : b.participants.where((p) => p.isSeated || p.isSpeaker).length,
            uniqueJoiners10m: b.uniqueJoiners10m,
            giftCoins10m: b.giftCoins10m > 0 ? b.giftCoins10m : b.recentGiftsDiamonds,
            likes10m: b.likes10m,
            messages10m: b.messages10m,
            growthRate: b.growthRate,
            avgStayTime: b.avgStayTime,
            itemUniqueId: b.id,
          );
          return scoreB.compareTo(scoreA);
        });
      } else if (_selectedCategory == 'All Rooms') {
        filteredRooms = List<AudioRoomV2>.from(allRooms)..sort((a, b) {
          final aPinned = a.isCurrentlyPinned;
          final bPinned = b.isCurrentlyPinned;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          return b.participantCount.compareTo(a.participantCount);
        });
      } else {
        filteredRooms = allRooms.where((room) => room.category == _selectedCategory).toList()
          ..sort((a, b) {
            final aPinned = a.isCurrentlyPinned;
            final bPinned = b.isCurrentlyPinned;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return b.participantCount.compareTo(a.participantCount);
          });
      }

      if (_selectedCountryCode != 'ALL') {
        filteredRooms = filteredRooms.where((room) {
          return _getRoomCountryCode(room).toUpperCase() == _selectedCountryCode.toUpperCase();
        }).toList();
      }

      final countryData = _selectedCountryCode != 'ALL' ? CountryHelper.getCountryData(_selectedCountryCode) : null;
      return RoomList(
        rooms: filteredRooms,
        title: state.isSearching ? 'Search Results' : 'All Rooms',
        showTitle: false,
        showTotalCount: false,
        isGrid: true,
        headerWidget: headerWidget,
        onRoomTap: _handleRoomTap,
        onJoinRoom: _handleJoinRoom,
        emptyMessage: _selectedCountryCode != 'ALL'
            ? 'No rooms available for ${countryData?.flag ?? ''} ${countryData?.code ?? _selectedCountryCode}'
            : (state.isSearching
                ? 'No rooms found for "${state.searchQuery}"'
                : 'No rooms available in this category'),
      );
    }

    if (state is AudioRoomsError) {
      return _buildErrorWidget(state.message);
    }

    return RoomList(
      rooms: const [],
      title: 'All Rooms',
      showTitle: false,
      isGrid: true,
      headerWidget: headerWidget,
      emptyMessage: 'No rooms available',
    );
  }

  /// Build Party tab (Audio Only)
  Widget _buildPartyTab(AudioRoomsState state) {
    final headerWidget = Column(
      children: [
        const BannerCarousel(),
        _buildCategoryFilterRow(),
      ],
    );

    if (state is AudioRoomsLoading) {
      return RoomList(
        rooms: const [],
        title: 'Party Rooms',
        showTitle: false,
        isLoading: true,
        headerWidget: headerWidget,
      );
    }

    if (state is AudioRoomsLoaded) {
      final allRooms = state.isSearching ? state.searchResults : state.popularRooms;
      final audioRooms = allRooms.where((room) => room.category != 'Live').toList();
      _preloadCreatorCountries(audioRooms);
      List<AudioRoomV2> filteredRooms;
      if (_selectedCategory == 'Trending' || _selectedCategory == 'Trending 🔥') {
        final affinity = SocialAffinityService();
        filteredRooms = List<AudioRoomV2>.from(audioRooms)..sort((a, b) {
          final aPinned = a.isCurrentlyPinned;
          final bPinned = b.isCurrentlyPinned;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;

          final scoreA = affinity.calculateBoostedScore(
            a.trendingScore,
            a.creatorId,
            participantIds: a.participants.map((p) => p.userId).toList(),
            participantCount: a.onlineCount > 0 ? a.onlineCount : a.participants.length,
            seatedCount: a.activeSpeakers > 0 ? a.activeSpeakers : a.participants.where((p) => p.isSeated || p.isSpeaker).length,
            uniqueJoiners10m: a.uniqueJoiners10m,
            giftCoins10m: a.giftCoins10m > 0 ? a.giftCoins10m : a.recentGiftsDiamonds,
            likes10m: a.likes10m,
            messages10m: a.messages10m,
            growthRate: a.growthRate,
            avgStayTime: a.avgStayTime,
            itemUniqueId: a.id,
          );
          final scoreB = affinity.calculateBoostedScore(
            b.trendingScore,
            b.creatorId,
            participantIds: b.participants.map((p) => p.userId).toList(),
            participantCount: b.onlineCount > 0 ? b.onlineCount : b.participants.length,
            seatedCount: b.activeSpeakers > 0 ? b.activeSpeakers : b.participants.where((p) => p.isSeated || p.isSpeaker).length,
            uniqueJoiners10m: b.uniqueJoiners10m,
            giftCoins10m: b.giftCoins10m > 0 ? b.giftCoins10m : b.recentGiftsDiamonds,
            likes10m: b.likes10m,
            messages10m: b.messages10m,
            growthRate: b.growthRate,
            avgStayTime: b.avgStayTime,
            itemUniqueId: b.id,
          );
          return scoreB.compareTo(scoreA);
        });
      } else if (_selectedCategory == 'All Rooms') {
        filteredRooms = List<AudioRoomV2>.from(audioRooms)..sort((a, b) {
          final aPinned = a.isCurrentlyPinned;
          final bPinned = b.isCurrentlyPinned;
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          return b.participantCount.compareTo(a.participantCount);
        });
      } else {
        filteredRooms = audioRooms.where((room) => room.category == _selectedCategory).toList()
          ..sort((a, b) {
            final aPinned = a.isCurrentlyPinned;
            final bPinned = b.isCurrentlyPinned;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return b.participantCount.compareTo(a.participantCount);
          });
      }

      if (_selectedCountryCode != 'ALL') {
        filteredRooms = filteredRooms.where((room) {
          return _getRoomCountryCode(room).toUpperCase() == _selectedCountryCode.toUpperCase();
        }).toList();
      }

      final countryData = _selectedCountryCode != 'ALL' ? CountryHelper.getCountryData(_selectedCountryCode) : null;
      return RoomList(
        rooms: filteredRooms,
        title: state.isSearching ? 'Search Results' : 'Party Rooms',
        showTitle: false,
        showTotalCount: false,
        headerWidget: headerWidget,
        onRoomTap: _handleRoomTap,
        onJoinRoom: _handleJoinRoom,
        emptyMessage: _selectedCountryCode != 'ALL'
            ? 'No rooms available for ${countryData?.flag ?? ''} ${countryData?.code ?? _selectedCountryCode}'
            : (state.isSearching
                ? 'No rooms found for "${state.searchQuery}"'
                : 'No rooms available in this category'),
      );
    }

    if (state is AudioRoomsError) {
      return _buildErrorWidget(state.message);
    }

    return RoomList(
      rooms: const [],
      title: 'Party Rooms',
      showTitle: false,
      headerWidget: headerWidget,
      emptyMessage: 'No rooms available',
    );
  }

  Widget _buildCategoryFilterRow() {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg = screenBgColor != null && screenBgColor.computeLuminance() > 0.5;

    final primaryTextColor = themeService?.getScreenTextColor('room') ??
        (isLightBg ? Colors.black87 : Colors.white);
    final secondaryTextColor =
        themeService?.getScreenSecondaryTextColor('room') ??
            (isLightBg ? Colors.black54 : Colors.white70);

    final countryData = _selectedCountryCode != 'ALL'
        ? CountryHelper.getCountryData(_selectedCountryCode)
        : null;

    final categories = [
      {'name': 'Trending', 'emoji': '🔥'},
      {
        'name': 'All Rooms',
        'emoji': countryData != null ? countryData.flag : '🌐',
        'displayName': countryData != null ? countryData.code : 'All Rooms',
      },
      {'name': 'Game', 'emoji': '🎮'},
      {'name': 'PK', 'emoji': '⚔️'},
      {'name': 'Event', 'emoji': '🏆'},
      {'name': 'Islamic', 'emoji': '☪️'},
      {'name': 'Talk Show', 'emoji': '🎤'},
    ];
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final name = cat['name']!;
          final emoji = cat['emoji']!;
          final displayName = cat['displayName'] ?? name;
          final isSelected = _selectedCategory == name;
          final isAllRoomsChip = name == 'All Rooms';

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                if (isAllRoomsChip) {
                  setState(() {
                    _selectedCategory = 'All Rooms';
                  });
                  _showCountryPickerBottomSheet(context);
                } else {
                  setState(() {
                    _selectedCategory = name;
                  });
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryTextColor.withValues(alpha: isLightBg ? 0.12 : 0.22)
                        : (isLightBg ? Colors.black.withValues(alpha: 0.04) : Colors.transparent),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primaryTextColor.withValues(alpha: isLightBg ? 0.35 : 0.45)
                          : (isLightBg ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.15)),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: isSelected ? primaryTextColor : secondaryTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      if (isAllRoomsChip) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: secondaryTextColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build my rooms tab (Mine)
  Widget _buildMyRoomsTab(AudioRoomsState state) {
    if (state is AudioRoomsLoading) {
      return const RoomList(
        rooms: [],
        title: 'My Room',
        isLoading: true,
      );
    }

    if (state is AudioRoomsLoaded) {
      return RoomList(
        rooms: state.userRooms,
        title: 'My Room',
        showTotalCount: false,
        onRoomTap: _handleRoomTap,
        onJoinRoom: _handleJoinRoom,
        emptyMessage: 'You haven\'t created or joined any rooms yet',
        emptyWidget: _buildMyRoomsEmptyWidget(),
      );
    }

    if (state is AudioRoomsError) {
      return _buildErrorWidget(state.message);
    }

    return RoomList(
      rooms: const [],
      title: 'My Room',
      showTotalCount: false,
      emptyMessage: 'You haven\'t created or joined any rooms yet',
      emptyWidget: _buildMyRoomsEmptyWidget(),
    );
  }

  /// Build Live tab (Video)
  Widget _buildLiveTab(AudioRoomsState state) {
    if (state is AudioRoomsLoading) {
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: BannerCarousel()),
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            ),
          ),
        ],
      );
    }

    final List<AudioRoomV2> liveRooms = [];
    if (state is AudioRoomsLoaded) {
      final allRooms = state.isSearching ? state.searchResults : state.popularRooms;
      liveRooms.addAll(allRooms.where((room) => room.category == 'Live'));
    }

    final currentUser = AuthController.instance.currentUser;
    
    bool hasActiveLiveRoom = false;
    if (state is AudioRoomsLoaded) {
      hasActiveLiveRoom = state.userRooms.any(
        (room) => room.creatorId == currentUser.userId && room.category == 'Live'
      );
    }

    List<Widget> roomWidgets = [];

    // If user has no active live room, show Create button
    if (!hasActiveLiveRoom) {
      roomWidgets.add(
        GestureDetector(
          onTap: () async {
             _showLoadingSnackBar('Creating Live Room...');
             try {
               final repository = AudioRoomsRepository();
               final newRoom = await repository.createRoom(
                 name: '${currentUser.fullname}\'s Live',
                 description: 'Welcome to my live stream!',
                 creatorId: currentUser.userId,
                 creatorName: currentUser.fullname,
                 creatorImageUrl: currentUser.photoUrl,
                 category: 'Live',
               );
               
               if (mounted) {
                 ScaffoldMessenger.of(context).hideCurrentSnackBar();
                 _navigateToRoom(newRoom);
               }
             } catch (e) {
               if (mounted) {
                 ScaffoldMessenger.of(context).hideCurrentSnackBar();
                 _showErrorSnackBar('Failed to create Live Room: ${e.toString()}');
               }
             }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
              color: Colors.grey[900],
              image: currentUser.photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(currentUser.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'CREATE',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Live Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundImage: currentUser.photoUrl.isNotEmpty
                                  ? NetworkImage(currentUser.photoUrl)
                                  : null,
                              backgroundColor: Colors.pinkAccent.withValues(alpha: 0.3),
                              child: currentUser.photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 6, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Create yours now',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
        )
      );
    }

    // Add actual live rooms
    for (var room in liveRooms) {
      final imageUrl = room.imageUrl ?? room.creatorImageUrl;
      final creatorImageUrl = room.creatorImageUrl;
      
      roomWidgets.add(
        GestureDetector(
          onTap: () {
             _handleRoomTap(room);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF3E2B5E), Color(0xFF1E142B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                  if (room.roomFrameUrl != null &&
                      room.roomFrameUrl!.isNotEmpty &&
                      (room.roomFrameUntil == null ||
                          room.roomFrameUntil!.isAfter(DateTime.now())))
                    UniversalAssetWidget(
                      url: room.roomFrameUrl,
                      fit: BoxFit.cover,
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt, color: Colors.purpleAccent, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            '${room.joinedUserIds.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: room.creatorId.isNotEmpty
                              ? FirebaseFirestore.instance
                                  .collection('Users')
                                  .doc(room.creatorId)
                                  .snapshots()
                              : null,
                          builder: (context, userSnap) {
                            String displayName = room.creatorName;
                            String? liveAvatar = creatorImageUrl;
                            if (userSnap.hasData && userSnap.data!.exists) {
                              final uData = userSnap.data!.data() as Map<String, dynamic>?;
                              if (uData != null) {
                                if (uData['fullname'] != null &&
                                    uData['fullname'].toString().trim().isNotEmpty) {
                                  displayName = uData['fullname'].toString().trim();
                                }
                                if (uData['photoUrl'] != null &&
                                    uData['photoUrl'].toString().trim().isNotEmpty) {
                                  liveAvatar = uData['photoUrl'].toString().trim();
                                }
                              }
                            }

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage: liveAvatar != null && liveAvatar.isNotEmpty
                                      ? NetworkImage(liveAvatar)
                                      : null,
                                  backgroundColor: Colors.purpleAccent.withValues(alpha: 0.3),
                                  child: (liveAvatar == null || liveAvatar.isEmpty)
                                      ? const Icon(Icons.person, size: 6, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      );
    }
    
    if (roomWidgets.isEmpty && state is AudioRoomsLoaded) {
      if (state.isSearching) {
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: BannerCarousel()),
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No live rooms found for "${state.searchQuery}"',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      }
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: BannerCarousel()),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return roomWidgets[index];
              },
              childCount: roomWidgets.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRoomsEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconlyLight.voice,
              size: 80,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No rooms yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first room or join an existing one to get started.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateRoomBottomSheet,
              icon: const Icon(Icons.add),
              label: const Text('Create Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build floating action button
  Widget _buildFloatingActionButton() {
    return BlocBuilder<AudioRoomsBloc, AudioRoomsState>(
      builder: (context, state) {
        if (state is AudioRoomsLoaded && _currentUser != null) {
          final myRooms = state.userRooms
              .where((r) => r.creatorId == _currentUser!.userId)
              .toList();
          final hasLiveRoom = myRooms.any((r) => r.category == 'Live');
          final hasAudioRoom = myRooms.any((r) => r.category != 'Live');

          // Hide FAB on Live tab if user already has a Live room
          if (_tabController.index == 3 && hasLiveRoom) {
            return const SizedBox.shrink();
          }
          // Hide FAB on Party tab if user already has an Audio room
          if (_tabController.index == 2 && hasAudioRoom) {
            return const SizedBox.shrink();
          }
          // If they have both rooms, they can't create anything new anywhere
          if (hasLiveRoom && hasAudioRoom) {
            return const SizedBox.shrink();
          }
        }

        return FloatingActionButton.extended(
          onPressed: _showCreateRoomBottomSheet,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Create Room'),
        );
      },
    );
  }


}

class _CountryPickerSheetWidget extends StatefulWidget {
  final String selectedCountryCode;
  final ValueChanged<String> onSelectCountry;

  const _CountryPickerSheetWidget({
    required this.selectedCountryCode,
    required this.onSelectCountry,
  });

  @override
  State<_CountryPickerSheetWidget> createState() => _CountryPickerSheetWidgetState();
}

class _CountryPickerSheetWidgetState extends State<_CountryPickerSheetWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCountries = CountryHelper.getAllCountries();
    final filteredCountries = allCountries.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.dialCode.contains(q);
    }).toList();

    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Country / কান্ট্রি সিলেক্ট করুন',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  hintText: 'Search by country name or code...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  prefixIcon: const Icon(IconlyLight.search, color: Colors.white54, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purpleAccent, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Country List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_searchQuery.isEmpty) ...[
                  _buildCountryTile(
                    code: 'ALL',
                    flag: '🌐',
                    name: 'All Rooms (সকল দেশ)',
                    dialCode: '',
                    isSelected: widget.selectedCountryCode == 'ALL',
                    onTap: () => widget.onSelectCountry('ALL'),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                ],

                ...filteredCountries.map((country) {
                  final isSelected = widget.selectedCountryCode.toUpperCase() == country.code.toUpperCase();
                  return _buildCountryTile(
                    code: country.code,
                    flag: country.flag,
                    name: country.name,
                    dialCode: country.dialCode,
                    isSelected: isSelected,
                    onTap: () => widget.onSelectCountry(country.code),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryTile({
    required String code,
    required String flag,
    required String name,
    required String dialCode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.purpleAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Colors.purpleAccent.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Text(
            flag,
            style: const TextStyle(fontSize: 24),
          ),
          title: Row(
            children: [
              if (code != 'ALL') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dialCode.isNotEmpty)
                Text(
                  dialCode,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.purpleAccent : Colors.white30,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

