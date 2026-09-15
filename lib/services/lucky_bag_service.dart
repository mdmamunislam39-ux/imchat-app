import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';

class LuckyBagService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper to get user's diamond balance checking both diamonds and wallet fields
  static int _getUserDiamondBalance(Map<String, dynamic> userData) {
    final val = userData['diamonds'] ?? userData['wallet'] ?? 0;
    if (val is double) return val.toInt();
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  /// Fetch a single LuckyBagModel by ID
  static Future<LuckyBagModel?> getLuckyBag(String roomId, String bagId) async {
    try {
      final doc = await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('lucky_bags')
          .doc(bagId)
          .get();
      if (doc.exists && doc.data() != null) {
        return LuckyBagModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('Error fetching lucky bag: $e');
    }
    return null;
  }

  /// Stream active lucky bag for a given room
  static Stream<LuckyBagModel?> streamActiveLuckyBag(String roomId) {
    return _firestore
        .collection('audio_rooms_v2')
        .doc(roomId)
        .collection('lucky_bags')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final bags = snapshot.docs
          .map((doc) => LuckyBagModel.fromMap(doc.data(), doc.id))
          .where((b) => b.isActive)
          .toList();
      if (bags.isEmpty) return null;
      bags.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bags.first;
    });
  }

  /// Stream claim history for a specific lucky bag
  static Stream<List<LuckyBagClaimModel>> streamClaims(
      String roomId, String bagId) {
    return _firestore
        .collection('audio_rooms_v2')
        .doc(roomId)
        .collection('lucky_bags')
        .doc(bagId)
        .collection('claims')
        .orderBy('rewardAmount', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LuckyBagClaimModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Check if user has already claimed from this lucky bag
  static Future<bool> hasUserClaimed({
    required String roomId,
    required String bagId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('lucky_bags')
          .doc(bagId)
          .collection('claims')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking claim status: $e');
      return false;
    }
  }

  /// Host / User creates a new Lucky Bag
  static Future<String?> createLuckyBag({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required int totalAmount,
    required int maxWinners,
    required int countdownSeconds,
    String distributionType = 'random',
    bool isPublic = false,
    String? message,
  }) async {
    try {
      final userRef = _firestore.collection('Users').doc(senderId);
      final roomBagsRef = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('lucky_bags');

      String newBagId = roomBagsRef.doc().id;

      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User account not found.');
        }

        final userData = userSnapshot.data() ?? {};
        int currentBalance = _getUserDiamondBalance(userData);

        if (currentBalance < totalAmount) {
          throw Exception(
              'Insufficient balance. You need $totalAmount diamonds.');
        }

        final newBalance = currentBalance - totalAmount;

        // Deduct sender balance on both 'diamonds' and 'wallet' fields for full app compatibility
        transaction.update(userRef, {
          'diamonds': newBalance,
          'wallet': newBalance,
        });

        final now = DateTime.now();
        final unlocksAt = now.add(Duration(seconds: countdownSeconds));
        final expiresAt = unlocksAt.add(const Duration(minutes: 10));

        final int distributableAmount = (totalAmount * 80) ~/ 100;
        final int appCommission = totalAmount - distributableAmount;

        final bagData = {
          'id': newBagId,
          'roomId': roomId,
          'senderId': senderId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'totalAmount': totalAmount,
          'distributableAmount': distributableAmount,
          'appCommission': appCommission,
          'remainingAmount': distributableAmount, // 80% pool for all winners combined
          'maxWinners': maxWinners,
          'claimedCount': 0,
          'entryFee': 0,
          'distributionType': distributionType,
          'isPublic': isPublic,
          'message': message,
          'status': 'active',
          'createdAt': Timestamp.fromDate(now),
          'unlocksAt': Timestamp.fromDate(unlocksAt),
          'expiresAt': Timestamp.fromDate(expiresAt),
        };

        transaction.set(roomBagsRef.doc(newBagId), bagData);
        transaction.set(_firestore.collection('global_lucky_bags').doc(newBagId), bagData);
      });

      return newBagId;
    } catch (e) {
      debugPrint('❌ Error creating Lucky Bag: $e');
      rethrow;
    }
  }

  /// Claim diamonds from an active Lucky Bag (Atomic Transaction)
  static Future<int> claimLuckyBag({
    required String roomId,
    required String bagId,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    try {
      final bagRef = _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('lucky_bags')
          .doc(bagId);

      final claimRef = bagRef.collection('claims').doc(userId);
      final userRef = _firestore.collection('Users').doc(userId);
      final globalBagRef = _firestore.collection('global_lucky_bags').doc(bagId);

      int rewardAmount = 0;

      await _firestore.runTransaction((transaction) async {
        // 1. ALL READS FIRST
        final bagSnapshot = await transaction.get(bagRef);
        if (!bagSnapshot.exists) {
          throw Exception('Lucky Bag no longer exists.');
        }

        final claimSnapshot = await transaction.get(claimRef);
        if (claimSnapshot.exists) {
          throw Exception('You have already claimed this Lucky Bag.');
        }

        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User account not found.');
        }

        // 2. CALCULATIONS
        final bagData = bagSnapshot.data()!;
        final status = bagData['status'] ?? 'active';
        final int remainingAmount = (bagData['remainingAmount'] ?? 0) is double
            ? (bagData['remainingAmount'] as double).toInt()
            : (bagData['remainingAmount'] ?? 0);
        final int maxWinners = (bagData['maxWinners'] ?? 1) is double
            ? (bagData['maxWinners'] as double).toInt()
            : (bagData['maxWinners'] ?? 1);
        final int claimedCount = (bagData['claimedCount'] ?? 0) is double
            ? (bagData['claimedCount'] as double).toInt()
            : (bagData['claimedCount'] ?? 0);
        final String distType = bagData['distributionType'] ?? 'random';
        final Timestamp expiresTimestamp = bagData['expiresAt'];
        final Timestamp? unlocksTimestamp = bagData['unlocksAt'];

        if (unlocksTimestamp != null &&
            DateTime.now().isBefore(unlocksTimestamp.toDate())) {
          throw Exception('Countdown is still running! Please wait.');
        }

        if (status != 'active' ||
            DateTime.now().isAfter(expiresTimestamp.toDate())) {
          throw Exception('This Lucky Bag has expired.');
        }

        if (claimedCount >= maxWinners || remainingAmount <= 0) {
          throw Exception('All rewards in this Lucky Bag have been claimed.');
        }

        // Calculate reward amount safely
        final int remainingWinners = maxWinners - claimedCount;
        if (remainingWinners == 1) {
          rewardAmount = remainingAmount;
        } else if (distType == 'equal') {
          rewardAmount = (remainingAmount / remainingWinners).floor();
          if (rewardAmount < 1) rewardAmount = 1;
        } else {
          // Double-Average Random Algorithm
          final int maxAllowed =
              ((remainingAmount / remainingWinners) * 2).floor();
          final Random random = Random();
          rewardAmount = 1 + random.nextInt(max(1, maxAllowed));
          if (rewardAmount > remainingAmount) {
            rewardAmount = remainingAmount;
          }
        }

        final int newClaimedCount = claimedCount + 1;
        final int newRemainingAmount = remainingAmount - rewardAmount;
        final bool isNowCompleted =
            newClaimedCount >= maxWinners || newRemainingAmount <= 0;

        final userData = userSnapshot.data() ?? {};
        int currentBalance = _getUserDiamondBalance(userData);
        final newBalance = currentBalance + rewardAmount;

        // 3. ALL WRITES AFTER READS
        final updateMap = {
          'claimedCount': newClaimedCount,
          'remainingAmount': newRemainingAmount,
          if (isNowCompleted) 'status': 'completed',
        };

        transaction.update(bagRef, updateMap);
        transaction.update(globalBagRef, updateMap);

        transaction.set(claimRef, {
          'userId': userId,
          'userName': userName,
          'userAvatar': userAvatar,
          'rewardAmount': rewardAmount,
          'isLuckyKing': false,
          'claimedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(userRef, {
          'diamonds': newBalance,
          'wallet': newBalance,
        });
      });

      return rewardAmount;
    } catch (e) {
      debugPrint('❌ Error claiming Lucky Bag: $e');
      rethrow;
    }
  }
}
