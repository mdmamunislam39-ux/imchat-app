import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/push_notification_service.dart';
import 'package:chat_messenger/services/backend_engine_manager.dart';

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
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      late StreamController<List<NewsFeedPost>> controller;
      StreamSubscription? postSub;
      StreamSubscription? likeSub;
      StreamSubscription? fsSub;
      final Map<String, NewsFeedPost> postsMap = {};

      void emitSorted() {
        if (controller.isClosed) return;
        final list = postsMap.values.where((p) => !p.isDeleted).toList();
        list.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        controller.add(list);
      }

      Future<void> fetchVpsPosts() async {
        try {
          final rawPosts = await vpsApi.getMomentPosts(limit: limit, type: 'latest');
          for (final row in rawPosts) {
            final post = NewsFeedPost.fromMap(row);
            postsMap[post.id] = post;
          }
          emitSorted();
        } catch (e) {
          debugPrint('[NewsFeedService] VPS getMomentPosts notice: $e');
        }
      }

      controller = StreamController<List<NewsFeedPost>>.broadcast(
        onListen: () {
          fetchVpsPosts();

          postSub = vpsSocket.momentPostStream.listen((data) {
            try {
              final post = NewsFeedPost.fromMap(data);
              postsMap[post.id] = post;
              emitSorted();
            } catch (_) {}
          });

          likeSub = vpsSocket.momentLikeStream.listen((data) {
            final postId = data['postId']?.toString();
            if (postId != null && postsMap.containsKey(postId)) {
              final old = postsMap[postId]!;
              final likedBy = List<String>.from(data['likedBy'] ?? old.likedBy);
              final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : likedBy.length;
              postsMap[postId] = old.copyWith(
                likedBy: likedBy,
                likeCount: likeCount,
              );
              emitSorted();
            }
          });

          // Firestore backup stream for seamless hybrid sync
          fsSub = _firestore
              .collection(_postsCollection)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .snapshots()
              .listen((snap) {
            for (final doc in snap.docs) {
              final post = NewsFeedPost.fromFirestore(doc);
              if (!postsMap.containsKey(post.id)) {
                postsMap[post.id] = post;
              }
            }
            emitSorted();
          }, onError: (_) {});
        },
        onCancel: () {
          postSub?.cancel();
          likeSub?.cancel();
          fsSub?.cancel();
        },
      );

      return controller.stream;
    }

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

  /// Real-time stream of trending posts ordered by calculatedTrendingScore
  static Stream<List<NewsFeedPost>> getTrendingPostsStream({
    DocumentSnapshot? lastDoc,
    int limit = 15,
  }) {
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      late StreamController<List<NewsFeedPost>> controller;
      StreamSubscription? postSub;
      StreamSubscription? likeSub;
      StreamSubscription? fsSub;
      final Map<String, NewsFeedPost> postsMap = {};

      void emitSorted() {
        if (controller.isClosed) return;
        final list = postsMap.values.where((p) => !p.isDeleted).toList();
        list.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.calculatedTrendingScore.compareTo(a.calculatedTrendingScore);
        });
        controller.add(list);
      }

      Future<void> fetchVpsTrending() async {
        try {
          final rawPosts = await vpsApi.getMomentPosts(limit: limit, type: 'trending');
          for (final row in rawPosts) {
            final post = NewsFeedPost.fromMap(row);
            postsMap[post.id] = post;
          }
          emitSorted();
        } catch (e) {
          debugPrint('[NewsFeedService] VPS trending posts notice: $e');
        }
      }

      controller = StreamController<List<NewsFeedPost>>.broadcast(
        onListen: () {
          fetchVpsTrending();

          postSub = vpsSocket.momentPostStream.listen((data) {
            try {
              final post = NewsFeedPost.fromMap(data);
              postsMap[post.id] = post;
              emitSorted();
            } catch (_) {}
          });

          likeSub = vpsSocket.momentLikeStream.listen((data) {
            final postId = data['postId']?.toString();
            if (postId != null && postsMap.containsKey(postId)) {
              final old = postsMap[postId]!;
              final likedBy = List<String>.from(data['likedBy'] ?? old.likedBy);
              final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : likedBy.length;
              postsMap[postId] = old.copyWith(
                likedBy: likedBy,
                likeCount: likeCount,
              );
              emitSorted();
            }
          });

          fsSub = _firestore
              .collection(_postsCollection)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .snapshots()
              .listen((snap) {
            for (final doc in snap.docs) {
              final post = NewsFeedPost.fromFirestore(doc);
              if (!postsMap.containsKey(post.id)) {
                postsMap[post.id] = post;
              }
            }
            emitSorted();
          }, onError: (_) {});
        },
        onCancel: () {
          postSub?.cancel();
          likeSub?.cancel();
          fsSub?.cancel();
        },
      );

      return controller.stream;
    }

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
      posts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.calculatedTrendingScore.compareTo(a.calculatedTrendingScore);
      });
      return posts;
    });
  }

  static Future<List<NewsFeedPost>> fetchMoreTrendingPosts({
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
      return b.calculatedTrendingScore.compareTo(a.calculatedTrendingScore);
    });
    return posts;
  }
  
  /// Real-time stream of a single post by ID
  static Stream<NewsFeedPost?> getPostByIdStream(String postId) {
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      late StreamController<NewsFeedPost?> controller;
      StreamSubscription? likeSub;
      StreamSubscription? fsSub;
      NewsFeedPost? currentPost;

      Future<void> fetchSingle() async {
        try {
          final data = await vpsApi.getSingleMomentPost(postId);
          if (data != null) {
            currentPost = NewsFeedPost.fromMap(data);
            if (!controller.isClosed) controller.add(currentPost);
          }
        } catch (_) {}
      }

      controller = StreamController<NewsFeedPost?>.broadcast(
        onListen: () {
          fetchSingle();
          likeSub = vpsSocket.momentLikeStream.listen((data) {
            if (data['postId']?.toString() == postId && currentPost != null) {
              final likedBy = List<String>.from(data['likedBy'] ?? currentPost!.likedBy);
              final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : likedBy.length;
              currentPost = currentPost!.copyWith(likedBy: likedBy, likeCount: likeCount);
              if (!controller.isClosed) controller.add(currentPost);
            }
          });
          fsSub = _firestore.collection(_postsCollection).doc(postId).snapshots().listen((snap) {
            if (snap.exists) {
              currentPost = NewsFeedPost.fromFirestore(snap);
              if (!controller.isClosed) controller.add(currentPost);
            }
          }, onError: (_) {});
        },
        onCancel: () {
          likeSub?.cancel();
          fsSub?.cancel();
        },
      );

      return controller.stream;
    }

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

      // VPS real-time sync
      if (BackendEngineManager.isVps) {
        final vpsApi = BackendEngineManager.instance.apiService;
        final vpsSocket = BackendEngineManager.instance.socketService;

        final postPayload = {
          'id': docRef.id,
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'userFrameId': userFrameId,
          'userLevel': userLevel ?? 1,
          'content': content,
          'media': mediaList.map((m) => m.toJson()).toList(),
          'mediaUrls': mediaList.map((m) => m.url).toList(),
          'mediaTypes': mediaList.map((m) => m.type).toList(),
          'visibility': visibility,
        };

        vpsSocket.publishMoment(postPayload);
        vpsApi.createMomentPost(postPayload).catchError((_) => null);
      }

      await docRef.set(post.toFirestore());

      // Send mention notifications in background
      _sendMentionNotifications(
        text: content,
        postId: docRef.id,
        senderUserId: userId,
        senderUserName: userName,
        senderAvatar: userAvatar,
        isComment: false,
      );

      return docRef.id;
    } catch (e) {
      debugPrint('❌ [NewsFeed] Error creating post: $e');
      return null;
    }
  }

  /// Delete a post (soft delete)
  static Future<void> deletePost(String postId) async {
    if (BackendEngineManager.isVps) {
      BackendEngineManager.instance.apiService.deleteMomentPost(postId).catchError((_) => false);
    }
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
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;
      vpsSocket.likeMoment(postId: postId, reactionType: 'like');
      vpsApi.likeMomentPost(postId, reactionType: 'like').catchError((_) => null);
    }

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

      final newLikeCount = likedBy.length;
      final commentCount = (data['commentCount'] as num?)?.toInt() ?? 0;
      final shareCount = (data['shareCount'] as num?)?.toInt() ?? 0;
      final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
      final newTrendingScore = (newLikeCount * 3.0) + (commentCount * 5.0) + (shareCount * 10.0) + (viewCount * 0.5);

      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': newLikeCount,
        'reactions': reactions,
        'trendingScore': newTrendingScore,
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
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;
      vpsSocket.likeMoment(postId: postId, reactionType: reaction.toJson());
      vpsApi.likeMomentPost(postId, reactionType: reaction.toJson()).catchError((_) => null);
    }

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

      final newLikeCount = likedBy.length;
      final commentCount = (data['commentCount'] as num?)?.toInt() ?? 0;
      final shareCount = (data['shareCount'] as num?)?.toInt() ?? 0;
      final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
      final newTrendingScore = (newLikeCount * 3.0) + (commentCount * 5.0) + (shareCount * 10.0) + (viewCount * 0.5);

      txn.update(ref, {
        'likedBy': likedBy,
        'likeCount': newLikeCount,
        'reactions': reactions,
        'trendingScore': newTrendingScore,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  // ─── Comments ──────────────────────────────────────────────────────────────

  static Stream<List<PostComment>> getCommentsStream(String postId) {
    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      late StreamController<List<PostComment>> controller;
      StreamSubscription? commentSub;
      StreamSubscription? fsSub;
      final Map<String, PostComment> commentsMap = {};

      void emitList() {
        if (controller.isClosed) return;
        final list = commentsMap.values.toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        controller.add(list);
      }

      Future<void> fetchVpsComments() async {
        try {
          final rawComments = await vpsApi.getMomentComments(postId);
          for (final row in rawComments) {
            final comment = PostComment.fromMap(row);
            commentsMap[comment.id] = comment;
          }
          emitList();
        } catch (_) {}
      }

      controller = StreamController<List<PostComment>>.broadcast(
        onListen: () {
          fetchVpsComments();

          commentSub = vpsSocket.momentCommentStream.listen((data) {
            if (data['postId']?.toString() == postId && data['comment'] is Map) {
              final comment = PostComment.fromMap(Map<String, dynamic>.from(data['comment']));
              commentsMap[comment.id] = comment;
              emitList();
            }
          });

          fsSub = _firestore
              .collection(_commentsCollection)
              .where('postId', isEqualTo: postId)
              .snapshots()
              .listen((snap) {
            for (final doc in snap.docs) {
              final comment = PostComment.fromFirestore(doc);
              commentsMap[comment.id] = comment;
            }
            emitList();
          }, onError: (_) {});
        },
        onCancel: () {
          commentSub?.cancel();
          fsSub?.cancel();
        },
      );

      return controller.stream;
    }

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

    if (BackendEngineManager.isVps) {
      final vpsApi = BackendEngineManager.instance.apiService;
      final vpsSocket = BackendEngineManager.instance.socketService;

      vpsSocket.commentMoment(
        postId: postId,
        commentId: docRef.id,
        text: text,
        userName: userName,
        userAvatar: userAvatar,
        userFrameId: userFrameId,
        imageUrl: imageUrl,
        replyToId: replyToId,
        replyToUserName: replyToUserName,
      );

      vpsApi.createMomentComment(
        postId: postId,
        commentId: docRef.id,
        text: text,
        userName: userName,
        userAvatar: userAvatar,
        userFrameId: userFrameId,
        imageUrl: imageUrl,
        replyToId: replyToId,
        replyToUserName: replyToUserName,
      ).catchError((_) => null);
    }

    final batch = _firestore.batch();
    batch.set(docRef, comment.toFirestore());
    batch.update(_firestore.collection(_postsCollection).doc(postId), {
      'commentCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
    await batch.commit();

    // Send mention notifications in background
    _sendMentionNotifications(
      text: text,
      postId: postId,
      senderUserId: userId,
      senderUserName: userName,
      senderAvatar: userAvatar,
      isComment: true,
    );
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

  /// Increment share count
  static Future<void> incrementShareCount(String postId) async {
    if (BackendEngineManager.isVps) {
      BackendEngineManager.instance.apiService.shareMomentPost(postId).catchError((_) => false);
    }
    await _firestore.collection(_postsCollection).doc(postId).update({
      'shareCount': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
  }

  // ─── Reporting & Moderation ───────────────────────────────────────────────

  /// Report a post
  static Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    final reportDoc = _firestore.collection('moment_reports').doc();
    final batch = _firestore.batch();

    batch.set(reportDoc, {
      'id': reportDoc.id,
      'postId': postId,
      'reporterId': reporterId,
      'reason': reason,
      'details': details ?? '',
      'createdAt': Timestamp.now(),
      'status': 'pending', // 'pending', 'resolved', 'dismissed'
    });

    batch.update(_firestore.collection(_postsCollection).doc(postId), {
      'reportCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Create an official notice post
  static Future<String?> createNoticePost({
    required String title,
    required String content,
    File? mediaFile,
    bool isPinned = true,
  }) async {
    try {
      final docRef = _firestore.collection(_postsCollection).doc();
      final now = DateTime.now();

      List<PostMedia> mediaList = [];
      if (mediaFile != null) {
        final ext = mediaFile.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
        final ref = _storage
            .ref()
            .child('news_feed_media/${docRef.id}/${now.millisecondsSinceEpoch}.$ext');
        await ref.putFile(mediaFile);
        final url = await ref.getDownloadURL();
        mediaList.add(PostMedia(url: url, type: isVideo ? 'video' : 'image'));
      }

      final post = NewsFeedPost(
        id: docRef.id,
        userId: 'admin_official',
        userName: 'imChat Official Notice',
        content: content,
        noticeTitle: title,
        isNotice: true,
        isPinned: isPinned,
        media: mediaList,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(post.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('❌ [NewsFeedService] Error creating notice: $e');
      return null;
    }
  }

  /// Stream reported posts
  static Stream<QuerySnapshot<Map<String, dynamic>>> getReportedPostsStream() {
    return _firestore
        .collection('moment_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Dismiss a report
  static Future<void> dismissReport(String reportId) async {
    await _firestore.collection('moment_reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedAt': Timestamp.now(),
    });
  }

  /// Delete a post by admin and update report status
  static Future<void> deleteReportedPost(String postId, String reportId) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection(_postsCollection).doc(postId), {
      'isDeleted': true,
      'updatedAt': Timestamp.now(),
    });
    batch.update(_firestore.collection('moment_reports').doc(reportId), {
      'status': 'resolved',
      'actionTaken': 'deleted',
      'resolvedAt': Timestamp.now(),
    });
    await batch.commit();
  }

  // ─── Ad Settings Configuration ──────────────────────────────────────────

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getAdSettingsStream() {
    return _firestore.collection('app_settings').doc('moment_ads').snapshots();
  }

  static Future<void> updateAdSettings(Map<String, dynamic> settings) async {
    await _firestore.collection('app_settings').doc('moment_ads').set(
      settings,
      SetOptions(merge: true),
    );
  }

  // ─── View Count Tracking ───────────────────────────────────────────────────

  static Future<void> incrementPostViewCount(String postId) async {
    try {
      await _firestore.collection(_postsCollection).doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  /// Extract mentions from text and send push/in-app notifications to mentioned users
  static Future<void> _sendMentionNotifications({
    required String text,
    required String postId,
    required String senderUserId,
    required String senderUserName,
    String? senderAvatar,
    bool isComment = false,
  }) async {
    if (text.isEmpty) return;

    final matches = RegExp(
      r'(@[a-zA-Z0-9_\.\-\u0980-\u09FF]+)',
      caseSensitive: false,
    ).allMatches(text);

    if (matches.isEmpty) return;

    final Set<String> processedQueries = {};

    for (final match in matches) {
      final rawMention = match.group(0)!;
      final query = rawMention.replaceAll('@', '').trim();
      if (query.isEmpty || processedQueries.contains(query.toLowerCase())) {
        continue;
      }
      processedQueries.add(query.toLowerCase());

      try {
        User? targetUser;

        // 1. Direct match by userId using UserApi
        targetUser = await UserApi.getUser(query);

        // 2. Query searchId
        if (targetUser == null) {
          final searchIdQuery = await _firestore
              .collection('Users')
              .where('searchId', isEqualTo: query)
              .limit(1)
              .get();
          if (searchIdQuery.docs.isNotEmpty) {
            targetUser = User.fromMap(searchIdQuery.docs.first.data());
          }
        }

        // 3. Match by fullname
        if (targetUser == null) {
          final snapshot =
              await _firestore.collection('Users').limit(200).get();
          final lowerQuery = query.toLowerCase();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final fullname = (data['fullname'] ?? '').toString();
            final cleanFullname = fullname.replaceAll(' ', '').toLowerCase();
            final searchId = (data['searchId'] ?? '').toString().toLowerCase();

            if (cleanFullname == lowerQuery ||
                fullname.toLowerCase() == lowerQuery ||
                searchId == lowerQuery ||
                doc.id.toLowerCase() == lowerQuery ||
                (cleanFullname.isNotEmpty &&
                    cleanFullname.contains(lowerQuery))) {
              targetUser = User.fromMap(data);
              break;
            }
          }
        }

        // Don't notify the sender themselves
        if (targetUser == null || targetUser.userId == senderUserId) {
          continue;
        }

        final title = isComment
            ? '$senderUserName mentioned you in a comment'
            : '$senderUserName mentioned you in a post';

        // 1. Save in-app notification in Firestore
        await _firestore.collection('user_notifications').add({
          'recipientId': targetUser.userId,
          'senderId': senderUserId,
          'senderName': senderUserName,
          'senderAvatar': senderAvatar ?? '',
          'type': isComment ? 'comment_mention' : 'post_mention',
          'title': title,
          'body': text,
          'postId': postId,
          'isRead': false,
          'createdAt': Timestamp.now(),
        });

        // 2. Send FCM Push Notification if deviceToken is present
        if (targetUser.deviceToken.isNotEmpty) {
          await PushNotificationService.sendNotification(
            type: NotificationType.alert,
            title: title,
            body: text,
            deviceToken: targetUser.deviceToken,
            call: {
              'type': isComment ? 'comment_mention' : 'post_mention',
              'postId': postId,
            },
          );
        }
      } catch (e) {
        debugPrint('❌ Error sending mention notification for @$query: $e');
      }
    }
  }
}

