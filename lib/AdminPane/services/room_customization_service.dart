import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/custom_room_id_model.dart';
import '../models/custom_room_id_history_model.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

class RoomCustomizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'premium_room_ids';
  static const String _roomsCollection = 'audio_rooms_v2';
  static const String _historyCollection = 'custom_room_id_history';

  // Get stream of all custom room IDs
  static Stream<List<CustomRoomIdModel>> getCustomRoomIdsStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('assignedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CustomRoomIdModel.fromFirestore(doc)).toList();
    });
  }

  // Get stream of custom room ID history
  static Stream<List<CustomRoomIdHistoryModel>> getCustomRoomIdHistoryStream() {
    return _firestore
        .collection(_historyCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CustomRoomIdHistoryModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  // Search room by original ID or Custom Short ID
  static Future<Map<String, dynamic>?> searchRoomByOriginalId(String searchId) async {
    try {
      // 1. First, check if it's a Custom Short ID by looking up premium_room_ids
      final customIdQuery = await _firestore
          .collection(_collectionName)
          .where('customId', isEqualTo: searchId)
          .limit(1)
          .get();

      String targetRoomId = searchId;
      if (customIdQuery.docs.isNotEmpty) {
        // If it's a custom ID, the document ID of premium_room_ids IS the original room ID
        targetRoomId = customIdQuery.docs.first.id;
      }

      // 2. Now search the AudioRoomsV2 collection by the resolved document ID
      final doc = await _firestore.collection(_roomsCollection).doc(targetRoomId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'id': doc.id,
          'roomId': doc.id,
          'name': data['roomName'] ?? data['name'] ?? 'Unknown Room',
          'imageUrl': data['roomImageUrl'] ?? data['imageUrl'] ?? '',
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error searching room: $e');
      return null;
    }
  }

  static void _addHistoryLog(
    WriteBatch batch, {
    required String roomId,
    required String currentOwnerId,
    required String customRoomId,
    required RoomIdHistoryAction action,
    String? notes,
  }) {
    final adminId = AuthController.instance.currentUser.userId;
    final historyRef = _firestore.collection(_historyCollection).doc();
    
    final historyModel = CustomRoomIdHistoryModel(
      id: historyRef.id,
      roomId: roomId,
      currentOwnerId: currentOwnerId,
      customRoomId: customRoomId,
      action: action,
      actionByAdminId: adminId,
      timestamp: DateTime.now(),
      notes: notes,
    );
    
    batch.set(historyRef, historyModel.toMap());
  }

  // Assign custom ID
  static Future<void> assignCustomRoomId(CustomRoomIdModel customRoomId) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Check if this custom ID is already taken and active
      final existingSnapshot = await _firestore
          .collection(_collectionName)
          .where('customId', isEqualTo: customRoomId.customRoomId)
          .where('isActive', isEqualTo: true)
          .get();
          
      if (existingSnapshot.docs.isNotEmpty) {
        throw Exception('This Custom ID is already assigned to another active room.');
      }

      // 2. Set doc in premium_room_ids using the original roomId as the Document ID (Expected by User App)
      final newDocRef = _firestore.collection(_collectionName).doc(customRoomId.roomId);
      batch.set(newDocRef, customRoomId.toFirestore());

      // 3. Mark the room to note it has a custom ID (but DO NOT overwrite its core roomId field!)
      final roomRef = _firestore.collection(_roomsCollection).doc(customRoomId.roomId);
      batch.update(roomRef, {
        'hasCustomId': true,
        'customIdExpiresAt': Timestamp.fromDate(customRoomId.expiresAt),
      });

      // 4. Add History Log
      _addHistoryLog(
        batch,
        roomId: customRoomId.roomId,
        currentOwnerId: '',
        customRoomId: customRoomId.customRoomId,
        action: RoomIdHistoryAction.assign,
        notes: 'Assigned ID: ${customRoomId.customRoomId}',
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error assigning custom room ID: $e');
      rethrow;
    }
  }

  // Update existing custom ID assignment (e.g. extend duration, change ID)
  static Future<void> updateCustomRoomId(String docId, DateTime newExpiresAt, bool isActive, {String? newCustomId}) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(docId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final roomId = data['roomId'];
      final currentOwnerId = data['currentOwnerId'] ?? '';
      final oldCustomId = data['customId'] ?? data['customRoomId'] ?? '';
      
      if (newCustomId != null && newCustomId.isNotEmpty && newCustomId != oldCustomId) {
        // Check uniqueness
        final existingSnapshot = await _firestore
            .collection(_collectionName)
            .where('customId', isEqualTo: newCustomId)
            .where('isActive', isEqualTo: true)
            .get();
            
        if (existingSnapshot.docs.isNotEmpty && existingSnapshot.docs.first.id != docId) {
          throw Exception('This Custom ID is already assigned to another active room.');
        }
      }

      final batch = _firestore.batch();
      
      // Update custom_room_ids doc
      final updateData = <String, dynamic>{
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'isActive': isActive,
      };
      
      String targetCustomId = oldCustomId;
      if (newCustomId != null && newCustomId.isNotEmpty) {
        updateData['customId'] = newCustomId;
        updateData['customRoomId'] = newCustomId; // fallback
        targetCustomId = newCustomId;
      }
      
      batch.update(docRef, updateData);

      // Update room doc
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      if (!isActive) {
        batch.update(roomRef, {
          'hasCustomId': false,
        });
      } else {
        batch.update(roomRef, {
          'customIdExpiresAt': Timestamp.fromDate(newExpiresAt),
        });
      }

      // Add History Log
      _addHistoryLog(
        batch,
        roomId: roomId,
        currentOwnerId: currentOwnerId,
        customRoomId: targetCustomId,
        action: RoomIdHistoryAction.update,
        notes: 'Updated active: $isActive, ${newCustomId != null ? 'Changed ID from $oldCustomId to $newCustomId' : 'Extended expiration'}',
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating custom room ID: $e');
      rethrow;
    }
  }

  // Delete custom ID assignment
  static Future<void> deleteCustomRoomId(String docId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(docId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final roomId = data['roomId'];
      final isActive = data['isActive'] ?? false;
      final currentOwnerId = data['currentOwnerId'] ?? '';
      final customRoomId = data['customId'] ?? data['customRoomId'] ?? '';

      final batch = _firestore.batch();
      batch.delete(docRef);

      if (isActive) {
        final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
        batch.update(roomRef, {
          'hasCustomId': false,
        });
      }

      // Add History Log
      _addHistoryLog(
        batch,
        roomId: roomId,
        currentOwnerId: currentOwnerId,
        customRoomId: customRoomId,
        action: RoomIdHistoryAction.remove,
        notes: 'Removed ID assignment',
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting custom room ID: $e');
      rethrow;
    }
  }
}
