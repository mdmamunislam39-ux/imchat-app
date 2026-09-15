import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reusable singleton manager to cache compiled fragment program
class AlphaVideoShaderManager {
  static final AlphaVideoShaderManager instance =
      AlphaVideoShaderManager._internal();
  AlphaVideoShaderManager._internal();

  ui.FragmentProgram? _program;
  bool _isInitializing = false;
  Completer<ui.FragmentProgram?>? _completer;

  Future<ui.FragmentProgram?> getProgram() async {
    if (_program != null) return _program;
    if (_isInitializing) return _completer?.future;

    _isInitializing = true;
    _completer = Completer<ui.FragmentProgram?>();

    try {
      debugPrint('🎨 AlphaVideoShaderManager: Compiling fragment program...');
      final program =
          await ui.FragmentProgram.fromAsset('shaders/alpha_video.frag');
      _program = program;
      debugPrint(
          '✅ AlphaVideoShaderManager: Fragment program compiled successfully!');
      _completer?.complete(program);
    } catch (e) {
      debugPrint(
          '❌ AlphaVideoShaderManager: Failed to compile fragment program: $e');
      _completer?.complete(null);
    }

    _isInitializing = false;
    return _program;
  }
}

/// A premium transparent video player widget for side-by-side or top-and-bottom alpha mask MP4s
class AlphaVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String? videoUrl;
  final bool isAsset;
  final double? width;
  final double? height;
  final bool
      isVerticalLayout; // true = vertical (top/bottom), false = horizontal (left/right)
  final bool
      isMaskLeft; // true = mask is on left/top, false = mask is on right/bottom
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
  State<AlphaVideoPlayer> createState() => _AlphaVideoPlayerState();
}

class _AlphaVideoPlayerState extends State<AlphaVideoPlayer> {
  VideoPlayerController? _controller;
  ui.FragmentShader? _shader;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _shaderLoaded = false;
  bool _isInternallyCreated = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(AlphaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.isAsset != widget.isAsset ||
        oldWidget.controller != widget.controller) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    if (widget.controller != null) {
      _controller = widget.controller;
      _isInternallyCreated = false;
      _isInitialized = _controller!.value.isInitialized;

      final program = await AlphaVideoShaderManager.instance.getProgram();
      if (program != null && mounted) {
        setState(() {
          _shader = program.fragmentShader();
          _shaderLoaded = true;
          _isInitialized = true;
        });
      }
      return;
    }

    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) return;

    // 1. Clean up existing controller if internally created
    if (_isInternallyCreated) {
      await _controller?.dispose();
    }

    // 2. Initialize video player
    try {
      final controller = widget.isAsset
          ? VideoPlayerController.asset(widget.videoUrl!)
          : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));

      _controller = controller;
      _isInternallyCreated = true;

      await controller.initialize();

      if (widget.loop) {
        await controller.setLooping(true);
      } else if (widget.onComplete != null) {
        controller.addListener(() {
          if (controller.value.position >= controller.value.duration) {
            widget.onComplete?.call();
          }
        });
      }

      if (widget.autoplay) {
        await controller.play();
      }

      // 3. Load & instantiate Shader
      final program = await AlphaVideoShaderManager.instance.getProgram();
      if (program != null && mounted) {
        setState(() {
          _shader = program.fragmentShader();
          _shaderLoaded = true;
        });
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ AlphaVideoPlayer: Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isInternallyCreated) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent)),
        ),
      );
    }

    final double aspect = widget.isVerticalLayout
        ? _controller!.value.aspectRatio * 2
        : _controller!.value.aspectRatio / 2;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: _shaderLoaded && _shader != null
              ? ShaderMask(
                  blendMode: BlendMode.src,
                  shaderCallback: (Rect bounds) {
                    final shader = _shader!;
                    // Set uniforms
                    shader.setFloat(0, bounds.width); // uSize.x
                    shader.setFloat(1, bounds.height); // uSize.y
                    final double layoutValue = widget.isVerticalLayout
                        ? (widget.isMaskLeft ? 3.0 : 1.0)
                        : (widget.isMaskLeft ? 2.0 : 0.0);
                    shader.setFloat(2, layoutValue); // uLayout
                    return shader;
                  },
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : ClipRect(
                  // Fallback: simple cropped view showing color side
                  child: FractionallySizedBox(
                    alignment: Alignment.topLeft,
                    widthFactor: widget.isVerticalLayout ? 1.0 : 2.0,
                    heightFactor: widget.isVerticalLayout ? 2.0 : 1.0,
                    child: VideoPlayer(_controller!),
                  ),
                ),
        ),
      ),
    );
  }
}
