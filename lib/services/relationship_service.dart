import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RelationshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> acceptInvitation(String invitationId, String userId) async {
    final invRef = _firestore.collection('relationshipInvitations').doc(invitationId);
    
    await _firestore.runTransaction((transaction) async {
      final invSnap = await transaction.get(invRef);
      if (!invSnap.exists) throw Exception('Invitation not found');
      
      final data = invSnap.data()!;
      final status = data['status'] ?? 'pending';
      if (status != 'pending') {
        throw Exception('This invitation is no longer pending.');
      }
      
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
        transaction.update(invRef, {'status': 'expired'});
        throw Exception('This invitation has expired.');
      }
      
      // Update invitation status
      transaction.update(invRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      
      // Create active relationship
      final senderRef = data['senderRef'] as DocumentReference;
      final receiverRef = data['receiverRef'] as DocumentReference;
      final type = data['relationshipType'] ?? 'friend';
      
      final relationshipId = _firestore.collection('relationships').doc().id;
      
      transaction.set(_firestore.collection('relationships').doc(relationshipId), {
        'relationshipId': relationshipId,
        'user1Ref': senderRef,
        'user2Ref': receiverRef,
        'relationshipType': type,
        'status': 'accepted',
        'intimacyPoints': 0,
        'couplePoints': 0,
        'friendshipPoints': 0,
        'currentLevel': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectInvitation(String invitationId) async {
    await _firestore.collection('relationshipInvitations').doc(invitationId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRelationshipProgress(String senderId, String receiverId, int pointsGained) async {
    try {
      final senderRef = _firestore.collection('Users').doc(senderId);
      final receiverRef = _firestore.collection('Users').doc(receiverId);

      // Query 1: user1Ref == senderRef && user2Ref == receiverRef
      final q1 = await _firestore
          .collection('relationships')
          .where('user1Ref', isEqualTo: senderRef)
          .where('user2Ref', isEqualTo: receiverRef)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Query 2: user1Ref == receiverRef && user2Ref == senderRef
      final q2 = await _firestore
          .collection('relationships')
          .where('user1Ref', isEqualTo: receiverRef)
          .where('user2Ref', isEqualTo: senderRef)
          .where('status', isEqualTo: 'accepted')
          .get();

      final docs = [...q1.docs, ...q2.docs];
      if (docs.isEmpty) return; // No active relationship between these two users

      final relDoc = docs.first;
      final relData = relDoc.data();
      final relId = relDoc.id;

      final type = relData['relationshipType']?.toString().toLowerCase() ?? 'friend';
      final int currentLevel = relData['currentLevel'] as int? ?? 1;
      
      // Determine points field
      final String pointsField = type == 'couple' ? 'couplePoints' : 'friendshipPoints';
      
      final int oldIntimacyPoints = relData['intimacyPoints'] as int? ?? 0;
      final int newIntimacyPoints = oldIntimacyPoints + pointsGained;

      // Determine new level using configurations
      int newLevel = currentLevel;
      
      try {
        final collectionName = type == 'couple' ? 'couple_levels' : 'relationshipLevels';
        final levelsSnap = await _firestore
            .collection(collectionName)
            .orderBy('level', descending: false)
            .get();
            
        if (levelsSnap.docs.isNotEmpty) {
          // Find the highest level achieved where newIntimacyPoints >= requiredPoints
          for (var doc in levelsSnap.docs) {
            final lvlData = doc.data();
            final int lvl = lvlData['level'] as int? ?? 1;
            final int reqPoints = lvlData['requiredPoints'] as int? ?? 0;
            if (newIntimacyPoints >= reqPoints) {
              if (lvl > newLevel) {
                newLevel = lvl;
              }
            }
          }
        } else {
          // Predefined fallback thresholds if collection relationshipLevels is empty
          final List<int> fallbackThresholds = [0, 100, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];
          for (int i = 0; i < fallbackThresholds.length; i++) {
            final int lvl = i + 1;
            final int reqPoints = fallbackThresholds[i];
            if (newIntimacyPoints >= reqPoints) {
              if (lvl > newLevel) {
                newLevel = lvl;
              }
            }
          }
        }
      } catch (lvlErr) {
        // Predefined fallback thresholds on error
        final List<int> fallbackThresholds = [0, 100, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];
        for (int i = 0; i < fallbackThresholds.length; i++) {
          final int lvl = i + 1;
          final int reqPoints = fallbackThresholds[i];
          if (newIntimacyPoints >= reqPoints) {
            if (lvl > newLevel) {
              newLevel = lvl;
            }
          }
        }
      }

      // Update Firestore
      await _firestore.collection('relationships').doc(relId).update({
        'intimacyPoints': FieldValue.increment(pointsGained),
        pointsField: FieldValue.increment(pointsGained),
        'currentLevel': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('Relationship $relId progress updated: +$pointsGained points, new level: $newLevel');

      if (newLevel > currentLevel) {
        final user1Ref = relData['user1Ref'];
        final user2Ref = relData['user2Ref'];
        
        String? user1Id;
        String? user2Id;
        
        if (user1Ref is DocumentReference) {
          user1Id = user1Ref.id;
        } else if (user1Ref is String) {
          user1Id = user1Ref;
        }
        
        if (user2Ref is DocumentReference) {
          user2Id = user2Ref.id;
        } else if (user2Ref is String) {
          user2Id = user2Ref;
        }
        
        if (user1Id != null && user2Id != null) {
          await _updateRelationshipLevelFrames(
            type: type,
            oldLevel: currentLevel,
            newLevel: newLevel,
            user1Id: user1Id,
            user2Id: user2Id,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating relationship progress: $e');
    }
  }

  Future<void> _updateRelationshipLevelFrames({
    required String type,
    required int oldLevel,
    required int newLevel,
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final collectionName = type == 'couple' ? 'couple_levels' : 'relationshipLevels';
      
      // 1. Fetch new level details
      final newLvlDoc = await _firestore.collection(collectionName).doc('level_$newLevel').get();
      if (!newLvlDoc.exists) return;
      final newLvlData = newLvlDoc.data()!;
      
      final String frameUrl = newLvlData['frameUrl'] as String? ?? '';

      // 2. Fetch old level details (to remove previous frames)
      String oldFrameUrl = '';
      if (oldLevel >= 1) {
        final oldLvlDoc = await _firestore.collection(collectionName).doc('level_$oldLevel').get();
        if (oldLvlDoc.exists) {
          final oldLvlData = oldLvlDoc.data()!;
          oldFrameUrl = oldLvlData['frameUrl'] as String? ?? '';
        }
      }

      final typeLabel = type == 'couple' ? 'Couple' : 'Friend';

      // 3. Update User 1 (initiator / sender)
      await _applyUserFrameReward(
        userId: user1Id,
        typeLabel: typeLabel,
        level: newLevel,
        oldLevel: oldLevel,
        newFrameUrl: frameUrl,
        oldFrameUrl: oldFrameUrl,
      );

      // 4. Update User 2 (partner / receiver)
      await _applyUserFrameReward(
        userId: user2Id,
        typeLabel: typeLabel,
        level: newLevel,
        oldLevel: oldLevel,
        newFrameUrl: frameUrl,
        oldFrameUrl: oldFrameUrl,
      );
    } catch (e) {
      debugPrint('Error updating relationship level frames: $e');
    }
  }

  Future<void> _applyUserFrameReward({
    required String userId,
    required String typeLabel,
    required int level,
    required int oldLevel,
    required String newFrameUrl,
    required String oldFrameUrl,
  }) async {
    try {
      final userRef = _firestore.collection('Users').doc(userId);
      final userDoc = await userRef.get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final custData = Map<String, dynamic>.from(userData['customization'] ?? {});

      final oldStoreItemId = '${typeLabel.toLowerCase()}_level_${oldLevel}_frame';
      final newStoreItemId = '${typeLabel.toLowerCase()}_level_${level}_frame';

      // Remove old frame from customization.ownedFrames list if present
      if (custData['ownedFrames'] != null) {
        final List<String> ownedFrames = List<String>.from(custData['ownedFrames']);
        if (oldFrameUrl.isNotEmpty) {
          ownedFrames.remove(oldFrameUrl);
        }
        // Also remove if the new frame url was somehow present (to avoid duplicates)
        if (newFrameUrl.isNotEmpty && !ownedFrames.contains(newFrameUrl)) {
          ownedFrames.add(newFrameUrl);
        }
        custData['ownedFrames'] = ownedFrames;
      } else {
        if (newFrameUrl.isNotEmpty) {
          custData['ownedFrames'] = [newFrameUrl];
        }
      }

      // Automatically equip the new frame!
      if (newFrameUrl.isNotEmpty) {
        custData['selectedFrameId'] = newStoreItemId;
      } else {
        // If no new frame, and they currently had the old one equipped, unequip it
        if (custData['selectedFrameId'] == oldStoreItemId) {
          custData['selectedFrameId'] = null;
        }
      }

      // Update User customization doc
      await userRef.update({'customization': custData});

      // Remove old frame from user_store_items
      if (oldFrameUrl.isNotEmpty) {
        final oldDocId = '${userId}_$oldStoreItemId';
        await _firestore.collection('user_store_items').doc(oldDocId).delete();
      }

      // Add new frame to user_store_items
      if (newFrameUrl.isNotEmpty) {
        final newDocId = '${userId}_$newStoreItemId';
        await _firestore.collection('user_store_items').doc(newDocId).set({
          'userId': userId,
          'storeItemId': newStoreItemId,
          'storeItemName': '$typeLabel Level $level Frame',
          'itemType': 'frame',
          'imageUrl': newFrameUrl,
          'assignedAt': FieldValue.serverTimestamp(),
          'expiresAt': null, // Permanent decoration
          'isActive': true,
        });
      }
    } catch (e) {
      debugPrint('Error applying user frame reward for $userId: $e');
    }
  }

  Future<void> removeRelationship(String relationshipId) async {
    try {
      final relRef = _firestore.collection('relationships').doc(relationshipId);
      final relSnap = await relRef.get();
      if (!relSnap.exists) return;

      final relData = relSnap.data()!;
      final type = relData['relationshipType']?.toString().toLowerCase() ?? 'friend';
      final int currentLevel = (relData['currentLevel'] as num?)?.toInt() ?? 1;

      // Extract user IDs to remove frame rewards if applicable
      final user1Ref = relData['user1Ref'];
      final user2Ref = relData['user2Ref'];
      String? user1Id;
      String? user2Id;
      if (user1Ref is DocumentReference) {
        user1Id = user1Ref.id;
      } else if (user1Ref is String) {
        user1Id = user1Ref;
      }
      if (user2Ref is DocumentReference) {
        user2Id = user2Ref.id;
      } else if (user2Ref is String) {
        user2Id = user2Ref;
      }

      // Delete the relationship document
      await relRef.delete();

      // Clean up frames if needed
      if (currentLevel >= 1) {
        final typeLabel = type == 'couple' ? 'couple' : 'friend';
        final storeItemId = '${typeLabel}_level_${currentLevel}_frame';
        if (user1Id != null) {
          await _removeUserFrameItem(user1Id, storeItemId);
        }
        if (user2Id != null) {
          await _removeUserFrameItem(user2Id, storeItemId);
        }
      }

      debugPrint('Relationship $relationshipId removed successfully.');
    } catch (e) {
      debugPrint('Error removing relationship $relationshipId: $e');
      rethrow;
    }
  }

  Future<void> _removeUserFrameItem(String userId, String storeItemId) async {
    try {
      final userRef = _firestore.collection('Users').doc(userId);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final custData = Map<String, dynamic>.from(userData['customization'] ?? {});
        if (custData['selectedFrameId'] == storeItemId) {
          custData['selectedFrameId'] = null;
          await userRef.update({'customization': custData});
        }
      }
      await _firestore.collection('user_store_items').doc('${userId}_$storeItemId').delete();
    } catch (e) {
      debugPrint('Error cleaning up user frame for $userId: $e');
    }
  }
}

