import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to handle social affinity, friends boost, and personalized discovery logic
class SocialAffinityService {
  static final SocialAffinityService _instance = SocialAffinityService._internal();
  factory SocialAffinityService() => _instance;
  SocialAffinityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<String> _followingIds = {};
  Set<String> _followerIds = {};
  Set<String> _chatContactIds = {};
  Set<String> _giftPartnerIds = {};
  bool _isInitialized = false;
  String? _initializedUserId;

  Set<String> get followingIds => _followingIds;
  Set<String> get followerIds => _followerIds;
  Set<String> get chatContactIds => _chatContactIds;
  Set<String> get giftPartnerIds => _giftPartnerIds;

  /// Initialize user's social connection network
  Future<void> init(String userId) async {
    if (userId.isEmpty) return;
    if (_isInitialized && _initializedUserId == userId) return;

    _initializedUserId = userId;
    _isInitialized = true;

    try {
      // 1. Fetch Following IDs
      final followingSnap = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('following')
          .get()
          .timeout(const Duration(seconds: 10));
      _followingIds = followingSnap.docs.map((doc) => doc.id).toSet();

      // 2. Fetch Followers IDs
      final followerSnap = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('followers')
          .get()
          .timeout(const Duration(seconds: 10));
      _followerIds = followerSnap.docs.map((doc) => doc.id).toSet();

      // 3. Fetch Gift Partners (Users with whom gift transactions occurred)
      final giftsSnap = await _firestore
          .collection('gift_transactions')
          .where('senderId', isEqualTo: userId)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 10));

      final giftRecvSnap = await _firestore
          .collection('gift_transactions')
          .where('receiverId', isEqualTo: userId)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 10));

      _giftPartnerIds = {
        ...giftsSnap.docs.map((doc) => (doc.data()['receiverId'] ?? '').toString()),
        ...giftRecvSnap.docs.map((doc) => (doc.data()['senderId'] ?? '').toString()),
      }..remove('');

      // 4. Fetch Recent Chat Contacts from Chats collection
      final chatsSnap = await _firestore
          .collection('Chats')
          .where('users', arrayContains: userId)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 10));

      final contacts = <String>{};
      for (var doc in chatsSnap.docs) {
        final users = (doc.data()['users'] as List<dynamic>?)?.map((u) => u.toString()).toList() ?? [];
        for (var uid in users) {
          if (uid != userId && uid.isNotEmpty) {
            contacts.add(uid);
          }
        }
      }
      _chatContactIds = contacts;

      debugPrint('✅ [SocialAffinityService] Loaded connections: '
          '${_followingIds.length} following, '
          '${_followerIds.length} followers, '
          '${_giftPartnerIds.length} gift partners, '
          '${_chatContactIds.length} chat contacts.');
    } catch (e) {
      debugPrint('⚠️ [SocialAffinityService] Initializing connections warning: $e');
    }
  }

  /// Calculate social affinity multiplier for a content creator / room host
  double getAffinityMultiplier(String creatorId, {List<String>? participantIds}) {
    if (creatorId.isEmpty) return 1.0;

    double multiplier = 1.0;

    // Check direct following, inbox friend, or gift partner (+60% boost)
    if (_followingIds.contains(creatorId) ||
        _chatContactIds.contains(creatorId) ||
        _giftPartnerIds.contains(creatorId)) {
      multiplier *= 1.60;
    }
    // Check follower (+35% boost)
    else if (_followerIds.contains(creatorId)) {
      multiplier *= 1.35;
    }

    // Check room participants for audio rooms
    if (participantIds != null && participantIds.isNotEmpty) {
      bool hasDirectFriendInRoom = participantIds.any(
        (id) => _followingIds.contains(id) || _chatContactIds.contains(id),
      );
      if (hasDirectFriendInRoom) {
        multiplier *= 1.25;
      }
    }

    return multiplier;
  }

  /// Calculate final boosted trending score aggregating all 10 core trending metrics
  double calculateBoostedScore(
    double baseScore,
    String creatorId, {
    List<String>? participantIds,
    int participantCount = 0,
    int seatedCount = 0,
    int uniqueJoiners10m = 0,
    int giftCoins10m = 0,
    int likes10m = 0,
    int messages10m = 0,
    double growthRate = 1.0,
    double avgStayTime = 0.0,
    String itemUniqueId = '',
  }) {
    final affinityMultiplier = getAffinityMultiplier(creatorId, participantIds: participantIds);

    // Aggregate 10 core trending metrics real-time boost
    final effectiveUserCount = participantIds?.length ?? participantCount;
    final liveBoost =
        (effectiveUserCount * 120.0) +
        (seatedCount * 60.0) +
        (uniqueJoiners10m * 40.0) +
        (giftCoins10m * 10.0) +
        (likes10m * 2.0) +
        (messages10m * 5.0) +
        (growthRate * 100.0) +
        (avgStayTime * 15.0);

    final combinedScore = (baseScore > 0 ? baseScore : 1.0) + liveBoost;

    // Intermittent discovery jitter (0.92 .. 1.08)
    int seed = itemUniqueId.hashCode;
    if (seed == 0) seed = DateTime.now().minute;
    final random = Random(seed);
    final discoveryJitter = 0.92 + (random.nextDouble() * 0.16);

    return combinedScore * affinityMultiplier * discoveryJitter;
  }
}
