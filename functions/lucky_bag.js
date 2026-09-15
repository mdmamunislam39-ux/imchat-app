const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.firestore();

/**
 * Cloud Function: createLuckyBag
 * Server-side verification and creation of Lucky Bag.
 */
exports.createLuckyBag = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { roomId, totalAmount, maxWinners, countdownSeconds, distributionType, message, isPublic } = data;
  const userId = context.auth.uid;

  if (!roomId || !totalAmount || totalAmount <= 0 || !maxWinners || maxWinners <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
  }

  const userRef = db.collection("Users").doc(userId);
  const roomBagsRef = db.collection("audio_rooms_v2").doc(roomId).collection("lucky_bags");

  try {
    const bagId = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "User account not found.");
      }

      const userData = userDoc.data();
      // Check both 'diamonds' and 'wallet' fields for user balance
      const currentWallet = Number(userData.diamonds ?? userData.wallet ?? 0);

      if (currentWallet < totalAmount) {
        throw new functions.https.HttpsError("failed-precondition", `Insufficient balance. You need ${totalAmount} diamonds.`);
      }

      const newBalance = currentWallet - totalAmount;

      // Deduct balance on both 'diamonds' and 'wallet' fields
      transaction.update(userRef, {
        diamonds: newBalance,
        wallet: newBalance,
      });

      const newBagRef = roomBagsRef.doc();
      const now = new Date();
      const countdown = Number(countdownSeconds) || 60;
      const unlocksAt = new Date(now.getTime() + countdown * 1000);
      const expiresAt = new Date(unlocksAt.getTime() + 10 * 60 * 1000);

      const distributableAmount = Math.floor((Number(totalAmount) * 80) / 100);
      const appCommission = Number(totalAmount) - distributableAmount;

      const bagData = {
        id: newBagRef.id,
        roomId: roomId,
        senderId: userId,
        senderName: userData.fullname || "Anonymous",
        senderAvatar: userData.photoUrl || null,
        totalAmount: Number(totalAmount),
        distributableAmount: distributableAmount,
        appCommission: appCommission,
        remainingAmount: distributableAmount, // 80% pool for all winners combined
        maxWinners: Number(maxWinners),
        claimedCount: 0,
        entryFee: 0,
        distributionType: distributionType || "random",
        isPublic: Boolean(isPublic),
        message: message || "Enjoy the lucky diamonds! 🎁",
        status: "active",
        createdAt: admin.firestore.Timestamp.fromDate(now),
        unlocksAt: admin.firestore.Timestamp.fromDate(unlocksAt),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      };

      const globalBagRef = db.collection("global_lucky_bags").doc(newBagRef.id);
      transaction.set(newBagRef, bagData);
      transaction.set(globalBagRef, bagData);
      return newBagRef.id;
    });

    return { success: true, bagId };
  } catch (error) {
    console.error("❌ Error in createLuckyBag Cloud Function:", error);
    throw new functions.https.HttpsError("internal", error.message || "Failed to create Lucky Bag.");
  }
});

/**
 * Cloud Function: claimLuckyBag
 * Server-side double-average random allocation and claim processing.
 */
exports.claimLuckyBag = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { roomId, bagId } = data;
  const userId = context.auth.uid;

  if (!roomId || !bagId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing parameters.");
  }

  const bagRef = db.collection("audio_rooms_v2").doc(roomId).collection("lucky_bags").doc(bagId);
  const claimRef = bagRef.collection("claims").doc(userId);
  const userRef = db.collection("Users").doc(userId);
  const globalBagRef = db.collection("global_lucky_bags").doc(bagId);

  try {
    const rewardAmount = await db.runTransaction(async (transaction) => {
      const bagDoc = await transaction.get(bagRef);
      if (!bagDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Lucky Bag not found.");
      }

      const claimDoc = await transaction.get(claimRef);
      if (claimDoc.exists) {
        throw new functions.https.HttpsError("already-exists", "You have already claimed this Lucky Bag.");
      }

      const bagData = bagDoc.data();
      const { status, remainingAmount, maxWinners, claimedCount, distributionType, unlocksAt, expiresAt } = bagData;
      const distType = distributionType || "random";

      const now = new Date();
      if (unlocksAt && unlocksAt.toDate() > now) {
        throw new functions.https.HttpsError("failed-precondition", "Countdown is still running! Please wait.");
      }

      if (status !== "active" || (expiresAt && expiresAt.toDate() < now)) {
        throw new functions.https.HttpsError("failed-precondition", "This Lucky Bag has expired.");
      }

      if (claimedCount >= maxWinners || remainingAmount <= 0) {
        throw new functions.https.HttpsError("resource-exhausted", "All rewards in this Lucky Bag have been claimed.");
      }

      // Compute reward
      const remainingWinners = maxWinners - claimedCount;
      let calculatedReward = 0;

      if (remainingWinners === 1) {
        calculatedReward = remainingAmount;
      } else if (distType === "equal") {
        calculatedReward = Math.floor(remainingAmount / remainingWinners) || 1;
      } else {
        // Double-Average Random Algorithm
        const maxAllowed = Math.floor((remainingAmount / remainingWinners) * 2);
        calculatedReward = 1 + Math.floor(Math.random() * Math.max(1, maxAllowed));
        if (calculatedReward > remainingAmount) {
          calculatedReward = remainingAmount;
        }
      }

      const userDoc = await transaction.get(userRef);
      const userData = userDoc.exists ? userDoc.data() : {};
      const currentWallet = Number(userData.diamonds ?? userData.wallet ?? 0);
      const newBalance = currentWallet + calculatedReward;

      const newClaimedCount = claimedCount + 1;
      const newRemainingAmount = remainingAmount - calculatedReward;
      const isCompleted = newClaimedCount >= maxWinners || newRemainingAmount <= 0;

      const bagUpdate = {
        claimedCount: newClaimedCount,
        remainingAmount: newRemainingAmount,
        status: isCompleted ? "completed" : "active",
      };

      transaction.update(bagRef, bagUpdate);
      transaction.update(globalBagRef, bagUpdate);

      transaction.set(claimRef, {
        userId,
        userName: userData.fullname || "User",
        userAvatar: userData.photoUrl || null,
        rewardAmount: calculatedReward,
        isLuckyKing: false,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (userDoc.exists) {
        transaction.update(userRef, {
          diamonds: newBalance,
          wallet: newBalance,
        });
      }

      return calculatedReward;
    });

    return { success: true, rewardAmount };
  } catch (error) {
    console.error("❌ Error in claimLuckyBag Cloud Function:", error);
    throw new functions.https.HttpsError("internal", error.message || "Failed to claim Lucky Bag.");
  }
});
