import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

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
    this.showFrame = true,
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
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    if (!showFrame) {
      return _buildAvatar(context, null);
    }

    // 1. Direct URL provided (highest priority & immediate)
    if (frameUrl != null && frameUrl!.isNotEmpty) {
      return _buildAvatar(context, frameUrl);
    }

    // 2. Real-time frame streaming when userId is provided
    if (userId != null && userId!.isNotEmpty) {
      if (Get.isRegistered<AuthController>() && userId == AuthController.instance.currentUser.userId) {
        return Obx(() {
          final liveUrl = AuthController.instance.currentFrameUrl.value;
          final cachedUrl = FrameHelper.getCachedUserFrameUrl(userId) ??
              (frameId != null ? FrameHelper.getCachedFrameUrl(frameId) : null);
          final initial = liveUrl.isNotEmpty ? liveUrl : cachedUrl;

          return StreamBuilder<String?>(
            stream: FrameHelper.streamUserFrame(userId!),
            initialData: initial,
            builder: (context, snapshot) {
              final resolved = liveUrl.isNotEmpty
                  ? liveUrl
                  : (snapshot.hasData ? snapshot.data : null);
              return _buildAvatar(context, resolved);
            },
          );
        });
      }

      final initialFrame = FrameHelper.getCachedUserFrameUrl(userId) ??
          (frameId != null ? FrameHelper.getCachedFrameUrl(frameId) : null);

      return StreamBuilder<String?>(
        stream: FrameHelper.streamUserFrame(userId!),
        initialData: initialFrame,
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          return _buildAvatar(context, resolved);
        },
      );
    }

    // 3. Fallback resolve via frameId if provided without userId
    if (frameId != null && frameId!.isNotEmpty) {
      final cachedByFrameId = FrameHelper.getCachedFrameUrl(frameId);
      return FutureBuilder<String?>(
        future: FrameHelper.getFrameUrl(frameId),
        initialData: cachedByFrameId,
        builder: (context, snapshot) {
          final resolved = snapshot.data ?? cachedByFrameId;
          return _buildAvatar(context, resolved);
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
                key: ValueKey(currentFrameUrl),
                url: currentFrameUrl,
                fit: BoxFit.contain,
                isAlphaVideo: true,
              ),
            ),
          ),
      ],
    );
  }
}

