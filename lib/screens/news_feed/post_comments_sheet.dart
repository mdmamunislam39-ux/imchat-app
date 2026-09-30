import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/rich_text_controller.dart';
import 'package:chat_messenger/components/rich_text_viewer.dart';

import 'package:chat_messenger/screens/news_feed/post_reactions_summary_bar.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/components/animated_svip_name.dart';

class PostCommentsSheet extends StatefulWidget {
  final NewsFeedPost post;
  const PostCommentsSheet({super.key, required this.post});

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final RichTextController _commentController = RichTextController();
  final FocusNode _focusNode = FocusNode();
  final String _currentUserId = AuthController.instance.currentUser.userId;
  String? _replyingToUserName;
  String? _replyingToId;
  String? _editingCommentId;
  File? _selectedImage;

  bool _showMentions = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _mentionResults = [];
  List<Map<String, dynamic>> _allUsers = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
    _fetchAllUsers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;

    if (!selection.isValid || selection.baseOffset == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);

    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtIndex != -1) {
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ') && !textAfterAt.contains('\n')) {
        _mentionStartIndex = lastAtIndex;
        final newQuery = textAfterAt.toLowerCase();
        
        if (newQuery != _mentionQuery || !_showMentions) {
          _mentionQuery = newQuery;
          _showMentions = true;
          _searchUsers(_mentionQuery);
          setState(() {});
        }
        return;
      }
    }

    if (_showMentions) {
      setState(() => _showMentions = false);
    }
  }

  Future<void> _fetchAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .limit(500)
          .get();
      _allUsers = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted && _showMentions) {
        _searchUsers(_mentionQuery);
      }
    } catch (e) {
      debugPrint('Error fetching users for mentions: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (_showMentions) {
        setState(() {
          _mentionResults = _allUsers.take(10).toList();
        });
      }
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    final results = _allUsers.where((user) {
      final fullname = (user['fullname'] ?? '').toString().toLowerCase();
      return fullname.contains(lowerQuery);
    }).take(10).toList();
    
    if (_showMentions && _mentionQuery == query) {
      setState(() {
        _mentionResults = results;
      });
    }
  }

  void _insertMention(String username) {
    if (_mentionStartIndex == -1) return;
    
    final text = _commentController.text;
    final textBefore = text.substring(0, _mentionStartIndex);
    final textAfter = text.substring(_commentController.selection.baseOffset);
    
    final formattedUsername = username.replaceAll(' ', ''); 
    final newText = '$textBefore@$formattedUsername $textAfter';
    
    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: _mentionStartIndex + formattedUsername.length + 2),
    );
    
    setState(() {
      _showMentions = false;
    });
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final user = AuthController.instance.currentUser;
    
    // Add tagged name prefix if replying
    final formattedText = _replyingToUserName != null 
        ? 'Replying to @$_replyingToUserName: $text'
        : text;

    if (_editingCommentId != null) {
      // Editing existing comment
      await NewsFeedService.editComment(
        commentId: _editingCommentId!,
        newText: text, // don't add reply prefix for edits
      );
    } else {
      // New comment
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await AppHelper.uploadFile(
          file: _selectedImage!,
          userId: user.userId,
        );
      }

      await NewsFeedService.addComment(
        postId: widget.post.id,
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

  void _triggerReply(String userName, String userId, String commentId) {
    setState(() {
      _replyingToUserName = userName.split(' ').first;
      _replyingToId = commentId;
      _editingCommentId = null;
      _selectedImage = null;
    });
    _focusNode.requestFocus();
  }

  void _triggerEdit(PostComment comment) {
    setState(() {
      _commentController.text = comment.text;
      _editingCommentId = comment.id;
      _replyingToUserName = null;
      _replyingToId = null;
      _selectedImage = null;
    });
    _focusNode.requestFocus();
  }

  void _pickImage() async {
    final file = await MediaHelper.pickMediaFromGallery();
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  void _viewUserProfile(String userId, {String? userName, String? userAvatar}) {
    Get.to(() => ProfilePageForRoom(
          userID: userId,
          userName: userName ?? '',
          userImage: userAvatar ?? '',
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Reactions Summary Bar (Screenshot 1: 😆👍 Kamrul Hasan + 7.9K    26 shares)
          PostReactionsSummaryBar(
            post: widget.post,
            isDarkMode: isDarkMode,
          ),
          const Divider(height: 1, thickness: 0.5),

          // Filter header (Most relevant ∨) matching Screenshot 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Most relevant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: StreamBuilder<List<PostComment>>(
              stream: NewsFeedService.getCommentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LoadingIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load comments',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconlyLight.chat, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final hasLiked = comment.likedBy.contains(_currentUserId);
                    final isOwnComment = comment.userId == _currentUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _viewUserProfile(comment.userId, userName: comment.userName, userAvatar: comment.userAvatar),
                            child: CachedCircleAvatar(
                              imageUrl: comment.userAvatar ?? '',
                              userId: comment.userId,
                              radius: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Comment Bubble Box
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF232334) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _viewUserProfile(comment.userId, userName: comment.userName, userAvatar: comment.userAvatar),
                                            child: AnimatedSvipName.fromUserId(
                                              userId: comment.userId,
                                              defaultName: comment.userName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isDarkMode ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                          if (comment.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified, color: Colors.blue, size: 13),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (comment.text.isNotEmpty)
                                        RichTextViewer(
                                          text: comment.text,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: isDarkMode ? const Color(0xFFD9D9D9) : Colors.black87,
                                          ),
                                        ),
                                      if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            comment.imageUrl!,
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.error),
                                          ),
                                        ),
                                      ],
                                      if (comment.isEdited) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '(Edited)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Actions (Like, Reply, Delete)
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
                                      Icon(Icons.thumb_up, size: 10, color: primaryColor),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${comment.likeCount}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _triggerReply(comment.userName, comment.userId, comment.id),
                                      child: Text(
                                        'Reply',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                    if (isOwnComment) ...[
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () => _triggerEdit(comment),
                                        child: Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.blue[400],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () => NewsFeedService.deleteComment(
                                          commentId: comment.id,
                                          postId: widget.post.id,
                                        ),
                                        child: Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.red[400],
                                          ),
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
          ),

          // Reply/Edit Indicator Banner
          if (_replyingToUserName != null || _editingCommentId != null || _selectedImage != null)
            Container(
              color: isDarkMode ? const Color(0xFF232334) : Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_selectedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(_selectedImage!, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (_editingCommentId != null)
                    Text(
                      'Editing comment...',
                      style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.black54),
                    )
                  else if (_replyingToUserName != null)
                    RichText(
                      text: TextSpan(
                        text: 'Replying to ',
                        style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.black54),
                        children: [
                          TextSpan(
                            text: '@$_replyingToUserName',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToUserName = null;
                      _replyingToId = null;
                      _editingCommentId = null;
                      _selectedImage = null;
                      if (_editingCommentId != null) _commentController.clear();
                    }),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            ),

          // Mentions Autocomplete List
          if (_showMentions && _mentionResults.isNotEmpty)
            Material(
              color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mentionResults.length,
                itemBuilder: (context, index) {
                  final user = _mentionResults[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundImage: user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty 
                          ? NetworkImage(user['photoUrl']) 
                          : null,
                      child: user['photoUrl'] == null || user['photoUrl'].toString().isEmpty 
                          ? const Icon(Icons.person, size: 16) 
                          : null,
                    ),
                    title: Text(user['fullname'] ?? 'User', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 13)),
                    onTap: () => _insertMention(user['fullname'] ?? 'User'),
                  );
                },
              ),
            ),
          ),

          // Input text editor
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 16
                  : MediaQuery.of(context).padding.bottom + 16,
            ),
            color: isDarkMode ? Colors.black : Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _submitComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
