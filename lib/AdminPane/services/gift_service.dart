import 'dart:async';
import 'package:chat_messenger/services/grab_the_top_service.dart';
import 'package:chat_messenger/services/top_exposure_service.dart';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/gift.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/services/relationship_service.dart';

/// Service for managing gifts in Firebase
class GiftService {
  static const String _giftsCollection = 'gift';
  static const String _transactionsCollection = 'gift_transactions';
  static final Map<String, Map<String, dynamic>> _giftDataCache = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Expose firestore for testing
  FirebaseFirestore get firestore => _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Get all gifts
  Future<List<Gift>> getAllGifts() async {
    final snapshot = await _firestore.collection(_giftsCollection).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Gift.fromJson({...doc.data(), 'id': doc.id})).toList();
  }

  /// Get available categories
  Future<List<String>> getAvailableCategories() async {
    final snapshot = await _firestore.collection(_giftsCollection).get();
    final categories = snapshot.docs.map((doc) => doc.data()['category'] as String?).whereType<String>().toSet().toList();
    return categories;
  }

  /// Get gifts by category
  Future<List<Gift>> getGiftsByCategory(String category) async {
    final snapshot = await _firestore.collection(_giftsCollection).where('category', isEqualTo: category).get();
    return snapshot.docs.map((doc) => Gift.fromJson({...doc.data(), 'id': doc.id})).toList();
  }

  /// Add a new gift
  Future<String> addGift({
    required String name,
    required String category,
    required int credits,
    File? pngFile,
    File? svgaFile,
    bool skipFileUpload = false,
    int? showingTimeSeconds,
  }) async {
    String? pngUrl;
    String? svgaUrl;

    if (!skipFileUpload) {
      if (pngFile != null) {
        final extension = pngFile.path.split('.').last.toLowerCase();
        final ref = _storage.ref().child('gifts/png/${_uuid.v4()}.$extension');
        await ref.putFile(pngFile);
        pngUrl = await ref.getDownloadURL();
      }
      if (svgaFile != null) {
        final extension = svgaFile.path.split('.').last.toLowerCase();
        final ref = _storage.ref().child('gifts/svga/${_uuid.v4()}.$extension');
        await ref.putFile(svgaFile);
        svgaUrl = await ref.getDownloadURL();
      }
    }

    final docRef = await _firestore.collection(_giftsCollection).add({
      'name': name,
      'category': category,
      'credits': credits,
      'pngUrl': pngUrl,
      'svgaUrl': svgaUrl,
      'isActive': true,
      if (showingTimeSeconds != null) 'showingTimeSeconds': showingTimeSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Update an existing gift
  Future<void> updateGift({
    required String id,
    required String name,
    required String category,
    required int credits,
    File? pngFile,
    File? svgaFile,
    int? showingTimeSeconds,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'category': category,
      'credits': credits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (showingTimeSeconds != null) {
      updates['showingTimeSeconds'] = showingTimeSeconds;
    }

    if (pngFile != null) {
      final extension = pngFile.path.split('.').last.toLowerCase();
      final ref = _storage.ref().child('gifts/png/${_uuid.v4()}.$extension');
      await ref.putFile(pngFile);
      updates['pngUrl'] = await ref.getDownloadURL();
    }
    
    if (svgaFile != null) {
      final extension = svgaFile.path.split('.').last.toLowerCase();
      final ref = _storage.ref().child('gifts/svga/${_uuid.v4()}.$extension');
      await ref.putFile(svgaFile);
      updates['svgaUrl'] = await ref.getDownloadURL();
    }

    await _firestore.collection(_giftsCollection).doc(id).update(updates);
  }

  /// Delete a gift
  Future<void> deleteGift(String id) async {
    await _firestore.collection(_giftsCollection).doc(id).delete();
  }

  String _cleanGiftName(String name) {
    var cleaned = name.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+x\d+$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*x\d+\s*\)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\s*combo\s*\)$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Send gifts asynchronously to multiple receivers
  /// Send gifts asynchronously to multiple receivers
  Future<void> sendGifts({
    required String giftId,
    required String giftName,
    required String giftPngUrl,
    required String? giftSvgaUrl,
    required int giftCredits,
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required List<Map<String, dynamic>> receivers,
    required String roomId,
    required bool sendChatMessage,
    int quantity = 1,
    bool isComboHit = false,
  }) async {
    return _processGiftSending(
      giftId: giftId,
      giftName: giftName,
      giftPngUrl: giftPngUrl,
      giftSvgaUrl: giftSvgaUrl,
      giftCredits: giftCredits,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      receivers: receivers,
      roomId: roomId,
      quantity: quantity,
      isComboHit: isComboHit,
    );
  }

  Future<void> _processGiftSending({
    required String giftId,
    required String giftName,
    required String giftPngUrl,
    required String? giftSvgaUrl,
    required int giftCredits,
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required List<Map<String, dynamic>> receivers,
    required String roomId,
    int quantity = 1,
    bool isComboHit = false,
  }) async {
    final int safeQuantity = quantity > 0 ? quantity : 1;
    final int perReceiverCredits = giftCredits * safeQuantity;
    final int totalCredits = perReceiverCredits * receivers.length;
    final String cleanName = _cleanGiftName(giftName);

    // Atomic Batch Write for all core transactions (Sender deduction, receiver beans, room transactions, room revenue)
    final WriteBatch batch = _firestore.batch();

    // Deduct sender diamonds
    batch.update(_firestore.collection('Users').doc(senderId), {
      'diamonds': FieldValue.increment(-totalCredits),
      'dailyDiamondsSent_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
      'weeklyDiamondsSent_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
      'monthlyDiamondsSent_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
      'totalDiamondsSent': FieldValue.increment(totalCredits),
    });

    // Add receiver beans & create room gift transaction docs (only for full SVGA animations, NOT for rapid combo hits)
    for (var receiver in receivers) {
      final receiverId = receiver['id'];
      final receiverName = receiver['name'];
      final receiverImageUrl = receiver['imageUrl'];

      batch.update(_firestore.collection('Users').doc(receiverId), {
        'beans': FieldValue.increment(perReceiverCredits),
        'dailyDiamondsReceived_${RankingHelper.dailySuffix}': FieldValue.increment(perReceiverCredits),
        'weeklyDiamondsReceived_${RankingHelper.weeklySuffix}': FieldValue.increment(perReceiverCredits),
        'weeklyDiamondsReceived_${RankingHelper.mondayWeeklySuffix}': FieldValue.increment(perReceiverCredits),
        'monthlyDiamondsReceived_${RankingHelper.monthlySuffix}': FieldValue.increment(perReceiverCredits),
        'totalDiamondsReceived': FieldValue.increment(perReceiverCredits),
      });

      // Write to gift_transactions collection ONLY if there is an animation URL to render AND it is NOT a combo hit.
      // Combo hits display the live combo count banner directly and shouldn't pollute the full-screen animation queue.
      if (!isComboHit && ((giftSvgaUrl != null && giftSvgaUrl.isNotEmpty) || giftPngUrl.isNotEmpty)) {
        final txRef = _firestore.collection(_transactionsCollection).doc();
        batch.set(txRef, {
          'giftId': giftId,
          'giftName': cleanName,
          'giftPngUrl': giftPngUrl,
          'giftSvgaUrl': giftSvgaUrl,
          'senderId': senderId,
          'senderName': senderName,
          'senderImageUrl': senderImageUrl,
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverImageUrl': receiverImageUrl,
          'roomId': roomId,
          'credits': giftCredits,
          'quantity': safeQuantity,
          'count': safeQuantity,
          'totalCredits': perReceiverCredits,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    // Update room total revenue and contributors in same batch if roomId provided
    if (roomId.isNotEmpty && roomId != '0') {
      batch.update(_firestore.collection('audio_rooms_v2').doc(roomId), {
        'totalRevenue': FieldValue.increment(totalCredits),
        'dailyRevenue_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
        'weeklyRevenue_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
        'weeklyRevenue_${RankingHelper.mondayWeeklySuffix}': FieldValue.increment(totalCredits),
        'monthlyRevenue_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
        'dailyRevenue': FieldValue.increment(totalCredits),
        'weeklyRevenue': FieldValue.increment(totalCredits),
        'monthlyRevenue': FieldValue.increment(totalCredits),
        'contributors.$senderId.userId': senderId,
        'contributors.$senderId.userName': senderName,
        'contributors.$senderId.userAvatar': senderImageUrl,
        'contributors.$senderId.totalContribution': FieldValue.increment(totalCredits),
        'contributors.$senderId.dailyContribution_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
        'contributors.$senderId.weeklyContribution_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
        'contributors.$senderId.weeklyContribution_${RankingHelper.mondayWeeklySuffix}': FieldValue.increment(totalCredits),
        'contributors.$senderId.monthlyContribution_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
        'contributors.$senderId.dailyContribution': FieldValue.increment(totalCredits),
        'contributors.$senderId.weeklyContribution': FieldValue.increment(totalCredits),
        'contributors.$senderId.monthlyContribution': FieldValue.increment(totalCredits),
        'contributors.$senderId.lastContributionAt': FieldValue.serverTimestamp(),
      });
    }

    // Commit ALL core operations in ONE SINGLE ATOMIC NETWORK REQUEST!
    await batch.commit();

    // 3. SECONDARY TRACKING RUNS ASYNCHRONOUSLY IN BACKGROUND MICROTASK!
    // Skip intermediate secondary tasks on 50ms rapid combo taps to prevent network queue saturation
    if (!isComboHit) {
      unawaited(Future.microtask(() async {
      try {
        // Sender level update
        try {
          await WalletService().updateUserLevel(
            userId: senderId,
            levelType: 'sending',
            progressGained: totalCredits,
          );
        } catch (_) {}

        // Sender family points
        final senderDoc = await _firestore.collection('Users').doc(senderId).get();
        final senderData = senderDoc.data();
        final String? senderFamilyId = senderData?['familyId'];
        if (senderFamilyId != null && senderFamilyId.isNotEmpty) {
          try {
            await _updateFamilyPointsAndLevel(senderFamilyId, totalCredits);
          } catch (_) {}
        }

        // Lucky Gift calculation
        Map<String, dynamic>? giftData = _giftDataCache[giftId];
        if (giftData == null && giftId.isNotEmpty) {
          try {
            final directDoc = await _firestore.collection('gift').doc(giftId).get();
            if (directDoc.exists && directDoc.data() != null) {
              giftData = directDoc.data();
              _giftDataCache[giftId] = giftData!;
            }
          } catch (_) {}
        }

        if (giftData != null) {
          final String cat = (giftData['category'] ?? '').toString().toLowerCase();
          final bool isLuckyGift = cat == 'lucky' || giftName.toLowerCase().contains('lucky') || giftData.containsKey('minMultiplier');
          if (isLuckyGift) {
            final int minMult = (giftData['minMultiplier'] ?? giftData['minMult'] ?? 2) as int;
            final int maxMult = (giftData['maxMultiplier'] ?? giftData['maxMult'] ?? 500) as int;
            final int winRate = (giftData['diamondCountPercent'] ?? giftData['winRate'] ?? 80) as int;
            final Random rand = Random();
            if (rand.nextInt(100) < winRate) {
              int chosenMultiplier = (minMult + rand.nextInt(maxMult - minMult + 1)).clamp(minMult, maxMult);
              final int wonDiamonds = perReceiverCredits * chosenMultiplier;
              await _firestore.collection('Users').doc(senderId).update({'diamonds': FieldValue.increment(wonDiamonds)});
              if (roomId.isNotEmpty && roomId != '0') {
                await _firestore.collection('audio_rooms_v2').doc(roomId).collection('lucky_wins').add({
                  'senderId': senderId,
                  'senderName': senderName,
                  'senderAvatar': senderImageUrl,
                  'giftName': cleanName,
                  'multiplier': chosenMultiplier,
                  'wonDiamonds': wonDiamonds,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }

        // Secondary receiver updates: levels, intimacy, exposure checks, permanent logs
        for (var receiver in receivers) {
          final receiverId = receiver['id'];
          final receiverName = receiver['name'];
          final receiverImageUrl = receiver['imageUrl'];

          try {
            await WalletService().updateUserLevel(userId: receiverId, levelType: 'receiving', progressGained: perReceiverCredits);
          } catch (_) {}

          try {
            await RelationshipService().updateRelationshipProgress(senderId, receiverId, perReceiverCredits);
          } catch (_) {}

          try {
            await GrabTheTopService.instance.checkAndTriggerGrabTheTop(
              giftId: giftId,
              giftName: cleanName,
              giftPngUrl: giftPngUrl,
              quantity: safeQuantity,
              senderId: senderId,
              senderName: senderName,
              senderImageUrl: senderImageUrl,
              receiverId: receiverId,
              receiverName: receiverName,
              receiverImageUrl: receiverImageUrl,
              roomId: roomId,
            );

            await TopExposureService.instance.checkAndTriggerTopExposure(
              giftId: giftId,
              giftName: cleanName,
              giftPngUrl: giftPngUrl,
              giftCredits: giftCredits,
              quantity: safeQuantity,
              totalDiamonds: perReceiverCredits,
              senderId: senderId,
              senderName: senderName,
              senderImageUrl: senderImageUrl,
              receiverId: receiverId,
              receiverName: receiverName,
              receiverImageUrl: receiverImageUrl,
              roomId: roomId,
            );
          } catch (_) {}

          try {
            await _firestore.collection('user_received_gifts').add({
              'giftId': giftId,
              'giftName': cleanName,
              'giftPngUrl': giftPngUrl,
              'giftSvgaUrl': giftSvgaUrl,
              'senderId': senderId,
              'senderName': senderName,
              'senderImageUrl': senderImageUrl,
              'receiverId': receiverId,
              'receiverName': receiverName,
              'receiverImageUrl': receiverImageUrl,
              'roomId': roomId,
              'credits': giftCredits,
              'quantity': safeQuantity,
              'count': safeQuantity,
              'totalCredits': perReceiverCredits,
              'timestamp': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      } catch (err) {
        debugPrint('⚠️ Secondary tracking background task error: $err');
      }
    }));
    }
  }

  /// Get gift transactions for a room as a stream
  Stream<List<GiftTransaction>> getGiftTransactions(String roomId) {
    return _firestore
        .collection(_transactionsCollection)
        .where('roomId', isEqualTo: roomId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return GiftTransaction.fromJson(data);
      }).toList();
    });
  }

  /// Update family points and automatically level up if threshold is reached
  Future<void> _updateFamilyPointsAndLevel(String familyId, int pointsToAdd) async {
    try {
      final docRef = _firestore.collection('families').doc(familyId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final int currentPoints = data['points'] ?? 0;
        final int currentLevel = data['level'] ?? 1;
        final int newPoints = currentPoints + pointsToAdd;

        final configDocRef = _firestore
            .collection('system_configs')
            .doc('family_settings');
        final configSnapshot = await transaction.get(configDocRef);

        List<int> requirements = [1000, 5000, 10000, 20000, 50000];
        if (configSnapshot.exists && configSnapshot.data() != null) {
          final configData = configSnapshot.data()!;
          if (configData['levelRequirements'] != null) {
            requirements = List<int>.from(configData['levelRequirements']);
          }
        }

        int newLevel = 1;
        for (int i = 0; i < requirements.length; i++) {
          if (newPoints >= requirements[i]) {
            newLevel = i + 2; // Level 2 corresponds to requirement index 0
          } else {
            break;
          }
        }

        final Map<String, dynamic> updateData = {
          'points': newPoints,
        };

        if (newLevel > currentLevel) {
          updateData['level'] = newLevel;
        }

        transaction.update(docRef, updateData);
      });
    } catch (e) {
      debugPrint('Error updating family points and level: $e');
    }
  }
}
