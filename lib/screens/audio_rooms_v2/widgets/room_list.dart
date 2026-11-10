import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/modern_room_card.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/explore_grid_room_card.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

/// Widget for displaying a list or grid of audio rooms
class RoomList extends StatelessWidget {
  final List<AudioRoomV2> rooms;
  final String title;
  final bool showTitle;
  final Function(AudioRoomV2)? onRoomTap;
  final Function(AudioRoomV2)? onJoinRoom;
  final bool isLoading;
  final String emptyMessage;
  final Widget? emptyWidget;
  final Widget? headerWidget;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool showTotalCount;
  final bool isGrid;

  const RoomList({
    super.key,
    required this.rooms,
    this.title = 'Rooms',
    this.showTitle = true,
    this.onRoomTap,
    this.onJoinRoom,
    this.isLoading = false,
    this.emptyMessage = 'No rooms available',
    this.emptyWidget,
    this.headerWidget,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.showTotalCount = true,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (rooms.isEmpty) {
      return _buildEmptyState();
    }

    if (isGrid) {
      return CustomScrollView(
        controller: scrollController,
        physics: physics,
        shrinkWrap: shrinkWrap,
        slivers: [
          if (headerWidget != null) SliverToBoxAdapter(child: headerWidget!),
          if (showTitle) SliverToBoxAdapter(child: _buildTitle()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final room = rooms[index];
                  return ExploreGridRoomCard(
                    room: room,
                    onTap: () => onRoomTap?.call(room),
                    onJoin: () => onJoinRoom?.call(room),
                  );
                },
                childCount: rooms.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (showTitle) _buildTitle(),

        // Room list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            shrinkWrap: shrinkWrap,
            physics: physics,
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: headerWidget != null ? rooms.length + 1 : rooms.length,
            itemBuilder: (context, index) {
              if (headerWidget != null && index == 0) {
                return headerWidget!;
              }
              final roomIndex = headerWidget != null ? index - 1 : index;
              final room = rooms[roomIndex];
              return ModernRoomCard(
                room: room,
                onTap: () => onRoomTap?.call(room),
                onJoin: () => onJoinRoom?.call(room),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build title section
  Widget _buildTitle() {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;
    final primaryTextColor = themeService?.getScreenTextColor('room') ??
        (isLightBg ? Colors.black87 : Colors.white);
    final secondaryTextColor =
        themeService?.getScreenSecondaryTextColor('room') ??
            (isLightBg ? Colors.black54 : Colors.white.withValues(alpha: 0.4));

    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          if (rooms.isNotEmpty && showTotalCount)
            Text(
              '${rooms.length} rooms',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    if (isGrid) {
      return CustomScrollView(
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          if (headerWidget != null) SliverToBoxAdapter(child: headerWidget!),
          if (showTitle) SliverToBoxAdapter(child: _buildTitle()),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildGridSkeletonCard(),
                childCount: 6,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (showTitle) _buildTitle(),
        Expanded(
          child: ListView.builder(
            shrinkWrap: shrinkWrap,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: headerWidget != null ? 6 : 5,
            itemBuilder: (context, index) {
              if (headerWidget != null && index == 0) return headerWidget!;
              return _buildSkeletonCard();
            },
          ),
        ),
      ],
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Column(
      children: [
        if (showTitle) _buildTitle(),
        Expanded(
          child: headerWidget != null
              ? ListView(
                  children: [
                    headerWidget!,
                    SizedBox(
                      height: 400,
                      child: emptyWidget ?? _buildDefaultEmptyWidget(),
                    ),
                  ],
                )
              : (emptyWidget ?? _buildDefaultEmptyWidget()),
        ),
      ],
    );
  }

  /// Build default empty widget
  Widget _buildDefaultEmptyWidget() {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;
    final primaryTextColor = themeService?.getScreenTextColor('room') ??
        (isLightBg ? Colors.black87 : Colors.white);
    final secondaryTextColor =
        themeService?.getScreenSecondaryTextColor('room') ??
            (isLightBg ? Colors.black54 : Colors.white.withValues(alpha: 0.7));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.voice_chat_outlined,
              size: 80,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: primaryTextColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new room or join an existing one to get started.',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build skeleton card for loading state
  Widget _buildSkeletonCard() {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightBg
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLightBg
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isLightBg ? Colors.grey[300] : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isLightBg ? Colors.grey[300] : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: isLightBg ? Colors.grey[300] : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: isLightBg ? Colors.grey[300] : Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: isLightBg ? Colors.grey[300] : Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isLightBg ? Colors.grey[300] : Colors.white12,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              Container(),
            ],
          ),
        ],
      ),
    );
  }

  /// Build skeleton card for grid loading state
  Widget _buildGridSkeletonCard() {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isLightBg
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Horizontal room list widget
class HorizontalRoomList extends StatelessWidget {
  final List<AudioRoomV2> rooms;
  final String title;
  final Function(AudioRoomV2)? onRoomTap;
  final Function(AudioRoomV2)? onJoinRoom;
  final bool isLoading;
  final VoidCallback? onSeeAll;

  const HorizontalRoomList({
    super.key,
    required this.rooms,
    required this.title,
    this.onRoomTap,
    this.onJoinRoom,
    this.isLoading = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;
    final primaryTextColor = themeService?.getScreenTextColor('room') ??
        (isLightBg ? Colors.black87 : Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              if (rooms.length > 3 && onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: isLoading ? _buildLoadingList() : _buildRoomList(),
        ),
      ],
    );
  }

  Widget _buildRoomList() {
    if (rooms.isEmpty) {
      return Center(
        child: Text(
          'No rooms available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          child: _buildHorizontalRoomCard(room),
        );
      },
    );
  }

  Widget _buildHorizontalRoomCard(AudioRoomV2 room) {
    final themeService = Get.isRegistered<AppThemeService>()
        ? Get.find<AppThemeService>()
        : null;
    final screenBgColor = themeService?.getScreenColor('room');
    final bool isLightBg =
        screenBgColor != null && screenBgColor.computeLuminance() > 0.5;
    final primaryTextColor = themeService?.getScreenTextColor('room') ??
        (isLightBg ? Colors.black87 : Colors.white);
    final secondaryTextColor =
        themeService?.getScreenSecondaryTextColor('room') ??
            (isLightBg ? Colors.black54 : Colors.white.withValues(alpha: 0.6));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isLightBg
                ? Colors.black.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isLightBg
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLightBg
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => onRoomTap?.call(room),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: room.imageUrl != null
                              ? NetworkImage(room.imageUrl!)
                              : null,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: room.imageUrl == null
                              ? Icon(
                                  Icons.voice_chat,
                                  size: 16,
                                  color: primaryColor,
                                )
                              : null,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isLightBg
                                ? Colors.black.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLightBg
                                  ? Colors.black.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${room.participantCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: primaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
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
                        String creatorDisplayName = room.creatorName;
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final uData =
                              userSnap.data!.data() as Map<String, dynamic>?;
                          if (uData != null &&
                              uData['fullname'] != null &&
                              uData['fullname'].toString().trim().isNotEmpty) {
                            creatorDisplayName =
                                uData['fullname'].toString().trim();
                          }
                        }
                        return Text(
                          'by $creatorDisplayName',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            room.isFull ? null : () => onJoinRoom?.call(room),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          room.isFull ? 'Full' : 'Join',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
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
}
