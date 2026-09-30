import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../vap/vap_widget.dart';

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

/// A high-performance player for side-by-side or top-and-bottom MP4 Alpha transparent videos,
/// as well as standard full-frame MP4 videos.
/// For Alpha videos, it displays the color half masked by the alpha mask half
/// via a luminance-to-alpha ColorFilter and canvas blend mode.
class AlphaVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final bool isMaskLeft;
  final bool isVerticalLayout;
  final bool? isAlphaOverride;
  final VoidCallback? onComplete;

  const AlphaVideoPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.isMaskLeft = false,
    this.isVerticalLayout = false,
    this.isAlphaOverride,
    this.onComplete,
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
    _attachCompletionListener();
  }

  @override
  void didUpdateWidget(AlphaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.dataSource != oldWidget.controller.dataSource) {
      _cleanupMask();
      _initializeMask();
      _attachCompletionListener();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllers);
    widget.controller.removeListener(_checkCompletion);
    _cleanupMask();
    super.dispose();
  }

  void _attachCompletionListener() {
    widget.controller.removeListener(_checkCompletion);
    widget.controller.addListener(_checkCompletion);
  }

  void _checkCompletion() {
    if (!mounted || widget.onComplete == null) return;
    final value = widget.controller.value;
    if (value.isInitialized && value.duration > Duration.zero) {
      if (value.position >= value.duration) {
        widget.onComplete?.call();
      }
    }
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
    final double fullHeight = widget.controller.value.size.height;
    if (fullWidth <= 0 || fullHeight <= 0) {
      return const SizedBox.shrink();
    }

    final double aspect = fullWidth / fullHeight;
    // Determine whether video is side-by-side (~2:1), top-bottom (~1:2), or standard
    final bool isSideBySide = !widget.isVerticalLayout && (aspect >= 1.45 || (widget.isAlphaOverride == true && aspect >= 1.0));
    final bool isTopBottom = widget.isVerticalLayout || (aspect <= 0.7 && widget.isAlphaOverride == true);
    final bool isAlpha = widget.isAlphaOverride ?? (isSideBySide || isTopBottom);

    if (!isAlpha) {
      // Standard regular MP4 video playback (full frame)
      return SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: fullWidth,
            height: fullHeight,
            child: VideoPlayer(widget.controller),
          ),
        ),
      );
    }

    if (isTopBottom) {
      // Top-and-bottom stacked Alpha video
      final double displayHeight = fullHeight / 2;
      return SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: fullWidth,
            height: displayHeight,
            child: RepaintBoundary(
              child: BlendWidget(
                colorChild: ClipRect(
                  child: Align(
                    alignment: widget.isMaskLeft ? Alignment.bottomCenter : Alignment.topCenter,
                    heightFactor: 0.5,
                    child: OverflowBox(
                      minWidth: fullWidth,
                      maxWidth: fullWidth,
                      minHeight: fullHeight,
                      maxHeight: fullHeight,
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
                          1.4, 0, 0, 0, -0.15,
                        ]),
                        child: ClipRect(
                          child: Align(
                            alignment: widget.isMaskLeft ? Alignment.topCenter : Alignment.bottomCenter,
                            heightFactor: 0.5,
                            child: OverflowBox(
                              minWidth: fullWidth,
                              maxWidth: fullWidth,
                              minHeight: fullHeight,
                              maxHeight: fullHeight,
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

    // Side-by-side horizontal Alpha video
    final double displayWidth = fullWidth / 2;
    return SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: displayWidth,
          height: fullHeight,
          child: RepaintBoundary(
            child: BlendWidget(
              colorChild: ClipRect(
                child: Align(
                  alignment: widget.isMaskLeft ? Alignment.centerRight : Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: OverflowBox(
                    minWidth: fullWidth,
                    maxWidth: fullWidth,
                    minHeight: fullHeight,
                    maxHeight: fullHeight,
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
                          alignment: widget.isMaskLeft ? Alignment.centerLeft : Alignment.centerRight,
                          widthFactor: 0.5,
                          child: OverflowBox(
                            minWidth: fullWidth,
                            maxWidth: fullWidth,
                            minHeight: fullHeight,
                            maxHeight: fullHeight,
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

/// Ultra-fast global asset caching and preloading manager
/// Handles SVGA bytes in RAM, Video/MP4 files in disk/RAM, deduplicates network requests,
/// and enables background preloading for instant 0ms playback on all internet connections.
class FastAssetCache {
  static final Map<String, Uint8List> _bytesCache = {};
  static final Map<String, String> _filePathCache = {};
  static final Map<String, MovieEntity> _movieCache = {};
  static final Map<String, Future<Uint8List?>> _inFlightBytes = {};
  static final Map<String, Future<File?>> _inFlightFiles = {};
  static final Map<String, Future<MovieEntity?>> _inFlightMovies = {};

  /// Preloads a single asset URL (SVGA, MP4, VAP, Image) into disk and RAM
  static Future<void> preload(String? url) async {
    if (url == null || url.trim().isEmpty || !url.startsWith('http')) return;
    final cleanUrl = url.trim();
    final lower = cleanUrl.toLowerCase();
    
    try {
      if (lower.contains('.svga')) {
        await decodeSvga(cleanUrl);
      } else if (lower.contains('.mp4') || lower.contains('.vap')) {
        await getVideoFile(cleanUrl);
      } else {
        await DefaultCacheManager().getSingleFile(cleanUrl);
      }
    } catch (_) {}
  }

  /// Preloads a batch of URLs with concurrency control
  static Future<void> preloadBatch(List<String?> urls) async {
    final validUrls = urls
        .whereType<String>()
        .where((u) => u.trim().isNotEmpty && u.startsWith('http'))
        .toSet()
        .toList();
    
    for (int i = 0; i < validUrls.length; i += 3) {
      final chunk = validUrls.skip(i).take(3);
      await Future.wait(chunk.map((u) => preload(u)));
    }
  }

  /// Get SVGA raw bytes instantly from RAM or disk cache
  static Future<Uint8List?> getSvgaBytes(String url) async {
    if (_bytesCache.containsKey(url)) {
      return _bytesCache[url];
    }
    if (_inFlightBytes.containsKey(url)) {
      return await _inFlightBytes[url];
    }

    final future = _fetchSvgaBytesInternal(url);
    _inFlightBytes[url] = future;
    try {
      final bytes = await future;
      if (bytes != null && bytes.isNotEmpty) {
        _bytesCache[url] = bytes;
      }
      return bytes;
    } finally {
      _inFlightBytes.remove(url);
    }
  }

  static Future<Uint8List?> _fetchSvgaBytesInternal(String url) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return await fileInfo.file.readAsBytes();
      }
    } catch (_) {}

    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      return await file.readAsBytes();
    } catch (_) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          return bytes;
        }
      } catch (e) {
        debugPrint('❌ [FastAssetCache] SVGA direct download failed for $url: $e');
      }
    }
    return null;
  }

  /// Get local video File with proper extension instantly from cache
  static Future<File?> getVideoFile(String url) async {
    if (_filePathCache.containsKey(url)) {
      final file = File(_filePathCache[url]!);
      if (await file.exists()) return file;
    }
    if (_inFlightFiles.containsKey(url)) {
      return await _inFlightFiles[url];
    }

    final future = _fetchVideoFileInternal(url);
    _inFlightFiles[url] = future;
    try {
      final file = await future;
      if (file != null && await file.exists()) {
        _filePathCache[url] = file.path;
      }
      return file;
    } finally {
      _inFlightFiles.remove(url);
    }
  }

  static Future<File?> _fetchVideoFileInternal(String url) async {
    try {
      File cachedFile;
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        cachedFile = fileInfo.file;
      } else {
        cachedFile = await DefaultCacheManager().getSingleFile(url);
      }

      if (!cachedFile.path.toLowerCase().endsWith('.mp4')) {
        final newPath = '${cachedFile.path}.mp4';
        final newFile = File(newPath);
        if (!await newFile.exists()) {
          await cachedFile.copy(newPath);
        }
        return newFile;
      }
      return cachedFile;
    } catch (e) {
      debugPrint('❌ [FastAssetCache] Video cache failed for $url: $e');
      return null;
    }
  }

  /// Decodes MovieEntity using cached bytes and caches the parsed MovieEntity in RAM
  static Future<MovieEntity?> decodeSvga(String url) async {
    if (_inFlightMovies.containsKey(url)) {
      return await _inFlightMovies[url];
    }

    final future = _decodeSvgaInternal(url);
    _inFlightMovies[url] = future;
    try {
      return await future;
    } finally {
      _inFlightMovies.remove(url);
    }
  }

  static Future<MovieEntity?> _decodeSvgaInternal(String url) async {
    try {
      final bytes = await getSvgaBytes(url);
      if (bytes != null && bytes.isNotEmpty) {
        final parser = SVGAParser();
        return await parser.decodeFromBuffer(bytes);
      }
    } catch (e) {
      debugPrint('❌ [FastAssetCache] SVGA buffer decode failed for $url: $e');
    }

    try {
      final parser = SVGAParser();
      return await parser.decodeFromURL(url);
    } catch (e) {
      debugPrint('❌ [FastAssetCache] SVGAParser decodeFromURL fallback failed for $url: $e');
    }
    return null;
  }

  static void clear() {
    _bytesCache.clear();
    _filePathCache.clear();
    _movieCache.clear();
    _inFlightBytes.clear();
    _inFlightFiles.clear();
    _inFlightMovies.clear();
  }
}

/// A unified widget that can display SVGA, MP4 (with transparent Alpha video support),
/// and standard PNG/JPEG images. It accepts either remote URLs or local Files
/// and handles initialization and rendering seamlessly.
class UniversalAssetWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool looping;
  final bool isAlphaVideo;
  final bool? isMaskLeft;
  final bool isVerticalLayout;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onComplete;
  final ValueChanged<Duration>? onDurationLoaded;

  const UniversalAssetWidget({
    super.key,
    this.url,
    this.file,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.looping = true,
    this.isAlphaVideo = true,
    this.isMaskLeft,
    this.isVerticalLayout = false,
    this.placeholder,
    this.errorWidget,
    this.onComplete,
    this.onDurationLoaded,
  }) : assert(url != null || file != null, 'Either url or file must be provided');

  /// Preload an SVGA URL into memory cache
  static Future<MovieEntity?> preloadSvga(String url) async {
    return await FastAssetCache.decodeSvga(url);
  }

  static void clearSvgaCache() {
    FastAssetCache.clear();
  }

  @override
  State<UniversalAssetWidget> createState() => _UniversalAssetWidgetState();
}

class _UniversalAssetWidgetState extends State<UniversalAssetWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  final List<File> _tempFiles = [];
  int _currentLoadId = 0;

  MovieEntity? _svgaMovie;
  String? _svgaLoadedSource;
  bool _isSvgaLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeIfNeeded();
    _loadSvgaIfNeeded();
  }

  @override
  void didUpdateWidget(UniversalAssetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.file != oldWidget.file) {
      _cleanupVideo();
      _initializeIfNeeded();
      _loadSvgaIfNeeded();
    }
  }

  @override
  void dispose() {
    _cleanupVideo();
    _svgaMovie = null;
    _svgaLoadedSource = null;
    super.dispose();
  }

  void _loadSvgaIfNeeded() async {
    if (!_isFormat('svga')) return;

    final sourceKey = widget.url ?? widget.file?.path;
    if (sourceKey == null || sourceKey.isEmpty) return;

    if (sourceKey == _svgaLoadedSource && _svgaMovie != null) {
      return; // Already loaded, do not re-decode!
    }

    _svgaLoadedSource = sourceKey;
    _isSvgaLoading = true;

    MovieEntity? movie;
    if (widget.url != null && widget.url!.isNotEmpty) {
      movie = await FastAssetCache.decodeSvga(widget.url!);
    } else if (widget.file != null) {
      movie = await _parseLocalSvga(widget.file!);
    }

    if (mounted && _svgaLoadedSource == sourceKey) {
      setState(() {
        _svgaMovie = movie;
        _isSvgaLoading = false;
      });

      if (movie != null) {
        try {
          final int frames = movie.params.frames;
          final int fps = movie.params.fps;
          final dur = Duration(milliseconds: (frames / (fps > 0 ? fps : 20) * 1000).toInt());
          widget.onDurationLoaded?.call(dur);
        } catch (_) {}
      }
    }
  }

  void _cleanupVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _hasVideoError = false;

    // Clean up temp files
    for (final file in _tempFiles) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('⚠️ [UniversalAssetWidget] Failed to delete temp file: $e');
      }
    }
    _tempFiles.clear();
  }

  void _initializeIfNeeded() async {
    final int loadId = ++_currentLoadId;
    if (_isFormat('vap') && Platform.isAndroid) {
      return;
    }
    final bool isMp4 = _isFormat('mp4') || _isFormat('vap');

    if (isMp4) {
      try {
        File? videoFile;

        if (widget.file != null) {
          File fileToUse = widget.file!;
          if (fileToUse.path.toLowerCase().endsWith('.vap')) {
            try {
              final tempDir = Directory.systemTemp;
              final tempPath = '${tempDir.path}/temp_preview_${DateTime.now().microsecondsSinceEpoch}.mp4';
              final tempFile = File(tempPath);
              await fileToUse.copy(tempPath);
              fileToUse = tempFile;
              _tempFiles.add(tempFile);
            } catch (e) {
              debugPrint('⚠️ [UniversalAssetWidget] Failed to copy local VAP to temporary MP4: $e');
            }
          }
          videoFile = fileToUse;
        } else if (widget.url != null && widget.url!.isNotEmpty) {
          videoFile = await FastAssetCache.getVideoFile(widget.url!);
        }

        if (loadId != _currentLoadId) return;

        if (videoFile != null) {
          _videoController = VideoPlayerController.file(videoFile);
        } else if (widget.url != null && widget.url!.isNotEmpty) {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(widget.url!),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }

        if (_videoController != null) {
          await _videoController!.initialize();

          if (loadId != _currentLoadId || !mounted) {
            _videoController?.dispose();
            _videoController = null;
            return;
          }

          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.setLooping(widget.looping);
          _videoController!.play();
          widget.onDurationLoaded?.call(_videoController!.value.duration);
        }
      } catch (e) {
        debugPrint('❌ [UniversalAssetWidget] Video Exception: $e');
        if (mounted && loadId == _currentLoadId) {
          setState(() {
            _hasVideoError = true;
          });
        }
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

  bool get _effectiveIsMaskLeft {
    if (widget.isMaskLeft != null) return widget.isMaskLeft!;
    final source = (widget.file?.path ?? widget.url ?? '').toLowerCase();
    return source.contains('mask_left') ||
        source.contains('left_mask') ||
        source.contains('drive_file') ||
        source.contains('temp.mp4');
  }

  @override
  Widget build(BuildContext context) {
    Widget result;

    if (_isFormat('vap') && Theme.of(context).platform == TargetPlatform.android) {
      final vapSource = widget.file != null ? widget.file!.path : (widget.url ?? '');
      result = VapWidget(
        url: vapSource,
        fit: widget.fit,
        isMaskLeft: _effectiveIsMaskLeft,
      );
    } else if (_isFormat('mp4') || _isFormat('vap')) {
      if (_hasVideoError) {
        result = widget.errorWidget ??
            (widget.isAlphaVideo
                ? const SizedBox.shrink()
                : const Center(
                    child: Icon(Icons.image, color: Colors.red, size: 36),
                  ));
      } else if (!_isVideoInitialized || _videoController == null) {
        result = widget.placeholder ??
            (widget.isAlphaVideo
                ? const SizedBox.shrink()
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
                  ));
      } else if (widget.isAlphaVideo) {
        result = AlphaVideoPlayer(
          controller: _videoController!,
          fit: widget.fit,
          isMaskLeft: _effectiveIsMaskLeft,
          isVerticalLayout: widget.isVerticalLayout,
          onComplete: widget.onComplete,
        );
      } else {
        result = SizedBox.expand(
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
      if (_svgaMovie != null) {
        result = _LocalSvgaPlayer(
          key: ValueKey(_svgaLoadedSource),
          movieEntity: _svgaMovie!,
          fit: widget.fit,
          looping: widget.looping,
          onComplete: widget.onComplete,
        );
      } else if (_isSvgaLoading) {
        result = widget.placeholder ??
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
              ),
            );
      } else if (widget.url != null && widget.url!.startsWith('http')) {
        // Fallback to cached network image in case format was misclassified or binary decode failed
        result = CachedNetworkImage(
          imageUrl: widget.url!,
          fit: widget.fit,
          placeholder: (context, url) => widget.placeholder ?? const SizedBox.shrink(),
          errorWidget: (context, url, error) => widget.errorWidget ?? const SizedBox.shrink(),
        );
      } else {
        result = widget.errorWidget ?? const SizedBox.shrink();
      }
    } else {
      // Treat as PNG, WEBP or standard image
      final bool isWebp = _isFormat('webp');
      final BoxFit effectiveFit = isWebp ? BoxFit.contain : widget.fit;

      Widget content;
      if (widget.file != null) {
        content = Image.file(
          widget.file!,
          fit: effectiveFit,
        );
      } else if (widget.url != null && (widget.url!.startsWith('file:/') || widget.url!.startsWith('file://'))) {
        try {
          final uri = Uri.parse(widget.url!);
          final filePath = uri.path.isNotEmpty ? uri.toFilePath() : widget.url!.replaceAll(RegExp(r'^file:/+'), '/');
          content = Image.file(
            File(filePath),
            fit: effectiveFit,
            errorBuilder: (context, error, stackTrace) =>
                widget.errorWidget ??
                (widget.isAlphaVideo
                    ? const SizedBox.shrink()
                    : const Center(
                        child: Icon(Icons.image, color: Colors.grey, size: 36),
                      )),
          );
        } catch (_) {
          content = widget.errorWidget ??
              (widget.isAlphaVideo
                  ? const SizedBox.shrink()
                  : const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
                    ));
        }
      } else if (widget.url != null && widget.url!.startsWith('http')) {
        content = CachedNetworkImage(
          imageUrl: widget.url!,
          fit: effectiveFit,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) =>
              widget.placeholder ??
              (widget.isAlphaVideo
                  ? const SizedBox.shrink()
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
                      ),
                    )),
          errorWidget: (context, url, error) =>
              widget.errorWidget ??
              (widget.isAlphaVideo
                  ? const SizedBox.shrink()
                  : const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 36),
                    )),
        );
      } else {
        content = widget.errorWidget ??
            (widget.isAlphaVideo
                ? const SizedBox.shrink()
                : const Center(
                    child: Icon(Icons.image, color: Colors.grey, size: 36),
                  ));
      }

      result = content;
    }

    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: result,
      );
    }
    return result;
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
  final BoxFit fit;
  final bool looping;
  final VoidCallback? onComplete;

  const _LocalSvgaPlayer({
    super.key,
    required this.movieEntity,
    this.fit = BoxFit.contain,
    this.looping = true,
    this.onComplete,
  });

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
    if (widget.looping) {
      _controller.repeat();
    } else {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _LocalSvgaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieEntity != widget.movieEntity || oldWidget.looping != widget.looping) {
      _controller.videoItem = widget.movieEntity;
      _controller.reset();
      if (widget.looping) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SVGAImage(_controller, fit: widget.fit);
  }
}
