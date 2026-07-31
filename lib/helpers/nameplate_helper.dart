import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NameplateHelper {
  static final Map<String, String> _cache = {};
  static final StoreService _storeService = StoreService();

  /// Fetch nameplate image URL using storeItemId
  static Future<String?> getNameplateUrl(String? nameplateId) async {
    if (nameplateId == null || nameplateId.isEmpty) {
      debugPrint('🏷️ [NameplateHelper] nameplateId is null or empty');
      return null;
    }

    // Check cache first
    if (_cache.containsKey(nameplateId)) {
      return _cache[nameplateId];
    }

    try {
      debugPrint('🏷️ [NameplateHelper] Fetching nameplate URL for id: $nameplateId');
      final item = await _storeService.getStoreItemDetails(nameplateId);
      if (item != null) {
        final url = item['fileUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '';
        debugPrint('🏷️ [NameplateHelper] Fetched URL: $url');
        if (url.isNotEmpty) {
          _cache[nameplateId] = url;
          return url;
        }
      } else {
        debugPrint('🏷️ [NameplateHelper] No store item found for id: $nameplateId');
      }
    } catch (e) {
      debugPrint('❌ [NameplateHelper] Error fetching nameplate URL: $e');
    }
    return null;
  }

  /// Fetch nameplate image URL directly using userId
  static Future<String?> getNameplateUrlFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedNameplateId = customization?['selectedNameplateId'] as String?;

      if (selectedNameplateId == null || selectedNameplateId.isEmpty) {
        return null;
      }

      return await getNameplateUrl(selectedNameplateId);
    } catch (e) {
      debugPrint('❌ [NameplateHelper] Error fetching nameplate for userId: $e');
      return null;
    }
  }
}
