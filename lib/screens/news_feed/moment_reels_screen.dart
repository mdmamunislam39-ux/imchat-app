import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/services/follow_service.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/rich_text_viewer.dart';
import 'package:chat_messenger/screens/news_feed/post_comments_sheet.dart';
import 'package:chat_messenger/screens/news_feed/widgets/fb_reaction_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';


class MomentReelsScreen extends StatefulWidget {
  final List<NewsFeedPost> videoPosts;
  final int initialIndex;

  const MomentReelsScreen({
    super.key,
    required this.videoPosts,
    required this.initialIndex,
  });

  @override
  State<MomentReelsScreen> createState() => _MomentReelsScreenState();
}

class _MomentReelsScreenState extends State<MomentReelsScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final String _currentUserId = AuthController.instance.currentUser.userId;

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
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videoPosts.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final post = widget.videoPosts[index];
              return _ReelsVideoItem(
                key: ValueKey(post.id),
                post: post,
                isCurrentPage: index == _currentIndex,
                currentUserId: _currentUserId,
              );
            },
          ),

          // Top Header Bar (Back button & Title)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Reels',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.camera_alt_outlined, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsVideoItem extends StatefulWidget {
  final NewsFeedPost post;
  final bool isCurrentPage;
  final String currentUserId;

  const _ReelsVideoItem({
    super.key,
    required this.post,
    required this.isCurrentPage,
    required this.currentUserId,
  });

  @override
  State<_ReelsVideoItem> createState() => _ReelsVideoItemState();
}

class _ReelsVideoItemState extends State<_ReelsVideoItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showHeartAnimation = false;
  bool _showSeekLeftAnimation = false;
  bool _showSeekRightAnimation = false;
  Offset _doubleTapPosition = Offset.zero;
  final GlobalKey _likeBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    NewsFeedService.incrementPostViewCount(widget.post.id);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return '$count';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void didUpdateWidget(covariant _ReelsVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage != oldWidget.isCurrentPage) {
      if (widget.isCurrentPage) {
        _controller?.play();
        setState(() => _isPlaying = true);
      } else {
        _controller?.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _initializeVideo() async {
    final videoMedia = widget.post.media.firstWhere(
      (m) => m.type == 'video',
      orElse: () => widget.post.media.first,
    );

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoMedia.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          if (widget.isCurrentPage) {
            _controller?.play();
            _controller?.setLooping(true);
          }
        }
      }).catchError((err) {
        debugPrint('❌ Error loading reels video: $err');
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller?.pause();
        _isPlaying = false;
      } else {
        _controller?.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_isInitialized) return;
    final current = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = current + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _controller!.seekTo(Duration.zero);
    } else if (newPosition > duration) {
      _controller!.seekTo(duration);
    } else {
      _controller!.seekTo(newPosition);
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    if (dx < screenWidth / 3) {
      // Double tap LEFT -> Seek -10s
      _seekRelative(-10);
      setState(() => _showSeekLeftAnimation = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showSeekLeftAnimation = false);
      });
    } else if (dx > screenWidth * 2 / 3) {
      // Double tap RIGHT -> Seek +10s
      _seekRelative(10);
      setState(() => _showSeekRightAnimation = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showSeekRightAnimation = false);
      });
    } else {
      // Double tap CENTER -> Heart animation + Love reaction
      setState(() {
        _doubleTapPosition = details.localPosition;
        _showHeartAnimation = true;
      });

      NewsFeedService.setReaction(
        postId: widget.post.id,
        userId: widget.currentUserId,
        reaction: ReactionType.love,
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showHeartAnimation = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double safeBottom = bottomInset > 0 ? bottomInset : 16.0;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Dark Gradient Overlays for readable text
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Left Seek (-10s) Animation Overlay
          if (_showSeekLeftAnimation)
            Positioned(
              left: 40,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                    SizedBox(height: 2),
                    Text(
                      '-10s',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Right Seek (+10s) Animation Overlay
          if (_showSeekRightAnimation)
            Positioned(
              right: 40,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                    SizedBox(height: 2),
                    Text(
                      '+10s',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Double Tap Heart Floating Animation
          if (_showHeartAnimation)
            Positioned(
              left: _doubleTapPosition.dx - 40,
              top: _doubleTapPosition.dy - 40,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.3),
                duration: const Duration(milliseconds: 400),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.pinkAccent,
                      size: 80,
                    ),
                  );
                },
              ),
            ),

          // Play / Pause Indicator Icon overlay
          if (!_isPlaying && _isInitialized)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 80,
              ),
            ),

          // Bottom Info Bar (User Profile, Caption, Music)
          Positioned(
            left: 16,
            bottom: 30 + safeBottom,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // User Row
                Row(
                  children: [
                    CachedCircleAvatar(
                      imageUrl: widget.post.userAvatar ?? '',
                      userId: widget.post.userId,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    AnimatedSvipName.fromUserId(
                      userId: widget.post.userId,
                      defaultName: widget.post.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.post.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified, color: Colors.blue, size: 16),
                      ),
                    const SizedBox(width: 12),
                    _buildFollowButton(),
                  ],
                ),
                const SizedBox(height: 10),

                // Caption
                if (widget.post.content.isNotEmpty)
                  RichTextViewer(
                    text: widget.post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),

                const SizedBox(height: 10),

                // Sound / Music indicator
                Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Original Audio - ${widget.post.userName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Action Column (Views, Reactions, Comments, Share, Mute)
          Positioned(
            right: 16,
            bottom: 36 + safeBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Count Button (ABOVE React Button)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('news_feed_posts')
                      .doc(widget.post.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int viewCount = widget.post.viewCount;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('viewCount')) {
                        viewCount = (data['viewCount'] as num).toInt();
                      }
                    }

                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          child: const Icon(
                            Icons.remove_red_eye_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCount(viewCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                // Facebook Reaction Button
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('news_feed_posts')
                      .doc(widget.post.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    Map<String, dynamic> reactionsMap = widget.post.reactions;
                    List<dynamic> likedBy = widget.post.likedBy;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      reactionsMap = data['reactions'] ?? {};
                      likedBy = data['likedBy'] ?? [];
                    }

                    final userReactionStr = reactionsMap[widget.currentUserId];
                    ReactionType? userReaction;
                    if (userReactionStr != null) {
                      try {
                        userReaction = ReactionType.values
                            .firstWhere((e) => e.name == userReactionStr);
                      } catch (_) {}
                    }

                    return Column(
                      children: [
                        GestureDetector(
                          key: _likeBtnKey,
                          onLongPress: () {
                            FbReactionPickerOverlay.show(
                              context,
                              targetKey: _likeBtnKey,
                              onReactionSelected: (react) {
                                NewsFeedService.setReaction(
                                  postId: widget.post.id,
                                  userId: widget.currentUserId,
                                  reaction: react,
                                );
                              },
                            );
                          },
                          onTap: () {
                            NewsFeedService.toggleLike(
                              postId: widget.post.id,
                              userId: widget.currentUserId,
                            );
                          },
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.black.withValues(alpha: 0.4),
                            child: Text(
                              userReaction?.emoji ?? '👍',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${likedBy.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                // Comment Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => PostCommentsSheet(post: widget.post),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        child: const Icon(Icons.comment, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.post.commentCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Share Button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final link = DeepLinkService.generatePostLink(widget.post.id);
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Check out this video from ${widget.post.userName} on imChat:\n\n${widget.post.content}\n\n$link',
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        child: const Icon(Icons.share, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Sound Mute Toggle
                GestureDetector(
                  onTap: _toggleMute,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Video Progress Bar & Timestamp at bottom (Facebook Reels Style)
          if (_isInitialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: safeBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Display Badge (e.g. 01:15 / 03:45)
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller!,
                    builder: (context, value, child) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Interactive Video Progress Bar with Drag Scrubbing
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFFE41E3F), // Facebook Red Accent
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    if (widget.post.userId == widget.currentUserId) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUserId)
          .collection('following')
          .doc(widget.post.userId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.hasData && snapshot.data!.exists;
        return GestureDetector(
          onTap: () async {
            if (isFollowing) {
              await FollowService.unfollowUser(
                currentUserId: widget.currentUserId,
                targetUserId: widget.post.userId,
              );
            } else {
              await FollowService.followUser(
                currentUserId: widget.currentUserId,
                targetUserId: widget.post.userId,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.white24 : Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
