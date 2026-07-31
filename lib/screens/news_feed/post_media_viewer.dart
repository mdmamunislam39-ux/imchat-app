import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class PostMediaViewer extends StatefulWidget {
  final List<PostMedia> mediaList;
  final int initialIndex;

  const PostMediaViewer({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
  });

  @override
  State<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<PostMediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final media = widget.mediaList[index];
              if (media.type == 'video') {
                return VideoPlayerItem(url: media.url);
              }
              return ImagePlayerItem(url: media.url);
            },
          ),

          // Header Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                  onPressed: () => Get.back(),
                ),
                const Spacer(),
                if (widget.mediaList.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.mediaList.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                const Spacer(),
                const SizedBox(width: 48), // Balance spacing
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePlayerItem extends StatelessWidget {
  final String url;
  const ImagePlayerItem({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => const Center(child: LoadingIndicator()),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white60, size: 50),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerItem extends StatefulWidget {
  final String url;
  const VideoPlayerItem({super.key, required this.url});

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          _controller.play();
          _controller.setLooping(true);
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: LoadingIndicator());
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: VideoPlayer(_controller),
            ),
            if (!_controller.value.isPlaying)
              GestureDetector(
                onTap: () => setState(() => _controller.play()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
