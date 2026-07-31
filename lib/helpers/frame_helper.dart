import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FrameHelper {
  static final Map<String, String> _cache = {};
  static final StoreService _storeService = StoreService();

  static Future<String?> getFrameUrl(String? frameId) async {
    if (frameId == null || frameId.isEmpty) {
      debugPrint('🖼️ [FrameHelper] frameId is null or empty');
      return null;
    }

    debugPrint('🖼️ [FrameHelper] Fetching frame URL for frameId: $frameId');

    // Check cache
    if (_cache.containsKey(frameId)) {
      debugPrint('🖼️ [FrameHelper] Found in cache: ${_cache[frameId]}');
      return _cache[frameId];
    }

    try {
      // Fetch from store
      final item = await _storeService.getStoreItemDetails(frameId);
      if (item != null) {
        final url = item['fileUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '';
        debugPrint('🖼️ [FrameHelper] Fetched URL: $url');
        _cache[frameId] = url;
        return url;
      } else {
        debugPrint('🖼️ [FrameHelper] No item found for frameId: $frameId');
      }
    } catch (e) {
      debugPrint('❌ [FrameHelper] Error fetching frame URL: $e');
    }
    return null;
  }

  /// Fetch frame URL from user's document
  static Future<String?> getFrameUrlFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      debugPrint('🖼️ [FrameHelper] userId is null or empty');
      return null;
    }

    debugPrint('🖼️ [FrameHelper] Fetching frame for userId: $userId');

    try {
      // Fetch user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('🖼️ [FrameHelper] User document not found for userId: $userId');
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedFrameId = customization?['selectedFrameId'];

      if (selectedFrameId == null || selectedFrameId.isEmpty) {
        debugPrint('🖼️ [FrameHelper] No frame equipped for userId: $userId');
        return null;
      }

      debugPrint(
          '🖼️ [FrameHelper] Found selectedFrameId: $selectedFrameId for userId: $userId');

      // Now fetch the frame URL using the frameId
      return await getFrameUrl(selectedFrameId);
    } catch (e) {
      debugPrint('❌ [FrameHelper] Error fetching frame for userId: $e');
      return null;
    }
  }
}
