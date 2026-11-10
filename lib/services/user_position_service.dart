import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';

class PositionConfigItem {
  final String frameItemId;
  final String badgeItemId;
  final String nameplateItemId;
  final String frameName;
  final String badgeName;
  final String nameplateName;
  final String frameUrl;
  final String badgeUrl;
  final String nameplateUrl;
  final DateTime? updatedAt;
  final String updatedBy;

  PositionConfigItem({
    this.frameItemId = '',
    this.badgeItemId = '',
    this.nameplateItemId = '',
    this.frameName = '',
    this.badgeName = '',
    this.nameplateName = '',
    this.frameUrl = '',
    this.badgeUrl = '',
    this.nameplateUrl = '',
    this.updatedAt,
    this.updatedBy = '',
  });

  bool get isConfigured =>
      frameItemId.isNotEmpty || badgeItemId.isNotEmpty || nameplateItemId.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'frameItemId': frameItemId.trim(),
      'badgeItemId': badgeItemId.trim(),
      'nameplateItemId': nameplateItemId.trim(),
      'frameName': frameName,
      'badgeName': badgeName,
      'nameplateName': nameplateName,
      'frameUrl': frameUrl,
      'badgeUrl': badgeUrl,
      'nameplateUrl': nameplateUrl,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  factory PositionConfigItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) return PositionConfigItem();
    return PositionConfigItem(
      frameItemId: map['frameItemId'] as String? ?? '',
      badgeItemId: map['badgeItemId'] as String? ?? '',
      nameplateItemId: map['nameplateItemId'] as String? ?? '',
      frameName: map['frameName'] as String? ?? '',
      badgeName: map['badgeName'] as String? ?? '',
      nameplateName: map['nameplateName'] as String? ?? '',
      frameUrl: map['frameUrl'] as String? ?? '',
      badgeUrl: map['badgeUrl'] as String? ?? '',
      nameplateUrl: map['nameplateUrl'] as String? ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: map['updatedBy'] as String? ?? '',
    );
  }
}

class UserPositionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _positionsConfigDoc = 'user_positions';
  static const String _settingsCollection = 'system_settings';
  static const String _usersCollection = 'Users';
  static const String _userStoreItemsCollection = 'user_store_items';

  static const List<String> supportedPositions = ['host', 'agency', 'seller', 'official', 'official_assistant'];

  static String getPositionDisplayName(String positionKey) {
    switch (positionKey.toLowerCase()) {
      case 'host':
        return 'Host (হোস্ট)';
      case 'agency':
        return 'Agency (এজেন্সি)';
      case 'seller':
        return 'Seller (সেলার)';
      case 'official':
        return 'Official (অফিসিয়াল)';
      case 'official_assistant':
        return 'Official Assistant (অফিসিয়াল অ্যাসিস্ট্যান্ট)';
      default:
        return positionKey;
    }
  }

  /// Get all position configs
  static Future<Map<String, PositionConfigItem>> getPositionConfigs() async {
    try {
      final doc = await _firestore.collection(_settingsCollection).doc(_positionsConfigDoc).get();
      final Map<String, dynamic> data = doc.exists ? (doc.data() ?? {}) : {};
      
      final Map<String, PositionConfigItem> result = {};
      for (final pos in supportedPositions) {
        if (data.containsKey(pos) && data[pos] is Map) {
          result[pos] = PositionConfigItem.fromMap(Map<String, dynamic>.from(data[pos] as Map));
        } else {
          result[pos] = PositionConfigItem();
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ [UserPositionService] Error fetching position configs: $e');
      return {for (final pos in supportedPositions) pos: PositionConfigItem()};
    }
  }

  /// Realtime stream of position configs
  static Stream<Map<String, PositionConfigItem>> getPositionConfigsStream() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_positionsConfigDoc)
        .snapshots()
        .map((snapshot) {
      final Map<String, dynamic> data = snapshot.exists ? (snapshot.data() ?? {}) : {};
      final Map<String, PositionConfigItem> result = {};
      for (final pos in supportedPositions) {
        if (data.containsKey(pos) && data[pos] is Map) {
          result[pos] = PositionConfigItem.fromMap(Map<String, dynamic>.from(data[pos] as Map));
        } else {
          result[pos] = PositionConfigItem();
        }
      }
      return result;
    });
  }

  /// Get details for a specific item by searching market_items, official_items, store_items, etc.
  static Future<Map<String, dynamic>?> getItemDetails(String itemId) async {
    final cleanId = itemId.trim();
    if (cleanId.isEmpty) return null;

    final collections = [
      'market_items',
      'official_items',
      'store_items',
      'items',
      'badges',
      'frames',
      'nameplates',
      'decorations',
      'gift_items',
      'gifts',
    ];

    final intId = int.tryParse(cleanId);

    // 1. Direct doc ID check
    for (final col in collections) {
      try {
        final doc = await _firestore.collection(col).doc(cleanId).get();
        if (doc.exists && doc.data() != null) {
          return _parseItemData(doc.id, doc.data()!, col);
        }
      } catch (_) {}
    }

    final idFields = [
      'displayId',
      'id',
      'itemId',
      'item_id',
      'storeItemId',
      'code',
      'searchId',
      'customId',
      'uniqueId',
    ];
    for (final col in collections) {
      for (final field in idFields) {
        try {
          // String query
          final snapStr = await _firestore
              .collection(col)
              .where(field, isEqualTo: cleanId)
              .limit(1)
              .get();
          if (snapStr.docs.isNotEmpty) {
            final doc = snapStr.docs.first;
            return _parseItemData(doc.id, doc.data(), col);
          }

          // Int query if numeric
          if (intId != null) {
            final snapInt = await _firestore
                .collection(col)
                .where(field, isEqualTo: intId)
                .limit(1)
                .get();
            if (snapInt.docs.isNotEmpty) {
              final doc = snapInt.docs.first;
              return _parseItemData(doc.id, doc.data(), col);
            }
          }
        } catch (_) {}
      }
    }

    // 3. Fallback: check VIP/SVIP level configs if it's a level tag
    try {
      final svipDoc = await _firestore.collection('config').doc('svip_levels').collection('levels').doc(cleanId).get();
      if (svipDoc.exists && svipDoc.data() != null) {
        return _parseItemData(svipDoc.id, svipDoc.data()!, 'svip_levels');
      }
    } catch (_) {}

    return null;
  }

  static Map<String, dynamic> _parseItemData(String docId, Map<String, dynamic> data, String collection) {
    final name = data['name'] ??
        data['title'] ??
        data['itemName'] ??
        data['badgeName'] ??
        data['frameName'] ??
        data['nameplateName'] ??
        'Item $docId';

    final imageUrl = data['fileUrl'] ??
        data['thumbnailUrl'] ??
        data['imageUrl'] ??
        data['image'] ??
        data['iconUrl'] ??
        data['icon'] ??
        data['url'] ??
        data['svgUrl'] ??
        data['mediaUrl'] ??
        data['badgeUrl'] ??
        data['frameUrl'] ??
        data['nameplateUrl'] ??
        data['badgeMediaUrl'] ??
        data['frameMediaUrl'] ??
        data['nameplateMediaUrl'] ??
        '';

    final category = data['category'] ??
        data['itemType'] ??
        data['type'] ??
        data['itemCategory'] ??
        collection;

    return {
      'id': docId,
      'name': name.toString(),
      'imageUrl': imageUrl.toString(),
      'category': category.toString(),
      'collection': collection,
    };
  }

  /// Save position configuration
  static Future<bool> savePositionConfig({
    required String positionKey,
    required String frameItemId,
    required String badgeItemId,
    required String nameplateItemId,
    required String adminId,
  }) async {
    try {
      final posKey = positionKey.toLowerCase().trim();
      if (!supportedPositions.contains(posKey)) {
        throw Exception('Unsupported position: $positionKey');
      }

      // Lookup item details for rich caching
      final frameDetails = frameItemId.isNotEmpty ? await getItemDetails(frameItemId) : null;
      final badgeDetails = badgeItemId.isNotEmpty ? await getItemDetails(badgeItemId) : null;
      final nameplateDetails = nameplateItemId.isNotEmpty ? await getItemDetails(nameplateItemId) : null;

      final configItem = PositionConfigItem(
        frameItemId: frameItemId.trim(),
        badgeItemId: badgeItemId.trim(),
        nameplateItemId: nameplateItemId.trim(),
        frameName: frameDetails?['name'] ?? (frameItemId.isNotEmpty ? 'Frame $frameItemId' : ''),
        badgeName: badgeDetails?['name'] ?? (badgeItemId.isNotEmpty ? 'Badge $badgeItemId' : ''),
        nameplateName: nameplateDetails?['name'] ?? (nameplateItemId.isNotEmpty ? 'Nameplate $nameplateItemId' : ''),
        frameUrl: frameDetails?['imageUrl'] ?? '',
        badgeUrl: badgeDetails?['imageUrl'] ?? '',
        nameplateUrl: nameplateDetails?['imageUrl'] ?? '',
        updatedAt: DateTime.now(),
        updatedBy: adminId,
      );

      await _firestore.collection(_settingsCollection).doc(_positionsConfigDoc).set({
        posKey: configItem.toMap(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));

      debugPrint('✅ [UserPositionService] Position config saved for $posKey');
      return true;
    } catch (e) {
      debugPrint('❌ [UserPositionService] Error saving position config: $e');
      return false;
    }
  }

  /// Search user by SearchId (profileId), id, uniqueId, phone, or fullname
  static Future<Map<String, dynamic>?> searchUser(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    try {
      // 1. Direct doc ID check
      final docById = await _firestore.collection(_usersCollection).doc(cleanQuery).get();
      if (docById.exists && docById.data() != null) {
        return {'id': docById.id, ...docById.data()!};
      }

      // 2. SearchId (profile ID)
      final searchIdSnap = await _firestore
          .collection(_usersCollection)
          .where('searchId', isEqualTo: cleanQuery)
          .limit(1)
          .get();
      if (searchIdSnap.docs.isNotEmpty) {
        return {'id': searchIdSnap.docs.first.id, ...searchIdSnap.docs.first.data()};
      }

      // 3. Unique ID
      final uniqueIdSnap = await _firestore
          .collection(_usersCollection)
          .where('uniqueId', isEqualTo: cleanQuery)
          .limit(1)
          .get();
      if (uniqueIdSnap.docs.isNotEmpty) {
        return {'id': uniqueIdSnap.docs.first.id, ...uniqueIdSnap.docs.first.data()};
      }

      // 4. Number search
      final phoneSnap = await _firestore
          .collection(_usersCollection)
          .where('number', isEqualTo: cleanQuery)
          .limit(1)
          .get();
      if (phoneSnap.docs.isNotEmpty) {
        return {'id': phoneSnap.docs.first.id, ...phoneSnap.docs.first.data()};
      }

      return null;
    } catch (e) {
      debugPrint('❌ [UserPositionService] Error searching user: $e');
      return null;
    }
  }

  /// Apply a position to a user:
  /// 1. Updates user role flags & userPositions array
  /// 2. Auto-assigns the configured Frame, Badge, and Nameplate to user_store_items and customization
  static Future<bool> applyPositionToUser({
    required String userId,
    required String positionKey,
    int durationDays = 365,
    String? adminId,
    String? userProfileId,
    String? userName,
  }) async {
    try {
      final posKey = positionKey.toLowerCase().trim();
      final userDocRef = _firestore.collection(_usersCollection).doc(userId);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        debugPrint('❌ [UserPositionService] User $userId not found');
        return false;
      }

      final userData = userDoc.data() ?? {};
      final now = DateTime.now();

      // Load position config
      final configs = await getPositionConfigs();
      final posConfig = configs[posKey] ?? PositionConfigItem();

      // 1. Prepare user doc role updates
      final Map<String, dynamic> userUpdates = {
        'userPositions': FieldValue.arrayUnion([posKey]),
        'updatedAt': Timestamp.fromDate(now),
      };

      if (posKey == 'host') {
        userUpdates['isHost'] = true;
        userUpdates['host'] = true;
        userUpdates['userType'] = 'host';
      } else if (posKey == 'agency') {
        userUpdates['isAgency'] = true;
        userUpdates['isAgencyManager'] = true;
        userUpdates['roles'] = FieldValue.arrayUnion(['agency']);
      } else if (posKey == 'seller') {
        userUpdates['isSeller'] = true;
        userUpdates['sellerStatus'] = 'active';
        userUpdates['roles'] = FieldValue.arrayUnion(['seller']);
      } else if (posKey == 'official') {
        userUpdates['isOfficial'] = true;
        userUpdates['isSubOfficial'] = true;
        userUpdates['userType'] = 'official';
        userUpdates['roles'] = FieldValue.arrayUnion(['official']);
      } else if (posKey == 'official_assistant') {
        userUpdates['isOfficialAssistant'] = true;
        userUpdates['roles'] = FieldValue.arrayUnion(['official_assistant']);
      }

      // 2. Assign Items if configured
      final customization = Map<String, dynamic>.from(userData['customization'] as Map? ?? {});

      // A) Frame
      if (posConfig.frameItemId.isNotEmpty) {
        var frameUrl = posConfig.frameUrl;
        var frameName = posConfig.frameName;
        if (frameUrl.isEmpty) {
          final fDetails = await getItemDetails(posConfig.frameItemId);
          frameUrl = fDetails?['imageUrl'] ?? '';
          frameName = fDetails?['name'] ?? frameName;
        }

        await _assignSingleItem(
          userId: userId,
          storeItemId: posConfig.frameItemId,
          itemName: frameName.isNotEmpty ? frameName : 'Position Frame',
          itemType: 'avatarFrame',
          imageUrl: frameUrl,
          durationDays: durationDays,
          adminId: adminId ?? 'system',
          positionKey: posKey,
        );

        final ownedFrames = List<String>.from(customization['ownedFrames'] as List? ?? []);
        if (!ownedFrames.contains(posConfig.frameItemId)) {
          ownedFrames.add(posConfig.frameItemId);
        }
        if (frameUrl.isNotEmpty && !ownedFrames.contains(frameUrl)) {
          ownedFrames.add(frameUrl);
        }
        customization['ownedFrames'] = ownedFrames;

        // Auto equip frame
        customization['selectedFrameId'] = posConfig.frameItemId;
        if (frameUrl.isNotEmpty) {
          customization['selectedFrame'] = frameUrl;
          customization['selectedFrameUrl'] = frameUrl;
        }
      }

      // B) Badge
      if (posConfig.badgeItemId.isNotEmpty) {
        var badgeUrl = posConfig.badgeUrl;
        var badgeName = posConfig.badgeName;
        if (badgeUrl.isEmpty) {
          final bDetails = await getItemDetails(posConfig.badgeItemId);
          badgeUrl = bDetails?['imageUrl'] ?? '';
          badgeName = bDetails?['name'] ?? badgeName;
        }

        await _assignSingleItem(
          userId: userId,
          storeItemId: posConfig.badgeItemId,
          itemName: badgeName.isNotEmpty ? badgeName : 'Position Badge',
          itemType: 'badge',
          imageUrl: badgeUrl,
          durationDays: durationDays,
          adminId: adminId ?? 'system',
          positionKey: posKey,
        );

        final rawOwned = List<dynamic>.from(customization['ownedBadges'] as List? ?? []);
        final cleanOwned = <String>[];
        for (final item in rawOwned) {
          if (item is String && item.trim().isNotEmpty) {
            final s = item.trim();
            if (s.startsWith('http') || s.startsWith('assets/')) {
              if (!cleanOwned.contains(s)) cleanOwned.add(s);
            } else if (s == posConfig.badgeItemId) {
              if (!cleanOwned.contains(s)) cleanOwned.add(s);
            }
          }
        }
        if (!cleanOwned.contains(posConfig.badgeItemId)) {
          cleanOwned.add(posConfig.badgeItemId);
        }
        if (badgeUrl.isNotEmpty && !cleanOwned.contains(badgeUrl)) {
          cleanOwned.add(badgeUrl);
        }
        customization['ownedBadges'] = cleanOwned;

        // Auto equip badge
        customization['selectedBadgeId'] = posConfig.badgeItemId;
        if (badgeUrl.isNotEmpty) {
          customization['selectedBadge'] = badgeUrl;
          customization['selectedBadgeUrl'] = badgeUrl;
        }
      }

      // C) Nameplate
      if (posConfig.nameplateItemId.isNotEmpty) {
        var nameplateUrl = posConfig.nameplateUrl;
        var nameplateName = posConfig.nameplateName;
        if (nameplateUrl.isEmpty) {
          final nDetails = await getItemDetails(posConfig.nameplateItemId);
          nameplateUrl = nDetails?['imageUrl'] ?? '';
          nameplateName = nDetails?['name'] ?? nameplateName;
        }

        await _assignSingleItem(
          userId: userId,
          storeItemId: posConfig.nameplateItemId,
          itemName: nameplateName.isNotEmpty ? nameplateName : 'Position Nameplate',
          itemType: 'nameplate',
          imageUrl: nameplateUrl,
          durationDays: durationDays,
          adminId: adminId ?? 'system',
          positionKey: posKey,
        );

        final ownedNameplates = List<String>.from(customization['ownedNameplates'] as List? ?? []);
        if (!ownedNameplates.contains(posConfig.nameplateItemId)) {
          ownedNameplates.add(posConfig.nameplateItemId);
        }
        if (nameplateUrl.isNotEmpty && !ownedNameplates.contains(nameplateUrl)) {
          ownedNameplates.add(nameplateUrl);
        }
        customization['ownedNameplates'] = ownedNameplates;

        final selectedNameplateIds = List<String>.from(customization['selectedNameplateIds'] as List? ?? []);
        if (!selectedNameplateIds.contains(posConfig.nameplateItemId)) {
          selectedNameplateIds.add(posConfig.nameplateItemId);
          customization['selectedNameplateIds'] = selectedNameplateIds;
        }
        customization['selectedNameplateId'] = posConfig.nameplateItemId;
        if (nameplateUrl.isNotEmpty) {
          customization['selectedNameplate'] = nameplateUrl;
          customization['selectedNameplateUrl'] = nameplateUrl;
        }
      }

      userUpdates['customization'] = customization;
      await userDocRef.update(userUpdates);

      if (posConfig.frameItemId.isNotEmpty) {
        await FrameHelper.updateUserFrameRealtime(
          userId: userId,
          frameId: posConfig.frameItemId,
          frameUrl: posConfig.frameUrl.isNotEmpty ? posConfig.frameUrl : null,
        );
      }

      // 3. Send Notification
      try {
        final posTitle = getPositionDisplayName(posKey);
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: posTitle,
          isAssigned: true,
          note: 'Exclusive items (Frame, Badge, Nameplate) have been added to your inventory & decorations in real time!',
        );
      } catch (ex) {
        debugPrint('⚠️ Notification failed: $ex');
      }

      debugPrint('✅ [UserPositionService] Successfully applied $posKey position to user $userId');
      return true;
    } catch (e) {
      debugPrint('❌ [UserPositionService] Error applying position to user: $e');
      return false;
    }
  }

  /// Internal helper to write/update user_store_items
  static Future<void> _assignSingleItem({
    required String userId,
    required String storeItemId,
    required String itemName,
    required String itemType,
    required String imageUrl,
    required int durationDays,
    required String adminId,
    required String positionKey,
  }) async {
    try {
      final existingQuery = await _firestore
          .collection(_userStoreItemsCollection)
          .where('userId', isEqualTo: userId)
          .where('storeItemId', isEqualTo: storeItemId)
          .limit(1)
          .get();

      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: durationDays));

      final posTitle = getPositionDisplayName(positionKey);
      final isVerify = positionKey == 'official' || positionKey == 'official_assistant';

      if (existingQuery.docs.isNotEmpty) {
        final docId = existingQuery.docs.first.id;
        await _firestore.collection(_userStoreItemsCollection).doc(docId).update({
          'isActive': true,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': adminId,
          'positionKey': positionKey,
          'storeItemName': itemName,
          'name': itemName,
          'title': itemName,
          'itemType': itemType,
          'category': itemType,
          'subCategory': 'Verification',
          'badgeSubCategory': 'Verification',
          'tag': posTitle,
          'badgeTag': posTitle,
          'description': 'Exclusive $posTitle Position $itemType',
          'verifyLevel': isVerify ? 3 : 2,
          'starRating': 5,
          if (imageUrl.isNotEmpty) ...{
            'imageUrl': imageUrl,
            'fileUrl': imageUrl,
            'thumbnailUrl': imageUrl,
            'pngUrl': imageUrl,
          },
        });
      } else {
        final docRef = _firestore.collection(_userStoreItemsCollection).doc();
        await docRef.set({
          'id': docRef.id,
          'userId': userId,
          'storeItemId': storeItemId,
          'storeItemName': itemName,
          'name': itemName,
          'title': itemName,
          'itemType': itemType,
          'category': itemType,
          'subCategory': 'Verification',
          'badgeSubCategory': 'Verification',
          'tag': posTitle,
          'badgeTag': posTitle,
          'description': 'Exclusive $posTitle Position $itemType',
          'verifyLevel': isVerify ? 3 : 2,
          'starRating': 5,
          'imageUrl': imageUrl,
          'fileUrl': imageUrl,
          'thumbnailUrl': imageUrl,
          'pngUrl': imageUrl,
          'isActive': true,
          'assignedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'assignedBy': adminId,
          'positionKey': positionKey,
        });
      }
    } catch (e) {
      debugPrint('❌ Error writing user_store_items for $storeItemId: $e');
    }
  }

  /// Remove position from user and clean up items in real time
  static Future<bool> removePositionFromUser({
    required String userId,
    required String positionKey,
    String? adminId,
  }) async {
    try {
      final posKey = positionKey.toLowerCase().trim();
      final userDocRef = _firestore.collection(_usersCollection).doc(userId);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() ?? {};
      final configs = await getPositionConfigs();
      final posConfig = configs[posKey] ?? PositionConfigItem();

      final customization = Map<String, dynamic>.from(userData['customization'] as Map? ?? {});

      // 1. Remove position-specific items from user_store_items
      final itemIdsToRemove = [
        posConfig.frameItemId,
        posConfig.badgeItemId,
        posConfig.nameplateItemId,
      ].where((id) => id.isNotEmpty).toList();

      for (final itemId in itemIdsToRemove) {
        final query = await _firestore
            .collection(_userStoreItemsCollection)
            .where('userId', isEqualTo: userId)
            .where('storeItemId', isEqualTo: itemId)
            .get();

        for (final doc in query.docs) {
          await doc.reference.delete();
        }
      }

      // 2. Remove from user customization inventory
      // Frame
      if (posConfig.frameItemId.isNotEmpty) {
        final ownedFrames = List<String>.from(customization['ownedFrames'] as List? ?? []);
        ownedFrames.remove(posConfig.frameItemId);
        customization['ownedFrames'] = ownedFrames;

        if (customization['selectedFrameId'] == posConfig.frameItemId) {
          customization['selectedFrameId'] = ownedFrames.isNotEmpty ? ownedFrames.first : '';
          customization['selectedFrame'] = '';
          customization['selectedFrameUrl'] = '';
        }
      }

      // Badge
      if (posConfig.badgeItemId.isNotEmpty) {
        final ownedBadges = List<String>.from(customization['ownedBadges'] as List? ?? []);
        ownedBadges.remove(posConfig.badgeItemId);
        customization['ownedBadges'] = ownedBadges;

        if (customization['selectedBadgeId'] == posConfig.badgeItemId) {
          customization['selectedBadgeId'] = ownedBadges.isNotEmpty ? ownedBadges.first : '';
          customization['selectedBadge'] = '';
          customization['selectedBadgeUrl'] = '';
        }
      }

      // Nameplate
      if (posConfig.nameplateItemId.isNotEmpty) {
        final ownedNameplates = List<String>.from(customization['ownedNameplates'] as List? ?? []);
        ownedNameplates.remove(posConfig.nameplateItemId);
        customization['ownedNameplates'] = ownedNameplates;

        final selectedNameplateIds = List<String>.from(customization['selectedNameplateIds'] as List? ?? []);
        selectedNameplateIds.remove(posConfig.nameplateItemId);
        customization['selectedNameplateIds'] = selectedNameplateIds;

        if (customization['selectedNameplateId'] == posConfig.nameplateItemId) {
          customization['selectedNameplateId'] = selectedNameplateIds.isNotEmpty ? selectedNameplateIds.first : '';
          if (selectedNameplateIds.isEmpty) {
            customization['selectedNameplate'] = '';
            customization['selectedNameplateUrl'] = '';
          }
        }
      }

      // 3. Prepare role updates
      final Map<String, dynamic> userUpdates = {
        'userPositions': FieldValue.arrayRemove([posKey]),
        'customization': customization,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (posKey == 'host') {
        userUpdates['isHost'] = false;
        userUpdates['host'] = false;
        if (userData['userType'] == 'host') {
          userUpdates['userType'] = 'regular';
        }
      } else if (posKey == 'agency') {
        userUpdates['isAgency'] = false;
        userUpdates['isAgencyManager'] = false;
        userUpdates['roles'] = FieldValue.arrayRemove(['agency']);
      } else if (posKey == 'seller') {
        userUpdates['isSeller'] = false;
        userUpdates['sellerStatus'] = 'inactive';
        userUpdates['roles'] = FieldValue.arrayRemove(['seller']);
      } else if (posKey == 'official') {
        userUpdates['isOfficial'] = false;
        userUpdates['isSubOfficial'] = false;
        userUpdates['roles'] = FieldValue.arrayRemove(['official']);
        if (userData['userType'] == 'official') {
          userUpdates['userType'] = 'regular';
        }
      } else if (posKey == 'official_assistant') {
        userUpdates['isOfficialAssistant'] = false;
        userUpdates['roles'] = FieldValue.arrayRemove(['official_assistant']);
      }

      await userDocRef.update(userUpdates);

      if (posConfig.frameItemId.isNotEmpty) {
        final remainingFrameId = customization['selectedFrameId']?.toString();
        await FrameHelper.updateUserFrameRealtime(
          userId: userId,
          frameId: (remainingFrameId != null && remainingFrameId.isNotEmpty) ? remainingFrameId : null,
          frameUrl: null,
        );
      }

      // Send official deactivation notification
      try {
        final posTitle = getPositionDisplayName(posKey);
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: posTitle,
          isAssigned: false,
        );
      } catch (ex) {
        debugPrint('⚠️ Error sending position deactivation notice: $ex');
      }

      debugPrint('✅ [UserPositionService] Removed $posKey position from user $userId and cleaned up items');
      return true;
    } catch (e) {
      debugPrint('❌ [UserPositionService] Error removing position: $e');
      return false;
    }
  }

  /// Get stream/list of all users having positions
  static Stream<List<Map<String, dynamic>>> getPositionUsersStream({String? filterPosition}) {
    Query query = _firestore.collection(_usersCollection);

    if (filterPosition != null && filterPosition.isNotEmpty && filterPosition != 'all') {
      if (filterPosition == 'host') {
        query = query.where('isHost', isEqualTo: true);
      } else if (filterPosition == 'seller') {
        query = query.where('isSeller', isEqualTo: true);
      } else if (filterPosition == 'agency') {
        query = query.where('isAgency', isEqualTo: true);
      } else if (filterPosition == 'official') {
        query = query.where('isOfficial', isEqualTo: true);
      } else if (filterPosition == 'official_assistant') {
        query = query.where('isOfficialAssistant', isEqualTo: true);
      }
    }

    return query.limit(100).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).where((user) {
        if (filterPosition != null && filterPosition.isNotEmpty && filterPosition != 'all') {
          return true;
        }
        return user['isHost'] == true ||
            user['isSeller'] == true ||
            user['isAgency'] == true ||
            user['isOfficial'] == true ||
            user['isOfficialAssistant'] == true ||
            (user['userPositions'] is List && (user['userPositions'] as List).isNotEmpty);
      }).toList();
    });
  }
}
