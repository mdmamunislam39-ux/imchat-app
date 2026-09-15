import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';
import 'package:chat_messenger/helpers/mic_refill_helper.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';

/// Service for managing store items and user purchases
class StoreService {
  /// Helper to check if an item is categorized as Official
  static bool _isOfficialCategory(dynamic category, dynamic isOfficial) {
    if (isOfficial == true) return true;
    if (category == null) return false;
    final catStr = category.toString().toLowerCase().trim();
    return catStr == 'official' ||
        catStr == 'officialstore' ||
        catStr == 'official_store';
  }

  static const String _storeItemsCollection = 'market_items';
  static const String _userStoreItemsCollection = 'user_store_items';

  // Static in-memory cache for fast lookup across screens & scroll rebuilds
  static final Map<String, Map<String, dynamic>> _itemDetailsCache = {};
  static final Map<String, Future<Map<String, dynamic>?>> _inFlightItemDetails =
      {};

  /// Synchronous cached details lookup
  static Map<String, dynamic>? getCachedItemDetails(String storeItemId) =>
      _itemDetailsCache[storeItemId];

  /// Cache invalidation/manual population
  static void setCachedStoreItemDetails(
      String storeItemId, Map<String, dynamic> data) {
    _itemDetailsCache[storeItemId] = data;
  }

  static void clearStoreItemDetailsCache() {
    _itemDetailsCache.clear();
    _inFlightItemDetails.clear();
  }

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
          .where((item) =>
              (item['type'] == 'seatDecor' || item['type'] == 'backgroundTheme') ||
              !_isOfficialCategory(item['category'], item['isOfficial']))
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
          .where((item) =>
              !_isOfficialCategory(item['category'], item['isOfficial']))
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
    debugPrint(
        '🏪 StoreService: Listening to $type items from both collections');

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
      for (final item in <Map<String, dynamic>>[
        ...marketItems,
        ...legacyItems
      ]) {
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

    List<Map<String, dynamic>> parseSnapshot(
        QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            if (data['isActive'] == false) return false;
            if (type != 'seatDecor' && type != 'backgroundTheme' && _isOfficialCategory(data['category'], data['isOfficial'])) {
              return false;
            }
            return true;
          })
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
    debugPrint(
        '🏪 StoreService: Listening to user store items for user $userId');
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
      debugPrint(
          '🏪 StoreService: user store items stream → ${items.length} active items');
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
      debugPrint(
          '🏪 StoreService: Listening to user items of type $type for user $userId');

      // Support type aliases so avatarFrame/frame, entryEffect/entry_effect both match
      List<String> types = [type];
      if (type == 'avatarFrame' || type == 'frame') {
        types = ['avatarFrame', 'frame'];
      } else if (type == 'entryEffect' || type == 'entry_effect') {
        types = ['entryEffect', 'entry_effect'];
      } else if (type == 'backgroundTheme' || type == 'profileSkin') {
        types = ['backgroundTheme', 'profileSkin'];
      }

      Query query = _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true);

      if (types.length == 1) {
        query = query.where('itemType', isEqualTo: types.first);
      } else {
        query = query.where('itemType', whereIn: types);
      }

      return query.snapshots().map((snapshot) {
        final rawItems = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>),
                })
            .toList();
        return _deduplicateItems(rawItems);
      });
    } catch (e, stackTrace) {
      debugPrint(
          '❌ StoreService: Error creating stream for user store items by type: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception(
          'Failed to create stream for user store items by type: $e');
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
        final oldDoc =
            await _firestore.collection('store_items').doc(storeItemId).get();
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
        'storeItemName':
            storeItemData['name'] ?? storeItemData['title'] ?? 'Item',
        'itemType':
            storeItemData['type'] ?? storeItemData['category'] ?? 'avatarFrame',
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
      final String itemType =
          storeItemData['type'] ?? storeItemData['category'] ?? '';
      String? fieldToUpdate;
      switch (itemType) {
        case 'entryEffect':
          fieldToUpdate = 'customization.ownedEntryEffects';
          break;
        case 'avatarFrame':
        case 'frame':
          fieldToUpdate = 'customization.ownedFrames';
          break;
        case 'roomTheme':
          fieldToUpdate = 'customization.ownedRoomThemes';
          break;
        case 'backgroundTheme':
        case 'profileSkin':
          fieldToUpdate = 'customization.ownedBackgroundThemes';
          break;
        case 'roomProfileBackground':
          fieldToUpdate = 'customization.ownedRoomProfileBackgrounds';
          break;
        case 'shortProfileTheme':
          fieldToUpdate = 'customization.ownedShortProfileThemes';
          break;
        case 'roomEntry':
          fieldToUpdate = 'customization.ownedRoomEntries';
          break;
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
        debugPrint(
            '⚠️ StoreService: Error sending assignment notification: $e');
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
    if (storeItemId.trim().isEmpty) return null;

    // 1. Check in-memory cache
    if (_itemDetailsCache.containsKey(storeItemId)) {
      return _itemDetailsCache[storeItemId];
    }

    // 2. Check in-flight requests to avoid concurrent duplicate network fetches
    if (_inFlightItemDetails.containsKey(storeItemId)) {
      return await _inFlightItemDetails[storeItemId];
    }

    final future = _fetchStoreItemDetails(storeItemId);
    _inFlightItemDetails[storeItemId] = future;
    try {
      final res = await future;
      if (res != null) {
        _itemDetailsCache[storeItemId] = res;
      }
      return res;
    } finally {
      _inFlightItemDetails.remove(storeItemId);
    }
  }

  Future<Map<String, dynamic>?> _fetchStoreItemDetails(
      String storeItemId) async {
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
        final result = {
          'id': doc.id,
          ...data,
        };
        _itemDetailsCache[storeItemId] = result;
        return result;
      }

      final oldDoc =
          await _firestore.collection('store_items').doc(storeItemId).get();

      if (oldDoc.exists) {
        final data = oldDoc.data()!;
        final result = {
          'id': oldDoc.id,
          ...data,
        };
        _itemDetailsCache[storeItemId] = result;
        return result;
      }

      // Fallback 0: Check official_items collection
      final officialDoc =
          await _firestore.collection('official_items').doc(storeItemId).get();

      if (officialDoc.exists) {
        final data = officialDoc.data()!;
        final result = {
          'id': officialDoc.id,
          ...data,
        };
        _itemDetailsCache[storeItemId] = result;
        return result;
      }

      // Fallback 1: Check user_store_items collection by storeItemId
      final userStoreSnap = await _firestore
          .collection(_userStoreItemsCollection)
          .where('storeItemId', isEqualTo: storeItemId)
          .limit(1)
          .get();
      if (userStoreSnap.docs.isNotEmpty) {
        final data = userStoreSnap.docs.first.data();
        final rawUrl = data['imageUrl'] ??
            data['fileUrl'] ??
            data['thumbnailUrl'] ??
            data['image'];
        final result = {
          ...data,
          'id': storeItemId,
          'name': data['storeItemName'] ?? data['name'] ?? 'Equipped Item',
        };
        if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
          final validRaw = rawUrl.toString().trim();
          result['fileUrl'] = validRaw;
          result['thumbnailUrl'] = validRaw;
          result['imageUrl'] = validRaw;
        }
        _itemDetailsCache[storeItemId] = result;
        return result;
      }

      // Fallback 2: Check VIP / SVIP configs
      if (storeItemId.startsWith('vip_') || storeItemId.startsWith('svip_')) {
        final isSvip = storeItemId.startsWith('svip_');
        final levelNum = storeItemId.replaceAll(RegExp(r'[^0-9]'), '');
        final col = isSvip ? 'svip_levels' : 'vip_levels';

        final candidateDocIds = isSvip
            ? ['svip$levelNum', 'level_$levelNum', 'svip_$levelNum', levelNum]
            : ['vip$levelNum', 'level_$levelNum', 'vip_$levelNum', levelNum];

        Map<String, dynamic>? data;
        for (final docId in candidateDocIds) {
          try {
            final cfgDoc = await _firestore
                .collection('config')
                .doc(col)
                .collection('levels')
                .doc(docId)
                .get();
            if (cfgDoc.exists && cfgDoc.data() != null) {
              data = cfgDoc.data()!;
              break;
            }
          } catch (_) {}
        }

        if (data != null) {
          String? extract(List<String> keys) {
            for (final k in keys) {
              final v = data![k];
              if (v != null && v.toString().trim().isNotEmpty) {
                return v.toString().trim();
              }
            }
            return null;
          }

          String? url;
          String type = 'avatarFrame';
          String typeName = 'Frame';
          if (storeItemId.contains('frame')) {
            url =
                extract(['frameMediaUrl', 'frameUrl', 'avatarFrame', 'frame']);
            type = 'avatarFrame';
            typeName = 'Frame';
          } else if (storeItemId.contains('badge')) {
            url = extract(['badgeMediaUrl', 'badgeUrl', 'badge']);
            type = 'badge';
            typeName = 'Badge';
          } else if (storeItemId.contains('entry')) {
            url = extract([
              'entryEffectMediaUrl',
              'entryEffectUrl',
              'entryTagUrl',
              'entryEffect'
            ]);
            type = 'entryEffect';
            typeName = 'Entry Effect';
          } else if (storeItemId.contains('skin') ||
              storeItemId.contains('theme')) {
            url = extract([
              'profileSkinMediaUrl',
              'profileSkinUrl',
              'profileCardUrl',
              'profileSkin',
              'backgroundTheme'
            ]);
            type = 'backgroundTheme';
            typeName = 'Profile Skin';
          } else if (storeItemId.contains('nameplate') ||
              storeItemId.contains('tag')) {
            url = extract([
              'nameplateMediaUrl',
              'nameplateUrl',
              'svipTagUrl',
              'nameplate',
              'svipTag'
            ]);
            type = 'nameplate';
            typeName = 'Nameplate';
          }

          final result = {
            ...data,
            'id': storeItemId,
            'name': '${isSvip ? "SVIP" : "VIP"} $levelNum $typeName',
            'itemType': type,
          };
          if (url != null && url.toString().trim().isNotEmpty) {
            final validUrl = url.toString().trim();
            result['fileUrl'] = validUrl;
            result['thumbnailUrl'] = validUrl;
            result['imageUrl'] = validUrl;
            result['badgeUrl'] = validUrl;
          }
          _itemDetailsCache[storeItemId] = result;
          return result;
        }
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
        case 'shortProfileTheme':
          fieldName = 'customization.selectedShortProfileThemeId';
          break;
        case 'roomEntry':
          fieldName = 'customization.selectedRoomEntryId';
          break;
        case 'nameplate':
          await _firestore.collection('Users').doc(userId).update({
            'customization.selectedNameplateIds':
                FieldValue.arrayUnion([itemId]),
            'customization.selectedNameplateId': itemId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('🏪 StoreService: Successfully equipped item');
          return true;
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

      if (itemType == 'avatarFrame' || itemType == 'frame') {
        final details = await getStoreItemDetails(itemId);
        final rawUrl = details?['fileUrl'] ??
            details?['thumbnailUrl'] ??
            details?['imageUrl'] ??
            details?['image'];
        final String? resolvedUrl = rawUrl?.toString();
        FrameHelper.setCachedUserFrame(
          userId: userId,
          frameId: itemId,
          frameUrl: resolvedUrl,
        );
        try {
          if (Get.isRegistered<AuthController>()) {
            final auth = AuthController.instance;
            if (auth.currentUser.userId == userId) {
              auth.currentFrameUrl.value = resolvedUrl ?? '';
              final cust =
                  auth.currentUser.customization ?? UserCustomization();
              cust.selectedFrameId = itemId;
              auth.currentUser.customization = cust;
            }
          }
        } catch (_) {}
        _syncFrameToActiveRoom(userId, itemId);
      }

      if (itemType == 'micRefill') {
        final details = await getStoreItemDetails(itemId);
        final rawUrl = details?['fileUrl'] ??
            details?['thumbnailUrl'] ??
            details?['imageUrl'] ??
            details?['image'];
        final String? resolvedUrl = rawUrl?.toString();
        MicRefillHelper.setCachedUserMicRefill(userId, resolvedUrl);
        try {
          if (Get.isRegistered<AuthController>()) {
            final auth = AuthController.instance;
            if (auth.currentUser.userId == userId) {
              final cust =
                  auth.currentUser.customization ?? UserCustomization();
              cust.selectedMicRefillId = itemId;
              auth.currentUser.customization = cust;
            }
          }
        } catch (_) {}
      }

      debugPrint('🏪 StoreService: Successfully equipped item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error equipping item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to equip item: $e');
    }
  }

  /// Unequip an item
  Future<bool> unequipItem(String userId, String itemType,
      [String? itemId]) async {
    try {
      debugPrint(
          '🏪 StoreService: Unequipping item of type $itemType for user $userId');

      if (itemType == 'nameplate' && itemId != null && itemId.isNotEmpty) {
        final userDoc = await _firestore.collection('Users').doc(userId).get();
        final cust = userDoc.data()?['customization'] as Map<String, dynamic>?;
        final List<dynamic> currentIds = cust?['selectedNameplateIds'] != null
            ? List.from(cust!['selectedNameplateIds'])
            : [];
        currentIds.remove(itemId);
        final newFirst =
            currentIds.isNotEmpty ? currentIds.first as String : null;

        final updates = <String, dynamic>{
          'customization.selectedNameplateIds':
              FieldValue.arrayRemove([itemId]),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (newFirst != null) {
          updates['customization.selectedNameplateId'] = newFirst;
        } else {
          updates['customization.selectedNameplateId'] = FieldValue.delete();
        }

        await _firestore.collection('Users').doc(userId).update(updates);
        debugPrint('🏪 StoreService: Successfully unequipped nameplate');
        return true;
      }

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
        case 'shortProfileTheme':
          fieldName = 'customization.selectedShortProfileThemeId';
          break;
        case 'roomEntry':
          fieldName = 'customization.selectedRoomEntryId';
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

      if (itemType == 'avatarFrame' || itemType == 'frame') {
        FrameHelper.setCachedUserFrame(
            userId: userId, frameId: null, frameUrl: null);
        try {
          if (Get.isRegistered<AuthController>()) {
            final auth = AuthController.instance;
            if (auth.currentUser.userId == userId) {
              auth.currentFrameUrl.value = '';
              final cust =
                  auth.currentUser.customization ?? UserCustomization();
              cust.selectedFrameId = null;
              auth.currentUser.customization = cust;
            }
          }
        } catch (_) {}
        _syncFrameToActiveRoom(userId, null);
      }

      if (itemType == 'micRefill') {
        MicRefillHelper.setCachedUserMicRefill(userId, null);
        try {
          if (Get.isRegistered<AuthController>()) {
            final auth = AuthController.instance;
            if (auth.currentUser.userId == userId) {
              final cust =
                  auth.currentUser.customization ?? UserCustomization();
              cust.selectedMicRefillId = null;
              auth.currentUser.customization = cust;
            }
          }
        } catch (_) {}
      }

      debugPrint('🏪 StoreService: Successfully unequipped item');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ StoreService: Error unequipping item: $e');
      debugPrint('❌ StoreService: Stack trace: $stackTrace');
      throw Exception('Failed to unequip item: $e');
    }
  }

  /// Sync equipped or unequipped frame to active minimized audio room in real time
  void _syncFrameToActiveRoom(String userId, String? frameId) {
    try {
      if (Get.isRegistered<MinimizedRoomController>()) {
        final minCtrl = MinimizedRoomController.instance;
        if (minCtrl.hasMinimizedRoom && minCtrl.minimizedRoom != null) {
          final room = minCtrl.minimizedRoom!;
          final pIdx = room.participants.indexWhere((p) => p.userId == userId);
          if (pIdx != -1) {
            final updated = room.participants[pIdx].copyWith(frameId: frameId);
            final newParticipants =
                List<AudioRoomParticipant>.from(room.participants);
            newParticipants[pIdx] = updated;
            minCtrl.updateMinimizedRoom(
                room.copyWith(participants: newParticipants));
          }
          AudioRoomsRepository()
              .updateParticipantFrameId(
                roomId: room.id,
                userId: userId,
                frameId: frameId,
              )
              .catchError((e) =>
                  debugPrint('Error syncing frame to minimized room: $e'));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [StoreService] Error syncing frame to active room: $e');
    }
  }

  /// Helper to deduplicate items by storeItemId for legacy duplicates
  List<Map<String, dynamic>> _deduplicateItems(
      List<Map<String, dynamic>> items) {
    final Map<String, Map<String, dynamic>> deduplicated = {};
    for (var item in items) {
      final storeItemId = item['storeItemId'] as String?;
      if (storeItemId != null && storeItemId.isNotEmpty) {
        if (!deduplicated.containsKey(storeItemId)) {
          deduplicated[storeItemId] = item;
        } else {
          // Keep the one with the latest expiration date or permanent
          final currentExpiry = item['expiresAt'] as Timestamp?;
          final existingExpiry =
              deduplicated[storeItemId]!['expiresAt'] as Timestamp?;

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
