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
import '../../../components/dynamic_diamond_icon.dart';

/// Class for grouping identical multi-recipient transactions
class GroupedGiftTransaction {
  final GiftTransaction primaryTransaction;
  final List<String> receiverIds;
  int totalQuantity;

  GroupedGiftTransaction({
    required this.primaryTransaction,
    required this.receiverIds,
    this.totalQuantity = 1,
  });
}

/// Overlay widget for displaying gift animations (SVGA, MP4, VAP, and Image/WebP/PNG gifts)
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
  AnimationController? _imageGiftAnimController;

  static bool _isHeavyAnimation(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('.vap') || lower.contains('.var') || lower.contains('.mp4') || lower.contains('.svga');
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

        // Proactively preload asset into RAM and disk cache immediately
        if (transaction.giftSvgaUrl != null && transaction.giftSvgaUrl!.trim().isNotEmpty) {
          FastAssetCache.preload(transaction.giftSvgaUrl);
        }
        if (transaction.giftPngUrl.trim().isNotEmpty) {
          FastAssetCache.preload(transaction.giftPngUrl);
        }

        // Rapid combo hits bypass full screen display and trigger flight directly
        if (transaction.isComboHit) {
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
            grouped.totalQuantity += (transaction.quantity > 0 ? transaction.quantity : 1);
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
            _currentTransaction!.totalQuantity += (transaction.quantity > 0 ? transaction.quantity : 1);
            merged = true;
          }
        }

        if (!merged) {
          _queue.add(GroupedGiftTransaction(
            primaryTransaction: transaction,
            receiverIds: [transaction.receiverId],
            totalQuantity: transaction.quantity > 0 ? transaction.quantity : 1,
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

    // Lookahead: Preload upcoming queue items in background
    for (final nextGroup in _queue.take(2)) {
      final nextUrl = nextGroup.primaryTransaction.giftSvgaUrl;
      if (nextUrl != null && nextUrl.isNotEmpty) {
        FastAssetCache.preload(nextUrl);
      }
    }

    if (mounted) {
      setState(() {
        _currentTransaction = transaction;
      });
    }

    try {
      debugPrint(
          '🎁 [GiftAnimation] Processing grouped gift: ${transaction.primaryTransaction.giftName} for ${transaction.receiverIds.length} users');

      final rawUrl = transaction.primaryTransaction.giftSvgaUrl?.toLowerCase() ?? '';
      final isVap = rawUrl.contains('.vap') || rawUrl.contains('.var');
      final isMp4 = rawUrl.contains('.mp4') || isVap;
      final isSvga = rawUrl.contains('.svga');

      if (isMp4) {
        _videoController?.dispose();

        // Get preloaded/cached file instantly from RAM/Disk
        File? cachedFile = await FastAssetCache.getVideoFile(
          transaction.primaryTransaction.giftSvgaUrl!,
        );

        Duration exactDuration = Duration.zero;

        if (cachedFile != null) {
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

            setState(() {});

            final videoDur = _videoController!.value.duration;
            if (transaction.primaryTransaction.showingTimeSeconds != null &&
                transaction.primaryTransaction.showingTimeSeconds! > 0) {
              exactDuration = Duration(seconds: transaction.primaryTransaction.showingTimeSeconds!);
            } else if (videoDur > Duration.zero) {
              exactDuration = videoDur;
            } else {
              exactDuration = const Duration(seconds: 4);
            }

            debugPrint('🎁 [GiftAnimation] Playing MP4/Alpha gift for exact duration: ${exactDuration.inMilliseconds}ms');
          } catch (e) {
            debugPrint('❌ [GiftAnimation] Video initialize error: $e');
            exactDuration = (transaction.primaryTransaction.showingTimeSeconds != null &&
                    transaction.primaryTransaction.showingTimeSeconds! > 0)
                ? Duration(seconds: transaction.primaryTransaction.showingTimeSeconds!)
                : const Duration(seconds: 4);
          }
        } else {
          exactDuration = (transaction.primaryTransaction.showingTimeSeconds != null &&
                  transaction.primaryTransaction.showingTimeSeconds! > 0)
              ? Duration(seconds: transaction.primaryTransaction.showingTimeSeconds!)
              : const Duration(seconds: 4);
        }

        // Wait EXACTLY for the video's full duration - not less, not more!
        await Future.delayed(exactDuration);
        debugPrint('🎁 [GiftAnimation] MP4/Alpha playback finished (Duration: ${exactDuration.inMilliseconds}ms)');
      } else if (isSvga) {
        dynamic videoItem;

        try {
          final svgaUrl = transaction.primaryTransaction.giftSvgaUrl;
          if (svgaUrl != null && svgaUrl.isNotEmpty) {
            videoItem = await FastAssetCache.decodeSvga(svgaUrl);
          } else {
            videoItem = null;
          }
        } catch (e) {
          debugPrint('❌ [GiftAnimation] SVGA Parse Error: $e');
        }

        if (!mounted) return;

        if (videoItem != null) {
          _svgaController?.dispose();
          _svgaController = SVGAAnimationController(vsync: this);
          _svgaController!.videoItem = videoItem;

          // Dynamically determine exact duration from SVGA file/controller (Frames / FPS)
          Duration svgaDuration = _svgaController!.duration ?? Duration.zero;
          if (svgaDuration == Duration.zero) {
            try {
              final int frames = (videoItem.params.frames ?? 60) as int;
              final int fps = (videoItem.params.fps ?? 20) as int;
              svgaDuration = Duration(milliseconds: (frames / (fps > 0 ? fps : 20) * 1000).toInt());
            } catch (_) {
              svgaDuration = const Duration(seconds: 4);
            }
          }

          final Completer<void> svgaCompleter = Completer<void>();
          _svgaController!.addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              if (!svgaCompleter.isCompleted) {
                svgaCompleter.complete();
              }
            }
          });

          setState(() {});

          _svgaController!.forward();

          // NO fixed duration limit! Safe timeout is actual SVGA duration + safety buffer
          final safeTimeout = svgaDuration + const Duration(milliseconds: 1000);
          await svgaCompleter.future.timeout(
            safeTimeout,
            onTimeout: () {
              debugPrint('⏱️ [GiftAnimation] SVGA safety timeout after ${safeTimeout.inMilliseconds}ms - advancing');
            },
          );
          debugPrint('🎁 [GiftAnimation] SVGA playback finished (Duration: ${svgaDuration.inMilliseconds}ms)');
        } else {
          final Duration fallbackDuration = _queue.isNotEmpty
              ? const Duration(milliseconds: 600)
              : const Duration(milliseconds: 1200);
          await Future.delayed(fallbackDuration);
        }
      } else {
        // Image / WebP / PNG / JPG / GIF gift with center pill banner - existing configured duration (7s default)
        _imageGiftAnimController?.dispose();
        const animDuration = Duration(seconds: 7);

        _imageGiftAnimController = AnimationController(
          vsync: this,
          duration: animDuration,
        );

        if (mounted) {
          setState(() {});
        }

        try {
          await _imageGiftAnimController!.forward();
        } catch (_) {}
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

    // Notify transaction finished, clear current and process next
    if (mounted) {
      widget.onTransactionFinished?.call(transaction.primaryTransaction);

      final vToDispose = _videoController;
      _videoController = null;
      final sToDispose = _svgaController;
      _svgaController = null;
      final iToDispose = _imageGiftAnimController;
      _imageGiftAnimController = null;

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
        try {
          iToDispose?.dispose();
        } catch (_) {}
      });

      // Small delay before next gift to prevent overlap/flicker
      await Future.delayed(const Duration(milliseconds: 80));
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
    try {
      _imageGiftAnimController?.dispose();
    } catch (_) {}
    _imageGiftAnimController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTransaction == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: _buildGiftAnimation(_currentTransaction!),
      ),
    );
  }

  Widget _buildGiftAnimation(GroupedGiftTransaction grouped) {
    final transaction = grouped.primaryTransaction;
    final url = transaction.giftSvgaUrl?.toLowerCase() ?? '';

    if (url.contains('.mp4') || url.contains('.vap') || url.contains('.var')) {
      return UniversalAssetWidget(
        url: transaction.giftSvgaUrl!,
        fit: BoxFit.contain,
        isAlphaVideo: true,
        looping: false,
      );
    } else if (url.contains('.svga')) {
      if (transaction.giftSvgaUrl != null &&
          transaction.giftSvgaUrl!.isNotEmpty &&
          _svgaController != null) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: SVGAImage(
            _svgaController!,
            fit: BoxFit.contain,
          ),
        );
      }
      return const SizedBox.shrink();
    } else {
      // Image Gift (WebP / PNG / JPG / GIF / Static & Animated Image gifts)
      return _buildImageGift(grouped);
    }
  }

  Widget _buildImageGift(GroupedGiftTransaction grouped) {
    final primaryTx = grouped.primaryTransaction;
    final imageUrl = (primaryTx.giftSvgaUrl != null &&
            primaryTx.giftSvgaUrl!.trim().isNotEmpty &&
            !_isHeavyAnimation(primaryTx.giftSvgaUrl))
        ? primaryTx.giftSvgaUrl!
        : primaryTx.giftPngUrl;

    final receiverText = grouped.receiverIds.length > 1
        ? '${grouped.receiverIds.length}People'
        : (primaryTx.receiverName.isNotEmpty ? primaryTx.receiverName : 'Recipient');

    final displayQuantity = grouped.totalQuantity > 0
        ? grouped.totalQuantity
        : (primaryTx.quantity > 0 ? primaryTx.quantity : 1);

    final anim = _imageGiftAnimController;

    return AnimatedBuilder(
      animation: anim ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final double val = anim?.value ?? 1.0;
        double scale = 1.0;
        double opacity = 1.0;

        if (val < 0.08) {
          final t = val / 0.08;
          scale = Curves.easeOutBack.transform(t);
          opacity = t.clamp(0.0, 1.0);
        } else if (val > 0.92) {
          final t = (val - 0.92) / 0.08;
          scale = 1.0 - (t * 0.2);
          opacity = (1.0 - t).clamp(0.0, 1.0);
        } else {
          scale = 1.0;
          opacity = 1.0;
        }

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gift Image (PNG / WebP / Image) - nicely constrained
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 155,
                      maxHeight: 155,
                      minWidth: 80,
                      minHeight: 80,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox.shrink(),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.card_giftcard,
                        size: 64,
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ),
                                   // Rounded Pill Banner below the gift image (slimmed down frame)
                  Container(
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 14,
                      top: 3,
                      bottom: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00A2FF),
                          Color(0xFF0066FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007BFF).withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Sender Avatar (kept clear and prominent)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            image: primaryTx.senderImageUrl != null &&
                                    primaryTx.senderImageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(
                                        primaryTx.senderImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: primaryTx.senderImageUrl == null ||
                                  primaryTx.senderImageUrl!.isEmpty
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // Sender Name and Receivers / Diamond Info
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                primaryTx.senderName.isNotEmpty
                                    ? primaryTx.senderName
                                    : 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  receiverText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const DynamicDiamondIcon(
                                  width: 13,
                                  height: 13,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${primaryTx.credits}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Multiplier Text (e.g. × 1 - double size)
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '× ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(1, 2),
                                    ),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: '$displayQuantity',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(1, 2),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
