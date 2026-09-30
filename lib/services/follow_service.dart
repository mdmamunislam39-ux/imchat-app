import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/services/backend_engine_manager.dart';

/// Clean follow service with proper error handling
class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Follow a user
  static Future<FollowResult> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Validate inputs
      if (currentUserId.isEmpty || targetUserId.isEmpty) {
        return FollowResult.error('Invalid user IDs provided');
      }

      if (currentUserId == targetUserId) {
        return FollowResult.error('Cannot follow yourself');
      }

      final currentUserRef = _firestore.collection('Users').doc(currentUserId);
      final targetUserRef = _firestore.collection('Users').doc(targetUserId);
      
      final followingDoc = currentUserRef.collection('following').doc(targetUserId);
      final followerDoc = targetUserRef.collection('followers').doc(currentUserId);
      
      // Check if already following
      final alreadyFollowing = (await followingDoc.get().timeout(const Duration(seconds: 15))).exists;
      if (alreadyFollowing) {
        return FollowResult.error('Already following this user');
      }
      
      // Add to both subcollections and update counters
      await Future.wait([
        followingDoc.set({
          'userId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15)),
        followerDoc.set({
          'userId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15)),
        currentUserRef.set({'following': FieldValue.increment(1)}, SetOptions(merge: true)).timeout(const Duration(seconds: 15)),
        targetUserRef.set({'followers': FieldValue.increment(1)}, SetOptions(merge: true)).timeout(const Duration(seconds: 15)),
      ]);
      
      // Trigger follow notification & sound feedback
      try {
        final senderDoc = await _firestore.collection('Users').doc(currentUserId).get();
        final senderName = senderDoc.data()?['fullname'] ?? senderDoc.data()?['displayName'] ?? 'User';
        OfficialTeamApi.sendFollowNotification(
          receiverId: targetUserId,
          senderName: senderName,
        );
        final player = AudioPlayer();
        await player.play(AssetSource('sounds/sent_msg.mp3'));
      } catch (soundErr) {
        debugPrint('Sound/notification error on follow: $soundErr');
      }

      // In VPS mode, also sync follow relation to VPS backend in background
      if (BackendEngineManager.isVps) {
        unawaited(Future(() async {
          try {
            await BackendEngineManager.instance.apiService.post('/api/user/follow', body: {
              'targetUserId': targetUserId,
            });
          } catch (_) {}
        }));
      }

      debugPrint('✅ Successfully followed user: $targetUserId');
      return FollowResult.success('Successfully followed user');
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      return FollowResult.error('Failed to follow user: $e');
    }
  }

  /// Unfollow a user
  static Future<FollowResult> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Validate inputs
      if (currentUserId.isEmpty || targetUserId.isEmpty) {
        return FollowResult.error('Invalid user IDs provided');
      }

      if (currentUserId == targetUserId) {
        return FollowResult.error('Cannot unfollow yourself');
      }

      final currentUserRef = _firestore.collection('Users').doc(currentUserId);
      final targetUserRef = _firestore.collection('Users').doc(targetUserId);
      
      final followingDoc = currentUserRef.collection('following').doc(targetUserId);
      final followerDoc = targetUserRef.collection('followers').doc(currentUserId);
      
      // Check if currently following
      final currentlyFollowing = (await followingDoc.get().timeout(const Duration(seconds: 15))).exists;
      if (!currentlyFollowing) {
        return FollowResult.error('Not currently following this user');
      }
      
      // Remove from both subcollections and update counters
      await Future.wait([
        followingDoc.delete().timeout(const Duration(seconds: 15)),
        followerDoc.delete().timeout(const Duration(seconds: 15)),
        currentUserRef.set({'following': FieldValue.increment(-1)}, SetOptions(merge: true)).timeout(const Duration(seconds: 15)),
        targetUserRef.set({'followers': FieldValue.increment(-1)}, SetOptions(merge: true)).timeout(const Duration(seconds: 15)),
      ]);
      
      // In VPS mode, also sync unfollow relation to VPS backend in background
      if (BackendEngineManager.isVps) {
        unawaited(Future(() async {
          try {
            await BackendEngineManager.instance.apiService.post('/api/user/unfollow', body: {
              'targetUserId': targetUserId,
            });
          } catch (_) {}
        }));
      }

      debugPrint('✅ Successfully unfollowed user: $targetUserId');
      return FollowResult.success('Successfully unfollowed user');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      return FollowResult.error('Failed to unfollow user: $e');
    }
  }

  /// Check if current user is following target user
  static Future<FollowResult> isFollowing({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Validate inputs
      if (currentUserId.isEmpty || targetUserId.isEmpty) {
        return FollowResult.error('Invalid user IDs provided');
      }

      final followingDoc = _firestore
          .collection('Users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      
      final doc = await followingDoc.get().timeout(const Duration(seconds: 15));
      final exists = doc.exists;
      debugPrint('🔍 [FollowService] Document exists for $currentUserId -> $targetUserId: $exists');
      return FollowResult.success('Follow status checked', data: exists.toString());
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return FollowResult.error('Failed to check follow status: $e');
    }
  }

  /// Get user's follower count
  static Future<FollowResult> getFollowerCount(String userId) async {
    try {
      if (userId.isEmpty) {
        return FollowResult.error('Invalid user ID provided');
      }

      final doc = await _firestore.collection('Users').doc(userId).get().timeout(const Duration(seconds: 15));
      final count = doc.data()?['followers'] ?? 0;
      return FollowResult.success('Follower count retrieved', data: count.toString());
    } catch (e) {
      debugPrint('❌ Error getting follower count: $e');
      return FollowResult.error('Failed to get follower count: $e');
    }
  }

  /// Get user's following count
  static Future<FollowResult> getFollowingCount(String userId) async {
    try {
      if (userId.isEmpty) {
        return FollowResult.error('Invalid user ID provided');
      }

      final doc = await _firestore.collection('Users').doc(userId).get().timeout(const Duration(seconds: 15));
      final count = doc.data()?['following'] ?? 0;
      return FollowResult.success('Following count retrieved', data: count.toString());
    } catch (e) {
      debugPrint('❌ Error getting following count: $e');
      return FollowResult.error('Failed to get following count: $e');
    }
  }
}

/// Result class for follow operations
class FollowResult {
  final bool isSuccess;
  final String message;
  final String? data;

  FollowResult._({
    required this.isSuccess,
    required this.message,
    this.data,
  });

  factory FollowResult.success(String message, {String? data}) {
    return FollowResult._(
      isSuccess: true,
      message: message,
      data: data,
    );
  }

  factory FollowResult.error(String message) {
    return FollowResult._(
      isSuccess: false,
      message: message,
    );
  }

  bool get isError => !isSuccess;
}