import 'package:flutter/material.dart';
import '../components/universal_asset_widget.dart';

/// Transparent Video (VAP / VAR / MP4 Alpha) Widget
/// Displays alpha-masked videos with 100% transparency and smooth 60fps hardware acceleration.
class VapWidget extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final bool isMaskLeft;
  final bool forceShader;
  final bool looping;
  final VoidCallback? onComplete;

  const VapWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.isMaskLeft = false,
    this.forceShader = false,
    this.looping = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return UniversalAssetWidget(
      url: url,
      fit: fit,
      isAlphaVideo: true,
      isMaskLeft: isMaskLeft,
      looping: looping,
      onComplete: onComplete,
    );
  }
}

