import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

/// Widget for displaying an audio room card with frosted glass blur
class RoomCard extends StatelessWidget {
  final AudioRoomV2 room;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool showJoinButton;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
    this.showJoinButton = true,
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

      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: defaultPadding,
          vertical: 8,
        ),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CachedCircleAvatar(
                            imageUrl: room.imageUrl ?? '',
                            radius: 25,
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            borderColor: primaryColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'by ${room.creatorName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLightBg
                                  ? Colors.black.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLightBg
                                    ? Colors.black.withValues(alpha: 0.1)
                                    : Colors.white.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  IconlyLight.user2,
                                  size: 14,
                                  color: primaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${room.participantCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (room.description.trim().isNotEmpty) ...[
                        Text(
                          room.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _buildParticipantsAvatars(),
                          ),
                          if (showJoinButton)
                            _buildActionButton(context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            timeago.format(room.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor.withValues(alpha: 0.8),
                            ),
                          ),
                          if (room.isFull)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'FULL',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildParticipantsAvatars() {
    if (room.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayParticipants = room.participants.take(4).toList();
    final remainingCount = room.participantCount - displayParticipants.length;

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          ...displayParticipants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
              child: CachedCircleAvatar(
                imageUrl: participant.userImageUrl ?? '',
                radius: 12,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                borderWidth: 1,
                borderColor: Colors.white,
              ),
            );
          }),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: Center(
                  child: Text(
                    '+${remainingCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (room.isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Full',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Join',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
