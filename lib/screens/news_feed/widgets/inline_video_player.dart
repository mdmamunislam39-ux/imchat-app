import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class InlineNewsFeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final VoidCallback onTapFullReels;

  const InlineNewsFeedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.onTapFullReels,
  });

  @override
  State<InlineNewsFeedVideoPlayer> createState() => _InlineNewsFeedVideoPlayerState();
}

class _InlineNewsFeedVideoPlayerState extends State<InlineNewsFeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_controller == null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
        _controller!.play();
      }
      return;
    }

    if (!_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) {
      setState(() => _isMuted = !_isMuted);
      return;
    }
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: (_isInitialized && _controller != null)
            ? _controller!.value.aspectRatio.clamp(0.75, 1.78)
            : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video or Thumbnail
            if (_isInitialized && _controller != null)
              VideoPlayer(_controller!)
            else if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
              Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.video_library, color: Colors.white54, size: 50),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black87,
                child: const Center(
                  child: Icon(Icons.video_library, color: Colors.white54, size: 50),
                ),
              ),

            // Tap Overlay to open full-screen Reels
            GestureDetector(
              onTap: widget.onTapFullReels,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),

            // Play / Pause Button Overlay
            if (!_isPlaying)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),

            // Controls Toolbar (Mute/Unmute & Fullscreen Reels indicator)
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  // Mute / Unmute Button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Fullscreen Reels Mode Button
                  GestureDetector(
                    onTap: widget.onTapFullReels,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Reels',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Inline Play / Pause toggle icon at top left
            if (_isInitialized)
              Positioned(
                left: 12,
                top: 12,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
