import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/services/svip_service.dart';
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

    // Filter out lower-tier VIP/SVIP if multiple exist, keeping only the highest tier
    final cleanIds = List<String>.from(nameplateIds);
    int highestVip = 0;
    int highestSvip = 0;
    for (final id in cleanIds) {
      if (id.startsWith('vip_vip')) {
        final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (lvl > highestVip) highestVip = lvl;
      } else if (id.startsWith('svip_svip')) {
        final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (lvl > highestSvip) highestSvip = lvl;
      }
    }

    cleanIds.removeWhere((id) {
      if (id.startsWith('vip_vip')) {
        final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return highestSvip > 0 || (lvl < highestVip);
      }
      if (id.startsWith('svip_svip')) {
        final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return lvl < highestSvip;
      }
      return false;
    });

    final futures = cleanIds.map((id) => getNameplateUrl(id));
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

      // Requirement: VIP / SVIP Nameplate is automatically active and only the highest tier is shown.
      if (userData != null) {
        final int activeSvip = (userData['activeSvipLevel'] as num?)?.toInt() ?? 0;
        final String svipMonth = userData['svipValidUntilMonth']?.toString() ?? '';
        final int activeVip = (userData['activeVipLevel'] as num?)?.toInt() ?? 0;
        DateTime? vipExpiry;
        if (userData['vipValidUntil'] != null) {
          if (userData['vipValidUntil'] is Timestamp) {
            vipExpiry = (userData['vipValidUntil'] as Timestamp).toDate();
          } else if (userData['vipValidUntil'] is String) {
            vipExpiry = DateTime.tryParse(userData['vipValidUntil'].toString());
          }
        }
        final String vipMonth = userData['vipValidUntilMonth']?.toString() ?? '';

        final bool isSvipActive = SvipService.isSvipActive(activeSvip, svipMonth);
        final bool isVipActive = SvipService.isVipActive(activeVip, vipExpiry, vipMonth);

        // Remove any outdated or lower tier VIP/SVIP nameplates
        ids.removeWhere((id) {
          if (id.startsWith('vip_vip')) {
            final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return !isVipActive || (lvl > 0 && lvl != activeVip);
          }
          if (id.startsWith('svip_svip')) {
            final lvl = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return !isSvipActive || (lvl > 0 && lvl != activeSvip);
          }
          return false;
        });

        if (isSvipActive) {
          final svipId = 'svip_svip${activeSvip}_nameplate';
          ids.remove(svipId);
          ids.insert(0, svipId); // Highest tier VIP nameplate in front
        } else if (isVipActive) {
          final vipId = 'vip_vip${activeVip}_nameplate';
          ids.remove(vipId);
          ids.insert(0, vipId); // Highest tier VIP nameplate in front
        }
      }

      return await getNameplateUrls(ids);
    } catch (e) {
      debugPrint('❌ [NameplateHelper] Error fetching nameplates for userId: $e');
      return [];
    }
  }
}
