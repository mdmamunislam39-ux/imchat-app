import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_messenger/api/official_team_api.dart';

/// Service for managing store items and user purchases
class StoreService {
  static const String _storeItemsCollection = 'market_items';
  static const String _userStoreItemsCollection = 'user_store_items';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Get all store items
  Future<List<Map<String, dynamic>>> getAllStoreItems() async {
    try {
      debugPrint('🏪 StoreService: Fetching all store items');
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      items.sort((a, b) {
        final starA = a['starRating'] as int? ?? 1;
        final starB = b['starRating'] as int? ?? 1;
        if (starA != starB) return starB.compareTo(starA);
        
        final dateA = a['createdAt'] as Timestamp?;
        final dateB = b['createdAt'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      debugPrint('🏪 StoreService: Retrieved ${items.length} store items');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store items: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store items: $e');
    }
  }

  /// Get store items by type
  Future<List<Map<String, dynamic>>> getStoreItemsByType(String type) async {
    try {
      debugPrint('🏪 StoreService: Fetching store items by type: $type');
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('type', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      items.sort((a, b) {
        final starA = a['starRating'] as int? ?? 1;
        final starB = b['starRating'] as int? ?? 1;
        if (starA != starB) return starB.compareTo(starA);

        final priceA = (a['diamondPrice'] as num?)?.toInt() ?? 0;
        final priceB = (b['diamondPrice'] as num?)?.toInt() ?? 0;
        return priceA.compareTo(priceB);
      });

      debugPrint(
          '🏪 StoreService: Retrieved ${items.length} items of type $type');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store items by type: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store items by type: $e');
    }
  }

  /// Get store items by type (Real-time stream)
  /// Queries BOTH 'market_items' and 'store_items' collections and merges results.
  /// This ensures items from both old (store_items) and new (market_items) admin paths appear.
  Stream<List<Map<String, dynamic>>> getStoreItemsByTypeStream(String type) {
    debugPrint('🏪 StoreService: Listening to $type items from both collections');

    // Keep latest snapshot from each collection
    List<Map<String, dynamic>> marketItems = [];
    List<Map<String, dynamic>> legacyItems = [];

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot>? marketSub;
    StreamSubscription<QuerySnapshot>? legacySub;

    List<Map<String, dynamic>> mergeAndSort() {
      // Combine and deduplicate by doc id
      final seen = <String>{};
      final combined = <Map<String, dynamic>>[];
      for (final item in <Map<String, dynamic>>[...marketItems, ...legacyItems]) {
        final id = item['id'] as String? ?? '';
        if (id.isNotEmpty && seen.add(id)) {
          combined.add(item);
        }
      }
      combined.sort((a, b) {
        final starA = a['starRating'] as int? ?? 1;
        final starB = b['starRating'] as int? ?? 1;
        if (starA != starB) return starB.compareTo(starA);
        final priceA = (a['diamondPrice'] as num?)?.toInt() ?? 0;
        final priceB = (b['diamondPrice'] as num?)?.toInt() ?? 0;
        return priceA.compareTo(priceB);
      });
      debugPrint('🏪 StoreService: $type merged → ${combined.length} items');
      return combined;
    }

    List<Map<String, dynamic>> parseSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        // Listen to market_items
        marketSub = _firestore
            .collection('market_items')
            .where('type', isEqualTo: type)
            .snapshots()
            .listen(
          (snap) {
            marketItems = parseSnapshot(snap);
            if (!controller.isClosed) controller.add(mergeAndSort());
          },
          onError: (e) => debugPrint('⚠️ market_items stream error: $e'),
        );

        // Listen to store_items (legacy)
        legacySub = _firestore
            .collection('store_items')
            .where('type', isEqualTo: type)
            .snapshots()
            .listen(
          (snap) {
            legacyItems = parseSnapshot(snap);
            if (!controller.isClosed) controller.add(mergeAndSort());
          },
          onError: (e) => debugPrint('⚠️ store_items stream error: $e'),
        );
      },
      onCancel: () {
        marketSub?.cancel();
        legacySub?.cancel();
      },
    );

    return controller.stream;
  }


  /// Get store items by category
  Future<List<Map<String, dynamic>>> getStoreItemsByCategory(
      String category) async {
    try {
      debugPrint(
          '🏪 StoreService: Fetching store items by category: $category');
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      items.sort((a, b) {
        final starA = a['starRating'] as int? ?? 1;
        final starB = b['starRating'] as int? ?? 1;
        if (starA != starB) return starB.compareTo(starA);

        final priceA = (a['diamondPrice'] as num?)?.toInt() ?? 0;
        final priceB = (b['diamondPrice'] as num?)?.toInt() ?? 0;
        return priceA.compareTo(priceB);
      });

      debugPrint(
          '🏪 StoreService: Retrieved ${items.length} items in category $category');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store items by category: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store items by category: $e');
    }
  }

  /// Get user's owned store items
  Future<List<Map<String, dynamic>>> getUserStoreItems(String userId) async {
    try {
      debugPrint('🏪 StoreService: Fetching user store items for $userId');
      final snapshot = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('assignedAt', descending: true)
          .get();

      final rawItems = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final items = _deduplicateItems(rawItems);

      debugPrint('🏪 StoreService: Retrieved ${items.length} user store items');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching user store items: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch user store items: $e');
    }
  }

  /// Get user's owned store items (Real-time stream)
  /// Uses only a single-field 'userId' filter to avoid needing a composite index.
  /// isActive is filtered client-side.
  Stream<List<Map<String, dynamic>>> getUserStoreItemsStream(String userId) {
    debugPrint('🏪 StoreService: Listening to user store items for user $userId');
    return _firestore
        .collection(_userStoreItemsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      // Filter inactive items client-side to avoid composite index requirement
      final rawItems = snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final items = _deduplicateItems(rawItems);
      // Sort by assignedAt descending
      items.sort((a, b) {
        final dateA = a['assignedAt'] as Timestamp?;
        final dateB = b['assignedAt'] as Timestamp?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
      debugPrint('🏪 StoreService: user store items stream → ${items.length} active items');
      return items;
    });
  }

  /// Get user's store items by type
  Future<List<Map<String, dynamic>>> getUserStoreItemsByType(
      String userId, String type) async {
    try {
      debugPrint('🏪 StoreService: Fetching user store items by type: $type');
      final snapshot = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('itemType', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .orderBy('assignedAt', descending: true)
          .get();

      final rawItems = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final items = _deduplicateItems(rawItems);

      debugPrint(
          '🏪 StoreService: Retrieved ${items.length} user items of type $type');
      return items;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching user store items by type: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch user store items by type: $e');
    }
  }

  /// Get user's owned store items of a specific type (Real-time stream)
  Stream<List<Map<String, dynamic>>> getUserStoreItemsByTypeStream(
      String userId, String type) {
    try {
      debugPrint('🏪 StoreService: Listening to user items of type $type for user $userId');
      return _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('itemType', isEqualTo: type)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final rawItems = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        return _deduplicateItems(rawItems);
      });
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error creating stream for user store items by type: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to create stream for user store items by type: $e');
    }
  }

  /// Check if user owns a specific store item
  Future<bool> userOwnsStoreItem(String userId, String storeItemId) async {
    try {
      debugPrint(
          '🏪 StoreService: Checking if user owns store item $storeItemId');
      final snapshot = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('storeItemId', isEqualTo: storeItemId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      final ownsItem = snapshot.docs.isNotEmpty;
      debugPrint('🏪 StoreService: User owns item: $ownsItem');
      return ownsItem;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error checking user ownership: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Assign store item to user (for admin use)
  Future<bool> assignStoreItemToUser({
    required String userId,
    required String storeItemId,
    required String assignedBy,
    int? expirationDays,
    Map<String, dynamic>? assetData,
  }) async {
    try {
      debugPrint(
          '🏪 StoreService: Assigning store item $storeItemId to user $userId');

      // Get store item details
      final storeItemDoc = await _firestore
          .collection(_storeItemsCollection)
          .doc(storeItemId)
          .get();

      Map<String, dynamic> storeItemData;
      if (storeItemDoc.exists) {
        storeItemData = storeItemDoc.data()!;
      } else if (assetData != null) {
        storeItemData = assetData;
      } else {
        final oldDoc = await _firestore
            .collection('store_items')
            .doc(storeItemId)
            .get();
        if (oldDoc.exists) {
          storeItemData = oldDoc.data()!;
        } else {
          storeItemData = {
            'name': 'Assigned Item',
            'type': 'avatarFrame',
          };
        }
      }

      final userStoreItemId = _uuid.v4();
      final userStoreItemData = {
        'id': userStoreItemId,
        'userId': userId,
        'storeItemId': storeItemId,
        'storeItemName': storeItemData['name'] ?? storeItemData['title'] ?? 'Item',
        'itemType': storeItemData['type'] ?? storeItemData['category'] ?? 'avatarFrame',
        'assignedAt': FieldValue.serverTimestamp(),
        'expiresAt': expirationDays != null
            ? Timestamp.fromDate(
                DateTime.now().add(Duration(days: expirationDays)))
            : null,
        'isActive': true,
        'assignedBy': assignedBy,
      };

      await _firestore
          .collection(_userStoreItemsCollection)
          .doc(userStoreItemId)
          .set(userStoreItemData);

      // Also ensure Users/{userId} customization array contains item ID
      final String itemType = storeItemData['type'] ?? storeItemData['category'] ?? '';
      String? fieldToUpdate;
      switch (itemType) {
        case 'entryEffect': fieldToUpdate = 'customization.ownedEntryEffects'; break;
        case 'avatarFrame':
        case 'frame': fieldToUpdate = 'customization.ownedFrames'; break;
        case 'roomTheme': fieldToUpdate = 'customization.ownedRoomThemes'; break;
        case 'backgroundTheme':
        case 'profileSkin': fieldToUpdate = 'customization.ownedBackgroundThemes'; break;
      }

      if (fieldToUpdate != null) {
        try {
          await _firestore.collection('Users').doc(userId).update({
            fieldToUpdate: FieldValue.arrayUnion([storeItemId]),
          });
        } catch (e) {
          debugPrint('⚠️ Error updating Users customization array: $e');
        }
      }

      // Send imChat Team Notification
      try {
        final userDoc = await _firestore.collection('Users').doc(userId).get();
        final deviceToken = userDoc.data()?['deviceToken'] ?? '';
        await OfficialTeamApi.sendAssetAssignmentNotice(
          receiverId: userId,
          receiverDeviceToken: deviceToken,
          assetName: storeItemData['name'] ?? 'Unknown Item',
          assetCategory: storeItemData['type'] ?? 'Store Item',
        );
      } catch (e) {
        debugPrint('⚠️ StoreService: Error sending assignment notification: $e');
      }

      debugPrint('🏪 StoreService: Successfully assigned store item to user');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error assigning store item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to assign store item: $e');
    }
  }

  /// Remove store item from user
  Future<bool> removeStoreItemFromUser({
    required String userId,
    required String storeItemId,
  }) async {
    try {
      debugPrint(
          '🏪 StoreService: Removing store item $storeItemId from user $userId');

      final snapshot = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('storeItemId', isEqualTo: storeItemId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('User store item not found');
      }

      // Deactivate the item
      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'isActive': false,
          'removedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('🏪 StoreService: Successfully removed store item from user');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error removing store item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to remove store item: $e');
    }
  }

  /// Get store item details
  Future<Map<String, dynamic>?> getStoreItemDetails(String storeItemId) async {
    try {
      debugPrint(
          '🏪 StoreService: Fetching store item details for $storeItemId');
      final doc = await _firestore
          .collection(_storeItemsCollection)
          .doc(storeItemId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('🏪 StoreService: Retrieved store item details');
        return {
          'id': doc.id,
          ...data,
        };
      }

      final oldDoc = await _firestore
          .collection('store_items')
          .doc(storeItemId)
          .get();

      if (oldDoc.exists) {
        final data = oldDoc.data()!;
        return {
          'id': oldDoc.id,
          ...data,
        };
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store item details: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store item details: $e');
    }
  }

  /// Get store categories
  Future<List<String>> getStoreCategories() async {
    try {
      debugPrint('🏪 StoreService: Fetching store categories');
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['category'] != null) {
          categories.add(data['category']);
        }
      }

      final categoryList = categories.toList()..sort();
      debugPrint(
          '🏪 StoreService: Retrieved ${categoryList.length} categories');
      return categoryList;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store categories: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store categories: $e');
    }
  }

  /// Get store item types
  Future<List<String>> getStoreItemTypes() async {
    try {
      debugPrint('🏪 StoreService: Fetching store item types');
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final types = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] != null) {
          types.add(data['type']);
        }
      }

      final typeList = types.toList()..sort();
      debugPrint('🏪 StoreService: Retrieved ${typeList.length} item types');
      return typeList;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error fetching store item types: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch store item types: $e');
    }
  }

  /// Search store items
  Future<List<Map<String, dynamic>>> searchStoreItems(String query) async {
    try {
      debugPrint('🏪 StoreService: Searching store items with query: $query');

      // Note: Firestore doesn't support full-text search natively
      // This is a simple implementation that searches in name and description
      final snapshot = await _firestore
          .collection(_storeItemsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final allItems = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      final filteredItems = allItems.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final description =
            (item['description'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) || description.contains(searchQuery);
      }).toList();

      debugPrint(
          '🏪 StoreService: Found ${filteredItems.length} items matching query');
      return filteredItems;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error searching store items: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to search store items: $e');
    }
  }

  /// Equip an item
  Future<bool> equipItem(String userId, String itemId, String itemType) async {
    try {
      debugPrint(
          '🏪 StoreService: Equipping item $itemId of type $itemType for user $userId');

      String fieldName;
      switch (itemType) {
        case 'badge':
          fieldName = 'customization.selectedBadgeId';
          break;
        case 'avatarFrame':
        case 'frame': // Handle potential type name variation
          fieldName = 'customization.selectedFrameId';
          break;
        case 'entryEffect':
          fieldName = 'customization.selectedEntryEffectId';
          break;
        case 'backgroundTheme':
        case 'profileSkin': // alias
          fieldName = 'customization.selectedBackgroundThemeId';
          break;
        case 'roomTheme':
          fieldName = 'customization.selectedRoomThemeId';
          break;
        case 'roomProfileBackground':
          fieldName = 'customization.selectedRoomProfileBackgroundId';
          break;
        case 'nameplate':
          fieldName = 'customization.selectedNameplateId';
          break;
        case 'micRefill':
          fieldName = 'customization.selectedMicRefillId';
          break;
        default:
          throw Exception('Unknown item type: $itemType');
      }

      await _firestore.collection('Users').doc(userId).update({
        fieldName: itemId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🏪 StoreService: Successfully equipped item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error equipping item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to equip item: $e');
    }
  }

  /// Unequip an item
  Future<bool> unequipItem(String userId, String itemType) async {
    try {
      debugPrint(
          '🏪 StoreService: Unequipping item of type $itemType for user $userId');

      String fieldName;
      switch (itemType) {
        case 'badge':
          fieldName = 'customization.selectedBadgeId';
          break;
        case 'avatarFrame':
        case 'frame':
          fieldName = 'customization.selectedFrameId';
          break;
        case 'entryEffect':
          fieldName = 'customization.selectedEntryEffectId';
          break;
        case 'backgroundTheme':
        case 'profileSkin': // alias
          fieldName = 'customization.selectedBackgroundThemeId';
          break;
        case 'roomTheme':
          fieldName = 'customization.selectedRoomThemeId';
          break;
        case 'roomProfileBackground':
          fieldName = 'customization.selectedRoomProfileBackgroundId';
          break;
        case 'nameplate':
          fieldName = 'customization.selectedNameplateId';
          break;
        case 'micRefill':
          fieldName = 'customization.selectedMicRefillId';
          break;
        default:
          throw Exception('Unknown item type: $itemType');
      }

      await _firestore.collection('Users').doc(userId).update({
        fieldName: FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🏪 StoreService: Successfully unequipped item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error unequipping item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to unequip item: $e');
    }
  }

  /// Helper to deduplicate items by storeItemId for legacy duplicates
  List<Map<String, dynamic>> _deduplicateItems(List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> deduplicated = {};
    for (var item in items) {
      final storeItemId = item['storeItemId'] as String?;
      if (storeItemId != null && storeItemId.isNotEmpty) {
        if (!deduplicated.containsKey(storeItemId)) {
          deduplicated[storeItemId] = item;
        } else {
          // Keep the one with the latest expiration date or permanent
          final currentExpiry = item['expiresAt'] as Timestamp?;
          final existingExpiry = deduplicated[storeItemId]!['expiresAt'] as Timestamp?;
          
          if (currentExpiry == null && existingExpiry != null) {
            deduplicated[storeItemId] = item; // Permanent beats temporary
          } else if (currentExpiry != null && existingExpiry != null) {
            if (currentExpiry.toDate().isAfter(existingExpiry.toDate())) {
              deduplicated[storeItemId] = item;
            }
          }
        }
      } else {
        final id = item['id'] ?? _uuid.v4();
        deduplicated[id] = item; // Fallback if no storeItemId
      }
    }
    final now = DateTime.now();
    return deduplicated.values.where((item) {
      final exp = item['expiresAt'] as Timestamp?;
      if (exp == null) return true;
      return exp.toDate().isAfter(now);
    }).toList();
  }
}