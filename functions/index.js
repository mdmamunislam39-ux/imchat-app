
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp({
  databaseURL: "https://imchat-84519-default-rtdb.firebaseio.com",
  storageBucket: "imchat-84519.appspot.com",
});


const firestore = admin.firestore();


// Import the ONLY Agora token generation function we need
const { generateAgoraToken } = require("./agora-token-generator");

// Export ONLY the main Agora function
exports.generateAgoraToken = generateAgoraToken;

// Real-time event leaderboard & room earning triggers
const realtimeEvents = require('./realtime_events');
exports.onGiftTransaction = realtimeEvents.onGiftTransaction;
exports.onRechargeTransaction = realtimeEvents.onRechargeTransaction;
exports.onGreedyGameWin = realtimeEvents.onGreedyGameWin;
exports.onFruitWheelWin = realtimeEvents.onFruitWheelWin;

// Event reward distribution cron job (every 5 minutes)
const eventRewards = require('./event_rewards_cron');
exports.distributeEventRewards = eventRewards.distributeEventRewards;

// Trending scores calculation cron job (every 10 minutes)
const trendingCron = require('./trending_cron');
exports.calculateTrendingScores = trendingCron.calculateTrendingScores;

// Lucky Bag Voice Room Cloud Functions
const luckyBag = require('./lucky_bag');
exports.createLuckyBag = luckyBag.createLuckyBag;
exports.claimLuckyBag = luckyBag.claimLuckyBag;

// SVIP Management & Seller Recharge
const svipManager = require('./svip_manager');

exports.sellerRecharge = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }
  const sellerUid = context.auth.uid;
  const targetUserId = data.targetUserId;
  const amount = Number(data.amount);

  if (!targetUserId || !amount || isNaN(amount) || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid target user or recharge amount.");
  }

  // Verify seller authorization
  const sellerQuerySnap = await firestore.collection('sellers').where('userId', '==', sellerUid).limit(1).get();
  if (sellerQuerySnap.empty) {
    throw new functions.https.HttpsError("permission-denied", "You are not an authorized diamond seller.");
  }

  const sellerDoc = sellerQuerySnap.docs[0];
  const sellerRef = sellerDoc.ref;
  const userRef = firestore.collection('Users').doc(targetUserId);

  const today = new Date();
  const currentMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;

  let finalMonthlyRecharge = amount;

  await firestore.runTransaction(async (transaction) => {
    const sSnap = await transaction.get(sellerRef);
    const uSnap = await transaction.get(userRef);

    if (!sSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Seller profile not found.");
    }
    if (!uSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Recipient user not found.");
    }

    const sData = sSnap.data() || {};
    const uData = uSnap.data() || {};

    if (sData.isActive === false) {
      throw new functions.https.HttpsError("permission-denied", "Seller account is inactive.");
    }

    const currentBalance = Number(sData.accountBalance || 0);
    if (currentBalance < amount) {
      throw new functions.https.HttpsError("failed-precondition", "Insufficient seller balance.");
    }

    const lastMonth = uData.lastRechargeMonth || '';
    const prevMonthly = lastMonth === currentMonth ? Number(uData.monthlyRechargeAmount || 0) : 0;
    finalMonthlyRecharge = prevMonthly + amount;

    // 1. Deduct seller balance
    transaction.update(sellerRef, {
      accountBalance: admin.firestore.FieldValue.increment(-amount),
      totalSales: admin.firestore.FieldValue.increment(amount),
      totalUsersRecharged: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Credit user diamonds & increment eligible seller recharge tracking
    transaction.update(userRef, {
      diamonds: admin.firestore.FieldValue.increment(amount),
      totalDiamonds: admin.firestore.FieldValue.increment(amount),
      monthlyRechargeAmount: finalMonthlyRecharge,
      eligibleSellerRechargeAmount: admin.firestore.FieldValue.increment(amount),
      totalEligibleSellerRechargeAmount: admin.firestore.FieldValue.increment(amount),
      lastRechargeMonth: currentMonth,
    });

    // 3. Create seller transaction record
    const txnRef = firestore.collection('seller_transactions').doc();
    transaction.set(txnRef, {
      sellerId: sellerUid,
      userId: targetUserId,
      amount: amount,
      type: 'recharge',
      source: 'seller_page',
      alreadyTrackedOnUser: true,
      description: `Seller recharge: ${amount} diamonds to ${uData.fullname || targetUserId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // 4. Trigger backend SVIP verification and auto-upgrade
  await svipManager.checkAndApplySvipUpgrade(targetUserId, finalMonthlyRecharge, currentMonth);

  return { success: true, amount: amount, monthlyRecharge: finalMonthlyRecharge };
});



exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  try {
    const { type, title, body, deviceToken, senderId, call } = data;

    // Check auth
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
    }

    // Validate parameters
    if (!type || !title || !body || !deviceToken || !senderId) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
    }
    const isCallNotification = type === "call";
    
    // Build notification message
    const message = {
      token: deviceToken,
      data: {
        type: type,
        call: JSON.stringify(call || {}),
        senderId: senderId,
        senderAvatar: data.senderAvatar || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        status: "done",
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        ttl: isCallNotification ? 60 * 1000 : 86400 * 1000,
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          },
        },
      },
    };

    if (!isCallNotification) {
      // For iOS native notification
      message.apns.payload.aps.alert = {
        title: title,
        body: body,
      };
      // We DO NOT set message.notification = ...
      // So Android receives a data-only message and we can handle it manually with flutter_local_notifications
    }

    const response = await admin.messaging().send(message);
    const successMsg = `Send push notification success. Response: ${response}`;
    console.log(successMsg);
    return successMsg;
  } catch (error) {
    const errorMsg = `Failed to send push notification. ${error}`;
    console.error(errorMsg);
    throw new functions.https.HttpsError("internal", errorMsg);
  }
});


exports.updateUserPresence = functions.database.ref("/{uid}/isOnline").onUpdate(
  async (change, context) => {
    const isOnline = change.after.val();
    const userRef = firestore.doc(`Users/${context.params.uid}`);

    const data = { isOnline: isOnline, lastActive: Date.now() };

    if (isOnline === false) {
      data.isTyping = false;
      data.isRecording = false;
    }

    return userRef.update(data);
  },
);


//
// <-- STORIES section -->
//

async function deleteFileFromStorage(fileUrl) {
  try {
    // Extract the file path from the URL
    const filePath = new URL(fileUrl).pathname.split("/").pop().replace(/%2F/g, "/");

    // Delete the file from Firebase Storage
    await storage.file(filePath).delete();
  } catch (error) {
    console.error("Error deleting file from storage:", error);
  }
}

/**
 *
 * @param {Array} files
 * @param {Number} currentTime
 * @param {Number} expirationTime
 * @return Array
 */
function filterAndDeleteExpiredFiles(files, currentTime, expirationTime) {
  const expiredFiles = files.filter((file) => file.createdAt < currentTime - expirationTime);

  for (const file of expiredFiles) {
    if (file.imageUrl !== undefined) {
      deleteFileFromStorage(file.imageUrl);
    } else {
      deleteFileFromStorage(file.videoUrl);
      deleteFileFromStorage(file.thumbnailUrl);
    }
  }

  return files.filter((file) => file.createdAt >= currentTime - expirationTime);
}


exports.deleteExpiredStories = functions.pubsub.schedule("every 1 hours")
  .timeZone("UTC").onRun(async (context) => {
    const expirationTime = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    const currentTime = new Date().getTime();

    const stories = await firestore.collection("Stories").get();

    if (stories.empty) {
      return null;
    }

    const batch = firestore.batch();

    stories.forEach((doc) => {
      const story = doc.data();

      // Filter out expired story texts
      const texts = story.texts
        .filter((text) => text.createdAt >= currentTime - expirationTime);

      // Filter out and delete expired image files
      const images = filterAndDeleteExpiredFiles(story.images, currentTime, expirationTime);

      // Filter out and delete expired video files
      const videos = filterAndDeleteExpiredFiles(story.videos, currentTime, expirationTime);


      // If any of the arrays were modified, update the story
      if (texts.length !== story.texts.length ||
        images.length !== story.images.length ||
        videos.length !== story.videos.length) {
        const totalStories = (texts.length + images.length + videos.length);

        if (totalStories === 0) {
          batch.delete(doc.ref);
        } else {
          batch.update(doc.ref, {
            texts: texts,
            images: images,
            videos: videos,
          });
        }
      }
    });

    // Commit the batch to Firestore
    await batch.commit();

    return null;
  });

//
// <-- END STORIES section -->
//
//
// <-- LEADERBOARD CLEANUP section -->
//
const leaderboardCleanup = require("./leaderboard_cleanup");
exports.resetDailyContributions = leaderboardCleanup.resetDailyContributions;
exports.resetWeeklyContributions = leaderboardCleanup.resetWeeklyContributions;
exports.resetMonthlyContributions = leaderboardCleanup.resetMonthlyContributions;
// <-- END LEADERBOARD CLEANUP section -->
//

//
// <-- FRUIT WHEEL GAME section -->
//
const fruitWheel = require("./fruit_wheel");
exports.tickFruitWheelGame = fruitWheel.tickFruitWheelGame;
exports.placeFruitWheelBet = fruitWheel.placeFruitWheelBet;
//
//
// <-- END FRUIT WHEEL GAME section -->
//

//
// <-- AGENCY COMMISSION section -->
const agencyCommission = require("./agency_commission");
exports.processWeeklyCommissions = agencyCommission.processWeeklyCommissions;
// <-- END AGENCY COMMISSION section -->

//
// <-- AUDIO ROOM PRESENCE CLEANUP -->
//
exports.onAudioRoomPresenceDelete = functions.database.ref("/audio_room_presence/{roomId}/{userId}").onDelete(
  async (snapshot, context) => {
    const roomId = context.params.roomId;
    const userId = context.params.userId;

    console.log(`User ${userId} disconnected or left room ${roomId}. Cleaning up Firestore...`);

    const roomRef = firestore.collection("audio_rooms").doc(roomId);

    try {
      // Get the room
      const roomDoc = await roomRef.get();
      if (!roomDoc.exists) return;

      const roomData = roomDoc.data();
      const participants = roomData.participants || [];

      // Check if user is actually in the room
      const participantIndex = participants.findIndex((p) => p.userId === userId);
      const isParticipant = participantIndex !== -1;

      // Also check and clear any seat occupied by this user
      const updatedSeats = roomData.settings?.seatConfiguration ? [...roomData.settings.seatConfiguration] : [];
      let seatModified = false;
      for (let i = 0; i < updatedSeats.length; i++) {
        if (updatedSeats[i].occupiedBy === userId) {
          updatedSeats[i].occupiedBy = null;
          seatModified = true;
        }
      }

      if (!isParticipant && !seatModified) {
        console.log(`User ${userId} is not in room ${roomId} and not seated. No cleanup needed.`);
        return;
      }

      // Remove participant
      const updatedParticipants = participants.filter((p) => p.userId !== userId);

      // If creator disconnects from a Live room, end the live room
      const isCreator = (roomData.creatorId === userId);
      let isActive = roomData.isActive !== false;
      if (isCreator && roomData.category === "Live") {
        isActive = false;
      }

      const updateData = {
        participants: updatedParticipants,
        isActive: isActive,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (roomData.settings) {
        updateData["settings.seatConfiguration"] = updatedSeats;
      }

      await roomRef.update(updateData);
      console.log(`Successfully cleaned up presence for user ${userId} in room ${roomId}`);
    } catch (error) {
      console.error(`Error cleaning up room presence for ${userId} in ${roomId}:`, error);
    }
  },
);

//
// <-- GREEDY GAME section -->
//
const greedyGame = require('./greedy_game');
exports.tickGreedyGame = greedyGame.tickGreedyGame;
exports.placeGreedyGameBet = greedyGame.placeGreedyGameBet;

const pinkGreedyGame = require('./pink_greedy_game');
exports.tickPinkGreedyGame = pinkGreedyGame.tickPinkGreedyGame;
exports.placePinkGreedyGameBet = pinkGreedyGame.placePinkGreedyGameBet;
// <-- END GREEDY GAME section -->

//
// <-- GAME AUTO TICK LOOP -->
//
exports.autoTickGamesLoop = functions.pubsub.schedule('* * * * *').onRun(async (context) => {
    // Run a loop for 55 seconds to continuously tick the games without hitting 60s boundary immediately
    const endTime = Date.now() + 55000;
    while(Date.now() < endTime) {
        try {
            // Await all ticks simultaneously
            await Promise.all([
                greedyGame.runGreedyTick(),
                pinkGreedyGame.runPinkGreedyTick(),
                fruitWheel.runFruitWheelTick()
            ]);
        } catch (e) {
            console.error("Auto tick error:", e);
        }
        // sleep for 1 second before next tick
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    return null;
});
// <-- END GAME AUTO TICK LOOP -->
