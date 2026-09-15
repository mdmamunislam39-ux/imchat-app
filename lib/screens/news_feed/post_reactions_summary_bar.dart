import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/screens/news_feed/post_reactions_sheet.dart';

/// Summary bar widget for reactions & shares matching Screenshot 1:
/// `[😆][👍] Kamrul Hasan + 7.9K                 26 shares`
class PostReactionsSummaryBar extends StatefulWidget {
  final NewsFeedPost post;
  final bool isDarkMode;

  const PostReactionsSummaryBar({
    super.key,
    required this.post,
    required this.isDarkMode,
  });

  @override
  State<PostReactionsSummaryBar> createState() => _PostReactionsSummaryBarState();
}

class _PostReactionsSummaryBarState extends State<PostReactionsSummaryBar> {
  String? _topReactorName;
  static final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadTopReactorName();
  }

  @override
  void didUpdateWidget(covariant PostReactionsSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likeCount != widget.post.likeCount ||
        oldWidget.post.reactions.length != widget.post.reactions.length) {
      _loadTopReactorName();
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '$count';
    }
  }

  Color _getReactionBgColor(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return const Color(0xFF1877F2);
      case ReactionType.love:
        return const Color(0xFFE41E3F);
      case ReactionType.haha:
      case ReactionType.wow:
      case ReactionType.sad:
        return const Color(0xFFF7B125);
      case ReactionType.angry:
        return const Color(0xFFE94B35);
    }
  }

  Future<void> _loadTopReactorName() async {
    String? firstUserId;
    if (widget.post.reactions.isNotEmpty) {
      firstUserId = widget.post.reactions.keys.first;
    } else if (widget.post.likedBy.isNotEmpty) {
      firstUserId = widget.post.likedBy.last;
    }

    if (firstUserId == null) return;

    if (_userNameCache.containsKey(firstUserId)) {
      if (mounted) {
        setState(() {
          _topReactorName = _userNameCache[firstUserId];
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(firstUserId).get();
      if (doc.exists && doc.data() != null) {
        final fullname = doc.data()!['fullname'] as String?;
        if (fullname != null && fullname.isNotEmpty) {
          _userNameCache[firstUserId] = fullname;
          if (mounted) {
            setState(() {
              _topReactorName = fullname;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading top reactor name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('news_feed_posts')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, snapshot) {
        int likeCount = widget.post.likeCount;
        int commentCount = widget.post.commentCount;
        int shareCount = widget.post.shareCount;
        Map<String, dynamic> reactionsMap = widget.post.reactions;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          likeCount = data['likeCount'] ?? 0;
          commentCount = data['commentCount'] ?? 0;
          shareCount = data['shareCount'] ?? 0;
          reactionsMap = data['reactions'] ?? {};
        }

        // Collect distinct reaction types present
        final Set<ReactionType> activeTypes = {};
        reactionsMap.forEach((userId, rVal) {
          final rStr = rVal is String ? rVal : (rVal is Map ? rVal['reaction'] : null);
          if (rStr != null) {
            try {
              activeTypes.add(ReactionType.values.firstWhere((r) => r.name == rStr));
            } catch (_) {}
          }
        });

        // Fallback if empty but likeCount > 0
        if (activeTypes.isEmpty && likeCount > 0) {
          activeTypes.add(ReactionType.like);
        }

        final List<ReactionType> displayTypes = activeTypes.take(3).toList();

        // Reactor text format: "Kamrul Hasan + 7.9K" or "Kamrul Hasan" or "7.9K"
        String summaryText = '';
        if (likeCount > 0) {
          if (_topReactorName != null && _topReactorName!.isNotEmpty) {
            if (likeCount == 1) {
              summaryText = _topReactorName!;
            } else {
              summaryText = '$_topReactorName + ${_formatCount(likeCount - 1)}';
            }
          } else {
            summaryText = _formatCount(likeCount);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Left side: Overlapping Reaction Badges + Summary Text (Screenshot 1)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    PostReactionsSheet.show(context, postId: widget.post.id);
                  },
                  child: Row(
                    children: [
                      if (activeTypes.isNotEmpty) ...[
                        SizedBox(
                          width: displayTypes.length == 1
                              ? 20
                              : (displayTypes.length == 2 ? 34 : 46),
                          height: 20,
                          child: Stack(
                            children: [
                              for (int i = 0; i < displayTypes.length; i++)
                                Positioned(
                                  left: i * 13.0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _getReactionBgColor(displayTypes[i]),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.isDarkMode
                                            ? const Color(0xFF161622)
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        displayTypes[i].emoji,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (summaryText.isNotEmpty)
                        Flexible(
                          child: Text(
                            summaryText,
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Text(
                          'Reactions',
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Right side: Shares / Comments summary
              Row(
                children: [
                  if (commentCount > 0)
                    Text(
                      '$commentCount comments',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  if (commentCount > 0 && shareCount > 0)
                    Text(
                      ' • ',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  if (shareCount > 0)
                    Text(
                      '$shareCount shares',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
