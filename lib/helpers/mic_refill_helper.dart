import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MicRefillHelper {
  static final Map<String, String> _cache = {};
  static final Map<String, String> _userRefillCache = {};
  static final StoreService _storeService = StoreService();

  static void setCachedUserMicRefill(String userId, String? url) {
    if (url != null && url.isNotEmpty) {
      _userRefillCache[userId] = url;
    } else {
      _userRefillCache.remove(userId);
    }
  }

  static void clearUserCache(String userId) {
    _userRefillCache.remove(userId);
  }

  static Future<String?> getMicRefillUrl(String? micRefillId) async {
    if (micRefillId == null || micRefillId.isEmpty) {
      return null;
    }

    // Direct url check
    if (micRefillId.startsWith('http://') ||
        micRefillId.startsWith('https://') ||
        micRefillId.startsWith('assets/')) {
      _cache[micRefillId] = micRefillId;
      return micRefillId;
    }

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
        if (url.isNotEmpty) {
          _cache[micRefillId] = url;
          return url;
        }
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
      return null;
    }

    if (_userRefillCache.containsKey(userId)) {
      final cached = _userRefillCache[userId];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
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
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedMicRefillId = (customization?['selectedMicRefillId'] ??
          userData?['selectedMicRefillId'] ??
          userData?['userCustomization']?['selectedMicRefillId']) as String?;

      if (selectedMicRefillId == null || selectedMicRefillId.isEmpty) {
        debugPrint('🎙️ [MicRefillHelper] No mic refill equipped for userId: $userId');
        return null;
      }

      debugPrint(
          '🎙️ [MicRefillHelper] Found selectedMicRefillId: $selectedMicRefillId for userId: $userId');

      // Now fetch the mic refill URL using the micRefillId
      final url = await getMicRefillUrl(selectedMicRefillId);
      if (url != null && url.isNotEmpty) {
        _userRefillCache[userId] = url;
      }
      return url;
    } catch (e) {
      debugPrint('❌ [MicRefillHelper] Error fetching mic refill for userId: $e');
      return null;
    }
  }
}
