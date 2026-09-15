import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FrameHelper {
  // Static in-memory caches for instantaneous frame rendering
  static final Map<String, String> _frameIdToUrlCache = {};
  static final Map<String, String> _userIdToFrameUrlCache = {};
  static final Map<String, String> _userIdToFrameIdCache = {};

  // In-flight deduplication to avoid redundant network/firestore requests
  static final Map<String, Future<String?>> _inFlightFrameId = {};
  static final Map<String, Future<String?>> _inFlightUserId = {};

  static final StoreService _storeService = StoreService();

  /// Synchronous cached lookups for instantaneous rendering without awaiting Future
  static String? getCachedFrameUrl(String? frameId) {
    if (frameId == null || frameId.isEmpty) return null;
    return _frameIdToUrlCache[frameId];
  }

  static String? getCachedUserFrameUrl(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userIdToFrameUrlCache[userId];
  }

  static String? getCachedUserFrameId(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userIdToFrameIdCache[userId];
  }

  /// Manually populate or update cache (e.g. upon equipping in store or receiving user updates)
  static void setCachedUserFrame({
    required String userId,
    String? frameId,
    String? frameUrl,
  }) {
    if (userId.isEmpty) return;
    if (frameId != null) {
      _userIdToFrameIdCache[userId] = frameId;
      if (frameUrl != null && frameUrl.isNotEmpty) {
        _frameIdToUrlCache[frameId] = frameUrl;
      }
    } else {
      _userIdToFrameIdCache.remove(userId);
    }

    if (frameUrl != null && frameUrl.isNotEmpty) {
      _userIdToFrameUrlCache[userId] = frameUrl;
    } else if (frameId == null) {
      _userIdToFrameUrlCache.remove(userId);
    } else {
      if (_frameIdToUrlCache.containsKey(frameId)) {
        _userIdToFrameUrlCache[userId] = _frameIdToUrlCache[frameId]!;
      } else {
        getFrameUrl(frameId).then((resolved) {
          if (resolved != null && resolved.isNotEmpty) {
            _userIdToFrameUrlCache[userId] = resolved;
          }
        });
      }
    }
  }

  static void setCachedFrameUrl(String frameId, String frameUrl) {
    if (frameId.isNotEmpty && frameUrl.isNotEmpty) {
      _frameIdToUrlCache[frameId] = frameUrl;
    }
  }

  static void clearCache() {
    _frameIdToUrlCache.clear();
    _userIdToFrameUrlCache.clear();
    _userIdToFrameIdCache.clear();
    _inFlightFrameId.clear();
    _inFlightUserId.clear();
  }

  /// Fetch frame URL for a specific frameId with in-flight deduplication and memory cache
  static Future<String?> getFrameUrl(String? frameId) async {
    if (frameId == null || frameId.isEmpty) {
      return null;
    }

    // 1. Check synchronous memory cache
    if (_frameIdToUrlCache.containsKey(frameId)) {
      return _frameIdToUrlCache[frameId];
    }

    // 2. Check in-flight requests
    if (_inFlightFrameId.containsKey(frameId)) {
      return await _inFlightFrameId[frameId];
    }

    final future = _fetchFrameUrl(frameId);
    _inFlightFrameId[frameId] = future;
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        _frameIdToUrlCache[frameId] = url;
      }
      return url;
    } finally {
      _inFlightFrameId.remove(frameId);
    }
  }

  static Future<String?> _fetchFrameUrl(String frameId) async {
    try {
      // Fetch from store
      final item = await _storeService.getStoreItemDetails(frameId);
      if (item != null) {
        final url = item['fileUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '';
        if (url is String && url.isNotEmpty) {
          _frameIdToUrlCache[frameId] = url;
          return url;
        }
      }

      // Fallback: Check user_store_items collection
      final snap = await FirebaseFirestore.instance
          .collection('user_store_items')
          .where('storeItemId', isEqualTo: frameId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final url = (data['fileUrl'] ?? data['imageUrl'] ?? data['thumbnailUrl'] ?? '') as String;
        if (url.isNotEmpty) {
          _frameIdToUrlCache[frameId] = url;
          return url;
        }
      }

      // Fallback: VIP/SVIP configs
      if (frameId.startsWith('vip_') || frameId.startsWith('svip_')) {
        final isSvip = frameId.startsWith('svip_');
        final levelNum = frameId.replaceAll(RegExp(r'[^0-9]'), '');
        final col = isSvip ? 'svip_levels' : 'vip_levels';
        final docId = isSvip ? 'svip$levelNum' : 'vip$levelNum';
        final cfgDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc(col)
            .collection('levels')
            .doc(docId)
            .get();
        if (cfgDoc.exists) {
          final data = cfgDoc.data()!;
          final url = (data['frameMediaUrl']?.toString() ?? '').isNotEmpty ? data['frameMediaUrl'] : data['frameUrl'];
          if (url != null && url.toString().isNotEmpty) {
            final strUrl = url.toString();
            _frameIdToUrlCache[frameId] = strUrl;
            return strUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [FrameHelper] Error fetching frame URL for frameId $frameId: $e');
    }
    return null;
  }

  /// Fetch frame URL from user's document with caching and in-flight deduplication
  static Future<String?> getFrameUrlFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return null;
    }

    // 1. Check user frame cache
    if (_userIdToFrameUrlCache.containsKey(userId)) {
      return _userIdToFrameUrlCache[userId];
    }

    // 2. Check in-flight requests
    if (_inFlightUserId.containsKey(userId)) {
      return await _inFlightUserId[userId];
    }

    final future = _fetchFrameUrlFromUserId(userId);
    _inFlightUserId[userId] = future;
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        _userIdToFrameUrlCache[userId] = url;
      }
      return url;
    } finally {
      _inFlightUserId.remove(userId);
    }
  }

  static Future<String?> _fetchFrameUrlFromUserId(String userId) async {
    try {
      // Fetch user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data();
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedFrameId = customization?['selectedFrameId'] as String?;

      if (selectedFrameId == null || selectedFrameId.isEmpty) {
        _userIdToFrameIdCache.remove(userId);
        _userIdToFrameUrlCache.remove(userId);
        return null;
      }

      _userIdToFrameIdCache[userId] = selectedFrameId;

      // Fetch frame URL using frameId
      final frameUrl = await getFrameUrl(selectedFrameId);
      if (frameUrl != null && frameUrl.isNotEmpty) {
        _userIdToFrameUrlCache[userId] = frameUrl;
      }
      return frameUrl;
    } catch (e) {
      debugPrint('❌ [FrameHelper] Error fetching frame for userId $userId: $e');
      return null;
    }
  }
}
