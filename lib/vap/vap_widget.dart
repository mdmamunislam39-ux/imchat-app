import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../widgets/alpha_video_player.dart';

class VapWidget extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool isMaskLeft;
  final bool forceShader;

  const VapWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.isMaskLeft = false,
    this.forceShader = false,
  });

  @override
  State<VapWidget> createState() => _VapWidgetState();
}

class _VapWidgetState extends State<VapWidget> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadVapFile();
  }

  @override
  void didUpdateWidget(VapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.isMaskLeft != widget.isMaskLeft) {
      _loadVapFile();
    }
  }

  Future<void> _loadVapFile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _localPath = null;
    });

    try {
      if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
        final file = await DefaultCacheManager().getSingleFile(widget.url);
        String finalPath = file.path;
        if (!finalPath.toLowerCase().endsWith('.mp4') && !finalPath.toLowerCase().endsWith('.vap')) {
          final newPath = '$finalPath.mp4';
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            await File(finalPath).copy(newPath);
          }
          finalPath = newPath;
        }
        if (mounted) {
          setState(() {
            _localPath = finalPath;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _localPath = widget.url;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ [VapWidget] Error caching VAP file: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
        ),
      );
    }

    if (_hasError || _localPath == null) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.redAccent),
      );
    }

    // Use native Tencent AnimView on Android only for official .vap files if not forcing shader
    final isVapExtension = widget.url.toLowerCase().endsWith('.vap');
    if (!widget.forceShader && isVapExtension && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'imchat/vap_view',
        creationParams: {
          'path': _localPath,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    // High-performance Flutter GPU fragment shader player for all alpha videos
    final isNetworkUrl = widget.url.startsWith('http://') || widget.url.startsWith('https://');
    return AlphaVideoPlayer(
      videoUrl: isNetworkUrl ? widget.url : _localPath,
      isAsset: !isNetworkUrl && !_localPath!.contains(Platform.pathSeparator),
      fit: widget.fit,
      isMaskLeft: widget.isMaskLeft,
      loop: false,
    );
  }
}
