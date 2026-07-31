import 'package:flutter/material.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
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
import 'package:cached_network_image/cached_network_image.dart';

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
  String _selectedCategory = 'All Rooms';

  // Cache the last loaded rooms so room-stream states don't wipe the list
  AudioRoomsLoaded? _cachedLoadedState;
  late Worker _settingsWorker;

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

    // Initialize BLoC
    _audioRoomsBloc = AudioRoomsBloc(
      repository: AudioRoomsRepository(),
    );

    // Load initial data
    _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DailyCheckInService.checkAndShowCheckIn(context);
    });
  }

  @override
  void dispose() {
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
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('Please log in to view rooms');
        return;
      }

      MinimizedRoomController.checkAndProceed(
        context: context,
        targetRoom: room,
        onProceed: () {
          debugPrint('🎯 Navigating directly to room for instant join...');
          _navigateToRoom(room);
        },
      );
    } catch (e) {
      debugPrint('🎯 Error in _handleRoomTap: $e');
      _showErrorSnackBar('Failed to access room. Please try again.');
    }
  }

  /// Handle join room
  void _handleJoinRoom(AudioRoomV2 room) {
    try {
      if (_currentUser == null) {
        _showErrorSnackBar('Please log in to join a room');
        return;
      }

      if (room.isFull) {
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
      );
    } catch (e) {
      debugPrint('🎯 Error in _handleJoinRoom: $e');
      _showErrorSnackBar('Failed to join room. Please try again.');
    }
  }

  /// Navigate to room screen
  void _navigateToRoom(AudioRoomV2 room) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudioRoomScreen(
            room: room,
            audioRoomsBloc: _audioRoomsBloc,
          ),
        ),
      );
      // Reload rooms list when returning (e.g. after minimizing a room),
      // because the BLoC state may be AudioRoomJoined which the list
      // builders don't handle, causing an empty list.
      _loadInitialData();
    } catch (e) {
      debugPrint('🎯 Error navigating to room: $e');
      _showErrorSnackBar('Failed to open room. Please try again.');
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
          final bool isStandalone = widget.showAppBar;
          
          final String? bgUrl = themeService.getScreenBgUrl('room');
          final Color? bgColor = themeService.getScreenColor('room');

          return Container(
            decoration: (isStandalone && bgUrl != null)
                ? BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(bgUrl),
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            child: Scaffold(
              backgroundColor: isStandalone 
                  ? (bgColor ?? const Color(0xFF120C1C))
                  : Colors.transparent,
              appBar: widget.showAppBar ? _buildAppBar() : null,
              body: _buildBody(),
              floatingActionButton: _buildFloatingActionButton(),
            ),
          );
        }),
      ),
    );
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          _buildTopNavTab('Mine', 0, isActive: _tabController.index == 0),
          _buildTopNavTab('All', 1, isActive: _tabController.index == 1),
          _buildTopNavTab('Party', 2, isActive: _tabController.index == 2),
          _buildTopNavTab('Live', 3, isActive: _tabController.index == 3),
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
        IconButton(
          tooltip: 'Top Rankings',
          icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoomTopRankingsScreen(audioRoomsBloc: _audioRoomsBloc),
            ),
          ),
        ),
        // Room ID Search icon
        IconButton(
          tooltip: 'Search by Room ID',
          icon: const Icon(IconlyLight.search, color: Colors.white70),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoomIdSearchScreen(audioRoomsBloc: _audioRoomsBloc),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopNavTab(String label, int index, {bool isActive = false}) {
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
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 18,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: 20,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return BlocConsumer<AudioRoomsBloc, AudioRoomsState>(
      listener: (context, state) {
        // Cache loaded state so room-stream emissions don't wipe the list
        if (state is AudioRoomsLoaded) {
          _cachedLoadedState = state;
        }

        if (state is AudioRoomJoined) {
          debugPrint('🎯 Room joined successfully, check visibility...');
          // Only navigate if this screen is the current top screen
          if (ModalRoute.of(context)?.isCurrent == true) {
            debugPrint('🎯 Screen is visible, navigating to room...');
            _navigateToRoom(state.room);
          } else {
            debugPrint('🎯 Screen is in background, skipping navigation.');
          }
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    _buildTopNavTab('Mine', 0, isActive: _tabController.index == 0),
                    _buildTopNavTab('All', 1, isActive: _tabController.index == 1),
                    _buildTopNavTab('Party', 2, isActive: _tabController.index == 2),
                    if (Get.find<GlobalSettingsService>().isLiveVideoRoomEnabled.value)
                      _buildTopNavTab('Live', 3, isActive: _tabController.index == 3),
                    const Spacer(),
                    // Top Rankings icon
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Top Rankings',
                      icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomTopRankingsScreen(audioRoomsBloc: _audioRoomsBloc),
                        ),
                      ),
                    ),
                    // Room ID Search icon
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      tooltip: 'Search by Room ID',
                      icon: const Icon(IconlyLight.search, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomIdSearchScreen(audioRoomsBloc: _audioRoomsBloc),
                        ),
                      ),
                    ),
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
        headerWidget: headerWidget,
      );
    }

    if (state is AudioRoomsLoaded) {
      final allRooms = state.isSearching ? state.searchResults : state.popularRooms;
      final filteredRooms = _selectedCategory == 'All Rooms'
          ? allRooms
          : allRooms.where((room) => room.category == _selectedCategory).toList();

      return RoomList(
        rooms: filteredRooms,
        title: state.isSearching ? 'Search Results' : 'All Rooms',
        showTitle: false,
        showTotalCount: false,
        headerWidget: headerWidget,
        onRoomTap: _handleRoomTap,
        onJoinRoom: _handleJoinRoom,
        emptyMessage: state.isSearching
            ? 'No rooms found for "${state.searchQuery}"'
            : 'No rooms available in this category',
      );
    }

    if (state is AudioRoomsError) {
      return _buildErrorWidget(state.message);
    }

    return RoomList(
      rooms: const [],
      title: 'All Rooms',
      showTitle: false,
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
      final filteredRooms = _selectedCategory == 'All Rooms'
          ? audioRooms
          : audioRooms.where((room) => room.category == _selectedCategory).toList();

      return RoomList(
        rooms: filteredRooms,
        title: state.isSearching ? 'Search Results' : 'Party Rooms',
        showTitle: false,
        showTotalCount: false,
        headerWidget: headerWidget,
        onRoomTap: _handleRoomTap,
        onJoinRoom: _handleJoinRoom,
        emptyMessage: state.isSearching
            ? 'No rooms found for "${state.searchQuery}"'
            : 'No rooms available in this category',
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
    final categories = [
      {'name': 'All Rooms', 'emoji': '🌐'},
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
          final isSelected = _selectedCategory == name;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = name;
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.transparent,
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
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
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
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundImage: creatorImageUrl != null && creatorImageUrl.isNotEmpty
                                  ? NetworkImage(creatorImageUrl)
                                  : null,
                              backgroundColor: Colors.purpleAccent.withValues(alpha: 0.3),
                              child: (creatorImageUrl == null || creatorImageUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 6, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room.creatorName,
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No rooms yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first room or join an existing one to get started.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
