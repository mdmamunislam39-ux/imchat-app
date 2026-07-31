import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MicRefillHelper {
  static final Map<String, String> _cache = {};
  static final StoreService _storeService = StoreService();

  static Future<String?> getMicRefillUrl(String? micRefillId) async {
    if (micRefillId == null || micRefillId.isEmpty) {
      debugPrint('🎙️ [MicRefillHelper] micRefillId is null or empty');
      return null;
    }

    debugPrint('🎙️ [MicRefillHelper] Fetching mic refill URL for micRefillId: $micRefillId');

    // Check cache
    if (_cache.containsKey(micRefillId)) {
      debugPrint('🎙️ [MicRefillHelper] Found in cache: ${_cache[micRefillId]}');
      return _cache[micRefillId];
    }

    try {
      // Fetch from store
      final item = await _storeService.getStoreItemDetails(micRefillId);
      if (item != null) {
        final url = item['fileUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '';
        debugPrint('🎙️ [MicRefillHelper] Fetched URL: $url');
        _cache[micRefillId] = url;
        return url;
      } else {
        debugPrint('🎙️ [MicRefillHelper] No item found for micRefillId: $micRefillId');
      }
    } catch (e) {
      debugPrint('❌ [MicRefillHelper] Error fetching mic refill URL: $e');
    }
    return null;
  }

  /// Fetch mic refill URL from user's document
  static Future<String?> getMicRefillUrlFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      debugPrint('🎙️ [MicRefillHelper] userId is null or empty');
      return null;
    }

    debugPrint('🎙️ [MicRefillHelper] Fetching mic refill for userId: $userId');

    try {
      // Fetch user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('🎙️ [MicRefillHelper] User document not found for userId: $userId');
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];
      final selectedMicRefillId = customization?['selectedMicRefillId'];

      if (selectedMicRefillId == null || selectedMicRefillId.isEmpty) {
        debugPrint('🎙️ [MicRefillHelper] No mic refill equipped for userId: $userId');
        return null;
      }

      debugPrint(
          '🎙️ [MicRefillHelper] Found selectedMicRefillId: $selectedMicRefillId for userId: $userId');

      // Now fetch the mic refill URL using the micRefillId
      return await getMicRefillUrl(selectedMicRefillId);
    } catch (e) {
      debugPrint('❌ [MicRefillHelper] Error fetching mic refill for userId: $e');
      return null;
    }
  }
}
