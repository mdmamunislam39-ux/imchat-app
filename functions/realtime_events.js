const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');
const firestore = admin.firestore();

let activeEventsCache = null;
let lastEventsCacheTime = 0;

async function getActiveEvents() {
  const now = Date.now();
  if (!activeEventsCache || now - lastEventsCacheTime > 60000) {
    try {
      const snap = await firestore.collection('events').where('status', '==', 'active').get();
      activeEventsCache = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      lastEventsCacheTime = now;
    } catch (e) {
      console.error("Error fetching active events", e);
      return [];
    }
  }
  return activeEventsCache;
}

// 1. Room Earning & Sender/Receiver Leaderboards Real-Time Trigger
// Triggers when a new gift transaction is logged
exports.onGiftTransaction = functions.region('asia-south1').firestore
  .document('gift_transactions/{transactionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const roomId = data.roomId;
    const credits = data.credits || 0;
    const senderId = data.senderId;
    const receiverId = data.receiverId;

    if (!data || credits <= 0) return null;

    const batch = firestore.batch();

    // A. Room Earning (if inside a room)
    // NOTE: audio_rooms_v2 totalRevenue is handled entirely by the mobile app (GiftService).
    // Updating it here caused double-counting.
    // (Intentionally removed to prevent double-count)

    // B. Leaderboards Stats collection (Generic)
    const today = new Date();
    const currentMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
    const currentWeek = `${today.getFullYear()}-W${getWeekNumber(today)}`;
    const currentDay = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    if (senderId) {
      const senderRef = firestore.collection('leaderboard_stats').doc(senderId);
      batch.set(senderRef, {
        totalSent: admin.firestore.FieldValue.increment(credits),
        [`sent_${currentDay}`]: admin.firestore.FieldValue.increment(credits),
        [`sent_${currentWeek}`]: admin.firestore.FieldValue.increment(credits),
        [`sent_${currentMonth}`]: admin.firestore.FieldValue.increment(credits),
      }, { merge: true });

      // C. Update Users collection fields for RoomTopRankingsScreen (Donators/Sent)
      // NOTE: User diamond fields are handled entirely by the mobile app (GiftService).
      // Updating them here caused double-counting.
      // (Intentionally removed to prevent double-count)
    }

    if (receiverId) {
      const receiverRef = firestore.collection('leaderboard_stats').doc(receiverId);
      batch.set(receiverRef, {
        totalReceived: admin.firestore.FieldValue.increment(credits),
        [`received_${currentDay}`]: admin.firestore.FieldValue.increment(credits),
        [`received_${currentWeek}`]: admin.firestore.FieldValue.increment(credits),
        [`received_${currentMonth}`]: admin.firestore.FieldValue.increment(credits),
      }, { merge: true });

      // D. Update Users collection fields for RoomTopRankingsScreen (Receivers/Received)
      // NOTE: User diamond fields are handled entirely by the mobile app (GiftService).
      // Updating them here caused double-counting.
      // (Intentionally removed to prevent double-count)

      // E. Update Agency Leaderboard Stats if Receiver is in an Agency
      const receiverSnap = await userReceiverRef.get();
      if (receiverSnap.exists) {
        const agencyId = receiverSnap.data().agencyId;
        if (agencyId) {
          const agencyStatsRef = firestore.collection('leaderboard_stats').doc(agencyId);
          batch.set(agencyStatsRef, {
            totalReceived: admin.firestore.FieldValue.increment(credits),
            [`received_${currentDay}`]: admin.firestore.FieldValue.increment(credits),
            [`received_${currentWeek}`]: admin.firestore.FieldValue.increment(credits),
            [`received_${currentMonth}`]: admin.firestore.FieldValue.increment(credits),
            isAgency: true,
          }, { merge: true });
        }
      }
    }

    // F. Track active events
    const activeEvents = await getActiveEvents();
    if (activeEvents && activeEvents.length > 0) {
      for (const event of activeEvents) {
        const eventPrefix = event.id.replace(/-/g, '_');
        const isWeeklyStar = event.eventType === 'weekly_star';
        const isRoomEvent = event.eventType === 'top_room';
        const isGifterReceiver = event.eventType === 'gifter_receiver';

        // Filter by eligible gifts
        if (isWeeklyStar && event.eligibleGiftIds && event.eligibleGiftIds.length > 0) {
          if (!event.eligibleGiftIds.includes(data.giftId?.toString())) continue;
        }

        // Filter by registration
        let senderRegistered = true;
        let receiverRegistered = true;
        
        if (event.hasRegistrationForm) {
          if (senderId) {
            const senderReg = await firestore.collection('events').doc(event.id).collection('registrations').doc(senderId).get();
            senderRegistered = senderReg.exists;
          } else {
            senderRegistered = false;
          }
          if (receiverId) {
            const receiverReg = await firestore.collection('events').doc(event.id).collection('registrations').doc(receiverId).get();
            receiverRegistered = receiverReg.exists;
          } else {
            receiverRegistered = false;
          }
        }

        // Add to Event specific stats
        if (senderId && senderRegistered) {
          batch.set(firestore.collection('leaderboard_stats').doc(senderId), {
            [`event_${eventPrefix}_sent`]: admin.firestore.FieldValue.increment(credits)
          }, { merge: true });
        }
        
        if (receiverId && receiverRegistered) {
          batch.set(firestore.collection('leaderboard_stats').doc(receiverId), {
            [`event_${eventPrefix}_received`]: admin.firestore.FieldValue.increment(credits)
          }, { merge: true });
        }

        // Top Room Event Tracking
        if (isRoomEvent && roomId && roomId !== '0') {
          // No registration check for room itself, but can check receiver.
          if (!event.hasRegistrationForm || receiverRegistered) {
            batch.set(firestore.collection('leaderboard_stats').doc(`room_${roomId}`), {
              isRoom: true,
              roomId: roomId,
              [`event_${eventPrefix}_received`]: admin.firestore.FieldValue.increment(credits)
            }, { merge: true });
          }
        }
      }
    }

    await batch.commit();
    return null;
  });

// 2. Recharge Event & Leaderboard Real-Time Trigger
const svipManager = require('./svip_manager');

exports.onRechargeTransaction = functions.region('asia-south1').firestore
  .document('seller_transactions/{transactionId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.type !== 'recharge' || !data.userId || !data.amount) return null;

    const userId = data.userId;
    const amount = Number(data.amount);

    const today = new Date();
    const currentMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
    const currentWeek = `${today.getFullYear()}-W${getWeekNumber(today)}`;
    const currentDay = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    const batch = firestore.batch();

    // 1. Leaderboard stats
    const userStatsRef = firestore.collection('leaderboard_stats').doc(userId);
    batch.set(userStatsRef, {
      totalRecharge: admin.firestore.FieldValue.increment(amount),
      [`recharge_${currentDay}`]: admin.firestore.FieldValue.increment(amount),
      [`recharge_${currentWeek}`]: admin.firestore.FieldValue.increment(amount),
      [`recharge_${currentMonth}`]: admin.firestore.FieldValue.increment(amount),
    }, { merge: true });

    // 2. User recharge tracking
    const userRef = firestore.collection('Users').doc(userId);
    const userSnap = await userRef.get();
    let currentMonthlyRecharge = amount;

    if (userSnap.exists) {
      const userData = userSnap.data() || {};
      const lastMonth = userData.lastRechargeMonth || '';
      
      if (data.alreadyTrackedOnUser === true) {
        // Already updated by sellerRecharge callable function
        currentMonthlyRecharge = Number(userData.monthlyRechargeAmount || amount);
        batch.update(userRef, {
          dailyRechargeAmount: admin.firestore.FieldValue.increment(amount),
          weeklyRechargeAmount: admin.firestore.FieldValue.increment(amount),
          totalRechargeAmount: admin.firestore.FieldValue.increment(amount),
        });
      } else {
        // Fallback / legacy path: calculate monthly recharge safely
        const prevMonthly = lastMonth === currentMonth ? Number(userData.monthlyRechargeAmount || 0) : 0;
        currentMonthlyRecharge = prevMonthly + amount;
        
        batch.update(userRef, {
          dailyRechargeAmount: admin.firestore.FieldValue.increment(amount),
          weeklyRechargeAmount: admin.firestore.FieldValue.increment(amount),
          totalRechargeAmount: admin.firestore.FieldValue.increment(amount),
          monthlyRechargeAmount: currentMonthlyRecharge,
          eligibleSellerRechargeAmount: admin.firestore.FieldValue.increment(amount),
          totalEligibleSellerRechargeAmount: admin.firestore.FieldValue.increment(amount),
          lastRechargeMonth: currentMonth,
        });
      }
    }

    await batch.commit();

    // 3. Backend SVIP Verification & Auto-Upgrade (Seller Recharge ONLY)
    await svipManager.checkAndApplySvipUpgrade(userId, currentMonthlyRecharge, currentMonth);

    return null;
  });

// Helper function to get week number
function getWeekNumber(d) {
  d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
}

// 3. Game Star Event Triggers
exports.onGreedyGameWin = functions.region('asia-south1').firestore
  .document('gready_game_leaderboard/daily/{dateId}/{userId}')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    
    if (!after || !change.after.exists) return null;
    
    const wonAfter = after.totalWon || 0;
    const wonBefore = before ? (before.totalWon || 0) : 0;
    const prize = wonAfter - wonBefore;
    
    if (prize <= 0) return null;

    const userId = context.params.userId;
    const batch = firestore.batch();
    const activeEvents = await getActiveEvents();
    
    if (activeEvents && activeEvents.length > 0) {
      for (const event of activeEvents) {
        if (event.eventType === 'game_star') {
          const eventPrefix = event.id.replace(/-/g, '_');
          let registered = true;
          
          if (event.hasRegistrationForm) {
            const regSnap = await firestore.collection('events').doc(event.id).collection('registrations').doc(userId).get();
            registered = regSnap.exists;
          }
          
          if (registered) {
            batch.set(firestore.collection('leaderboard_stats').doc(userId), {
              [`event_${eventPrefix}_greedy_game`]: admin.firestore.FieldValue.increment(prize)
            }, { merge: true });
          }
        }
      }
    }
    
    await batch.commit();
    return null;
  });

exports.onFruitWheelWin = functions.region('asia-south1').firestore
  .document('leaderboard_stats/{userId}')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    
    if (!after || !change.after.exists) return null;
    
    const wonAfter = after.fruit_wheel_won || 0;
    const wonBefore = before ? (before.fruit_wheel_won || 0) : 0;
    const prize = wonAfter - wonBefore;
    
    if (prize <= 0) return null;

    const userId = context.params.userId;
    const batch = firestore.batch();
    const activeEvents = await getActiveEvents();
    
    if (activeEvents && activeEvents.length > 0) {
      for (const event of activeEvents) {
        if (event.eventType === 'game_star') {
          const eventPrefix = event.id.replace(/-/g, '_');
          let registered = true;
          
          if (event.hasRegistrationForm) {
            const regSnap = await firestore.collection('events').doc(event.id).collection('registrations').doc(userId).get();
            registered = regSnap.exists;
          }
          
          if (registered) {
            batch.set(firestore.collection('leaderboard_stats').doc(userId), {
              [`event_${eventPrefix}_fruit_wheel`]: admin.firestore.FieldValue.increment(prize)
            }, { merge: true });
          }
        }
      }
    }
    
    await batch.commit();
    return null;
  });
