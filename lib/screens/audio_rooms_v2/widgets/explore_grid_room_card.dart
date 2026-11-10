import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/mini_equalizer.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_level_badge_widget.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

import 'package:chat_messenger/helpers/country_helper.dart';

/// Explore Grid Room Card matching modern explore UI layout
class ExploreGridRoomCard extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const ExploreGridRoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
  });

  String _getRoomCountryCode() {
    if (room.countryCode != null && room.countryCode!.trim().isNotEmpty) {
      final code = CountryHelper.detectCountryCodeFromPhoneOrUser(
          countryStr: room.countryCode);
      if (code.isNotEmpty) return code;
    }
    if (room.creatorCountry != null && room.creatorCountry!.trim().isNotEmpty) {
      final code = CountryHelper.detectCountryCodeFromPhoneOrUser(
          countryStr: room.creatorCountry);
      if (code.isNotEmpty) return code;
    }
    if (room.creatorPhone != null && room.creatorPhone!.trim().isNotEmpty) {
      final code = CountryHelper.detectCountryCodeFromPhoneOrUser(
          phone: room.creatorPhone);
      if (code.isNotEmpty) return code;
    }
    return 'BD'; // Default fallback
  }

  Widget _buildCountryFlagBadge(String countryCode) {
    final cleanCode = countryCode.trim().toUpperCase();
    final flagEmoji = CountryHelper.codeToFlag(cleanCode);

    return Container(
      width: 17,
      height: 12,
      margin: const EdgeInsets.only(right: 4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.white,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 2,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          'flags/${cleanCode.toLowerCase()}.png',
          package: 'country_code_picker',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              flagEmoji.isNotEmpty ? flagEmoji : '🌐',
              style: const TextStyle(fontSize: 8.5),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final catLower = category.toLowerCase().trim();
    if (catLower == 'chat') {
      return const Color(0xFF00C853); // Emerald Green
    } else if (catLower == 'party') {
      return const Color(0xFFFF9800); // Amber Orange
    } else if (catLower == 'any' ||
        catLower == 'all' ||
        catLower == 'all rooms') {
      return const Color(0xFF00B0FF); // Sky Blue / Cyan
    } else if (catLower == 'game') {
      return const Color(0xFF7C4DFF); // Purple
    } else if (catLower == 'pk') {
      return const Color(0xFFFF1744); // Crimson Red
    } else if (catLower == 'islamic') {
      return const Color(0xFF00897B); // Teal
    } else if (catLower == 'event' || catLower == 'talk show') {
      return const Color(0xFFFF6D00); // Deep Orange
    } else if (catLower == 'live') {
      return const Color(0xFFE91E63); // Pink
    }
    return const Color(0xFF00C853); // Default to green
  }

  String _getCategoryLabel(String category) {
    if (category.trim().isEmpty) return 'Chat';
    if (category == 'All Rooms') return 'Any';
    return category;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeService = Get.isRegistered<AppThemeService>()
          ? Get.find<AppThemeService>()
          : null;
      final screenBgColor = themeService?.getScreenColor('room');
      final bool isLightBg =
          screenBgColor != null && screenBgColor.computeLuminance() > 0.5;

      final String? coverUrl = (room.imageUrl != null &&
              room.imageUrl!.isNotEmpty)
          ? room.imageUrl
          : (room.creatorImageUrl != null && room.creatorImageUrl!.isNotEmpty
              ? room.creatorImageUrl
              : null);

      final categoryColor = _getCategoryColor(room.category);
      final categoryLabel = _getCategoryLabel(room.category);
      final activityBadge = _buildActiveActivityBadge();
      final countryCode = _getRoomCountryCode();

      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isLightBg
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image or Fallback Gradient
                    coverUrl != null
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildFallbackCover(isLightBg),
                          )
                        : _buildFallbackCover(isLightBg),

                    // Active Room Frame (if any)
                    if (room.roomFrameUrl != null &&
                        room.roomFrameUrl!.isNotEmpty &&
                        (room.roomFrameUntil == null ||
                            room.roomFrameUntil!.isAfter(DateTime.now())))
                      Positioned.fill(
                        child: IgnorePointer(
                          child: UniversalAssetWidget(
                            url: room.roomFrameUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // Bottom Gradient Shadow for readability
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.32, 0.62, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Room Level Badge (Top Right)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: RoomLevelBadgeWidget(
                        totalRevenue: room.totalRevenue,
                        height: 33,
                      ),
                    ),

                    // Top Left Corner: Active Game/Activity Badge (PK, Ludo, Carrom, YouTube, Voting) + Pinned / Trending
                    if (activityBadge != null ||
                        room.isCurrentlyPinned ||
                        room.trendingScore > 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activityBadge != null) ...[
                              activityBadge,
                              if (room.isCurrentlyPinned ||
                                  room.trendingScore > 0)
                                const SizedBox(width: 3.5),
                            ],
                            if (room.isCurrentlyPinned)
                              _buildPinnedBadge()
                            else if (room.trendingScore > 0)
                              _buildTrendingBadge(),
                          ],
                        ),
                      ),

                    // Bottom Content: Category & Stats (Top) + Room Title with Country Flag (Bottom)
                    Positioned(
                      bottom: 6,
                      left: 7,
                      right: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Top Row: Left Badges (Category + Official) & Right Stats (Avatars + Count)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left: Category Pill & Official Badge
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: categoryColor,
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        categoryLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black26,
                                                blurRadius: 1,
                                                offset: Offset(0, 0.5)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (room.isOfficial) ...[
                                      const SizedBox(width: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1DA1F2),
                                              Color(0xFF0072B1)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1DA1F2)
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              color: Colors.white,
                                              size: 9,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'Official',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                      color: Colors.black26,
                                                      blurRadius: 1,
                                                      offset:
                                                          Offset(0, 0.5)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),

                              // Right: Overlapping Avatars
                              _buildOverlappingAvatars(),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // 2. Bottom Row: Room Name with Country Flag (Left) & Equalizer + Count (Right)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildCountryFlagBadge(countryCode),
                              Expanded(
                                child: Text(
                                  room.name.trim().isNotEmpty
                                      ? room.name
                                      : 'Audio Room',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildAudioEqualizerAndCount(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFallbackCover(bool isLightBg) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C194D), Color(0xFF180D2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: 44,
        ),
      ),
    );
  }

  Widget _buildOverlappingAvatars() {
    final List<String> avatarUrls = [];
    for (final p in room.participants) {
      if (p.userImageUrl != null && p.userImageUrl!.isNotEmpty) {
        avatarUrls.add(p.userImageUrl!);
      }
      if (avatarUrls.length >= 4) break;
    }

    if (avatarUrls.isEmpty &&
        room.creatorImageUrl != null &&
        room.creatorImageUrl!.isNotEmpty) {
      avatarUrls.add(room.creatorImageUrl!);
    }

    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < avatarUrls.length; i++)
            Align(
              widthFactor: 0.65,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                  image: DecorationImage(
                    image: NetworkImage(avatarUrls[i]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // Plus add indicator circle
          Align(
            widthFactor: 0.65,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Icon(Icons.add, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioEqualizerAndCount() {
    final int count = room.participantCount > 0 ? room.participantCount : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const MiniEqualizer(
          color: Color(0xFF00E676), // Bright Green
          size: 10,
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3D00), Color(0xFFFF9100)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrangeAccent.withValues(alpha: 0.4),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin, color: Colors.white, size: 9),
          SizedBox(width: 2),
          Text(
            'PINNED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFF5252)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 9),
          const SizedBox(width: 2),
          Text(
            room.trendingScore.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a compact, glowing indicator badge for active activities in the room
  /// (e.g. YouTube sync player, Ludo, Carrom, PK battle, Voting).
  Widget? _buildActiveActivityBadge() {
    String? label;
    Widget? iconWidget;
    Color borderColor = Colors.white24;
    Color bgColor = Colors.black.withValues(alpha: 0.65);
    Color textColor = Colors.white;
    List<Color>? gradientColors;

    if (room.pkBattleState.isActive) {
      label = 'PK';
      borderColor = const Color(0xFFFF2B67).withValues(alpha: 0.9);
      gradientColors = const [Color(0xFFFF2B67), Color(0xFFD946EF)];
      textColor = Colors.white;
      iconWidget = const Text(
        '⚔️',
        style: TextStyle(fontSize: 10),
      );
    } else if (room.isLudoActive) {
      label = 'Ludo';
      borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.9);
      gradientColors = const [Color(0xFF4CAF50), Color(0xFF2E7D32)];
      textColor = Colors.white;
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Image.asset(
          'assets/images/ludo_board.jpg',
          width: 12,
          height: 12,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('🎲', style: TextStyle(fontSize: 10)),
        ),
      );
    } else if (room.isCarromActive) {
      label = 'Carrom';
      borderColor = const Color(0xFFFF9800).withValues(alpha: 0.9);
      gradientColors = const [Color(0xFFFF9800), Color(0xFFE65100)];
      textColor = Colors.white;
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Image.asset(
          'assets/images/carrom_board_preview.jpg',
          width: 12,
          height: 12,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.album_rounded,
            size: 11,
            color: Colors.white,
          ),
        ),
      );
    } else if (room.activeYoutubeVideoId != null &&
        room.activeYoutubeVideoId!.isNotEmpty) {
      label = 'YouTube';
      borderColor = const Color(0xFFFF0000).withValues(alpha: 0.9);
      gradientColors = const [Color(0xFFFF0000), Color(0xFFB71C1C)];
      textColor = Colors.white;
      iconWidget = Container(
        width: 13,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2.5),
        ),
        child: const Center(
          child: Icon(Icons.play_arrow, size: 8, color: Color(0xFFFF0000)),
        ),
      );
    } else if (room.isVotingActive) {
      label = 'Voting';
      borderColor = const Color(0xFF2196F3).withValues(alpha: 0.9);
      gradientColors = const [Color(0xFF2196F3), Color(0xFF1565C0)];
      textColor = Colors.white;
      iconWidget = const Icon(
        Icons.how_to_vote_rounded,
        size: 11,
        color: Colors.white,
      );
    }

    if (label == null || iconWidget == null) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: gradientColors == null ? bgColor : null,
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(color: Colors.black45, blurRadius: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
