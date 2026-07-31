import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A custom MultiChildRenderObjectWidget that composites two children
/// using an offscreen Canvas layer and a custom BlendMode.
class BlendWidget extends MultiChildRenderObjectWidget {
  BlendWidget({
    super.key,
    required Widget colorChild,
    required Widget maskChild,
    this.blendMode = BlendMode.dstIn,
  }) : super(children: [colorChild, maskChild]);

  final BlendMode blendMode;

  @override
  RenderBlendWidget createRenderObject(BuildContext context) {
    return RenderBlendWidget(blendMode: blendMode);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBlendWidget renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class RenderBlendWidget extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  RenderBlendWidget({required BlendMode blendMode}) : _blendMode = blendMode;

  BlendMode _blendMode;
  BlendMode get blendMode => _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  void performLayout() {
    double width = constraints.hasBoundedWidth ? constraints.maxWidth : 300.0;
    double height = constraints.hasBoundedHeight ? constraints.maxHeight : 300.0;
    if (width.isInfinite || width <= 0) width = 300.0;
    if (height.isInfinite || height <= 0) height = 300.0;
    size = Size(width, height);

    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tight(size), parentUsesSize: true);
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) return;
    
    // 1. Create a composite layer for the blend operation
    context.canvas.saveLayer(offset & size, Paint());
    
    // 2. Draw the destination (colorChild)
    context.paintChild(firstChild!, offset);
    
    // 3. Draw the source (maskChild) using the composite blend mode
    if (lastChild != null && lastChild != firstChild) {
      context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
      context.paintChild(lastChild!, offset);
      context.canvas.restore(); // Blends the maskChild onto colorChild using _blendMode
    }
    
    context.canvas.restore(); // Composites the blended result onto the screen
  }
}

/// A high-performance player for side-by-side MP4 Alpha transparent videos.
/// It displays the left half (color) masked by the right half (alpha mask)
/// via a luminance-to-alpha ColorFilter and canvas blend mode.
class AlphaVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final BoxFit fit;

  const AlphaVideoPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
  });

  @override
  State<AlphaVideoPlayer> createState() => _AlphaVideoPlayerState();
}

class _AlphaVideoPlayerState extends State<AlphaVideoPlayer> {
  VideoPlayerController? _maskController;
  bool _isMaskInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMask();
  }

  @override
  void didUpdateWidget(AlphaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.dataSource != oldWidget.controller.dataSource) {
      _cleanupMask();
      _initializeMask();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllers);
    _cleanupMask();
    super.dispose();
  }

  void _cleanupMask() {
    _maskController?.removeListener(_syncMaskPlayback);
    _maskController?.dispose();
    _maskController = null;
    _isMaskInitialized = false;
  }

  void _initializeMask() {
    final String url = widget.controller.dataSource;
    if (url.isEmpty) return;

    try {
      if (widget.controller.dataSourceType == DataSourceType.file) {
        final file = File(url);
        _maskController = VideoPlayerController.file(file);
      } else if (widget.controller.dataSourceType == DataSourceType.asset) {
        _maskController = VideoPlayerController.asset(url);
      } else {
        _maskController = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      _maskController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isMaskInitialized = true;
          });
          _maskController!.setLooping(widget.controller.value.isLooping);
          _maskController!.setVolume(0.0); // Mute mask player to prevent audio echo
          
          // Sync initial play state
          if (widget.controller.value.isPlaying) {
            _maskController!.play();
            _maskController!.seekTo(widget.controller.value.position);
          }
          
          _maskController!.addListener(_syncMaskPlayback);
        }
      }).catchError((e) {
        debugPrint('❌ [AlphaVideoPlayer] Mask controller init failed: $e');
      });
    } catch (e) {
      debugPrint('❌ [AlphaVideoPlayer] Mask controller exception: $e');
    }

    widget.controller.addListener(_syncControllers);
  }

  void _syncControllers() {
    if (_maskController == null || !_isMaskInitialized || !mounted) return;

    // Sync play/pause state
    if (widget.controller.value.isPlaying && !_maskController!.value.isPlaying) {
      _maskController!.play();
    } else if (!widget.controller.value.isPlaying && _maskController!.value.isPlaying) {
      _maskController!.pause();
    }

    // Sync position if it drifts by more than 150ms
    final diff = (widget.controller.value.position - _maskController!.value.position).inMilliseconds.abs();
    if (diff > 150) {
      _maskController!.seekTo(widget.controller.value.position);
    }
  }

  void _syncMaskPlayback() {
    if (_maskController == null || !_isMaskInitialized || !mounted) return;

    // In case the mask player pauses itself or finishes early, keep in sync
    if (widget.controller.value.isPlaying && !_maskController!.value.isPlaying) {
      _maskController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final double fullWidth = widget.controller.value.size.width;
    final double height = widget.controller.value.size.height;
    // Side-by-side means actual display width is half the video width
    final double displayWidth = fullWidth / 2;

    return SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: displayWidth,
          height: height,
          child: RepaintBoundary(
            child: BlendWidget(
              colorChild: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: OverflowBox(
                    minWidth: fullWidth,
                    maxWidth: fullWidth,
                    minHeight: height,
                    maxHeight: height,
                    child: VideoPlayer(widget.controller),
                  ),
                ),
              ),
              maskChild: _isMaskInitialized
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0,
                        1.4, 0, 0, 0, -0.15, // Map Red channel of grayscale mask to Alpha with a linear threshold to clean up compression artifacts
                      ]),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 0.5,
                          child: OverflowBox(
                            minWidth: fullWidth,
                            maxWidth: fullWidth,
                            minHeight: height,
                            maxHeight: height,
                            child: VideoPlayer(_maskController!),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              blendMode: BlendMode.dstIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// A unified widget that can display SVGA, MP4 (with transparent Alpha video support),
/// and standard PNG/JPEG images. It accepts either remote URLs or local Files
/// and handles initialization and rendering seamlessly.
class UniversalAssetWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final BoxFit fit;
  final bool looping;
  final bool isAlphaVideo;

  const UniversalAssetWidget({
    super.key,
    this.url,
    this.file,
    this.fit = BoxFit.contain,
    this.looping = true,
    this.isAlphaVideo = true,
  })  : assert(url != null || file != null, 'Either url or file must be provided');

  @override
  State<UniversalAssetWidget> createState() => _UniversalAssetWidgetState();
}

class _UniversalAssetWidgetState extends State<UniversalAssetWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _initializeIfNeeded();
  }

  @override
  void didUpdateWidget(UniversalAssetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.file != oldWidget.file) {
      _cleanupVideo();
      _initializeIfNeeded();
    }
  }

  @override
  void dispose() {
    _cleanupVideo();
    super.dispose();
  }

  void _cleanupVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _hasVideoError = false;
  }

  void _initializeIfNeeded() {
    final bool isMp4 = _isFormat('mp4');

    if (isMp4) {
      try {
        if (widget.file != null) {
          _videoController = VideoPlayerController.file(widget.file!);
        } else if (widget.url != null && widget.url!.isNotEmpty) {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(widget.url!),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }

        if (_videoController != null) {
          _videoController!.initialize().then((_) {
            if (mounted) {
              setState(() {
                _isVideoInitialized = true;
              });
              _videoController!.setLooping(widget.looping);
              _videoController!.play();
            }
          }).catchError((e) {
            debugPrint('❌ [UniversalAssetWidget] Video Init Error: $e');
            if (mounted) {
              setState(() {
                _hasVideoError = true;
              });
            }
          });
        }
      } catch (e) {
        debugPrint('❌ [UniversalAssetWidget] Video Exception: $e');
        setState(() {
          _hasVideoError = true;
        });
      }
    }
  }

  bool _isFormat(String extension) {
    if (widget.file != null) {
      return widget.file!.path.toLowerCase().endsWith('.$extension');
    }
    if (widget.url != null) {
      // Strips query parameters from the url to check extension
      final cleanUrl = widget.url!.split('?').first.toLowerCase();
      return cleanUrl.endsWith('.$extension') || cleanUrl.contains('.$extension');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isFormat('mp4')) {
      if (_hasVideoError) {
        return const Center(
          child: Icon(Icons.image, color: Colors.red, size: 36),
        );
      }
      if (!_isVideoInitialized || _videoController == null) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
        );
      }

      if (widget.isAlphaVideo) {
        return AlphaVideoPlayer(
          controller: _videoController!,
          fit: widget.fit,
        );
      } else {
        return SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      }
    } else if (_isFormat('svga')) {
      if (widget.file != null) {
        // SVGAs are typically parsed from Assets or URL in the library.
        // For local files chosen via file picker in admin panel,
        // we can read the bytes and load it using SVGAParser.
        return FutureBuilder<MovieEntity?>(
          future: _parseLocalSvga(widget.file!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
              );
            }
            return _LocalSvgaPlayer(
              movieEntity: snapshot.data!,
            );
          },
        );
      } else {
        return SVGAEasyPlayer(
          resUrl: widget.url!,
          fit: widget.fit,
        );
      }
    } else {
      // Treat as PNG or standard image
      if (widget.file != null) {
        return Image.file(
          widget.file!,
          fit: widget.fit,
        );
      } else {
        return CachedNetworkImage(
          imageUrl: widget.url!,
          fit: widget.fit,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.image, color: Colors.grey, size: 36),
          ),
        );
      }
    }
  }

  Future<MovieEntity?> _parseLocalSvga(File file) async {
    try {
      final parser = SVGAParser();
      final bytes = await file.readAsBytes();
      return await parser.decodeFromBuffer(bytes);
    } catch (e) {
      debugPrint('❌ [UniversalAssetWidget] Local SVGA Parse Error: $e');
      return null;
    }
  }
}

/// Custom stateful player to render a parsed SVGA MovieEntity using a controller
class _LocalSvgaPlayer extends StatefulWidget {
  final MovieEntity movieEntity;
  const _LocalSvgaPlayer({required this.movieEntity});

  @override
  State<_LocalSvgaPlayer> createState() => _LocalSvgaPlayerState();
}

class _LocalSvgaPlayerState extends State<_LocalSvgaPlayer> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _controller.videoItem = widget.movieEntity;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SVGAImage(_controller);
  }
}
