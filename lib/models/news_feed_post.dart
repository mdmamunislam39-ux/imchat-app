import 'package:cloud_firestore/cloud_firestore.dart';

/// Reaction types for posts
enum ReactionType { like, love, haha, wow, sad, angry }

extension ReactionTypeExtension on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.haha:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😡';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.like:
        return 'Like';
      case ReactionType.love:
        return 'Love';
      case ReactionType.haha:
        return 'Haha';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Sad';
      case ReactionType.angry:
        return 'Angry';
    }
  }

  String toJson() => name;

  static ReactionType fromJson(String value) {
    return ReactionType.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ReactionType.like,
    );
  }
}

/// Media attachment in a post
class PostMedia {
  final String url;
  final String type; // 'image' or 'video'
  final String? thumbnailUrl;
  final double? aspectRatio;

  const PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.aspectRatio,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
      thumbnailUrl: json['thumbnailUrl'],
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'aspectRatio': aspectRatio,
    };
  }
}

/// Comment on a post
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? userFrameId;
  final bool isVerified;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedBy;
  final String? replyToId;
  final String? replyToUserName;
  final String? imageUrl;
  final bool isEdited;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userFrameId,
    this.isVerified = false,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
    this.likedBy = const [],
    this.replyToId,
    this.replyToUserName,
    this.imageUrl,
    this.isEdited = false,
  });

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PostComment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'],
      userFrameId: data['userFrameId'],
      isVerified: data['isVerified'] ?? false,
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replyToId: data['replyToId'],
      replyToUserName: data['replyToUserName'],
      imageUrl: data['imageUrl'],
      isEdited: data['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userFrameId': userFrameId,
      'isVerified': isVerified,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedBy': likedBy,
      'replyToId': replyToId,
      'replyToUserName': replyToUserName,
      'imageUrl': imageUrl,
      'isEdited': isEdited,
    };
  }
}

/// News Feed Post model
class NewsFeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? userFrameId;
  final bool isVerified;
  final int? userLevel;
  final String? userLevelBadgeUrl;
  final String content;
  final List<PostMedia> media;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final Map<String, String> reactions; // userId -> reactionType
  final List<String> likedBy;
  final String visibility; // 'public', 'friends', 'private'
  final bool isPinned;
  final bool isDeleted;

  const NewsFeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userFrameId,
    this.isVerified = false,
    this.userLevel,
    this.userLevelBadgeUrl,
    required this.content,
    this.media = const [],
    required this.createdAt,
    required this.updatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.reactions = const {},
    this.likedBy = const [],
    this.visibility = 'public',
    this.isPinned = false,
    this.isDeleted = false,
  });

  factory NewsFeedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NewsFeedPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'],
      userFrameId: data['userFrameId'],
      isVerified: data['isVerified'] ?? false,
      userLevel: data['userLevel'],
      userLevelBadgeUrl: data['userLevelBadgeUrl'],
      content: data['content'] ?? '',
      media: (data['media'] as List<dynamic>?)
              ?.map((m) => PostMedia.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      visibility: data['visibility'] ?? 'public',
      isPinned: data['isPinned'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userFrameId': userFrameId,
      'isVerified': isVerified,
      'userLevel': userLevel,
      'userLevelBadgeUrl': userLevelBadgeUrl,
      'content': content,
      'media': media.map((m) => m.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'reactions': reactions,
      'likedBy': likedBy,
      'visibility': visibility,
      'isPinned': isPinned,
      'isDeleted': isDeleted,
    };
  }

  NewsFeedPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userFrameId,
    bool? isVerified,
    int? userLevel,
    String? userLevelBadgeUrl,
    String? content,
    List<PostMedia>? media,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    Map<String, String>? reactions,
    List<String>? likedBy,
    String? visibility,
    bool? isPinned,
    bool? isDeleted,
  }) {
    return NewsFeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userFrameId: userFrameId ?? this.userFrameId,
      isVerified: isVerified ?? this.isVerified,
      userLevel: userLevel ?? this.userLevel,
      userLevelBadgeUrl: userLevelBadgeUrl ?? this.userLevelBadgeUrl,
      content: content ?? this.content,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      reactions: reactions ?? this.reactions,
      likedBy: likedBy ?? this.likedBy,
      visibility: visibility ?? this.visibility,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Check if current user has liked
  bool isLikedBy(String userId) => likedBy.contains(userId);

  /// Get user's reaction type
  ReactionType? getUserReaction(String userId) {
    final reaction = reactions[userId];
    if (reaction == null) return null;
    return ReactionTypeExtension.fromJson(reaction);
  }

  /// Get total reaction count
  int get totalReactions => reactions.length;
}
