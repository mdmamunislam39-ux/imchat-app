import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/gift.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:chat_messenger/services/wallet_service.dart';

/// Service for managing gifts in Firebase
class GiftService {
  static const String _giftsCollection = 'gift';
  static const String _transactionsCollection = 'gift_transactions';

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
  }) async {
    String? pngUrl;
    String? svgaUrl;

    if (!skipFileUpload) {
      if (pngFile != null) {
        final ref = _storage.ref().child('gifts/png/${_uuid.v4()}.png');
        await ref.putFile(pngFile);
        pngUrl = await ref.getDownloadURL();
      }
      if (svgaFile != null) {
        final ref = _storage.ref().child('gifts/svga/${_uuid.v4()}.svga');
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
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'category': category,
      'credits': credits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (pngFile != null) {
      final ref = _storage.ref().child('gifts/png/${_uuid.v4()}.png');
      await ref.putFile(pngFile);
      updates['pngUrl'] = await ref.getDownloadURL();
    }
    
    if (svgaFile != null) {
      final ref = _storage.ref().child('gifts/svga/${_uuid.v4()}.svga');
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
  }) async {
    final int safeQuantity = quantity > 0 ? quantity : 1;
    final int perReceiverCredits = giftCredits * safeQuantity;
    final int totalCredits = perReceiverCredits * receivers.length;
    final String cleanName = _cleanGiftName(giftName);

    // Deduct from sender and update tracking
    final senderWallet = await _firestore.collection('Users').doc(senderId).get();
    final senderDiamonds = senderWallet.data()?['diamonds'] ?? 0;
    if (senderDiamonds < totalCredits) throw Exception('Insufficient diamonds');

    await _firestore.collection('Users').doc(senderId).update({
      'diamonds': FieldValue.increment(-totalCredits),
      'dailyDiamondsSent_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
      'weeklyDiamondsSent_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
      'monthlyDiamondsSent_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
      'totalDiamondsSent': FieldValue.increment(totalCredits),
    });

    // Update sender level (Sending progress)
    try {
      await WalletService().updateUserLevel(
        userId: senderId,
        levelType: 'sending',
        progressGained: totalCredits,
      );
    } catch (e) {
      debugPrint('Failed to update sender level: $e');
    }

    // Increment sender's family points if they belong to a family
    final senderData = senderWallet.data();
    final String? senderFamilyId = senderData?['familyId'];
    if (senderFamilyId != null && senderFamilyId.isNotEmpty) {
      await _updateFamilyPointsAndLevel(senderFamilyId, totalCredits);
    }

    // Add to receivers
    for (var receiver in receivers) {
      try {
        final receiverId = receiver['id'];
        final receiverName = receiver['name'];
        final receiverImageUrl = receiver['imageUrl'];

        final receiverDoc = await _firestore.collection('Users').doc(receiverId).get();
        if (!receiverDoc.exists) continue;
        final receiverData = receiverDoc.data();
        final String? receiverFamilyId = receiverData?['familyId'];

        await _firestore.collection('Users').doc(receiverId).update({
          'beans': FieldValue.increment(perReceiverCredits),
          'dailyDiamondsReceived_${RankingHelper.dailySuffix}': FieldValue.increment(perReceiverCredits),
          'weeklyDiamondsReceived_${RankingHelper.weeklySuffix}': FieldValue.increment(perReceiverCredits),
          'weeklyDiamondsReceived_${RankingHelper.mondayWeeklySuffix}': FieldValue.increment(perReceiverCredits),
          'monthlyDiamondsReceived_${RankingHelper.monthlySuffix}': FieldValue.increment(perReceiverCredits),
          'totalDiamondsReceived': FieldValue.increment(perReceiverCredits),
        });

        // Update receiver level (Receiving progress)
        try {
          await WalletService().updateUserLevel(
            userId: receiverId,
            levelType: 'receiving',
            progressGained: perReceiverCredits,
          );
        } catch (e) {
          debugPrint('Failed to update receiver level: $e');
        }

        // Increment receiver's family points if they belong to a family
        if (receiverFamilyId != null && receiverFamilyId.isNotEmpty) {
          await _updateFamilyPointsAndLevel(receiverFamilyId, perReceiverCredits);
        }

        // If receiver belongs to an Agency as a host, update real-time host performance & agency commission
        final String? receiverAgencyId = receiverData?['agencyId'];
        if (receiverAgencyId != null && receiverAgencyId.isNotEmpty) {
          try {
            final hostQuery = await _firestore
                .collection('hosts')
                .where('userId', isEqualTo: receiverId)
                .where('isActive', isEqualTo: true)
                .limit(1)
                .get();

            if (hostQuery.docs.isNotEmpty) {
              final hostDoc = hostQuery.docs.first;
              final double commission = perReceiverCredits * 0.10; // 10% agency commission

              await _firestore.collection('hosts').doc(hostDoc.id).update({
                'performance.totalDiamonds': FieldValue.increment(perReceiverCredits),
                'performance.totalGiftsReceived': FieldValue.increment(safeQuantity),
                'performance.totalEarnings': FieldValue.increment(perReceiverCredits),
                'performance.lastUpdated': FieldValue.serverTimestamp(),
              });

              await _firestore.collection('agencies').doc(receiverAgencyId).update({
                'totalCommissionEarned': FieldValue.increment(commission),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              await _firestore.collection('host_earnings').add({
                'hostId': hostDoc.id,
                'agencyId': receiverAgencyId,
                'diamondsEarned': perReceiverCredits,
                'commissionAmount': commission,
                'earningDate': FieldValue.serverTimestamp(),
                'period': RankingHelper.mondayWeeklySuffix,
                'description': 'Received gift: $cleanName x$safeQuantity',
              });
            }
          } catch (agencyErr) {
            debugPrint('⚠️ Failed to update agency/host earnings: $agencyErr');
          }
        }

        // Log transaction
        await _firestore.collection(_transactionsCollection).add({
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

        // Permanently archive for Gift Wall
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
      } catch (e) {
        debugPrint('Error processing receiver: $e');
      }
    }

    // Update room total revenue and contributors if roomId is provided
    if (roomId.isNotEmpty && roomId != '0') {
      try {
        await _firestore.collection('audio_rooms_v2').doc(roomId).update({
          'totalRevenue': FieldValue.increment(totalCredits),
          'dailyRevenue_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
          'weeklyRevenue_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
          'monthlyRevenue_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
          'contributors.$senderId.userId': senderId,
          'contributors.$senderId.userName': senderName,
          'contributors.$senderId.userAvatar': senderImageUrl,
          'contributors.$senderId.totalContribution': FieldValue.increment(totalCredits),
          'contributors.$senderId.dailyContribution_${RankingHelper.dailySuffix}': FieldValue.increment(totalCredits),
          'contributors.$senderId.weeklyContribution_${RankingHelper.weeklySuffix}': FieldValue.increment(totalCredits),
          'contributors.$senderId.monthlyContribution_${RankingHelper.monthlySuffix}': FieldValue.increment(totalCredits),
          'contributors.$senderId.lastContributionAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to update room revenue: $e');
      }
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
