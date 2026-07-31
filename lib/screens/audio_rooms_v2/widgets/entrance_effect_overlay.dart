import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../models/entrance_effect.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/universal_asset_widget.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Overlay widget for displaying entrance effect animations using SVGA
class EntranceEffectOverlay extends StatefulWidget {
  final List<EntranceEffect> effects;
  final VoidCallback? onAnimationComplete;

  const EntranceEffectOverlay({
    super.key,
    required this.effects,
    this.onAnimationComplete,
  });

  @override
  State<EntranceEffectOverlay> createState() => _EntranceEffectOverlayState();
}

class _EntranceEffectOverlayState extends State<EntranceEffectOverlay> {
  final List<EntranceEffect> _queue = [];
  final Set<String> _processedIds = {};
  EntranceEffect? _currentEffect;
  bool _isProcessing = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _addEffects(widget.effects);
  }

  @override
  void dispose() {
    _isProcessing = false;
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EntranceEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _addEffects(widget.effects);
  }

  void _addEffects(List<EntranceEffect> effects) {
    bool added = false;
    for (final effect in effects) {
      final effectKey =
          '${effect.userId}_${effect.timestamp.millisecondsSinceEpoch}';
      if (!_processedIds.contains(effectKey)) {
        _processedIds.add(effectKey);
        _queue.add(effect);
        added = true;
      }
    }

    if (added && !_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (!mounted) return;

    if (_queue.isEmpty) {
      if (mounted) {
        setState(() {
          _currentEffect = null;
          _isProcessing = false;
        });
      }
      widget.onAnimationComplete?.call();
      return;
    }

    _isProcessing = true;
    final effect = _queue.removeAt(0);

    if (mounted) {
      setState(() {
        _currentEffect = effect;
      });
    }

    try {
      debugPrint(
          '🎬 [EntranceAnimation] Processing entrance for: ${effect.userName}');

      final url = effect.effectUrl.toLowerCase();
      final isMp4 = url.contains('.mp4');
      final isPng = url.contains('.png');
      Duration duration = const Duration(seconds: 4); // Default fallback

      if (isMp4) {
        _videoController?.dispose();
        
        // Cache the file locally to guarantee instant, deadlock-free playback on all devices
        final cachedFile = await DefaultCacheManager().getSingleFile(effect.effectUrl);
        
        _videoController = VideoPlayerController.file(
          cachedFile,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _videoController!.initialize();
        if (!mounted) {
          _videoController?.dispose();
          _videoController = null;
          return;
        }

        // Instantly trigger a rebuild once the controller is initialized so the player is displayed immediately!
        setState(() {});

        await _videoController!.play();
        if (!mounted) {
          _videoController?.dispose();
          _videoController = null;
          return;
        }
        duration = _videoController!.value.duration;
        debugPrint('🎬 [EntranceAnimation] MP4 duration: ${duration.inMilliseconds}ms');
      } else if (isPng) {
        duration = const Duration(seconds: 4);
        debugPrint('🎬 [EntranceAnimation] PNG duration: 4000ms');
      } else {
        final parser = SVGAParser();
        dynamic videoItem;

        // 1. Wait for SVGA to load/decode
        if (effect.effectUrl.isNotEmpty) {
          try {
            videoItem = await parser.decodeFromURL(effect.effectUrl);
          } catch (e) {
            debugPrint('❌ [EntranceAnimation] SVGA Parse Error: $e');
          }
        }

        if (!mounted) return;

        // 2. Determine duration dynamically from decoded SVGA
        if (videoItem != null) {
          final frames = videoItem.frames;
          final fps = videoItem.fps;
          final durationMs = (frames / fps * 1000).toInt();
          duration = Duration(milliseconds: durationMs);
          debugPrint(
              '🎬 [EntranceAnimation] Calculated duration: ${duration.inMilliseconds}ms ($frames frames @ $fps fps)');
        }
      }

      // 3. Wait exactly for the dynamically calculated duration of this specific file
      await Future.delayed(duration);
      if (!mounted) return;
    } catch (e) {
      debugPrint('❌ [EntranceAnimation] Error processing entrance effect: $e');
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
    }

    // 4. Clear current and process next
    if (mounted) {
      setState(() {
        _currentEffect = null;
      });
      _videoController?.dispose();
      _videoController = null;
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _processQueue();
      }
    } else {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEffect == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: _buildSVGAAnimation(_currentEffect!),
      ),
    );
  }

  Widget _buildSVGAAnimation(EntranceEffect effect) {
    if (effect.effectUrl.isNotEmpty) {
      final url = effect.effectUrl.toLowerCase();

      if (url.contains('.mp4')) {
        return _videoController != null && _videoController!.value.isInitialized
            ? AlphaVideoPlayer(
                controller: _videoController!,
                fit: BoxFit.cover,
              )
            : const SizedBox.shrink();
      } else if (url.contains('.png')) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: effect.effectUrl,
              fit: BoxFit.contain,
            ),
          ),
        );
      }

      debugPrint('🎬 [EntranceAnimation] Displaying SVGA via SVGAEasyPlayer: ${effect.effectUrl}');

      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SVGAEasyPlayer(
          resUrl: effect.effectUrl,
          fit: BoxFit.cover, // Fit full screen
        ),
      );
    } else {
      debugPrint('🎬 [EntranceAnimation] No effect URL provided');
      return const SizedBox.shrink();
    }
  }
}
