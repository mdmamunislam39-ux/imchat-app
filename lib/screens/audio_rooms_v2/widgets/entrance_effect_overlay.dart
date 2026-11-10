import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../models/entrance_effect.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/universal_asset_widget.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../vap/vap_widget.dart';

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

        // Proactively preload entrance animation into RAM/Disk
        if (effect.effectUrl.isNotEmpty) {
          FastAssetCache.preload(effect.effectUrl);
        }
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

    // Lookahead: Preload upcoming queue items in background
    for (final nextEffect in _queue.take(2)) {
      if (nextEffect.effectUrl.isNotEmpty) {
        FastAssetCache.preload(nextEffect.effectUrl);
      }
    }

    if (mounted) {
      setState(() {
        _currentEffect = effect;
      });
    }

    try {
      debugPrint(
          '🎬 [EntranceAnimation] Processing entrance of type ${effect.type} for: ${effect.userName}');

      final url = effect.effectUrl.toLowerCase();
      final isVap = url.contains('.vap') || url.contains('.var');
      final isMp4 = url.contains('.mp4') || isVap;
      final isPng = url.contains('.png');
      Duration duration = const Duration(seconds: 4); // Default fallback

      if (effect.type == 'roomEntry') {
        duration = const Duration(milliseconds: 4000);
        debugPrint('🎬 [EntranceAnimation] Room Entry Banner duration: 4000ms');
      } else if (isMp4) {
        _videoController?.dispose();

        // Get preloaded/cached video file instantly
        File? cachedFile = await FastAssetCache.getVideoFile(effect.effectUrl);

        if (cachedFile != null) {
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

          duration = _videoController!.value.duration;

          await _videoController!.play();
          if (!mounted) {
            _videoController?.dispose();
            _videoController = null;
            return;
          }
          debugPrint(
              '🎬 [EntranceAnimation] MP4/Alpha duration: ${duration.inMilliseconds}ms');
        }
      } else if (isPng) {
        duration = const Duration(seconds: 4);
        debugPrint('🎬 [EntranceAnimation] PNG duration: 4000ms');
      } else {
        dynamic videoItem;

        // 1. Wait for SVGA to load/decode instantly from RAM/Disk
        if (effect.effectUrl.isNotEmpty) {
          try {
            videoItem = await FastAssetCache.decodeSvga(effect.effectUrl);
          } catch (e) {
            debugPrint('❌ [EntranceAnimation] SVGA Parse Error: $e');
          }
        }

        if (!mounted) return;

        // 2. Determine duration dynamically from decoded SVGA
        if (videoItem != null) {
          try {
            final int frames = (videoItem.params.frames ?? 60) as int;
            final int fps = (videoItem.params.fps ?? 20) as int;
            final durationMs = (frames / (fps > 0 ? fps : 20) * 1000).toInt();
            duration = Duration(milliseconds: durationMs);
            debugPrint(
                '🎬 [EntranceAnimation] Calculated duration: ${duration.inMilliseconds}ms ($frames frames @ $fps fps)');
          } catch (_) {
            duration = const Duration(seconds: 4);
          }
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
    if (effect.type == 'roomEntry') {
      return RoomEntryBannerWidget(effect: effect);
    }
    if (effect.effectUrl.isNotEmpty) {
      final url = effect.effectUrl.toLowerCase();

      if (url.contains('.mp4') || url.contains('.vap') || url.contains('.var')) {
        return UniversalAssetWidget(
          url: effect.effectUrl,
          fit: BoxFit.cover,
          isAlphaVideo: true,
          looping: false,
        );
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

      debugPrint(
          '🎬 [EntranceAnimation] Displaying SVGA via SVGAEasyPlayer: ${effect.effectUrl}');

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

class RoomEntryBannerWidget extends StatefulWidget {
  final EntranceEffect effect;

  const RoomEntryBannerWidget({super.key, required this.effect});

  @override
  State<RoomEntryBannerWidget> createState() => _RoomEntryBannerWidgetState();
}

class _RoomEntryBannerWidgetState extends State<RoomEntryBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Total duration is 4000ms.
    // 0ms -> 500ms: slide in from right.
    // 500ms -> 3500ms: stay in center (3 seconds).
    // 3500ms -> 4000ms: slide out to left.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(2.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 500 / 4000 * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 3000 / 4000 * 100,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(-2.0, 0.0))
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 500 / 4000 * 100,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effect = widget.effect;
    final userAvatar = effect.userAvatar;
    final userName = effect.userName;
    final isSvga = effect.effectUrl.toLowerCase().contains('.svga');

    return Center(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background layer
              Positioned.fill(
                child: isSvga
                    ? UniversalAssetWidget(
                        url: effect.effectUrl,
                        fit: BoxFit.fill,
                      )
                    : (effect.effectUrl.isNotEmpty &&
                            effect.effectUrl.startsWith('http') &&
                            !effect.effectUrl.toLowerCase().endsWith('.vap') &&
                            !effect.effectUrl.toLowerCase().endsWith('.mp4'))
                        ? CachedNetworkImage(
                            imageUrl: effect.effectUrl,
                            fit: BoxFit.fill,
                            placeholder: (context, url) => const SizedBox.shrink(),
                            errorWidget: (context, url, error) {
                              debugPrint('❌ [EntranceAnimation] Error loading decoration background image: $error');
                              return const SizedBox.shrink();
                            },
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1E88E5).withValues(alpha: 0.85), // Premium Royal Blue
                                  const Color(0xFF00E676).withValues(alpha: 0.65), // Vibrant Emerald Green
                                  const Color(0xFF00E676).withValues(alpha: 0.1),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF00E676).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                          ),
              ),
              // Content layer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: userAvatar != null && userAvatar.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: userAvatar,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => _buildLetterAvatar(userName),
                              )
                            : _buildLetterAvatar(userName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Username
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black54,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action Text
                    Text(
                      'entered the room ✨',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black54,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLetterAvatar(String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF00E676),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
