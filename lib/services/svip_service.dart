import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:chat_messenger/api/official_team_api.dart';

class SvipService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      final bool isLevelUpgrade = highestEligibleSvip > currentActiveSvip;
      final bool isMonthlyRenewal = userValidUntilMonth != currentMonth;
      final bool shouldApply = highestEligibleSvip > 0 && highestSvipData != null && (isLevelUpgrade || isMonthlyRenewal || highestEligibleSvip >= currentActiveSvip);

      // Apply SVIP Upgrade / Renewal / Sync if eligible
      if (shouldApply) {
        final levelId = highestSvipData['id'] as String;
        final levelNum = levelId.replaceAll(RegExp(r'[^0-9]'), '');
        final claimedRef = _firestore.collection('Users').doc(userId).collection('claimed_svips').doc(currentMonth);
        transaction.set(claimedRef, {levelId: true}, SetOptions(merge: true));

        transaction.update(userRef, {
          'activeSvipLevel': highestEligibleSvip,
          'svipValidUntilMonth': currentMonth,
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

        final now = DateTime.now();
        final nextMonth = DateTime(now.year, now.month + 1, 1);
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
              'expiresAt': Timestamp.fromDate(nextMonth),
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
