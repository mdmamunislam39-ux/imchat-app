import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../components/universal_asset_widget.dart' as uaw;

/// High-performance transparent Alpha Video Player widget
class AlphaVideoPlayer extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? videoUrl;
  final bool isAsset;
  final double? width;
  final double? height;
  final bool isVerticalLayout;
  final bool isMaskLeft;
  final bool loop;
  final bool autoplay;
  final VoidCallback? onComplete;
  final BoxFit fit;

  const AlphaVideoPlayer({
    super.key,
    this.controller,
    this.videoUrl,
    this.isAsset = false,
    this.width,
    this.height,
    this.isVerticalLayout = false,
    this.isMaskLeft = false,
    this.loop = true,
    this.autoplay = true,
    this.onComplete,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return SizedBox(
        width: width,
        height: height,
        child: uaw.AlphaVideoPlayer(
          controller: controller!,
          fit: fit,
          isMaskLeft: isMaskLeft,
          isVerticalLayout: isVerticalLayout,
          onComplete: onComplete,
        ),
      );
    }

    if (videoUrl == null || videoUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: height,
      child: uaw.UniversalAssetWidget(
        url: videoUrl,
        fit: fit,
        looping: loop,
        isAlphaVideo: true,
        isMaskLeft: isMaskLeft,
        isVerticalLayout: isVerticalLayout,
        onComplete: onComplete,
      ),
    );
  }
}

