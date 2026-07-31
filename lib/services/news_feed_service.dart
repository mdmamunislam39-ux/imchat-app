import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/news_feed_post.dart';

class NewsFeedService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _postsCollection = 'news_feed_posts';
  static const String _commentsCollection = 'news_feed_comments';

  // ─── Posts ────────────────────────────────────────────────────────────────

  static Stream<List<NewsFeedPost>> getPostsStream({
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return query.snapshots().map((snap) {
      final posts = snap.docs
          .map((doc) => NewsFeedPost.fromFirestore(doc))
          .where((post) => !post.isDeleted)
          .toList();
      // Local sort to keep pinned posts on top
      posts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return posts;
    });
  }
  
  /// Real-time stream of a single post by ID
  static Stream<NewsFeedPost?> getPostByIdStream(String postId) {
    return _firestore
        .collection(_postsCollection)
        .doc(postId)
        .snapshots()
        .map((snap) => snap.exists ? NewsFeedPost.fromFirestore(snap) : null);
  }

  static Future<List<NewsFeedPost>> fetchMorePosts({
    required DocumentSnapshot lastDoc,
    int limit = 15,
  }) async {
    final snap = await _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();

    final posts = snap.docs
        .map((doc) => NewsFeedPost.fromFirestore(doc))
        .where((post) => !post.isDeleted)
        .toList();
    posts.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return posts;
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchPostsPage({
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return query.get();
  }

  /// Create a new post
  static Future<String?> createPost({
    required String userId,
    required String userName,
    String? userAvatar,
    String? userFrameId,
    bool isVerified = false,
    int? userLevel,
    String? userLevelBadgeUrl,
    required String content,
    List<File>? mediaFiles,
    String visibility = 'public',
  }) async {
    try {
      final docRef = _firestore.collection(_postsCollection).doc();
      final now = DateTime.now();

      // Upload media files
      final List<PostMedia> mediaList = [];
      if (mediaFiles != null) {
        for (final file in mediaFiles) {
          final ext = file.path.split('.').last.toLowerCase();
          final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
          final type = isVideo ? 'video' : 'image';

          final ref = _storage
              .ref()
              .child('news_feed_media/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}.$ext');
          await ref.putFile(file);
          final url = await ref.getDownloadURL();

          mediaList.add(PostMedia(url: url, type: type));
        }
      }

      final post = NewsFeedPost(
        id: docRef.id,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        userFrameId: userFrameId,
        isVerified: isVerified,
        userLevel: userLevel,
        userLevelBadgeUrl: userLevelBadgeUrl,
        content: content,
        media: mediaList,
        createdAt: now,
        updatedAt: now,
        visibility: visibility,
      );

      await docRef.set(post.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('❌ [NewsFeed] Error creating post: $e');
      return null;
    }
  }

  /// Delete a post (soft delete)
  static Future<void> deletePost(String postId) async {
    await _firestore.collection(_postsCollection).doc(postId).update({
      'isDeleted': true,
      'updatedAt': Timestamp.now(),
    });
  }

  // ─── Reactions ─────────────────────────────────────────────────────────────

  /// Toggle like on a post
  static Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final ref = _firestore.collection(_postsCollection).doc(postId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      final Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        reactions.remove(userId);
      } else {
        likedBy.add(userId);
        reactions[userId] = ReactionType.like.toJson();
      }

      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': likedBy.length,
        'reactions': reactions,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Set a specific reaction on a post
  static Future<void> setReaction({
    required String postId,
    required String userId,
    required ReactionType reaction,
  }) async {
    final ref = _firestore.collection(_postsCollection).doc(postId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      final Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final String reactionKey = reaction.toJson();
      final currentReaction = reactions[userId];

      if (currentReaction == reactionKey) {
        // Remove reaction (toggle off)
        reactions.remove(userId);
        likedBy.remove(userId);
      } else {
        // Set new reaction
        reactions[userId] = reactionKey;
        if (!likedBy.contains(userId)) {
          likedBy.add(userId);
        }
      }

      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': likedBy.length,
        'reactions': reactions,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  // ─── Comments ──────────────────────────────────────────────────────────────

  static Stream<List<PostComment>> getCommentsStream(String postId) {
    return _firestore
        .collection(_commentsCollection)
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snap) {
      final comments = snap.docs.map((doc) => PostComment.fromFirestore(doc)).toList();
      // Local sort by createdAt to avoid composite index error
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  /// Add a comment to a post
  static Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatar,
    String? userFrameId,
    bool isVerified = false,
    required String text,
    String? imageUrl,
    String? replyToId,
    String? replyToUserName,
  }) async {
    final docRef = _firestore.collection(_commentsCollection).doc();
    final comment = PostComment(
      id: docRef.id,
      postId: postId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userFrameId: userFrameId,
      isVerified: isVerified,
      text: text,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      replyToId: replyToId,
      replyToUserName: replyToUserName,
    );

    final batch = _firestore.batch();
    batch.set(docRef, comment.toFirestore());
    batch.update(_firestore.collection(_postsCollection).doc(postId), {
      'commentCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
    await batch.commit();
  }

  /// Delete a comment
  static Future<void> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection(_commentsCollection).doc(commentId));
    batch.update(_firestore.collection(_postsCollection).doc(postId), {
      'commentCount': FieldValue.increment(-1),
      'updatedAt': Timestamp.now(),
    });
    await batch.commit();
  }

  /// Edit a comment
  static Future<void> editComment({
    required String commentId,
    required String newText,
  }) async {
    await _firestore.collection(_commentsCollection).doc(commentId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  /// Toggle like on a comment
  static Future<void> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async {
    final ref = _firestore.collection(_commentsCollection).doc(commentId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': likedBy.length,
      });
    });
  }

  // ─── Share ─────────────────────────────────────────────────────────────────

  /// Increment share count
  static Future<void> incrementShareCount(String postId) async {
    await _firestore.collection(_postsCollection).doc(postId).update({
      'shareCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
  }
}
