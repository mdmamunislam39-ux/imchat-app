import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentGiftsService {
  static const String _keyPrefix = 'recent_gifts_';
  static const int maxRecentGifts = 50;

  // In-memory cache for instant zero-latency retrieval
  static List<String>? _cachedGiftIds;

  /// Load recent gift IDs from local persistent storage
  static Future<List<String>> getRecentGiftIds({String? userId}) async {
    if (_cachedGiftIds != null) {
      return List<String>.from(_cachedGiftIds!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = (userId != null && userId.isNotEmpty)
          ? '$_keyPrefix$userId'
          : '${_keyPrefix}global';
      final list = prefs.getStringList(key) ?? [];
      _cachedGiftIds = List<String>.from(list);
      return List<String>.from(_cachedGiftIds!);
    } catch (e) {
      debugPrint('❌ [RecentGiftsService] Error reading recent gifts: $e');
      return _cachedGiftIds ?? [];
    }
  }

  /// Synchronously get cached recent gift IDs (if loaded in memory)
  static List<String> getCachedRecentGiftIds() {
    return _cachedGiftIds != null ? List<String>.from(_cachedGiftIds!) : [];
  }

  /// Record a recently sent gift ID (moves to top/index 0)
  static Future<void> recordRecentGift(String giftId, {String? userId}) async {
    if (giftId.trim().isEmpty) return;
    try {
      final currentList = List<String>.from(
          _cachedGiftIds ?? await getRecentGiftIds(userId: userId));

      // Remove any existing occurrence of this gift
      currentList.removeWhere((id) => id == giftId);

      // Insert at the front (index 0) so newest is on top
      currentList.insert(0, giftId);

      // Keep maximum limit
      if (currentList.length > maxRecentGifts) {
        currentList.removeRange(maxRecentGifts, currentList.length);
      }

      _cachedGiftIds = currentList;

      final prefs = await SharedPreferences.getInstance();
      final key = (userId != null && userId.isNotEmpty)
          ? '$_keyPrefix$userId'
          : '${_keyPrefix}global';
      await prefs.setStringList(key, currentList);
    } catch (e) {
      debugPrint('❌ [RecentGiftsService] Error saving recent gift: $e');
    }
  }

  /// Clear recent gifts if needed
  static Future<void> clearRecentGifts({String? userId}) async {
    _cachedGiftIds = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = (userId != null && userId.isNotEmpty)
          ? '$_keyPrefix$userId'
          : '${_keyPrefix}global';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('❌ [RecentGiftsService] Error clearing recent gifts: $e');
    }
  }
}
