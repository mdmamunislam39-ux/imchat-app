const admin = require('firebase-admin');
const firestore = admin.firestore();

/**
 * Checks and auto-upgrades a user's SVIP level based strictly on eligible seller recharge amount.
 * 
 * @param {string} userId - User ID to evaluate
 * @param {number} eligibleRechargeAmount - Cumulative eligible seller recharge for the current month
 * @param {string} currentMonth - "YYYY-MM" string representation
 * @returns {Promise<{upgraded: boolean, newLevel: number}>}
 */
async function checkAndApplySvipUpgrade(userId, eligibleRechargeAmount, currentMonth) {
  try {
    const userRef = firestore.collection('Users').doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      console.log(`[svip_manager] User ${userId} does not exist.`);
      return { upgraded: false, newLevel: 0 };
    }

    const userData = userSnap.data() || {};
    const currentActiveSvip = Number(userData.activeSvipLevel || 0);

    // Fetch SVIP level configurations
    const svipConfigSnap = await firestore
      .collection('config')
      .doc('svip_levels')
      .collection('levels')
      .get();

    if (svipConfigSnap.empty) {
      console.log('[svip_manager] No SVIP levels configured in config/svip_levels/levels.');
      return { upgraded: false, newLevel: currentActiveSvip };
    }

    const svipLevels = svipConfigSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Find highest eligible SVIP tier based on eligible seller recharge
    let highestEligibleSvip = currentActiveSvip;
    let highestSvipData = null;

    for (const level of svipLevels) {
      const levelId = String(level.id || '');
      const levelNum = parseInt(levelId.replace(/\D/g, ''), 10) || 1;
      const rawTarget = level.rechargeTarget != null ? level.rechargeTarget : level.requiredRechargeAmount;
      const target = Number(rawTarget || 0);

      if (eligibleRechargeAmount >= target && levelNum > highestEligibleSvip) {
        highestEligibleSvip = levelNum;
        highestSvipData = level;
      }
    }

    // If no upgrade needed, return early
    if (highestEligibleSvip <= currentActiveSvip || !highestSvipData) {
      return { upgraded: false, newLevel: currentActiveSvip };
    }

    console.log(`[svip_manager] Upgrading user ${userId} from SVIP ${currentActiveSvip} to SVIP ${highestEligibleSvip} (Recharge: ${eligibleRechargeAmount})`);

    const levelId = String(highestSvipData.id || `svip${highestEligibleSvip}`);
    const levelNumStr = levelId.replace(/\D/g, '') || String(highestEligibleSvip);

    let custData = Object.assign({}, userData.customization || {});

    function addAssetToInventory(listKey, url) {
      if (url && typeof url === 'string' && url.trim().length > 0) {
        const currentList = Array.isArray(custData[listKey]) ? [...custData[listKey]] : [];
        if (!currentList.includes(url)) {
          currentList.push(url);
          custData[listKey] = currentList;
        }
      }
    }

    // Clean previous SVIP assets from customization lists
    for (const lvl of svipLevels) {
      const lId = String(lvl.id || '');
      const lNum = parseInt(lId.replace(/\D/g, ''), 10) || 0;
      if (lNum > 0 && lNum < highestEligibleSvip) {
        const oldUrls = [
          lvl.badgeMediaUrl, lvl.badgeUrl,
          lvl.frameMediaUrl, lvl.frameUrl,
          lvl.entryEffectMediaUrl, lvl.entryEffectUrl,
          lvl.profileSkinMediaUrl, lvl.profileSkinUrl,
          lvl.nameplateMediaUrl, lvl.nameplateUrl,
        ].filter(Boolean);

        for (const u of oldUrls) {
          if (Array.isArray(custData.ownedBadges)) {
            custData.ownedBadges = custData.ownedBadges.filter(item => item !== u);
          }
          if (Array.isArray(custData.ownedFrames)) {
            custData.ownedFrames = custData.ownedFrames.filter(item => item !== u);
          }
          if (Array.isArray(custData.ownedEntryEffects)) {
            custData.ownedEntryEffects = custData.ownedEntryEffects.filter(item => item !== u);
          }
          if (Array.isArray(custData.ownedBackgroundThemes)) {
            custData.ownedBackgroundThemes = custData.ownedBackgroundThemes.filter(item => item !== u);
          }
          if (Array.isArray(custData.ownedNameplates)) {
            custData.ownedNameplates = custData.ownedNameplates.filter(item => item !== u);
          }
        }
      }
    }

    // Unequip previous SVIP items if equipped
    const selFrame = String(custData.selectedFrameId || '');
    const selEntry = String(custData.selectedEntryEffectId || '');
    const selTheme = String(custData.selectedBackgroundThemeId || '');

    for (let old = 1; old < highestEligibleSvip; old++) {
      if (selFrame === `svip_svip${old}_frame`) {
        custData.selectedFrameId = null;
      }
      if (selEntry === `svip_svip${old}_entry`) {
        custData.selectedEntryEffectId = null;
      }
      if (selTheme === `svip_svip${old}_skin`) {
        custData.selectedBackgroundThemeId = null;
      }
    }

    if (Array.isArray(custData.selectedNameplateIds)) {
      let npIds = [...custData.selectedNameplateIds];
      for (let old = 1; old < highestEligibleSvip; old++) {
        npIds = npIds.filter(id => id !== `svip_svip${old}_nameplate`);
      }
      custData.selectedNameplateIds = npIds;
    }

    // Extract new asset URLs
    const badgeUrl = highestSvipData.badgeMediaUrl || highestSvipData.badgeUrl || '';
    const frameUrl = highestSvipData.frameMediaUrl || highestSvipData.frameUrl || '';
    const entryEffectUrl = highestSvipData.entryEffectMediaUrl || highestSvipData.entryEffectUrl || '';
    const profileSkinUrl = highestSvipData.profileSkinMediaUrl || highestSvipData.profileSkinUrl || '';
    const nameplateUrl = highestSvipData.nameplateMediaUrl || highestSvipData.nameplateUrl || '';

    addAssetToInventory('ownedBadges', badgeUrl);
    addAssetToInventory('ownedFrames', frameUrl);
    addAssetToInventory('ownedEntryEffects', entryEffectUrl);
    addAssetToInventory('ownedBackgroundThemes', profileSkinUrl);
    addAssetToInventory('ownedNameplates', nameplateUrl);

    // Auto-equip SVIP nameplate
    if (nameplateUrl) {
      const nameplateStoreId = `svip_${levelId}_nameplate`;
      custData.selectedNameplateId = nameplateStoreId;
      const currentNameplateIds = Array.isArray(custData.selectedNameplateIds)
        ? [...custData.selectedNameplateIds]
        : [];
      if (!currentNameplateIds.includes(nameplateStoreId)) {
        currentNameplateIds.push(nameplateStoreId);
      }
      custData.selectedNameplateIds = currentNameplateIds;
    }

    const batch = firestore.batch();

    // 1. Update user document
    batch.update(userRef, {
      activeSvipLevel: highestEligibleSvip,
      svipValidUntilMonth: currentMonth,
      customization: custData,
    });

    // 2. Mark claimed level for this month
    const claimedRef = firestore
      .collection('Users')
      .doc(userId)
      .collection('claimed_svips')
      .doc(currentMonth);
    batch.set(claimedRef, { [levelId]: true }, { merge: true });

    // 3. Delete old SVIP items from user_store_items
    const suffixes = ['badge', 'frame', 'entry', 'skin', 'nameplate'];
    for (let old = 1; old < highestEligibleSvip; old++) {
      for (const s of suffixes) {
        const oldDocRef = firestore
          .collection('user_store_items')
          .doc(`${userId}_svip_svip${old}_${s}`);
        batch.delete(oldDocRef);
      }
    }

    // 4. Provision new SVIP items into user_store_items with expiration date
    const now = new Date();
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    const expiresAtTimestamp = admin.firestore.Timestamp.fromDate(nextMonth);

    const itemsToAdd = [
      { type: 'badge', idSuffix: 'badge', name: `SVIP ${levelNumStr} Badge`, url: badgeUrl },
      { type: 'avatarFrame', idSuffix: 'frame', name: `SVIP ${levelNumStr} Frame`, url: frameUrl },
      { type: 'entryEffect', idSuffix: 'entry', name: `SVIP ${levelNumStr} Entry Effect`, url: entryEffectUrl },
      { type: 'backgroundTheme', idSuffix: 'skin', name: `SVIP ${levelNumStr} Profile Skin`, url: profileSkinUrl },
      { type: 'nameplate', idSuffix: 'nameplate', name: `SVIP ${levelNumStr} Nameplate`, url: nameplateUrl },
    ];

    for (const item of itemsToAdd) {
      if (item.url) {
        const storeItemId = `svip_${levelId}_${item.idSuffix}`;
        const itemDocRef = firestore
          .collection('user_store_items')
          .doc(`${userId}_${storeItemId}`);

        batch.set(itemDocRef, {
          userId: userId,
          storeItemId: storeItemId,
          storeItemName: item.name,
          itemType: item.type,
          imageUrl: item.url,
          assignedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: expiresAtTimestamp,
          isActive: true,
        }, { merge: true });
      }
    }

    await batch.commit();
    console.log(`[svip_manager] Successfully committed SVIP upgrade to Level ${highestEligibleSvip} for user ${userId}`);

    // Clean up any remaining older SVIP items asynchronously
    cleanupOlderSvipItems(userId, highestEligibleSvip).catch(e => {
      console.error('[svip_manager] Error during async cleanup of older items:', e);
    });

    // Send official notification message
    sendSvipUpgradeNotification(userId, userData, highestEligibleSvip).catch(e => {
      console.error('[svip_manager] Error sending SVIP upgrade notification:', e);
    });

    return { upgraded: true, newLevel: highestEligibleSvip };
  } catch (error) {
    console.error('[svip_manager] Error in checkAndApplySvipUpgrade:', error);
    return { upgraded: false, newLevel: 0 };
  }
}

/**
 * Cleans up any remaining older SVIP items in user_store_items
 */
async function cleanupOlderSvipItems(userId, newSvipLevel) {
  const snap = await firestore
    .collection('user_store_items')
    .where('userId', '==', userId)
    .get();

  if (snap.empty) return;

  const batch = firestore.batch();
  let hasDeletes = false;

  for (const doc of snap.docs) {
    const storeItemId = String(doc.data().storeItemId || '');
    if (storeItemId.startsWith('svip_svip')) {
      const match = storeItemId.match(/svip_svip(\d+)_/);
      if (match) {
        const oldLevel = parseInt(match[1], 10) || 0;
        if (oldLevel > 0 && oldLevel < newSvipLevel) {
          batch.delete(doc.ref);
          hasDeletes = true;
        }
      }
    }
  }

  if (hasDeletes) {
    await batch.commit();
    console.log(`[svip_manager] Cleaned up legacy SVIP items for user ${userId}`);
  }
}

/**
 * Sends official notification to user when SVIP level is unlocked
 */
async function sendSvipUpgradeNotification(userId, userData, newLevel) {
  try {
    const officialTeamId = 'official_team';
    const msgId = `svip_upgrade_${userId}_${newLevel}_${Date.now()}`;
    const messageText = `🎉 Congratulations! You have unlocked SVIP Level ${newLevel} via Seller Recharge! Your exclusive rewards (Frame, Entry Effect, Profile Skin, Badge, and Nameplate) have been automatically assigned and updated.`;

    const messageData = {
      msgId: msgId,
      senderId: officialTeamId,
      type: 'text',
      textMsg: messageText,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = firestore.batch();

    // 1. Message in user's official chat
    const msgRef = firestore
      .collection('Users')
      .doc(userId)
      .collection('Chats')
      .doc(officialTeamId)
      .collection('Messages')
      .doc(msgId);
    batch.set(msgRef, messageData);

    // 2. Official notification subcollection
    const notifRef = firestore
      .collection('Users')
      .doc(userId)
      .collection('official_notifications')
      .doc(msgId);
    batch.set(notifRef, messageData);

    // 3. User chat summary node
    const chatRef = firestore
      .collection('Users')
      .doc(userId)
      .collection('Chats')
      .doc(officialTeamId);
    batch.set(chatRef, {
      senderId: officialTeamId,
      msgType: 'text',
      lastMsg: messageText,
      msgId: msgId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 4. Central audit log
    const auditRef = firestore.collection('official_notification_logs').doc(msgId);
    batch.set(auditRef, {
      msgId: msgId,
      senderId: officialTeamId,
      receiverId: userId,
      messageText: messageText,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 5. Send FCM push notification if device token is available
    const deviceToken = userData.deviceToken;
    if (deviceToken) {
      const payload = {
        token: deviceToken,
        data: {
          type: 'message',
          title: 'SVIP Level Upgraded! 👑',
          body: messageText,
          senderId: officialTeamId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: { priority: 'high' },
        apns: { payload: { aps: { alert: { title: 'SVIP Level Upgraded! 👑', body: messageText }, sound: 'default' } } },
      };
      await admin.messaging().send(payload);
    }
  } catch (e) {
    console.error('[svip_manager] Failed to send push notification for SVIP upgrade:', e);
  }
}

module.exports = {
  checkAndApplySvipUpgrade,
};
