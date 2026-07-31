import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';

import 'svg_icon.dart';
import 'universal_asset_widget.dart';

class CachedCircleAvatar extends StatelessWidget {
  const CachedCircleAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.isOnline = false,
    this.backgroundColor,
    this.borderColor,
    this.iconSize,
    this.lastActive,
    this.frameUrl,
    this.frameId,
    this.userId,
    this.frameScale = 1.0,
    this.isGroup = false,
    this.isBroadcast = false,
    this.borderWidth = 2.0,
    this.padding = 2,
    this.showOfflineStatus = false,
  });

  final String imageUrl;
  final double radius;
  final bool isOnline;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? iconSize;
  final int? lastActive;
  final String? frameUrl;
  final String? frameId;
  final String? userId;
  final double frameScale;
  final bool isGroup;
  final bool isBroadcast;
  final double borderWidth;
  final double padding;
  final bool showOfflineStatus;

  @override
  Widget build(BuildContext context) {
    // Fetch frame from user document if userId is provided (highest priority for real-time sync)
    if (userId != null && userId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Fallback to frameId or frameUrl if user doc not loaded/found
            if (frameUrl != null && frameUrl!.isNotEmpty) {
              return _buildAvatar(context, frameUrl);
            }
            if (frameId != null && frameId!.isNotEmpty) {
              return FutureBuilder<String?>(
                future: FrameHelper.getFrameUrl(frameId),
                builder: (context, frameSnapshot) {
                  return _buildAvatar(context, frameSnapshot.data);
                },
              );
            }
            return _buildAvatar(context, null);
          }
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final customization = userData?['customization'] as Map<String, dynamic>?;
          final selectedFrameId = customization?['selectedFrameId'] as String?;
          
          if (selectedFrameId == null || selectedFrameId.isEmpty) {
            // NO EQUIPPED FRAME IN DB! 
            // We should NOT fallback to old cached frameId since the DB is the source of truth.
            return _buildAvatar(context, null);
          }
          
          return FutureBuilder<String?>(
            future: FrameHelper.getFrameUrl(selectedFrameId),
            builder: (context, frameSnapshot) {
              final resolvedFrameUrl = frameSnapshot.data;
              return _buildAvatar(context, resolvedFrameUrl);
            },
          );
        },
      );
    }

    // Otherwise, priority: frameUrl > frameId
    if (frameUrl != null && frameUrl!.isNotEmpty) {
      return _buildAvatar(context, frameUrl);
    }

    if (frameId != null && frameId!.isNotEmpty) {
      return FutureBuilder<String?>(
        future: FrameHelper.getFrameUrl(frameId),
        builder: (context, snapshot) {
          final resolvedFrameUrl = snapshot.data;
          return _buildAvatar(context, resolvedFrameUrl);
        },
      );
    }

    return _buildAvatar(context, null);
  }

  Widget _buildAvatar(BuildContext context, String? currentFrameUrl) {
    final bool isUrlResult = imageUrl.toLowerCase().contains("http");

    // Check if offline
    bool isOffline = true;

    if (lastActive != null) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int diff = now - lastActive!;
      // Check if user is online (last active < 10 minutes)
      if (diff < 600000) {
        isOffline = false;
      }
    }

    // Determine background color
    final Color? bgColor = backgroundColor ?? Colors.grey[350];

    // Broadcast icon
    final Widget broadcastIcon = SvgIcon('assets/icons/broadcast.svg',
        width: iconSize ?? 25, height: iconSize ?? 25, color: Colors.white);

    Widget imageWidget;
    if (imageUrl.isEmpty) {
      imageWidget = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: isGroup && isBroadcast
            ? broadcastIcon
            : Icon(isGroup ? IconlyBold.user3 : IconlyBold.profile,
                color: Colors.white, size: iconSize ?? 25),
      );
    } else {
      imageWidget = isUrlResult
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: radius,
                backgroundColor: bgColor,
                backgroundImage: imageProvider,
              ),
              placeholder: (context, url) => CircleAvatar(
                radius: radius,
                backgroundColor: bgColor,
                child: LoadingIndicator(
                    size:
                        radius * 0.5), // Use LoadingIndicator as in legacy code
              ),
              errorWidget: (context, url, error) => CircleAvatar(
                radius: radius,
                backgroundColor: bgColor,
                child: Icon(
                  IconlyBold
                      .profile, // Use IconlyBold.profile as in legacy code
                  color: Colors.white,
                  size: iconSize ?? radius,
                ),
              ),
            )
          : CircleAvatar(
              radius: radius,
              backgroundColor: bgColor,
              backgroundImage: const AssetImage('assets/images/logo.png'),
            );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? Colors.transparent,
              width: borderWidth,
            ),
          ),
          padding: EdgeInsets.all(padding),
          child: imageWidget,
        ),

        // Online/Offline status
        if (isOnline || !isOffline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          )
        else if (showOfflineStatus && lastActive != null)
          Builder(builder: (context) {
            final int now = DateTime.now().millisecondsSinceEpoch;
            final int diff = now - lastActive!;
            Color dotColor = Colors.transparent;
            bool showDot = false;

            if (diff >= 600000 && diff < 3600000) {
              // 10 mins to 1 hour (Orange)
              dotColor = Colors.orange;
              showDot = true;
            } else if (diff >= 3600000) {
              // > 1 hour (Red)
              dotColor = Colors.red;
              showDot = true;
            }

            if (!showDot) return const SizedBox.shrink();

            return Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            );
          }),

        // Frame
        if (currentFrameUrl != null && currentFrameUrl.isNotEmpty)
          Positioned(
            top: -radius * 0.4 * frameScale,
            bottom: -radius * 0.4 * frameScale,
            left: -radius * 0.4 * frameScale,
            right: -radius * 0.4 * frameScale,
            child: IgnorePointer(
              child: UniversalAssetWidget(
                url: currentFrameUrl,
                fit: BoxFit.cover,
                isAlphaVideo: true,
              ),
            ),
          ),
      ],
    );
  }
}

