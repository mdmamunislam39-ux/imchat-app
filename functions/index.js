
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();


const storage = admin.storage().bucket();
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
      },
      apns: {
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
      if (participantIndex === -1) {
        console.log(`User ${userId} is not in room ${roomId}. No cleanup needed.`);
        return;
      }

      // Remove participant
      const updatedParticipants = participants.filter((p) => p.userId !== userId);

      // Also clear seat if they were sitting
      const updatedSeats = roomData.settings?.seatConfiguration || [];
      const leavingParticipant = participants[participantIndex];
      if (leavingParticipant.seatNumber !== null && leavingParticipant.seatNumber !== undefined) {
        const seatIndex = updatedSeats.findIndex((s) => s.seatNumber === leavingParticipant.seatNumber);
        if (seatIndex !== -1) {
          updatedSeats[seatIndex].occupiedBy = null;
        }
      }

      // Handle host transfer if creator leaves and there are other participants
      const isCreator = (roomData.creatorId === userId);
      if (isCreator && updatedParticipants.length > 0) {
        updatedParticipants[0].isHost = true;
      }

      const updateData = {
        participants: updatedParticipants,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (roomData.settings) {
        updateData["settings.seatConfiguration"] = updatedSeats;
      }

      await roomRef.update(updateData);
      console.log(`Successfully removed user ${userId} from room ${roomId}`);
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
