import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/rich_text_controller.dart';
import 'package:chat_messenger/components/rich_text_viewer.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/screens/news_feed/moment_reels_screen.dart';
import 'package:chat_messenger/screens/news_feed/post_media_viewer.dart';
import 'package:chat_messenger/screens/news_feed/post_reactions_summary_bar.dart';
import 'package:chat_messenger/screens/news_feed/widgets/inline_video_player.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;

  const SinglePostScreen({super.key, required this.postId});

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  final RichTextController _commentController = RichTextController();
  final FocusNode _focusNode = FocusNode();
  final String _currentUserId = AuthController.instance.currentUser.userId;
  String? _replyingToUserName;
  String? _replyingToId;
  String? _editingCommentId;
  File? _selectedImage;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sharePost(NewsFeedPost post) {
    final link = DeepLinkService.generatePostLink(post.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
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
                    Navigator.pop(context);
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
                    Navigator.pop(context);
                    await NewsFeedService.incrementShareCount(post.id);
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Check out this post from ${post.userName} on imChat:\n\n"${post.content}"\n\nLink: $link',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewUserProfile(String userId, {String? userName, String? userAvatar}) {
    Get.to(() => ProfilePageForRoom(
          userID: userId,
          userName: userName ?? '',
          userImage: userAvatar ?? '',
        ));
  }

  void _sendComment(NewsFeedPost post) async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final user = AuthController.instance.currentUser;
    final formattedText = _replyingToUserName != null
        ? 'Replying to @$_replyingToUserName: $text'
        : text;

    if (_editingCommentId != null) {
      await NewsFeedService.editComment(
        commentId: _editingCommentId!,
        newText: text,
      );
    } else {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await AppHelper.uploadFile(
          file: _selectedImage!,
          userId: user.userId,
        );
      }

      await NewsFeedService.addComment(
        postId: post.id,
        userId: user.userId,
        userName: user.fullname,
        userAvatar: user.photoUrl,
        userFrameId: user.customization?.selectedFrameId,
        isVerified: user.isVerified,
        text: formattedText,
        imageUrl: uploadedImageUrl,
        replyToId: _replyingToId,
        replyToUserName: _replyingToUserName,
      );
    }

    if (!mounted) return;
    setState(() {
      _commentController.clear();
      _replyingToUserName = null;
      _replyingToId = null;
      _editingCommentId = null;
      _selectedImage = null;
    });
    _focusNode.unfocus();
  }

  void _pickImage() async {
    final file = await MediaHelper.pickMediaFromGallery();
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Widget _buildMediaGallery(NewsFeedPost post) {
    if (post.media.isEmpty) return const SizedBox.shrink();
    final mediaList = post.media;

    if (mediaList.length == 1) {
      final media = mediaList.first;
      if (media.type == 'video') {
        return InlineNewsFeedVideoPlayer(
          videoUrl: media.url,
          thumbnailUrl: media.thumbnailUrl,
          onTapFullReels: () {
            Get.to(() => MomentReelsScreen(
                  videoPosts: [post],
                  initialIndex: 0,
                ));
          },
        );
      }

      return GestureDetector(
        onTap: () => Get.to(() => PostMediaViewer(mediaList: mediaList)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 420),
          width: double.infinity,
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: (media.aspectRatio ?? 4 / 3).clamp(0.75, 1.78),
            child: Hero(
              tag: 'single_media_${post.id}',
              child: Image.network(
                media.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
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
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mediaList.length == 2 ? 2 : 2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: mediaList.length > 4 ? 4 : mediaList.length,
            itemBuilder: (context, index) {
              final media = mediaList[index];
              return GestureDetector(
                onTap: () => Get.to(() => PostMediaViewer(mediaList: mediaList, initialIndex: index)),
                child: Image.network(
                  media.thumbnailUrl ?? media.url,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDarkMode ? const Color(0xFF161622) : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F1A) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0.5,
        title: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              final link = DeepLinkService.generatePostLink(widget.postId);
              SharePlus.instance.share(
                ShareParams(text: 'Check out this post on imChat:\n$link'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<NewsFeedPost?>(
        stream: NewsFeedService.getPostByIdStream(widget.postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text(
                    'This post has been deleted or is unavailable.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final post = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Card
                      Container(
                        color: cardBgColor,
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _viewUserProfile(post.userId, userName: post.userName, userAvatar: post.userAvatar),
                                    child: CachedCircleAvatar(
                                      imageUrl: post.userAvatar ?? '',
                                      userId: post.userId,
                                      radius: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            AnimatedSvipName.fromUserId(
                                              userId: post.userId,
                                              defaultName: post.userName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDarkMode ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            if (post.isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, color: Colors.blue, size: 15),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          post.timeAgo,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => _sharePost(post),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Post Text Content
                            if (post.content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: RichTextViewer(
                                  text: post.content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: isDarkMode ? Colors.white.withValues(alpha: 0.95) : Colors.black87,
                                  ),
                                ),
                              ),

                            // Post Media Attachments
                            if (post.media.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildMediaGallery(post),
                            ],

                            const SizedBox(height: 8),

                            // Reactions Summary Bar
                            PostReactionsSummaryBar(post: post, isDarkMode: isDarkMode),

                            const Divider(height: 1, thickness: 0.5),

                            // Action Buttons: Like, Comment, Share
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  // Like Button
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => NewsFeedService.toggleLike(postId: post.id, userId: _currentUserId),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              post.likedBy.contains(_currentUserId) ? Icons.thumb_up : Icons.thumb_up_outlined,
                                              size: 18,
                                              color: post.likedBy.contains(_currentUserId) ? primaryColor : (isDarkMode ? Colors.white60 : Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Like',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: post.likedBy.contains(_currentUserId) ? primaryColor : (isDarkMode ? Colors.white60 : Colors.grey[600]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Comment Button
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _focusNode.requestFocus(),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(IconlyLight.chat, size: 18, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
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
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.share_outlined, size: 18, color: isDarkMode ? Colors.white60 : Colors.grey[600]),
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
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Comments Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Comments',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),

                      // Comments Stream List
                      StreamBuilder<List<PostComment>>(
                        stream: NewsFeedService.getCommentsStream(post.id),
                        builder: (context, commentSnap) {
                          if (commentSnap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: LoadingIndicator()),
                            );
                          }

                          final comments = commentSnap.data ?? [];
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(IconlyLight.chat, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No comments yet. Be the first!',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final hasLiked = comment.likedBy.contains(_currentUserId);
                              final isOwnComment = comment.userId == _currentUserId;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _viewUserProfile(comment.userId, userName: comment.userName, userAvatar: comment.userAvatar),
                                      child: CachedCircleAvatar(
                                        imageUrl: comment.userAvatar ?? '',
                                        userId: comment.userId,
                                        radius: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isDarkMode ? const Color(0xFF232334) : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                AnimatedSvipName.fromUserId(
                                                  userId: comment.userId,
                                                  defaultName: comment.userName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDarkMode ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                RichTextViewer(
                                                  text: comment.text,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDarkMode ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                                  ),
                                                ),
                                                if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      comment.imageUrl!,
                                                      width: 140,
                                                      height: 140,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () => NewsFeedService.toggleCommentLike(
                                                  commentId: comment.id,
                                                  userId: _currentUserId,
                                                ),
                                                child: Text(
                                                  'Like',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: hasLiked ? primaryColor : Colors.grey[500],
                                                  ),
                                                ),
                                              ),
                                              if (comment.likeCount > 0) ...[
                                                const SizedBox(width: 4),
                                                Text('${comment.likeCount}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                              ],
                                              const SizedBox(width: 14),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _replyingToUserName = comment.userName.split(' ').first;
                                                    _replyingToId = comment.id;
                                                  });
                                                  _focusNode.requestFocus();
                                                },
                                                child: Text(
                                                  'Reply',
                                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[500]),
                                                ),
                                              ),
                                              if (isOwnComment) ...[
                                                const SizedBox(width: 14),
                                                GestureDetector(
                                                  onTap: () => NewsFeedService.deleteComment(
                                                    commentId: comment.id,
                                                    postId: post.id,
                                                  ),
                                                  child: Text(
                                                    'Delete',
                                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.red[400]),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Comment Input Composer at Bottom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingToUserName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text('Replying to @$_replyingToUserName', style: const TextStyle(fontSize: 12, color: primaryColor)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => _replyingToUserName = null),
                                child: const Icon(Icons.close, size: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image_outlined, color: primaryColor),
                            onPressed: _pickImage,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDarkMode ? const Color(0xFF232334) : Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: primaryColor),
                            onPressed: () => _sendComment(post),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
