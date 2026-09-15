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
        debugPrint('🏷️ [NameplateHelper] No store item found for id: $nameplateId, trying fallbacks...');
      }

      // Check user_store_items fallback
      final storeSnap = await FirebaseFirestore.instance
          .collection('user_store_items')
          .where('storeItemId', isEqualTo: nameplateId)
          .limit(1)
          .get();
      if (storeSnap.docs.isNotEmpty) {
        final url = storeSnap.docs.first.data()['imageUrl'] as String? ?? '';
        if (url.isNotEmpty) {
          _cache[nameplateId] = url;
          return url;
        }
      }

      // Check VIP/SVIP level config fallback
      if (nameplateId.startsWith('vip_') || nameplateId.startsWith('svip_')) {
        final isSvip = nameplateId.startsWith('svip_');
        final levelNum = nameplateId.replaceAll(RegExp(r'[^0-9]'), '');
        final docId = isSvip ? 'svip$levelNum' : 'vip$levelNum';
        final col = isSvip ? 'svip_levels' : 'vip_levels';
        final doc = await FirebaseFirestore.instance
            .collection('config')
            .doc(col)
            .collection('levels')
            .doc(docId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final url = (data?['nameplateMediaUrl']?.toString() ?? '').isNotEmpty
              ? data!['nameplateMediaUrl'].toString()
              : data?['nameplateUrl']?.toString() ?? '';
          if (url.isNotEmpty) {
            _cache[nameplateId] = url;
            return url;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [NameplateHelper] Error fetching nameplate URL: $e');
    }
    return null;
  }

  /// Fetch multiple nameplate image URLs using a list of storeItemIds
  static Future<List<String>> getNameplateUrls(List<String>? nameplateIds) async {
    if (nameplateIds == null || nameplateIds.isEmpty) {
      return [];
    }

    final futures = nameplateIds.map((id) => getNameplateUrl(id));
    final results = await Future.wait(futures);
    return results.whereType<String>().where((url) => url.isNotEmpty).toList();
  }

  /// Fetch nameplate image URL directly using userId (returns first available nameplate)
  static Future<String?> getNameplateUrlFromUserId(String? userId) async {
    final urls = await getNameplateUrlsFromUserId(userId);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// Fetch all nameplate image URLs directly using userId
  static Future<List<String>> getNameplateUrlsFromUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return [];
      }

      final userData = userDoc.data();
      final customization = userData?['customization'];

      List<String> ids = [];
      if (customization != null) {
        if (customization['selectedNameplateIds'] != null) {
          ids = List<String>.from(customization['selectedNameplateIds']);
        } else if (customization['selectedNameplateId'] != null &&
            (customization['selectedNameplateId'] as String).isNotEmpty) {
          ids = [customization['selectedNameplateId'] as String];
        }
      }

      // Requirement 5: VIP / SVIP Nameplate is automatically active.
      // If user has active SVIP or VIP status and no nameplate is selected yet,
      // resolve active SVIP/VIP nameplate automatically.
      if (ids.isEmpty && userData != null) {
        final now = DateTime.now();
        final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
        final int activeSvip = userData['activeSvipLevel'] as int? ?? 0;
        final String svipMonth = userData['svipValidUntilMonth']?.toString() ?? '';
        final int activeVip = userData['activeVipLevel'] as int? ?? 0;
        final Timestamp? vipExpiry = userData['vipValidUntil'] as Timestamp?;
        final bool isSvipActive = activeSvip > 0 && svipMonth == currentMonth;
        final bool isVipActive = activeVip > 0 &&
            (vipExpiry == null || vipExpiry.toDate().isAfter(now));

        if (isSvipActive) {
          ids.add('svip_svip${activeSvip}_nameplate');
        } else if (isVipActive) {
          ids.add('vip_vip${activeVip}_nameplate');
        }
      }

      return await getNameplateUrls(ids);
    } catch (e) {
      debugPrint('❌ [NameplateHelper] Error fetching nameplates for userId: $e');
      return [];
    }
  }
}
