import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/mini_equalizer.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_level_badge_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/helpers/country_helper.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

/// Modern, premium room card with frosted glass blur and real-time theme adaptation
class ModernRoomCard extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const ModernRoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
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

      final activeBadge = _buildActiveActivityBadge(isLightBg);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isLightBg
                  ? Colors.black.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: isLightBg
                    ? Colors.white.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLightBg
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Room Image (Large square on the left)
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Avatar (80x80)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isLightBg ? Colors.grey[300] : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        room.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPlaceholder(isLightBg),
                                      )
                                    : _buildPlaceholder(isLightBg),
                              ),
                              
                              // Room Frame (Overlaying Avatar)
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
                                
                              // Room Level Badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: RoomLevelBadgeWidget(
                                  totalRevenue: room.totalRevenue,
                                  height: 28,
                                ),
                              ),

                              // Pinned Badge or Trending Badge
                              if (room.isCurrentlyPinned)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                  ),
                                )
                              else if (room.trendingScore > 0)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Colors.orange, Colors.redAccent],
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
                                        const Icon(Icons.local_fire_department, color: Colors.white, size: 10),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${room.trendingScore.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
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
                        const SizedBox(width: 12),

                        // Right Content Section (Title, Creator, Avatars, Description & Active Activity)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Group: Title + Equalizer & Creator
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Room Name & Equalizer Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          room.name,
                                          style: TextStyle(
                                            color: primaryTextColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MiniEqualizer(
                                            color: Colors.pinkAccent.withValues(alpha: 0.8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${room.participantCount}',
                                            style: TextStyle(
                                              color: primaryTextColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  _buildCreatorRow(secondaryTextColor, isLightBg),
                                ],
                              ),

                              // Middle Group: Participant Avatars (if any)
                              if (room.participants.isNotEmpty)
                                _buildParticipantAvatars(isLightBg),

                              // Bottom Group: Room Description + Active Activity Badge (YouTube, PK, Ludo, Carrom, etc.)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Room Description
                                  Expanded(
                                    child: Text(
                                      room.description.trim().isNotEmpty
                                          ? room.description.trim()
                                          : '',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Active Activity Badge
                                  if (activeBadge != null) ...[
                                    const SizedBox(width: 6),
                                    activeBadge,
                                  ],
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
          ),
        ),
      );
    });
  }

  Widget _buildPlaceholder([bool isLightBg = false]) {
    return Center(
      child: Icon(Icons.mic, color: isLightBg ? Colors.black38 : Colors.white54, size: 30),
    );
  }

  Widget _buildCreatorRow(Color secondaryTextColor, bool isLightBg) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(room.creatorId).snapshots(),
      builder: (context, snapshot) {
        String displayName = room.creatorName;
        String? userPhone = room.creatorPhone;
        String? fallbackUserCountry = room.creatorCountry;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            if (userData.containsKey('fullname')) {
              displayName = userData['fullname'] ?? room.creatorName;
            }
            userPhone = userData['number'] ?? userPhone;
            fallbackUserCountry = fallbackUserCountry ?? userData['country'];
          }
        }

        final countryCode = (room.countryCode != null && room.countryCode!.isNotEmpty)
            ? CountryHelper.detectCountryCodeFromPhoneOrUser(countryStr: room.countryCode)
            : (room.creatorCountry != null && room.creatorCountry!.isNotEmpty)
                ? CountryHelper.detectCountryCodeFromPhoneOrUser(countryStr: room.creatorCountry)
                : CountryHelper.detectCountryCodeFromPhoneOrUser(
                    phone: userPhone,
                    countryStr: fallbackUserCountry,
                  );
        final flag = CountryHelper.codeToFlag(countryCode);

        return Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isLightBg
                    ? Colors.black.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isLightBg
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    countryCode,
                    style: TextStyle(
                      color: isLightBg
                          ? Colors.black87
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (room.isOfficial) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1DA1F2), Color(0xFF0072B1)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DA1F2).withValues(alpha: 0.4),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 10,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Official',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildParticipantAvatars([bool isLightBg = false]) {
    if (room.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayParticipants = room.participants.take(5).toList();

    return SizedBox(
      height: 20,
      child: Row(
        children: displayParticipants.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CachedCircleAvatar(
              imageUrl: entry.value.userImageUrl ?? '',
              radius: 9,
              borderWidth: 1,
              borderColor: isLightBg ? Colors.black12 : Colors.white24,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds a compact, elegant indicator badge for what activity is currently active
  /// in the room (e.g. PK battle, Ludo, Carrom, YouTube sync player, or Voting).
  Widget? _buildActiveActivityBadge([bool isLightBg = false]) {
    String? label;
    Widget? iconWidget;
    Color borderColor = isLightBg ? Colors.black26 : Colors.white24;
    Color bgColor = isLightBg ? Colors.black.withValues(alpha: 0.05) : Colors.white10;
    Color textColor = isLightBg ? Colors.black87 : Colors.white;

    if (room.pkBattleState.isActive) {
      label = 'PK';
      borderColor = const Color(0xFFFF2B67).withValues(alpha: 0.5);
      bgColor = const Color(0xFFFF2B67).withValues(alpha: 0.15);
      textColor = isLightBg ? const Color(0xFFFF2B67) : Colors.white;
      iconWidget = const Text(
        '⚔️',
        style: TextStyle(fontSize: 10),
      );
    } else if (room.isLudoActive) {
      label = 'Ludo';
      borderColor = const Color(0xFF4CAF50).withValues(alpha: 0.5);
      bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      textColor = isLightBg ? const Color(0xFF2E7D32) : Colors.white;
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Image.asset(
          'assets/images/ludo_board.jpg',
          width: 12,
          height: 12,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.casino_rounded,
            size: 11,
            color: Color(0xFF4CAF50),
          ),
        ),
      );
    } else if (room.isCarromActive) {
      label = 'Carrom';
      borderColor = const Color(0xFFFF9800).withValues(alpha: 0.5);
      bgColor = const Color(0xFFFF9800).withValues(alpha: 0.15);
      textColor = isLightBg ? const Color(0xFFE65100) : Colors.white;
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
            color: Color(0xFFFF9800),
          ),
        ),
      );
    } else if (room.activeYoutubeVideoId != null &&
        room.activeYoutubeVideoId!.isNotEmpty) {
      label = 'YouTube';
      borderColor = const Color(0xFFFF0000).withValues(alpha: 0.5);
      bgColor = const Color(0xFFFF0000).withValues(alpha: 0.15);
      textColor = isLightBg ? const Color(0xFFCC0000) : Colors.white;
      iconWidget = Container(
        width: 14,
        height: 11,
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000),
          borderRadius: BorderRadius.circular(2.5),
        ),
        child: const Center(
          child: Icon(Icons.play_arrow, size: 9, color: Colors.white),
        ),
      );
    } else if (room.isVotingActive) {
      label = 'Voting';
      borderColor = const Color(0xFF2196F3).withValues(alpha: 0.5);
      bgColor = const Color(0xFF2196F3).withValues(alpha: 0.15);
      textColor = isLightBg ? const Color(0xFF1976D2) : Colors.white;
      iconWidget = const Icon(
        Icons.how_to_vote_rounded,
        size: 11,
        color: Color(0xFF2196F3),
      );
    }

    if (label == null || iconWidget == null) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
