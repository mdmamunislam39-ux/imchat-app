import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../AdminPane/models/gift.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../components/universal_asset_widget.dart';
import '../../../vap/vap_widget.dart';

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
  final Function(GiftTransaction transaction)? onTransactionFinished;
  final Function(GiftTransaction transaction, List<String> receiverIds)? onGiftFlightTriggered;

  const GiftAnimationOverlay({
    super.key,
    required this.transactions,
    this.onAnimationComplete,
    this.onTransactionFinished,
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

  static final Map<String, Uint8List> _svgaBytesCache = {};

  Future<dynamic> _loadSvgaWithCache(String url) async {
    try {
      Uint8List? bytes = _svgaBytesCache[url];
      if (bytes == null) {
        final file = await DefaultCacheManager()
            .getSingleFile(url)
            .timeout(const Duration(seconds: 4));
        bytes = await file.readAsBytes();
        _svgaBytesCache[url] = bytes;
      }
      final parser = SVGAParser();
      return await parser.decodeFromBuffer(bytes);
    } catch (_) {
      final parser = SVGAParser();
      return await parser.decodeFromURL(url).timeout(const Duration(seconds: 3));
    }
  }

  @override
  void initState() {
    super.initState();
    _addTransactions(widget.transactions);
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

        // Combo hits and simple gifts without SVGA animation skip full-screen playback queue
        if (transaction.giftSvgaUrl == null || transaction.giftSvgaUrl!.trim().isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onGiftFlightTriggered?.call(transaction, [transaction.receiverId]);
            widget.onTransactionFinished?.call(transaction);
          });
          continue;
        }

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
      final isVap = url.contains('.vap');
      final isMp4 = url.contains('.mp4') || isVap;
      final isPng = url.contains('.png');

      if (isMp4) {
        _videoController?.dispose();

        // Cache the file locally to guarantee instant playback
        File cachedFile = await DefaultCacheManager()
            .getSingleFile(transaction.primaryTransaction.giftSvgaUrl!)
            .timeout(const Duration(seconds: 5));
            
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

          if (isVap && Theme.of(context).platform == TargetPlatform.android) {
            final duration = _videoController!.value.duration;
            await Future.delayed(duration);
            debugPrint('🎁 [GiftAnimation] VAP Android native playback finished via duration timer: $duration');
          } else {
            final Completer<void> videoCompleter = Completer<void>();
            _videoController!.addListener(() {
              if (_videoController == null) return;
              
              if (_videoController!.value.hasError) {
                debugPrint('❌ [GiftAnimation] MP4 player error during playback: ${_videoController!.value.errorDescription}');
                if (!videoCompleter.isCompleted) {
                  videoCompleter.complete();
                }
              } else {
                final pos = _videoController!.value.position;
                final dur = _videoController!.value.duration;
                if ((dur > Duration.zero && pos >= dur) ||
                    (pos > const Duration(milliseconds: 500) && !_videoController!.value.isPlaying)) {
                  if (!videoCompleter.isCompleted) {
                    videoCompleter.complete();
                  }
                }
              }
            });

            await _videoController!.play();
            if (!mounted) {
              _videoController?.dispose();
              _videoController = null;
              return;
            }
            final duration = _videoController!.value.duration;
            final safeTimeout = duration > Duration.zero
                ? duration + const Duration(milliseconds: 800)
                : const Duration(seconds: 4);

            await videoCompleter.future.timeout(
              safeTimeout,
              onTimeout: () {
                debugPrint('⏱️ [GiftAnimation] MP4 player timeout after ${safeTimeout.inMilliseconds}ms - advancing');
              },
            );
            debugPrint('🎁 [GiftAnimation] MP4 playback finished');
          }
        } catch (e) {
          debugPrint('❌ [GiftAnimation] Video initialize error: $e');
        }
      } else if (isPng) {
        final Duration fallbackDuration = _queue.isNotEmpty
            ? const Duration(milliseconds: 600)
            : const Duration(milliseconds: 1200);
        await Future.delayed(fallbackDuration);
        debugPrint('🎁 [GiftAnimation] PNG duration fallback: ${fallbackDuration.inMilliseconds}ms');
      } else {
        dynamic videoItem;

        // 1. Wait for SVGA to load/decode (using memory cache)
        try {
          final svgaUrl = transaction.primaryTransaction.giftSvgaUrl;
          if (svgaUrl != null && svgaUrl.isNotEmpty) {
            videoItem = await _loadSvgaWithCache(svgaUrl);
          } else {
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

          int durationMs = 3000;
          try {
            final int frames = (videoItem.frames ?? 60) as int;
            final int fps = (videoItem.FPS ?? 20) as int;
            final calcMs = ((frames / (fps > 0 ? fps : 20)) * 1000).toInt() + 500;
            durationMs = calcMs.clamp(1000, 8000);
          } catch (_) {}

          await svgaCompleter.future.timeout(
            Duration(milliseconds: durationMs),
            onTimeout: () {
              debugPrint('⏱️ [GiftAnimation] SVGA completer timeout after ${durationMs}ms - advancing');
            },
          );
          debugPrint('🎁 [GiftAnimation] SVGA playback finished');
        } else {
          final Duration fallbackDuration = _queue.isNotEmpty
              ? const Duration(milliseconds: 600)
              : const Duration(milliseconds: 1200);
          await Future.delayed(fallbackDuration);
        }
      }

      if (!mounted) return;

      if (widget.onGiftFlightTriggered != null) {
        widget.onGiftFlightTriggered!(
            transaction.primaryTransaction, transaction.receiverIds);
      }
    } catch (e) {
      debugPrint('❌ [GiftAnimation] Error processing gift: $e');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (widget.onGiftFlightTriggered != null) {
        widget.onGiftFlightTriggered!(
            transaction.primaryTransaction, transaction.receiverIds);
      }
    }

    // 4. Notify transaction finished, clear current and process next
    if (mounted) {
      widget.onTransactionFinished?.call(transaction.primaryTransaction);

      final vToDispose = _videoController;
      _videoController = null;
      final sToDispose = _svgaController;
      _svgaController = null;

      setState(() {
        _currentTransaction = null;
      });

      // Dispose controllers after the frame unmounts to prevent paint assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          vToDispose?.dispose();
        } catch (_) {}
        try {
          sToDispose?.dispose();
        } catch (_) {}
      });

      // Small delay before next gift to prevent overlap/flicker
      await Future.delayed(const Duration(milliseconds: 100));
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

    if (url.contains('.vap') && Theme.of(context).platform == TargetPlatform.android) {
      return VapWidget(
        url: transaction.giftSvgaUrl!,
        fit: BoxFit.contain,
      );
    } else if (url.contains('.mp4') || url.contains('.vap')) {
      if (_videoController == null || !_videoController!.value.isInitialized) {
        return const SizedBox.shrink();
      }

      return AlphaVideoPlayer(
        controller: _videoController!,
        fit: BoxFit.contain,
      );
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
