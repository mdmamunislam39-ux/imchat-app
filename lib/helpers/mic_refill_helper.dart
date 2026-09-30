import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

class MicRefillHelper {
  // Static in-memory caches for instantaneous mic refill rendering
  static final Map<String, String> _refillIdToUrlCache = {};
  static final Map<String, String> _userIdToRefillUrlCache = {};
  static final Map<String, String> _userIdToRefillIdCache = {};

  // In-flight deduplication to avoid redundant network/firestore requests
  static final Map<String, Future<String?>> _inFlightRefillId = {};
  static final Map<String, Future<String?>> _inFlightUserId = {};

  static final StoreService _storeService = StoreService();

  // Observable for current logged-in user's active mic refill URL
  static final RxString currentMicRefillUrl = ''.obs;

  /// Synchronous cached lookups for instantaneous rendering without awaiting Future
  static String? getCachedRefillUrl(String? refillId) {
    if (refillId == null || refillId.isEmpty) return null;
    return _refillIdToUrlCache[refillId];
  }

  static String? getCachedUserMicRefill(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userIdToRefillUrlCache[userId];
  }

  static String? getCachedUserMicRefillId(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _userIdToRefillIdCache[userId];
  }

  /// Manually populate or update cache (e.g. upon equipping in store or unequipped)
  static void setCachedUserMicRefill(String userId, String? url, [String? refillId]) {
    if (userId.isEmpty) return;
    if (url != null && url.isNotEmpty) {
      _userIdToRefillUrlCache[userId] = url;
      if (refillId != null && refillId.isNotEmpty) {
        _userIdToRefillIdCache[userId] = refillId;
        _refillIdToUrlCache[refillId] = url;
      }
    } else {
      _userIdToRefillUrlCache.remove(userId);
      _userIdToRefillIdCache.remove(userId);
    }

    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = AuthController.instance;
        if (auth.currentUser.userId == userId) {
          currentMicRefillUrl.value = url ?? '';
        }
      }
    } catch (_) {}
  }

  static void clearUserCache(String userId) {
    _userIdToRefillUrlCache.remove(userId);
    _userIdToRefillIdCache.remove(userId);
    _inFlightUserId.remove(userId);
  }

  static void clearCache() {
    _refillIdToUrlCache.clear();
    _userIdToRefillUrlCache.clear();
    _userIdToRefillIdCache.clear();
    _inFlightRefillId.clear();
    _inFlightUserId.clear();
  }

  /// Real-time stream of mic refill URL from Firestore for ANY user on a seat
  static Stream<String?> streamUserMicRefill(String userId) {
    if (userId.isEmpty) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) {
        setCachedUserMicRefill(userId, null);
        return null;
      }

      final userData = snapshot.data();
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedMicRefillId = (customization?['selectedMicRefillId'] ??
          userData?['selectedMicRefillId'] ??
          userData?['userCustomization']?['selectedMicRefillId']) as String?;

      if (selectedMicRefillId == null || selectedMicRefillId.isEmpty) {
        setCachedUserMicRefill(userId, null);
        return null;
      }

      final url = await getMicRefillUrl(selectedMicRefillId);
      setCachedUserMicRefill(userId, url, selectedMicRefillId);
      return url;
    });
  }

  /// Fetch mic refill URL for a specific refillId with in-flight deduplication and memory cache
  static Future<String?> getMicRefillUrl(String? micRefillId) async {
    if (micRefillId == null || micRefillId.isEmpty) {
      return null;
    }

    // Direct url check
    if (micRefillId.startsWith('http://') ||
        micRefillId.startsWith('https://') ||
        micRefillId.startsWith('assets/')) {
      _refillIdToUrlCache[micRefillId] = micRefillId;
      return micRefillId;
    }

    // 1. Check synchronous memory cache
    if (_refillIdToUrlCache.containsKey(micRefillId)) {
      return _refillIdToUrlCache[micRefillId];
    }

    // 2. Check in-flight requests
    if (_inFlightRefillId.containsKey(micRefillId)) {
      return await _inFlightRefillId[micRefillId];
    }

    final future = _fetchRefillUrl(micRefillId);
    _inFlightRefillId[micRefillId] = future;
    try {
      final url = await future;
      if (url != null && url.isNotEmpty) {
        _refillIdToUrlCache[micRefillId] = url;
      }
      return url;
    } finally {
      _inFlightRefillId.remove(micRefillId);
    }
  }

  static Future<String?> _fetchRefillUrl(String micRefillId) async {
    try {
      // Fetch from store
      final item = await _storeService.getStoreItemDetails(micRefillId);
      if (item != null) {
        final url = item['fileUrl'] ??
            item['thumbnailUrl'] ??
            item['imageUrl'] ??
            item['image'] ??
            '';
        if (url is String && url.isNotEmpty) {
          _refillIdToUrlCache[micRefillId] = url;
          return url;
        }
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

    if (_userIdToRefillUrlCache.containsKey(userId)) {
      return _userIdToRefillUrlCache[userId];
    }

    if (_inFlightUserId.containsKey(userId)) {
      return await _inFlightUserId[userId];
    }

    final future = _fetchUserRefillUrl(userId);
    _inFlightUserId[userId] = future;
    try {
      final url = await future;
      setCachedUserMicRefill(userId, url);
      return url;
    } finally {
      _inFlightUserId.remove(userId);
    }
  }

  static Future<String?> _fetchUserRefillUrl(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedMicRefillId = (customization?['selectedMicRefillId'] ??
          userData?['selectedMicRefillId'] ??
          userData?['userCustomization']?['selectedMicRefillId']) as String?;

      if (selectedMicRefillId == null || selectedMicRefillId.isEmpty) {
        return null;
      }

      return await getMicRefillUrl(selectedMicRefillId);
    } catch (e) {
      debugPrint('❌ [MicRefillHelper] Error fetching mic refill for userId: $e');
      return null;
    }
  }
}
