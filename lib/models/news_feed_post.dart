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
    return PostComment.fromMap(data, id: doc.id);
  }

  factory PostComment.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime createdAt = DateTime.now();
    final rawCreated = data['createdAt'] ?? data['created_at'];
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    } else if (rawCreated is DateTime) {
      createdAt = rawCreated;
    }

    return PostComment(
      id: id ?? data['id']?.toString() ?? '',
      postId: data['postId']?.toString() ?? data['post_id']?.toString() ?? '',
      userId: data['userId']?.toString() ?? data['user_id']?.toString() ?? '',
      userName: data['userName']?.toString() ?? data['user_name']?.toString() ?? data['author_name']?.toString() ?? 'Unknown',
      userAvatar: data['userAvatar']?.toString() ?? data['user_avatar']?.toString() ?? data['author_avatar']?.toString(),
      userFrameId: data['userFrameId']?.toString() ?? data['user_frame_id']?.toString(),
      isVerified: data['isVerified'] == true || data['is_verified'] == true,
      text: data['text']?.toString() ?? '',
      createdAt: createdAt,
      likeCount: (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : ((data['like_count'] is num) ? (data['like_count'] as num).toInt() : 0),
      likedBy: List<String>.from(data['likedBy'] ?? data['liked_by'] ?? []),
      replyToId: data['replyToId']?.toString() ?? data['reply_to_id']?.toString(),
      replyToUserName: data['replyToUserName']?.toString() ?? data['reply_to_user_name']?.toString(),
      imageUrl: data['imageUrl']?.toString() ?? data['image_url']?.toString(),
      isEdited: data['isEdited'] == true || data['is_edited'] == true,
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
  final bool isNotice;
  final String? noticeTitle;
  final int reportCount;
  final int viewCount;
  final double trendingScore;

  /// Dynamic calculated trending score combining base score, likes, comments, shares, views and recency boost
  double get calculatedTrendingScore {
    double score = trendingScore;
    score += (likeCount * 3.0);
    score += (commentCount * 5.0);
    score += (shareCount * 10.0);
    score += (viewCount * 0.5);

    // Recency boost: bonus points for newer posts (up to 72 hours)
    final hoursAgo = DateTime.now().difference(createdAt).inHours;
    if (hoursAgo < 24) {
      score += (24 - hoursAgo) * 2.0;
    } else if (hoursAgo < 72) {
      score += (72 - hoursAgo) * 0.5;
    }
    return score;
  }

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
    this.isNotice = false,
    this.noticeTitle,
    this.reportCount = 0,
    this.viewCount = 0,
    this.trendingScore = 0.0,
  });

  factory NewsFeedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NewsFeedPost.fromMap(data, id: doc.id);
  }

  factory NewsFeedPost.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime createdAt = DateTime.now();
    final rawCreated = data['createdAt'] ?? data['created_at'];
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    } else if (rawCreated is DateTime) {
      createdAt = rawCreated;
    }

    DateTime updatedAt = createdAt;
    final rawUpdated = data['updatedAt'] ?? data['updated_at'];
    if (rawUpdated is Timestamp) {
      updatedAt = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated)?.toLocal() ?? createdAt;
    } else if (rawUpdated is DateTime) {
      updatedAt = rawUpdated;
    }

    List<PostMedia> mediaList = [];
    if (data['media'] is List) {
      mediaList = (data['media'] as List)
          .map((m) => PostMedia.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } else if (data['media_urls'] is List) {
      final urls = List<String>.from(data['media_urls']);
      final types = List<String>.from(data['media_types'] ?? []);
      for (int i = 0; i < urls.length; i++) {
        mediaList.add(PostMedia(url: urls[i], type: i < types.length ? types[i] : 'image'));
      }
    }

    return NewsFeedPost(
      id: id ?? data['id']?.toString() ?? '',
      userId: data['userId']?.toString() ?? data['user_id']?.toString() ?? '',
      userName: data['userName']?.toString() ?? data['user_name']?.toString() ?? data['fullname']?.toString() ?? 'Unknown',
      userAvatar: data['userAvatar']?.toString() ?? data['user_avatar']?.toString() ?? data['photo_url']?.toString(),
      userFrameId: data['userFrameId']?.toString() ?? data['user_frame_id']?.toString() ?? data['active_frame_id']?.toString(),
      isVerified: data['isVerified'] == true || data['is_verified'] == true,
      userLevel: (data['userLevel'] is num) ? (data['userLevel'] as num).toInt() : ((data['user_level'] is num) ? (data['user_level'] as num).toInt() : ((data['level'] is num) ? (data['level'] as num).toInt() : null)),
      userLevelBadgeUrl: data['userLevelBadgeUrl']?.toString() ?? data['user_level_badge_url']?.toString(),
      content: data['content']?.toString() ?? '',
      media: mediaList,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likeCount: (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : ((data['like_count'] is num) ? (data['like_count'] as num).toInt() : 0),
      commentCount: (data['commentCount'] is num) ? (data['commentCount'] as num).toInt() : ((data['comment_count'] is num) ? (data['comment_count'] as num).toInt() : 0),
      shareCount: (data['shareCount'] is num) ? (data['shareCount'] as num).toInt() : ((data['share_count'] is num) ? (data['share_count'] as num).toInt() : 0),
      reactions: Map<String, String>.from((data['reactions'] is Map) ? (data['reactions'] as Map) : {}),
      likedBy: List<String>.from(data['likedBy'] ?? data['liked_by'] ?? []),
      visibility: data['visibility']?.toString() ?? 'public',
      isPinned: data['isPinned'] == true || data['is_pinned'] == true,
      isDeleted: data['isDeleted'] == true || data['is_deleted'] == true,
      isNotice: data['isNotice'] == true || data['is_notice'] == true,
      noticeTitle: data['noticeTitle']?.toString() ?? data['notice_title']?.toString(),
      reportCount: (data['reportCount'] is num) ? (data['reportCount'] as num).toInt() : 0,
      viewCount: (data['viewCount'] is num) ? (data['viewCount'] as num).toInt() : 0,
      trendingScore: (data['trendingScore'] is num) ? (data['trendingScore'] as num).toDouble() : 0.0,
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
      'isNotice': isNotice,
      'noticeTitle': noticeTitle,
      'reportCount': reportCount,
      'viewCount': viewCount,
      'trendingScore': trendingScore,
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
    bool? isNotice,
    String? noticeTitle,
    int? reportCount,
    int? viewCount,
    double? trendingScore,
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
      isNotice: isNotice ?? this.isNotice,
      noticeTitle: noticeTitle ?? this.noticeTitle,
      reportCount: reportCount ?? this.reportCount,
      viewCount: viewCount ?? this.viewCount,
      trendingScore: trendingScore ?? this.trendingScore,
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
