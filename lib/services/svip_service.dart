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
      int currentActiveLevel = userData['activeSvipLevel'] ?? 0;
      int highestEligibleLevel = currentActiveLevel;
      Map<String, dynamic>? highestLevelData;

      for (var level in svipLevels) {
        final levelId = level['id'] as String;
        final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final rawTarget = level['rechargeTarget'];
        final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
        
        if (newRechargeAmount >= target && levelNum > highestEligibleLevel) {
          highestEligibleLevel = levelNum;
          highestLevelData = level;
        }
      }

      if (highestEligibleLevel > currentActiveLevel && highestLevelData != null) {
        final levelId = highestLevelData['id'] as String;

        // Mark as claimed for the month
        final claimedRef = _firestore.collection('Users').doc(userId).collection('claimed_svips').doc(currentMonth);
        transaction.set(claimedRef, {levelId: true}, SetOptions(merge: true));

        // Update Level
        transaction.update(userRef, {
          'activeSvipLevel': highestEligibleLevel,
          'svipValidUntilMonth': currentMonth,
        });

        // Add assets to inventory
        Map<String, dynamic> custData = userData['customization'] ?? {};
        void addAssetToInventory(String listKey, String url) {
          if (url.isNotEmpty) {
            List<String> currentList = List<String>.from(custData[listKey] ?? []);
            if (!currentList.contains(url)) {
              currentList.add(url);
              custData[listKey] = currentList;
            }
          }
        }

        addAssetToInventory('ownedBadges', (highestLevelData['badgeMediaUrl']?.toString() ?? '').isNotEmpty ? highestLevelData['badgeMediaUrl'] : highestLevelData['badgeUrl'] ?? '');
        addAssetToInventory('ownedFrames', (highestLevelData['frameMediaUrl']?.toString() ?? '').isNotEmpty ? highestLevelData['frameMediaUrl'] : highestLevelData['frameUrl'] ?? '');
        addAssetToInventory('ownedEntryEffects', (highestLevelData['entryEffectMediaUrl']?.toString() ?? '').isNotEmpty ? highestLevelData['entryEffectMediaUrl'] : highestLevelData['entryEffectUrl'] ?? '');
        addAssetToInventory('ownedBackgroundThemes', (highestLevelData['profileSkinMediaUrl']?.toString() ?? '').isNotEmpty ? highestLevelData['profileSkinMediaUrl'] : highestLevelData['profileSkinUrl'] ?? '');
        addAssetToInventory('ownedNameplates', (highestLevelData['nameplateMediaUrl']?.toString() ?? '').isNotEmpty ? highestLevelData['nameplateMediaUrl'] : highestLevelData['nameplateUrl'] ?? '');

        transaction.update(userRef, {'customization': custData});

        // Send imChat Team Notification about SVIP level upgrade and assets unlocked
        try {
          final deviceToken = userData['deviceToken'] ?? '';
          await OfficialTeamApi.sendOfficialMessage(
            receiverId: userId,
            receiverDeviceToken: deviceToken,
            messageText: "🎉 Congratulations! You have unlocked SVIP Level $highestEligibleLevel. SVIP rewards (Frames, Entry Effects, and Background Skins) have been unlocked and added to your profile/room customization settings!",
          );
        } catch (e) {
          debugPrint('⚠️ SvipService: Error sending notification: $e');
        }
      }
    } catch (e) {
      debugPrint('Error auto-upgrading SVIP: $e');
    }
  }
}
