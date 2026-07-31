import 'dart:async';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/screens/news_feed/post_creation_screen.dart';
import 'package:chat_messenger/screens/news_feed/post_media_viewer.dart';
import 'package:chat_messenger/components/rich_text_viewer.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/services/follow_service.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'post_comments_sheet.dart';
import 'post_reactions_summary_bar.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<NewsFeedPost> _posts = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  StreamSubscription? _feedSubscription;
  final String _currentUserId = AuthController.instance.currentUser.userId;

  @override
  void initState() {
    super.initState();
    _setupRealtimeFeed();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  /// Setup real-time updates for the initial batch of posts
  void _setupRealtimeFeed() {
    _feedSubscription?.cancel();
    setState(() {
      _isLoadingMore = true;
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    _feedSubscription = FirebaseFirestore.instance
        .collection('news_feed_posts')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      
      final updatedPosts = snapshot.docs
          .map((doc) => NewsFeedPost.fromFirestore(doc))
          .where((post) => !post.isDeleted)
          .toList();
          
      // Local sort to keep pinned posts on top
      updatedPosts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(updatedPosts);
          _isLoadingMore = false;
          if (snapshot.docs.length < 10) {
            _hasMore = false;
          }
        });
      }
    }, onError: (err) {
      debugPrint('❌ [NewsFeedScreen] Realtime feed error: $err');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    });
  }

  /// Paginate more posts when scrolling down
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snap = await NewsFeedService.fetchPostsPage(
        lastDoc: _lastDocument,
        limit: 10,
      );

      if (snap.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      _lastDocument = snap.docs.last;
      final newPosts = snap.docs
          .map((doc) => NewsFeedPost.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          // Prevent duplicates
          for (var post in newPosts) {
            if (!_posts.any((p) => p.id == post.id)) {
              _posts.add(post);
            }
          }
          _isLoadingMore = false;
          if (snap.docs.length < 10) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [NewsFeedScreen] Load more posts error: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    _setupRealtimeFeed();
  }

  @override
  Widget build(BuildContext context) {
    final User currentUser = AuthController.instance.currentUser;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F1A) : const Color(0xFFF3F4F6),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: primaryColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Container(
                color: isDarkMode ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.lightBlue,
                      highlightColor: isDarkMode ? Colors.white : Colors.lightBlueAccent.shade100,
                      child: Text(
                        'imChat Moment',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Get.to(() => const PostCreationScreen()),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),



            // Share what's on mind section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                color: isDarkMode ? Colors.black : Colors.white,
                child: Row(
                  children: [
                    CachedCircleAvatar(
                      imageUrl: currentUser.photoUrl,
                      userId: currentUser.userId,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Get.to(() => const PostCreationScreen()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            "What's on your mind, ${currentUser.fullname.split(' ').first}?",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(IconlyLight.image, color: Colors.green),
                      onPressed: () => Get.to(() => const PostCreationScreen(autoPickMedia: true)),
                    ),
                  ],
                ),
              ),
            ),

            // Feed posts list
            _isLoadingMore && _posts.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: LoadingIndicator()),
                  )
                : _posts.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No posts yet',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _posts.length) {
                              return _hasMore
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Center(child: LoadingIndicator()),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                        child: Text(
                                          'You have seen all updates',
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        ),
                                      ),
                                    );
                            }

                            final post = _posts[index];
                            return _buildPostCard(context, post, isDarkMode);
                          },
                          childCount: _posts.length + 1,
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, NewsFeedPost post, bool isDarkMode) {
    final isOwnPost = post.userId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RealtimePostHeader(
            post: post,
            currentUserId: _currentUserId,
            isOwnPost: isOwnPost,
            isDarkMode: isDarkMode,
            onViewProfile: () => _viewUserProfile(post.userId),
            onOptionsTap: () => _showPostOptions(context, post, isOwnPost),
          ),

          // Post Text Content
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: RichTextViewer(
                text: post.content,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.95) : Colors.black87,
                ),
              ),
            ),

          // Post Media Attachments
          if (post.media.isNotEmpty)
            _buildMediaGallery(post),

          // Footer metrics counters
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('news_feed_posts').doc(post.id).snapshots(),
            builder: (context, snapshot) {
              List<dynamic> likedBy = post.likedBy;
              Map<String, dynamic> reactionsMap = post.reactions;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                likedBy = data['likedBy'] ?? [];
                reactionsMap = data['reactions'] ?? {};
              }

              final bool hasLiked = likedBy.contains(_currentUserId);
              final dynamic userReactionData = reactionsMap[_currentUserId];
              ReactionType? userReaction;
              if (userReactionData != null) {
                final String reactionValue = userReactionData is String ? userReactionData : (userReactionData['reaction'] ?? '');
                try {
                  userReaction = ReactionType.values.firstWhere((e) => e.name == reactionValue);
                } catch (_) {}
              }

              return Column(
                children: [
                  PostReactionsSummaryBar(
                    post: post,
                    isDarkMode: isDarkMode,
                  ),

          const Divider(height: 1, thickness: 0.5),

          // Footer Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // React / Like Button with Reaction menu support
                Expanded(
                  child: GestureDetector(
                    onLongPress: () => _showReactionsPanel(context, post),
                    child: InkWell(
                      onTap: () => NewsFeedService.toggleLike(postId: post.id, userId: _currentUserId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasLiked ? Icons.thumb_up : IconlyLight.heart,
                              size: 20,
                              color: hasLiked
                                  ? (userReaction == null ? Colors.blue : _getReactionColor(userReaction))
                                  : (isDarkMode ? Colors.white60 : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasLiked ? (userReaction?.label ?? 'Like') : 'Like',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: hasLiked
                                    ? (userReaction == null ? Colors.blue : _getReactionColor(userReaction))
                                    : (isDarkMode ? Colors.white60 : Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Comment Button
                Expanded(
                  child: InkWell(
                    onTap: () => _showCommentsSheet(context, post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            IconlyLight.chat,
                            size: 20,
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Share Button
                Expanded(
                  child: InkWell(
                    onTap: () => _sharePost(post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            IconlyLight.send,
                            size: 20,
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDarkMode ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  ),
],
      ),
    );
  }

  Widget _buildMediaGallery(NewsFeedPost post) {
    if (post.media.isEmpty) return const SizedBox.shrink();

    final mediaList = post.media;

    if (mediaList.length == 1) {
      return GestureDetector(
        onTap: () => Get.to(() => PostMediaViewer(mediaList: mediaList)),
        child: AspectRatio(
          aspectRatio: mediaList.first.aspectRatio ?? 16 / 9,
          child: Hero(
            tag: 'media_${post.id}',
            child: Container(
              color: Colors.black,
              child: SizedBox.expand(child: _buildMediaItem(mediaList.first)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AspectRatio(
        aspectRatio: 1.0, 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildGridContent(mediaList),
        ),
      ),
    );
  }

  Widget _buildGridContent(List<PostMedia> mediaList) {
    final len = mediaList.length;
    const spacing = 4.0;
    
    Widget buildGridItem(int index) {
      return GestureDetector(
        onTap: () => Get.to(() => PostMediaViewer(mediaList: mediaList, initialIndex: index)),
        child: Container(
          color: Colors.grey[300],
          child: SizedBox.expand(child: _buildMediaItem(mediaList[index])),
        ),
      );
    }
    
    if (len == 2) {
      return Row(
        children: [
          Expanded(child: buildGridItem(0)),
          const SizedBox(width: spacing),
          Expanded(child: buildGridItem(1)),
        ],
      );
    }
    
    if (len == 3) {
      return Row(
        children: [
          Expanded(child: buildGridItem(0)),
          const SizedBox(width: spacing),
          Expanded(
            child: Column(
              children: [
                Expanded(child: buildGridItem(1)),
                const SizedBox(height: spacing),
                Expanded(child: buildGridItem(2)),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: buildGridItem(0)),
              const SizedBox(width: spacing),
              Expanded(child: buildGridItem(1)),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(child: buildGridItem(2)),
              const SizedBox(width: spacing),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    buildGridItem(3),
                    if (len > 4)
                      GestureDetector(
                        onTap: () => Get.to(() => PostMediaViewer(mediaList: mediaList, initialIndex: 3)),
                        child: Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: Text(
                            '+${len - 4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(PostMedia media) {
    if (media.type == 'video') {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            media.thumbnailUrl ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.video_library, color: Colors.white, size: 48),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      );
    }

    return Image.network(
      media.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.grey[300]),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white, size: 48),
      ),
    );
  }

  Color _getReactionColor(ReactionType reaction) {
    switch (reaction) {
      case ReactionType.like:
        return Colors.blue;
      case ReactionType.love:
        return Colors.red;
      case ReactionType.haha:
      case ReactionType.wow:
      case ReactionType.sad:
        return Colors.amber;
      case ReactionType.angry:
        return const Color(0xFFFF4500);
    }
  }

  void _showPostOptions(BuildContext context, NewsFeedPost post, bool isOwnPost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                if (isOwnPost) ...[
                  ListTile(
                    leading: const Icon(IconlyLight.edit, color: Colors.blue),
                    title: const Text('Edit Caption'),
                    onTap: () {
                      Get.back();
                      _editPostCaption(post);
                    },
                  ),
                  ListTile(
                    leading: const Icon(IconlyLight.delete, color: Colors.red),
                    title: const Text('Delete Post'),
                    onTap: () {
                      Get.back();
                      _confirmDeletePost(post.id);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(IconlyLight.addUser, color: Colors.green),
                    title: const Text('Follow User'),
                    onTap: () {
                      Get.back();
                      // Trigger follow workflow
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                    title: const Text('Report Post'),
                    onTap: () {
                      Get.back();
                      Get.snackbar(
                        'Reported',
                        'Thank you for reporting. We will review this post.',
                        backgroundColor: Colors.black.withValues(alpha: 0.7),
                        colorText: Colors.white,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCommentsSheet(BuildContext context, NewsFeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostCommentsSheet(post: post),
    );
  }

  void _showReactionsPanel(BuildContext context, NewsFeedPost post) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ReactionType.values.map((react) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  NewsFeedService.setReaction(
                    postId: post.id,
                    userId: _currentUserId,
                    reaction: react,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    react.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _sharePost(NewsFeedPost post) async {
    final link = DeepLinkService.generatePostLink(post.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.copy_rounded, color: primaryColor),
                ),
                title: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Copy post link to clipboard'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(context); // close bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post link copied to clipboard'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.share_rounded, color: Colors.blue),
                ),
                title: const Text('Invite / Share', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Share post via other apps'),
                onTap: () async {
                  Navigator.pop(context); // close bottom sheet
                  await NewsFeedService.incrementShareCount(post.id);
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Check out this post from ${post.userName} on imChat:\n\n"${post.content}"\n\nLink: $link'
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _editPostCaption(NewsFeedPost post) {
    final textController = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
          title: const Text('Edit Caption'),
          content: TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter new caption...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (textController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('news_feed_posts')
                      .doc(post.id)
                      .update({
                    'content': textController.text.trim(),
                    'updatedAt': Timestamp.now(),
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to permanently delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await NewsFeedService.deletePost(postId);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _viewUserProfile(String userId) async {
    final user = await UserApi.getUser(userId);
    if (user != null) {
      Get.to(() => ProfilePageForRoom(
        userID: user.userId,
        userName: user.fullname,
        userImage: user.photoUrl,
      ));
    } else {
      Get.snackbar(
        'Error',
        'User not found',
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    }
  }
}

class RealtimePostHeader extends StatelessWidget {
  final NewsFeedPost post;
  final String currentUserId;
  final bool isOwnPost;
  final bool isDarkMode;
  final VoidCallback onViewProfile;
  final VoidCallback onOptionsTap;

  const RealtimePostHeader({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isOwnPost,
    required this.isDarkMode,
    required this.onViewProfile,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(post.userId).snapshots(),
      builder: (context, userSnapshot) {
        String userName = post.userName;
        bool isVerified = post.isVerified;
        String? userLevelBadgeUrl = post.userLevelBadgeUrl;
        String userAvatarUrl = post.userAvatar ?? '';
        int userLevel = post.userLevel ?? 1;
        int? sendingLevelNum;
        int? receivingLevelNum;
        String? selectedNameplateId;

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = data['fullname'] ?? userName;
          isVerified = data['isVerified'] ?? isVerified;
          userLevelBadgeUrl = data['levelBadgeUrl'] ?? userLevelBadgeUrl;
          userAvatarUrl = data['photoUrl'] ?? userAvatarUrl;
          if (data['sendingLevel'] != null) {
            sendingLevelNum = data['sendingLevel']['level'];
          }
          if (data['receivingLevel'] != null) {
            receivingLevelNum = data['receivingLevel']['level'];
          }
          final levelStr = data['level'] ?? '1';
          userLevel = int.tryParse(levelStr.toString()) ?? userLevel;
          
          final customization = data['customization'] as Map<String, dynamic>?;
          selectedNameplateId = customization?['selectedNameplateId'] as String?;
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onViewProfile,
                child: CachedCircleAvatar(
                  imageUrl: userAvatarUrl,
                  userId: post.userId,
                  radius: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: onViewProfile,
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, color: Colors.blue, size: 16),
                          ),
                        if (userLevelBadgeUrl != null && userLevelBadgeUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Image.network(
                              userLevelBadgeUrl,
                              width: 22,
                              height: 22,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (sendingLevelNum != null)
                          _buildSingleLevelBadge('sending_config', sendingLevelNum),

                        if (receivingLevelNum != null)
                          _buildSingleLevelBadge('receiving_config', receivingLevelNum),

                        if (selectedNameplateId != null && selectedNameplateId.isNotEmpty)
                          FutureBuilder<String?>(
                            future: NameplateHelper.getNameplateUrl(selectedNameplateId),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: snapshot.data!,
                                  height: 18,
                                  fit: BoxFit.contain,
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          post.timeAgo,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          post.visibility == 'public'
                              ? Icons.public
                              : post.visibility == 'friends'
                                  ? Icons.people
                                  : Icons.lock,
                          size: 12,
                          color: isDarkMode ? Colors.white30 : Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isOwnPost) ...[
                _buildFollowButton(),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
                onPressed: onOptionsTap,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleLevelBadge(String configDoc, int levelNumber) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('level_configurations').doc(configDoc).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['levels'] == null) return const SizedBox.shrink();
        
        final levels = List<Map<String, dynamic>>.from(data['levels']);
        String? imageUrl;
        for (final lvl in levels) {
          if (lvl['levelNumber']?.toString() == levelNumber.toString()) {
            imageUrl = lvl['imageUrl'] as String?;
            break;
          }
        }
        
        if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
        
        return CachedNetworkImage(
          imageUrl: imageUrl,
          height: 18,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildFollowButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUserId)
          .collection('following')
          .doc(post.userId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.hasData && snapshot.data!.exists;
        return GestureDetector(
          onTap: () async {
            if (isFollowing) {
              await FollowService.unfollowUser(
                currentUserId: currentUserId,
                targetUserId: post.userId,
              );
            } else {
              await FollowService.followUser(
                currentUserId: currentUserId,
                targetUserId: post.userId,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.grey[300] : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFollowing ? Icons.how_to_reg : Icons.add,
                  size: 14,
                  color: isFollowing ? Colors.black87 : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: isFollowing ? Colors.black87 : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
