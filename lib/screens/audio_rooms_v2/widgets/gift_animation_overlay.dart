import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../AdminPane/models/gift.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../widgets/alpha_video_player.dart';

/// Class for grouping identical multi-recipient transactions
class GroupedGiftTransaction {
  final GiftTransaction primaryTransaction;
  final List<String> receiverIds;

  GroupedGiftTransaction({
    required this.primaryTransaction,
    required this.receiverIds,
  });
}

/// Overlay widget for displaying gift animations using SVGA/MP4
class GiftAnimationOverlay extends StatefulWidget {
  final List<GiftTransaction> transactions;
  final VoidCallback? onAnimationComplete;
  final Function(GiftTransaction transaction, List<String> receiverIds)? onGiftFlightTriggered;

  const GiftAnimationOverlay({
    super.key,
    required this.transactions,
    this.onAnimationComplete,
    this.onGiftFlightTriggered,
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> with TickerProviderStateMixin {
  final List<GroupedGiftTransaction> _queue = [];
  final Set<String> _processedIds = {};
  GroupedGiftTransaction? _currentTransaction;
  bool _isProcessing = false;
  VideoPlayerController? _videoController;
  SVGAAnimationController? _svgaController;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _addTransactions(widget.transactions);
  }

  Future<void> _loadShader() async {
    final program = await AlphaVideoShaderManager.instance.getProgram();
    if (program != null && mounted) {
      setState(() {
        _shader = program.fragmentShader();
      });
    }
  }

  @override
  void didUpdateWidget(GiftAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _addTransactions(widget.transactions);
  }

  void _addTransactions(List<GiftTransaction> transactions) {
    bool added = false;
    for (final transaction in transactions) {
      if (!_processedIds.contains(transaction.id)) {
        _processedIds.add(transaction.id);

        // Group together transactions that represent the same physical gift event
        // (same sender, same gift ID, timestamp within 1.5 seconds)
        bool merged = false;

        // Try to merge into the queue
        for (var grouped in _queue) {
          final diff = grouped.primaryTransaction.timestamp
              .difference(transaction.timestamp)
              .inMilliseconds
              .abs();
          if (grouped.primaryTransaction.senderId == transaction.senderId &&
              grouped.primaryTransaction.giftId == transaction.giftId &&
              diff <= 1500) {
            if (!grouped.receiverIds.contains(transaction.receiverId)) {
              grouped.receiverIds.add(transaction.receiverId);
            }
            merged = true;
            break;
          }
        }

        // Also check if we can merge with the currently playing transaction
        if (!merged && _currentTransaction != null) {
          final diff = _currentTransaction!.primaryTransaction.timestamp
              .difference(transaction.timestamp)
              .inMilliseconds
              .abs();
          if (_currentTransaction!.primaryTransaction.senderId == transaction.senderId &&
              _currentTransaction!.primaryTransaction.giftId == transaction.giftId &&
              diff <= 1500) {
            if (!_currentTransaction!.receiverIds.contains(transaction.receiverId)) {
              _currentTransaction!.receiverIds.add(transaction.receiverId);
            }
            merged = true;
          }
        }

        if (!merged) {
          _queue.add(GroupedGiftTransaction(
            primaryTransaction: transaction,
            receiverIds: [transaction.receiverId],
          ));
          added = true;
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
          _currentTransaction = null;
          _isProcessing = false;
        });
      }
      widget.onAnimationComplete?.call();
      return;
    }

    _isProcessing = true;
    final transaction = _queue.removeAt(0);

    if (mounted) {
      setState(() {
        _currentTransaction = transaction;
      });
    }

    try {
      debugPrint(
          '🎁 [GiftAnimation] Processing grouped gift: ${transaction.primaryTransaction.giftName} for ${transaction.receiverIds.length} users');

      final url = transaction.primaryTransaction.giftSvgaUrl?.toLowerCase() ?? '';
      final isMp4 = url.contains('.mp4');
      final isPng = url.contains('.png');
      Duration duration = const Duration(seconds: 4); // Default fallback

      if (isMp4) {
        _videoController?.dispose();

        // Cache the file locally to guarantee instant playback
        File cachedFile = await DefaultCacheManager()
            .getSingleFile(transaction.primaryTransaction.giftSvgaUrl!);
            
        // Critical Fix: Android's MediaExtractor fails to decode the video track 
        // if the file doesn't have an .mp4 extension, resulting in audio-only black screens.
        if (!cachedFile.path.toLowerCase().endsWith('.mp4')) {
          final newPath = '${cachedFile.path}.mp4';
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            await cachedFile.copy(newPath);
          }
          cachedFile = newFile;
        }

        try {
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

          final Completer<void> videoCompleter = Completer<void>();
          _videoController!.addListener(() {
            if (_videoController == null) return;
            
            if (_videoController!.value.hasError) {
              debugPrint('❌ [GiftAnimation] MP4 player error during playback: ${_videoController!.value.errorDescription}');
              if (!videoCompleter.isCompleted) {
                videoCompleter.complete();
              }
            } else if (_videoController!.value.position >= _videoController!.value.duration &&
                !_videoController!.value.isPlaying) {
              if (!videoCompleter.isCompleted) {
                videoCompleter.complete();
              }
            }
          });

          await _videoController!.play();
          if (!mounted) {
            _videoController?.dispose();
            _videoController = null;
            return;
          }
          await videoCompleter.future;
          debugPrint('🎁 [GiftAnimation] MP4 playback finished via callback');
        } catch (e) {
          debugPrint('❌ [GiftAnimation] Video initialize error: $e');
        }
      } else if (isPng) {
        await Future.delayed(const Duration(seconds: 4));
        debugPrint('🎁 [GiftAnimation] PNG duration fallback: 4000ms');
      } else {
        final parser = SVGAParser();
        dynamic videoItem;

        // 1. Wait for SVGA to load/decode
        try {
          if (transaction.primaryTransaction.giftSvgaUrl != null &&
              transaction.primaryTransaction.giftSvgaUrl!.isNotEmpty) {
            videoItem = await parser
                .decodeFromURL(transaction.primaryTransaction.giftSvgaUrl!);
          } else {
            debugPrint('🎁 [GiftAnimation] No SVGA URL, skipping animation to prevent OOM');
            videoItem = null;
          }
        } catch (e) {
          debugPrint('❌ [GiftAnimation] SVGA Parse Error: $e');
        }

        if (!mounted) return;

        // 2. Play SVGA and wait for completion via callback
        if (videoItem != null) {
          _svgaController?.dispose();
          _svgaController = SVGAAnimationController(vsync: this);
          _svgaController!.videoItem = videoItem;

          final Completer<void> svgaCompleter = Completer<void>();
          _svgaController!.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (!svgaCompleter.isCompleted) {
                svgaCompleter.complete();
              }
            }
          });

          setState(() {}); // Trigger rebuild to show SVGAImage

          _svgaController!.forward(); // Play exactly once
          await svgaCompleter.future;
          debugPrint('🎁 [GiftAnimation] SVGA playback finished via callback');
        } else {
          await Future.delayed(const Duration(seconds: 4)); // fallback
        }
      }

      if (!mounted) return;

      if (widget.onGiftFlightTriggered != null) {
        widget.onGiftFlightTriggered!(
            transaction.primaryTransaction, transaction.receiverIds);
      }
    } catch (e) {
      debugPrint('❌ [GiftAnimation] Error processing gift: $e');
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      if (widget.onGiftFlightTriggered != null) {
        widget.onGiftFlightTriggered!(
            transaction.primaryTransaction, transaction.receiverIds);
      }
    }

    // 4. Clear current and process next
    if (mounted) {
      setState(() {
        _currentTransaction = null;
      });
      try {
        _videoController?.dispose();
      } catch (_) {}
      _videoController = null;
      try {
        _svgaController?.dispose();
      } catch (_) {}
      _svgaController = null;
      // Small delay before next gift to prevent overlap/flicker
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _processQueue();
      }
    } else {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isProcessing = false;
    _queue.clear();
    try {
      _videoController?.dispose();
    } catch (_) {}
    _videoController = null;
    try {
      _svgaController?.dispose();
    } catch (_) {}
    _svgaController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTransaction == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: _buildSVGAAnimation(_currentTransaction!.primaryTransaction),
      ),
    );
  }

  Widget _buildSVGAAnimation(GiftTransaction transaction) {
    final url = transaction.giftSvgaUrl?.toLowerCase() ?? '';

    if (url.contains('.mp4')) {
      if (_videoController == null || !_videoController!.value.isInitialized) {
        return const SizedBox.shrink();
      }

      Widget videoWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );

      if (_shader != null) {
        final double aspect = _videoController!.value.aspectRatio / 2; // Horizontal side-by-side
        return Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: ShaderMask(
              blendMode: BlendMode.src,
              shaderCallback: (Rect bounds) {
                final shader = _shader!;
                shader.setFloat(0, bounds.width);  // uSize.x
                shader.setFloat(1, bounds.height); // uSize.y
                shader.setFloat(2, 0.0); // uLayout (0.0 = horizontal)
                return shader;
              },
              child: videoWidget,
            ),
          ),
        );
      }

      // Fallback if shader is not loaded yet
      return videoWidget;
    } else if (url.contains('.png')) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: transaction.giftSvgaUrl!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (transaction.giftSvgaUrl != null &&
        transaction.giftSvgaUrl!.isNotEmpty &&
        _svgaController != null) {
      debugPrint(
          '🎁 [GiftAnimation] Displaying SVGA via SVGAImage from Firebase URL: ${transaction.giftSvgaUrl}');

      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SVGAImage(
          _svgaController!,
          fit: BoxFit.contain,
        ),
      );
    } else {
      debugPrint('🎁 [GiftAnimation] No SVGA URL or controller not initialized, skipping fallback asset to prevent OOM');
      return const SizedBox.shrink();
    }
  }
}
