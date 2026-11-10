import 'package:chat_messenger/services/store_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/models/user.dart';

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

  /// Real-time instantaneous update that immediately reflects on UI, AuthController,
  /// Minimized Audio Room floating player, and Firestore room seats
  static Future<void> updateUserFrameRealtime({
    required String userId,
    required String? frameId,
    String? frameUrl,
  }) async {
    if (userId.isEmpty) return;

    // 1. Resolve frameUrl if missing
    String? resolvedUrl = frameUrl;
    if (frameId != null && frameId.isNotEmpty && (resolvedUrl == null || resolvedUrl.isEmpty)) {
      resolvedUrl = await getFrameUrl(frameId);
    }

    // 2. Immediate memory cache update
    setCachedUserFrame(userId: userId, frameId: frameId, frameUrl: resolvedUrl);

    // 3. Update AuthController if current logged in user
    try {
      if (Get.isRegistered<AuthController>()) {
        final auth = AuthController.instance;
        if (auth.currentUser.userId == userId) {
          auth.currentFrameUrl.value = resolvedUrl ?? '';
          final cust = auth.currentUser.customization ?? UserCustomization();
          cust.selectedFrameId = frameId;
          auth.currentUser.customization = cust;
        }
      }
    } catch (_) {}

    // 4. Sync immediately to minimized floating room & active audio room repository
    try {
      if (Get.isRegistered<MinimizedRoomController>()) {
        final minCtrl = MinimizedRoomController.instance;
        if (minCtrl.hasMinimizedRoom && minCtrl.minimizedRoom != null) {
          final room = minCtrl.minimizedRoom!;
          final pIdx = room.participants.indexWhere((p) => p.userId == userId);
          if (pIdx != -1) {
            final updated = room.participants[pIdx].copyWith(frameId: frameId);
            final newParticipants = List<AudioRoomParticipant>.from(room.participants);
            newParticipants[pIdx] = updated;
            minCtrl.updateMinimizedRoom(room.copyWith(participants: newParticipants));
          }
          AudioRoomsRepository().updateParticipantFrameId(
            roomId: room.id,
            userId: userId,
            frameId: frameId,
          ).catchError((e) => debugPrint('Error syncing frame to minimized room: $e'));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [FrameHelper] Error syncing frame to active room: $e');
    }
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

  /// One-time cached lookup for user's frame URL to avoid continuous Firestore snapshot streams
  static Future<String?> getUserFrameUrl(String? userId) async {
    if (userId == null || userId.isEmpty) return null;

    // 1. Check synchronous memory cache
    if (_userIdToFrameUrlCache.containsKey(userId)) {
      return _userIdToFrameUrlCache[userId];
    }

    // 2. Check in-flight deduplication
    if (_inFlightUserId.containsKey(userId)) {
      return await _inFlightUserId[userId];
    }

    final future = _fetchUserFrameUrl(userId);
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

  static Future<String?> _fetchUserFrameUrl(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (!doc.exists) return null;
      final userData = doc.data();
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedFrameId = (customization?['selectedFrameId'] ??
          userData?['selectedFrameId'] ??
          userData?['userCustomization']?['selectedFrameId']) as String?;

      if (selectedFrameId == null || selectedFrameId.isEmpty) {
        setCachedUserFrame(userId: userId, frameId: null, frameUrl: null);
        return null;
      }

      final url = await getFrameUrl(selectedFrameId);
      setCachedUserFrame(userId: userId, frameId: selectedFrameId, frameUrl: url);
      return url;
    } catch (e) {
      debugPrint('Error fetching user frame URL: $e');
      return null;
    }
  }

  /// Real-time stream of avatar frame URL from Firestore for ANY user
  static Stream<String?> streamUserFrame(String userId) {
    if (userId.isEmpty) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) {
        setCachedUserFrame(userId: userId, frameId: null, frameUrl: null);
        return null;
      }

      final userData = snapshot.data();
      final customization = userData?['customization'] as Map<String, dynamic>?;
      final selectedFrameId = (customization?['selectedFrameId'] ??
          userData?['selectedFrameId'] ??
          userData?['userCustomization']?['selectedFrameId']) as String?;

      if (selectedFrameId == null || selectedFrameId.isEmpty) {
        setCachedUserFrame(userId: userId, frameId: null, frameUrl: null);
        return null;
      }

      final url = await getFrameUrl(selectedFrameId);
      setCachedUserFrame(userId: userId, frameId: selectedFrameId, frameUrl: url);
      return url;
    });
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
            item['animationUrl'] ??
            item['frameUrl'] ??
            item['frameMediaUrl'] ??
            item['svgaUrl'] ??
            item['assetUrl'] ??
            item['mediaUrl'] ??
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
        final url = (data['fileUrl'] ??
                data['animationUrl'] ??
                data['frameUrl'] ??
                data['frameMediaUrl'] ??
                data['svgaUrl'] ??
                data['assetUrl'] ??
                data['imageUrl'] ??
                data['thumbnailUrl'] ??
                '')
            .toString();
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
