import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get family members
  Future<List<Map<String, dynamic>>> getFamilyMembers(String familyId) async {
    try {
      final familyRef = _firestore.collection('families').doc(familyId);
      final querySnapshot = await _firestore
          .collection('family_members')
          .where('family_id', isEqualTo: familyRef)
          .orderBy('contribution_flame', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting family members: $e');
      return [];
    }
  }

  Future<String> createFamily({
    required String name,
    required String description,
    required String logoUrl,
    required String creatorId,
    required String creatorName,
    required String creatorPhoto,
    required int requiredDiamonds,
  }) async {
    try {
      debugPrint('👨‍👩‍👧‍👦 Creating family: $name');

      // 1. Deduct diamonds as creation cost
      final userRef = _firestore.collection('Users').doc(creatorId);
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception('User not found');
      
      final diamonds = (userDoc.data()?['diamonds'] as num?)?.toInt() ?? 0;
      if (diamonds < requiredDiamonds) {
        throw Exception('Insufficient diamonds. Creation costs $requiredDiamonds diamonds.');
      }

      final batch = _firestore.batch();
      
      // Deduct diamonds from user
      batch.update(userRef, {
        'diamonds': FieldValue.increment(-requiredDiamonds),
      });

      // 2. Generate unique 6-digit family ID
      String newFamilyId = '';
      bool isUnique = false;
      final random = Random();
      while (!isUnique) {
        newFamilyId = (100000 + random.nextInt(900000)).toString();
        final doc = await _firestore.collection('families').doc(newFamilyId).get();
        if (!doc.exists) {
          isUnique = true;
        }
      }

      final familyRef = _firestore.collection('families').doc(newFamilyId);
      final familyId = newFamilyId;

      final familyData = {
        'family_id': familyId,
        'family_name': name,
        'family_bio': description,
        'cover_image': logoUrl,
        'owner_id': creatorId,
        'level': 'steel',
        'flame_points': 0,
        'member_count': 1,
        'created_at': FieldValue.serverTimestamp(),
      };

      batch.set(familyRef, familyData);

      // 3. Add creator to family_members
      final memberRef = _firestore.collection('family_members').doc();
      batch.set(memberRef, {
        'member_id': memberRef.id,
        'family_id': familyRef,
        'user_id': userRef,
        'role': 'owner',
        'contribution_flame': 0,
        'joined_at': FieldValue.serverTimestamp(),
      });

      // 4. Update creator user document
      batch.update(userRef, {
        'familyId': familyId,
        'familyName': name,
      });

      await batch.commit();
      debugPrint('✅ Family created successfully with ID: $familyId');
      return familyId;
    } catch (e) {
      debugPrint('❌ Error creating family: $e');
      rethrow;
    }
  }

  // Auto-migrate a single old family to 6-digit ID
  Future<void> migrateSingleFamily(String oldFamilyId) async {
    try {
      final doc = await _firestore.collection('families').doc(oldFamilyId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      
      // Generate unique 6-digit family ID
      String newFamilyId = '';
      bool isUnique = false;
      final random = Random();
      while (!isUnique) {
        newFamilyId = (100000 + random.nextInt(900000)).toString();
        final checkDoc = await _firestore.collection('families').doc(newFamilyId).get();
        if (!checkDoc.exists) {
          isUnique = true;
        }
      }

      data['familyId'] = newFamilyId;
      
      final batch = _firestore.batch();
      
      // 1. Create new family doc
      batch.set(_firestore.collection('families').doc(newFamilyId), data);
      
      // 2. Update all members
      final List<dynamic> memberIds = data['memberIds'] ?? [];
      for (var mId in memberIds) {
        batch.update(_firestore.collection('Users').doc(mId.toString()), {
          'familyId': newFamilyId
        });
      }
      
      // 3. Delete old family doc
      batch.delete(_firestore.collection('families').doc(oldFamilyId));
      
      await batch.commit();
      debugPrint('✅ Migrated family $oldFamilyId to $newFamilyId');
    } catch (e) {
      debugPrint('❌ Error migrating family: $e');
    }
  }



  // Get single family details
  Future<Map<String, dynamic>?> getFamily(String familyId) async {
    try {
      final doc = await _firestore.collection('families').doc(familyId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('❌ Error getting family: $e');
      return null;
    }
  }

  // Get all active families (leaderboard / list)
  Future<List<Map<String, dynamic>>> getAllFamilies() async {
    try {
      final querySnapshot = await _firestore
          .collection('families')
          .orderBy('points', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting all families: $e');
      return [];
    }
  }

  // Send request to join a Family
  Future<void> sendJoinRequest({
    required String familyId,
    required String familyName,
    required String userId,
    required String userName,
    required String userPhoto,
  }) async {
    try {
      debugPrint('👤 Sending join request from user $userId to family $familyId');

      // Check if already a member or pending request exists
      final existingQuery = await _firestore
          .collection('family_requests')
          .where('familyId', isEqualTo: familyId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('You already have a pending request for this family.');
      }

      final requestId = _firestore.collection('family_requests').doc().id;
      await _firestore.collection('family_requests').doc(requestId).set({
        'requestId': requestId,
        'familyId': familyId,
        'familyName': familyName,
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error sending join request: $e');
      rethrow;
    }
  }

  // Get pending join requests for a family (Leader view)
  Future<List<Map<String, dynamic>>> getFamilyRequests(String familyId) async {
    try {
      final querySnapshot = await _firestore
          .collection('family_requests')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'pending')
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting family requests: $e');
      return [];
    }
  }

  // Accept join request (Leader action)
  Future<void> acceptRequest({
    required String requestId,
    required String familyId,
    required String familyName,
    required String userId,
  }) async {
    try {
      debugPrint('✅ Accepting join request: $requestId');

      final batch = _firestore.batch();

      // 1. Update request status
      batch.update(_firestore.collection('family_requests').doc(requestId), {
        'status': 'approved',
      });

      // 2. Add user to family member IDs
      batch.update(_firestore.collection('families').doc(familyId), {
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // 3. Update user document family fields
      batch.update(_firestore.collection('Users').doc(userId), {
        'familyId': familyId,
        'familyName': familyName,
      });

      await batch.commit();
      debugPrint('✅ Request accepted, user $userId is now a family member');
    } catch (e) {
      debugPrint('❌ Error accepting request: $e');
      rethrow;
    }
  }

  // Reject join request (Leader action)
  Future<void> rejectRequest(String requestId) async {
    try {
      await _firestore.collection('family_requests').doc(requestId).update({
        'status': 'rejected',
      });
    } catch (e) {
      debugPrint('❌ Error rejecting request: $e');
      rethrow;
    }
  }

  // Leave a Family (Member action)
  Future<void> leaveFamily(String userId, String familyId) async {
    try {
      debugPrint('🚪 User $userId leaving family $familyId');

      final batch = _firestore.batch();

      // 1. Remove user from family member IDs list
      batch.update(_firestore.collection('families').doc(familyId), {
        'memberIds': FieldValue.arrayRemove([userId]),
      });

      // 2. Clear user document family fields
      batch.update(_firestore.collection('Users').doc(userId), {
        'familyId': null,
        'familyName': null,
      });

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error leaving family: $e');
      rethrow;
    }
  }

  // Kick family member (Leader action)
  Future<void> removeMember(String familyId, String userId) async {
    await leaveFamily(userId, familyId);
  }

  // Delete family completely (Leader action)
  Future<void> deleteFamily(String familyId) async {
    try {
      debugPrint('🗑️ Deleting family: $familyId');

      // Get all members of the family
      final membersQuery = await _firestore
          .collection('Users')
          .where('familyId', isEqualTo: familyId)
          .get();

      final batch = _firestore.batch();

      // Clear family fields for all members
      for (var doc in membersQuery.docs) {
        batch.update(doc.reference, {
          'familyId': null,
          'familyName': null,
        });
      }

      // Delete the family document
      batch.delete(_firestore.collection('families').doc(familyId));

      await batch.commit();
      debugPrint('✅ Family deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting family: $e');
      rethrow;
    }
  }

  // Update family details (Leader action)
  Future<void> updateFamilyDetails({
    required String familyId,
    required String newName,
    required String newDescription,
    required String newLogoUrl,
  }) async {
    try {
      debugPrint('📝 Updating family details for: $familyId');
      final batch = _firestore.batch();

      // 1. Update family document details
      batch.update(_firestore.collection('families').doc(familyId), {
        'family_name': newName,
        'family_bio': newDescription,
        'cover_image': newLogoUrl,
      });

      // 2. Query and update all member documents to reflect new name
      final membersQuery = await _firestore
          .collection('Users')
          .where('familyId', isEqualTo: familyId)
          .get();

      for (var doc in membersQuery.docs) {
        batch.update(doc.reference, {
          'familyName': newName,
        });
      }

      await batch.commit();
      debugPrint('✅ Family details updated and synced successfully');
    } catch (e) {
      debugPrint('❌ Error updating family details: $e');
      rethrow;
    }
  }
}
