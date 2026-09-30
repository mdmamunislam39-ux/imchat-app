import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:chat_messenger/api/official_team_api.dart';

class SvipService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate the month until which SVIP is valid (current month + 1 full extra month grace period)
  static String calculateSvipValidUntilMonth(DateTime rechargeDate) {
    final nextMonthDate = DateTime(rechargeDate.year, rechargeDate.month + 1, 1);
    return "${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}";
  }

  /// Check if user's SVIP is currently active (supports current month + 1 month retention)
  static bool isSvipActive(int activeSvipLevel, String svipValidUntilMonth) {
    if (activeSvipLevel <= 0 || svipValidUntilMonth.trim().isEmpty) return false;
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    return currentMonth.compareTo(svipValidUntilMonth) <= 0;
  }

  /// Check if user's VIP is currently active
  static bool isVipActive(int activeVipLevel, DateTime? vipValidUntil, [String vipValidUntilMonth = '']) {
    if (activeVipLevel <= 0) return false;
    if (vipValidUntilMonth.toLowerCase() == 'unlimited') return true;
    if (vipValidUntil != null) {
      if (vipValidUntil.year >= 2090) return true;
      return vipValidUntil.isAfter(DateTime.now());
    }
    return false;
  }

  /// Check and auto-upgrade user's SVIP level if they meet the threshold
  static Future<void> checkAndAutoUpgradeSvip({
    required String userId,
    required int newRechargeAmount,
    required String currentMonth,
    required Transaction transaction,
    required DocumentReference userRef,
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> svipLevels,
  }) async {
    try {
      // Check SVIP eligibility
      int currentActiveSvip = (userData['activeSvipLevel'] as num?)?.toInt() ?? 0;
      final String userValidUntilMonth = userData['svipValidUntilMonth']?.toString() ?? '';
      int highestEligibleSvip = 0;
      Map<String, dynamic>? highestSvipData;

      for (var level in svipLevels) {
        final levelId = level['id']?.toString() ?? '';
        final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final rawTarget = level['rechargeTarget'] ?? level['requiredRechargeAmount'];
        final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
        
        if (newRechargeAmount >= target && levelNum > highestEligibleSvip) {
          highestEligibleSvip = levelNum;
          highestSvipData = level;
        }
      }

      Map<String, dynamic> custData = Map<String, dynamic>.from(userData['customization'] ?? {});
      bool hasUpdates = false;

      void addAssetToInventory(String listKey, String url, String storeItemId) {
        List<String> currentList = List<String>.from(custData[listKey] ?? []);
        bool modified = false;
        if (url.isNotEmpty && !currentList.contains(url)) {
          currentList.add(url);
          modified = true;
        }
        if (storeItemId.isNotEmpty && !currentList.contains(storeItemId)) {
          currentList.add(storeItemId);
          modified = true;
        }
        if (modified) {
          custData[listKey] = currentList;
          hasUpdates = true;
        }
      }

      String extractUrl(Map<String, dynamic> data, List<String> candidateKeys) {
        for (final key in candidateKeys) {
          final val = data[key]?.toString().trim() ?? '';
          if (val.isNotEmpty && (val.startsWith('http://') || val.startsWith('https://') || val.startsWith('assets/'))) {
            return val;
          }
        }
        return '';
      }

      final now = DateTime.now();
      final validUntilMonth = calculateSvipValidUntilMonth(now);
      final bool isLevelUpgrade = highestEligibleSvip > currentActiveSvip;
      final bool isMonthlyRenewal = userValidUntilMonth != validUntilMonth;
      final bool shouldApply = highestEligibleSvip > 0 && highestSvipData != null && (isLevelUpgrade || isMonthlyRenewal || highestEligibleSvip >= currentActiveSvip);

      // Apply SVIP Upgrade / Renewal / Sync if eligible
      if (shouldApply) {
        final levelId = highestSvipData['id'] as String;
        final levelNum = levelId.replaceAll(RegExp(r'[^0-9]'), '');
        final claimedRef = _firestore.collection('Users').doc(userId).collection('claimed_svips').doc(currentMonth);
        transaction.set(claimedRef, {levelId: true}, SetOptions(merge: true));

        transaction.update(userRef, {
          'activeSvipLevel': highestEligibleSvip,
          'svipValidUntilMonth': validUntilMonth,
        });

        // Automatically delete all previous SVIP level items from user_store_items if upgraded
        if (isLevelUpgrade) {
          final suffixes = ['badge', 'frame', 'entry', 'skin', 'nameplate'];
          for (int old = 1; old < highestEligibleSvip; old++) {
            for (final s in suffixes) {
              final oldDocRef = _firestore
                  .collection('user_store_items')
                  .doc('${userId}_svip_svip${old}_$s');
              transaction.delete(oldDocRef);
            }
          }

          // Clean previous SVIP asset URLs from customization lists
          for (var lvl in svipLevels) {
            final lId = lvl['id'] as String? ?? '';
            final lNum = int.tryParse(lId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (lNum > 0 && lNum < highestEligibleSvip) {
              final oldUrls = [
                lvl['badgeMediaUrl']?.toString() ?? '',
                lvl['badgeUrl']?.toString() ?? '',
                lvl['frameMediaUrl']?.toString() ?? '',
                lvl['frameUrl']?.toString() ?? '',
                lvl['entryEffectMediaUrl']?.toString() ?? '',
                lvl['entryEffectUrl']?.toString() ?? '',
                lvl['profileSkinMediaUrl']?.toString() ?? '',
                lvl['profileSkinUrl']?.toString() ?? '',
                lvl['nameplateMediaUrl']?.toString() ?? '',
                lvl['nameplateUrl']?.toString() ?? '',
              ];
              for (final u in oldUrls) {
                if (u.isNotEmpty) {
                  (custData['ownedBadges'] as List?)?.remove(u);
                  (custData['ownedFrames'] as List?)?.remove(u);
                  (custData['ownedEntryEffects'] as List?)?.remove(u);
                  (custData['ownedBackgroundThemes'] as List?)?.remove(u);
                  (custData['ownedNameplates'] as List?)?.remove(u);
                }
              }
            }
          }

          // Unequip previous SVIP items if equipped
          final selFrame = custData['selectedFrameId']?.toString() ?? '';
          final selEntry = custData['selectedEntryEffectId']?.toString() ?? '';
          final selTheme = custData['selectedBackgroundThemeId']?.toString() ?? '';
          for (int old = 1; old < highestEligibleSvip; old++) {
            if (selFrame == 'svip_svip${old}_frame') {
              custData['selectedFrameId'] = null;
            }
            if (selEntry == 'svip_svip${old}_entry') {
              custData['selectedEntryEffectId'] = null;
            }
            if (selTheme == 'svip_svip${old}_skin') {
              custData['selectedBackgroundThemeId'] = null;
            }
          }

          if (custData['selectedNameplateIds'] is List) {
            final npIds = List<String>.from(custData['selectedNameplateIds'] as List);
            for (int old = 1; old < highestEligibleSvip; old++) {
              npIds.remove('svip_svip${old}_nameplate');
            }
            custData['selectedNameplateIds'] = npIds;
          }
        }

        final badgeUrl = extractUrl(highestSvipData, [
          'badgeMediaUrl', 'badgeUrl', 'badgeImage', 'badge', 'iconUrl', 'badgeIcon', 'icon'
        ]);
        final frameUrl = extractUrl(highestSvipData, [
          'frameMediaUrl', 'frameUrl', 'frameImage', 'frame', 'avatarFrameUrl', 'avatarFrameMediaUrl', 'avatarFrame'
        ]);
        final entryEffectUrl = extractUrl(highestSvipData, [
          'entryEffectMediaUrl', 'entryEffectUrl', 'entryEffectImage', 'entryEffect', 'entryMediaUrl', 'entryUrl', 'entryTagUrl', 'entryTagMediaUrl', 'entryTag', 'entranceEffectUrl'
        ]);
        final profileSkinUrl = extractUrl(highestSvipData, [
          'profileSkinMediaUrl', 'profileSkinUrl', 'profileSkinImage', 'profileSkin', 'profileCardMediaUrl', 'profileCardUrl', 'profileCardImage', 'profileCard', 'cardUrl', 'cardMediaUrl', 'backgroundThemeUrl', 'backgroundThemeMediaUrl'
        ]);
        final nameplateUrl = extractUrl(highestSvipData, [
          'nameplateMediaUrl', 'nameplateUrl', 'nameplateImage', 'nameplate', 'svipTagMediaUrl', 'svipTagUrl', 'svipTagImage', 'svipTag', 'tagMediaUrl', 'tagUrl', 'tagImage', 'tag'
        ]);

        addAssetToInventory('ownedBadges', badgeUrl, 'svip_${levelId}_badge');
        addAssetToInventory('ownedFrames', frameUrl, 'svip_${levelId}_frame');
        addAssetToInventory('ownedEntryEffects', entryEffectUrl, 'svip_${levelId}_entry');
        addAssetToInventory('ownedBackgroundThemes', profileSkinUrl, 'svip_${levelId}_skin');
        addAssetToInventory('ownedNameplates', nameplateUrl, 'svip_${levelId}_nameplate');

        // Requirement 5: VIP/SVIP Nameplate is automatically active
        if (nameplateUrl.isNotEmpty) {
          final nameplateStoreId = 'svip_${levelId}_nameplate';
          custData['selectedNameplateId'] = nameplateStoreId;
          custData['selectedNameplateUrl'] = nameplateUrl;
          custData['selectedNameplate'] = nameplateUrl;
          final currentNameplateIds = List<String>.from(custData['selectedNameplateIds'] ?? []);
          if (!currentNameplateIds.contains(nameplateStoreId)) {
            currentNameplateIds.add(nameplateStoreId);
          }
          custData['selectedNameplateIds'] = currentNameplateIds;
          hasUpdates = true;
        }

        final expiryDate = DateTime(now.year, now.month + 2, 0, 23, 59, 59);
        final List<Map<String, String>> itemsToAdd = [
          {'type': 'badge', 'idSuffix': 'badge', 'name': 'SVIP $levelNum Badge', 'url': badgeUrl},
          {'type': 'avatarFrame', 'idSuffix': 'frame', 'name': 'SVIP $levelNum Frame', 'url': frameUrl},
          {'type': 'entryEffect', 'idSuffix': 'entry', 'name': 'SVIP $levelNum Entry Effect', 'url': entryEffectUrl},
          {'type': 'backgroundTheme', 'idSuffix': 'skin', 'name': 'SVIP $levelNum Profile Skin', 'url': profileSkinUrl},
          {'type': 'nameplate', 'idSuffix': 'nameplate', 'name': 'SVIP $levelNum Nameplate', 'url': nameplateUrl},
        ];

        for (final item in itemsToAdd) {
          final url = item['url'] ?? '';
          if (url.isNotEmpty) {
            final storeItemId = 'svip_${levelId}_${item['idSuffix']}';
            final docRef = _firestore
                .collection('user_store_items')
                .doc('${userId}_$storeItemId');

            transaction.set(docRef, {
              'userId': userId,
              'storeItemId': storeItemId,
              'storeItemName': item['name'],
              'name': item['name'],
              'itemType': item['type'],
              'type': item['type'],
              'imageUrl': url,
              'fileUrl': url,
              'thumbnailUrl': url,
              'image': url,
              'assignedAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(expiryDate),
              'isActive': true,
            }, SetOptions(merge: true));
          }
        }

        // Send Notification
        try {
          final deviceToken = userData['deviceToken'] ?? '';
          await OfficialTeamApi.sendOfficialMessage(
            receiverId: userId,
            receiverDeviceToken: deviceToken,
            messageText: "🎉 Congratulations! You have unlocked SVIP Level $highestEligibleSvip. All SVIP rewards (Badge, Frame, Entry Effect, Profile Card, and Nameplate) have been unlocked in your My Items & Decorations in real time!",
          );
        } catch (e) {
          debugPrint('⚠️ SvipService: Error sending SVIP notification: $e');
        }
      }

      if (hasUpdates) {
        transaction.update(userRef, {'customization': custData});
      }

      if (highestEligibleSvip > currentActiveSvip) {
        cleanupPreviousSvipItemsFromFirestore(userId, highestEligibleSvip);
      }
    } catch (e) {
      debugPrint('Error auto-upgrading SVIP: $e');
    }
  }

  /// Automatically check if VIP or SVIP has expired, and clean up all rewards & statuses
  static Future<void> checkAndCleanupExpiredVipAndSvip(String userId, [Map<String, dynamic>? initialData]) async {
    try {
      final userRef = _firestore.collection('Users').doc(userId);
      Map<String, dynamic> userData = initialData ?? {};
      if (userData.isEmpty) {
        final snap = await userRef.get();
        if (!snap.exists || snap.data() == null) return;
        userData = snap.data()!;
      }

      final int activeVip = (userData['activeVipLevel'] as num?)?.toInt() ?? 0;
      DateTime? vipValidUntil;
      if (userData['vipValidUntil'] != null) {
        if (userData['vipValidUntil'] is Timestamp) {
          vipValidUntil = (userData['vipValidUntil'] as Timestamp).toDate();
        } else if (userData['vipValidUntil'] is String) {
          vipValidUntil = DateTime.tryParse(userData['vipValidUntil'].toString());
        }
      }
      final String vipValidMonth = (userData['vipValidUntilMonth'] ?? '').toString();

      final int activeSvip = (userData['activeSvipLevel'] as num?)?.toInt() ?? 0;
      final String svipValidMonth = (userData['svipValidUntilMonth'] ?? '').toString();

      final bool vipStillValid = isVipActive(activeVip, vipValidUntil, vipValidMonth);
      final bool svipStillValid = isSvipActive(activeSvip, svipValidMonth);

      bool needsUserUpdate = false;
      final Map<String, dynamic> userUpdates = {};
      Map<String, dynamic> custData = Map<String, dynamic>.from(userData['customization'] ?? {});
      bool custModified = false;

      // VIP Expired Cleanup
      if (activeVip > 0 && !vipStillValid) {
        debugPrint('⏰ [SvipService] VIP expired for user $userId (expiry: $vipValidUntil). Cleaning up...');
        userUpdates['activeVipLevel'] = 0;
        userUpdates['vipValidUntil'] = null;
        userUpdates['vipValidUntilMonth'] = '';
        needsUserUpdate = true;

        // Unequip VIP items
        if (custData['selectedNameplateId']?.toString().startsWith('vip_') ?? false) {
          custData['selectedNameplateId'] = null;
          custData['selectedNameplateUrl'] = null;
          custData['selectedNameplate'] = null;
          custModified = true;
        }
        if (custData['selectedNameplateIds'] is List) {
          final list = List<String>.from(custData['selectedNameplateIds']);
          list.removeWhere((id) => id.startsWith('vip_'));
          custData['selectedNameplateIds'] = list;
          custModified = true;
        }
        if (custData['selectedFrameId']?.toString().startsWith('vip_') ?? false) {
          custData['selectedFrameId'] = null;
          custModified = true;
        }
        if (custData['selectedEntryEffectId']?.toString().startsWith('vip_') ?? false) {
          custData['selectedEntryEffectId'] = null;
          custModified = true;
        }
        if (custData['selectedBackgroundThemeId']?.toString().startsWith('vip_') ?? false) {
          custData['selectedBackgroundThemeId'] = null;
          custModified = true;
        }

        // Clean VIP items from owned lists
        void cleanOwned(String key) {
          if (custData[key] is List) {
            final list = List<String>.from(custData[key]);
            final initialLen = list.length;
            list.removeWhere((item) => item.contains('vip_'));
            if (list.length != initialLen) {
              custData[key] = list;
              custModified = true;
            }
          }
        }
        cleanOwned('ownedBadges');
        cleanOwned('ownedFrames');
        cleanOwned('ownedEntryEffects');
        cleanOwned('ownedBackgroundThemes');
        cleanOwned('ownedNameplates');

        // Delete / deactivate VIP items from user_store_items
        _cleanupStoreItemsPrefix(userId, 'vip_');
      }

      // SVIP Expired Cleanup
      if (activeSvip > 0 && !svipStillValid) {
        debugPrint('⏰ [SvipService] SVIP expired for user $userId (validUntilMonth: $svipValidMonth). Cleaning up...');
        userUpdates['activeSvipLevel'] = 0;
        userUpdates['svipValidUntilMonth'] = '';
        needsUserUpdate = true;

        // Unequip SVIP items
        if (custData['selectedNameplateId']?.toString().startsWith('svip_') ?? false) {
          custData['selectedNameplateId'] = null;
          custData['selectedNameplateUrl'] = null;
          custData['selectedNameplate'] = null;
          custModified = true;
        }
        if (custData['selectedNameplateIds'] is List) {
          final list = List<String>.from(custData['selectedNameplateIds']);
          list.removeWhere((id) => id.startsWith('svip_'));
          custData['selectedNameplateIds'] = list;
          custModified = true;
        }
        if (custData['selectedFrameId']?.toString().startsWith('svip_') ?? false) {
          custData['selectedFrameId'] = null;
          custModified = true;
        }
        if (custData['selectedEntryEffectId']?.toString().startsWith('svip_') ?? false) {
          custData['selectedEntryEffectId'] = null;
          custModified = true;
        }
        if (custData['selectedBackgroundThemeId']?.toString().startsWith('svip_') ?? false) {
          custData['selectedBackgroundThemeId'] = null;
          custModified = true;
        }

        // Clean SVIP items from owned lists
        void cleanOwned(String key) {
          if (custData[key] is List) {
            final list = List<String>.from(custData[key]);
            final initialLen = list.length;
            list.removeWhere((item) => item.contains('svip_'));
            if (list.length != initialLen) {
              custData[key] = list;
              custModified = true;
            }
          }
        }
        cleanOwned('ownedBadges');
        cleanOwned('ownedFrames');
        cleanOwned('ownedEntryEffects');
        cleanOwned('ownedBackgroundThemes');
        cleanOwned('ownedNameplates');

        // Delete / deactivate SVIP items from user_store_items
        _cleanupStoreItemsPrefix(userId, 'svip_');
      }

      if (custModified) {
        userUpdates['customization'] = custData;
        needsUserUpdate = true;
      }

      if (needsUserUpdate) {
        await userRef.update(userUpdates);
      }
    } catch (e) {
      debugPrint('⚠️ [SvipService] Error during expiration cleanup: $e');
    }
  }

  static Future<void> _cleanupStoreItemsPrefix(String userId, String prefix) async {
    try {
      final snap = await _firestore
          .collection('user_store_items')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      bool hasDeletes = false;

      for (final doc in snap.docs) {
        final storeItemId = doc.data()['storeItemId']?.toString() ?? '';
        if (storeItemId.startsWith(prefix)) {
          batch.delete(doc.reference);
          hasDeletes = true;
        }
      }

      if (hasDeletes) {
        await batch.commit();
        debugPrint('🧹 [SvipService] Removed expired store items with prefix $prefix for user $userId');
      }
    } catch (e) {
      debugPrint('⚠️ [SvipService] Error removing store items for prefix $prefix: $e');
    }
  }

  /// Asynchronously sweeps user_store_items to delete any items from older SVIP levels
  static Future<void> cleanupPreviousSvipItemsFromFirestore(String userId, int newSvipLevel) async {
    try {
      final snap = await _firestore
          .collection('user_store_items')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      bool hasDeletes = false;

      for (final doc in snap.docs) {
        final storeItemId = doc.data()['storeItemId']?.toString() ?? '';
        if (storeItemId.startsWith('svip_svip')) {
          final match = RegExp(r'svip_svip(\d+)_').firstMatch(storeItemId);
          if (match != null) {
            final oldLevel = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (oldLevel > 0 && oldLevel < newSvipLevel) {
              batch.delete(doc.reference);
              hasDeletes = true;
            }
          }
        }
      }

      if (hasDeletes) {
        await batch.commit();
        debugPrint('🧹 [SvipService] Cleaned up previous SVIP items for user $userId (upgraded to SVIP $newSvipLevel)');
      }
    } catch (e) {
      debugPrint('⚠️ [SvipService] Error during async cleanup of previous SVIP items: $e');
    }
  }
}
