import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/services/global_settings_service.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a random 8-character alphanumeric string
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Gets the existing referral code or creates a new one if it doesn't exist.
  Future<String> getOrCreateReferralCode(String userId) async {
    try {
      final docRef = _firestore.collection('Users').doc(userId);
      final docSnap = await docRef.get();
      
      if (!docSnap.exists) {
        throw Exception('User not found');
      }

      final data = docSnap.data() as Map<String, dynamic>;
      final String? existingCode = data['referralCode'];

      if (existingCode != null && existingCode.isNotEmpty) {
        return existingCode;
      }

      // Generate a new code
      String newCode = '';
      bool isUnique = false;
      
      // Ensure uniqueness
      while (!isUnique) {
        newCode = _generateRandomCode();
        final querySnap = await _firestore
            .collection('Users')
            .where('referralCode', isEqualTo: newCode)
            .limit(1)
            .get();
        if (querySnap.docs.isEmpty) {
          isUnique = true;
        }
      }

      // Save to user profile
      await docRef.update({'referralCode': newCode});
      return newCode;
    } catch (e) {
      debugPrint('Error getting or creating referral code: $e');
      rethrow;
    }
  }

  /// Submits a referral code. 
  /// Throws an Exception if invalid (e.g. own code, already referred, or invalid code).
  Future<void> submitReferralCode(String currentUserId, String code) async {
    try {
      final currentUserRef = _firestore.collection('Users').doc(currentUserId);
      final currentUserSnap = await currentUserRef.get();
      
      if (!currentUserSnap.exists) {
        throw Exception('Current user not found.');
      }
      
      final currentUserData = currentUserSnap.data() as Map<String, dynamic>;
      
      // Validation 1: User already submitted a code
      if (currentUserData['referredBy'] != null && currentUserData['referredBy'].toString().isNotEmpty) {
        throw Exception('You have already submitted a referral code.');
      }

      // Validation 2: Cannot use own code
      if (currentUserData['referralCode'] == code) {
        throw Exception('You cannot use your own referral code.');
      }

      // Validation 3: Check if the code belongs to a valid user
      final referrerQuery = await _firestore
          .collection('Users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (referrerQuery.docs.isEmpty) {
        throw Exception('Invalid referral code.');
      }

      final referrerDoc = referrerQuery.docs.first;

      // Determine the reward amount from GlobalSettingsService
      int rewardDiamonds = 100; // Default
      if (Get.isRegistered<GlobalSettingsService>()) {
        rewardDiamonds = Get.find<GlobalSettingsService>().invitationRewardDiamonds.value;
      }

      // Perform a batch write to ensure atomic update
      final batch = _firestore.batch();

      // Update Current User
      batch.update(currentUserRef, {
        'referredBy': code,
        'diamonds': FieldValue.increment(rewardDiamonds),
        'totalDiamonds': FieldValue.increment(rewardDiamonds),
      });

      // Update Referrer
      batch.update(referrerDoc.reference, {
        'diamonds': FieldValue.increment(rewardDiamonds),
        'totalDiamonds': FieldValue.increment(rewardDiamonds),
        'referralCount': FieldValue.increment(1),
      });

      await batch.commit();

    } catch (e) {
      debugPrint('Error submitting referral code: $e');
      rethrow;
    }
  }
}
