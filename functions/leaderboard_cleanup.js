/**
 * Cloud Functions for Audio Room Leaderboard Reset
 * Deploy this to Firebase Cloud Functions environment.
 * 
 * Dependencies:
 * - firebase-functions
 * - firebase-admin
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// admin.initializeApp(); // ALREADY INITIALIZED IN index.js
const db = admin.firestore();

/**
 * Reset Daily Contributions at 12:00 PM (Noon) every day
 * Timezone: Asia/Karachi (adjust as needed)
 */
exports.resetDailyContributions = functions.pubsub
    .schedule("0 12 * * *")
    .timeZone("Asia/Karachi") // Adjust timezone
    .onRun(async (context) => {
        console.log("⏰ Starting daily contribution reset...");

        const roomsRef = db.collection("audio_rooms_v2");
        const snapshot = await roomsRef.where("isActive", "==", true).get();

        if (snapshot.empty) {
            console.log("No active rooms found.");
            return null;
        }

        const batchSize = 500;
        let batch = db.batch();
        let operationCount = 0;

        for (const doc of snapshot.docs) {
            const roomData = doc.data();
            const contributors = roomData.contributors || {};
            let updated = false;

            // Reset dailyContribution for all contributors
            const updatedContributors = {};
            for (const [userId, contributor] of Object.entries(contributors)) {
                if (contributor.dailyContribution > 0) {
                    updatedContributors[`contributors.${userId}.dailyContribution`] = 0;
                    updated = true;
                }
            }

            if (updated) {
                batch.update(doc.ref, updatedContributors);
                operationCount++;

                if (operationCount >= batchSize) {
                    await batch.commit();
                    batch = db.batch();
                    operationCount = 0;
                }
            }
        }

        if (operationCount > 0) {
            await batch.commit();
        }

        console.log("✅ Daily contributions reset complete.");
        return null;
    });

/**
 * Reset Weekly Contributions every Sunday Midnight / Monday at 12:00 AM (00:00 Dhaka Time)
 */
exports.resetWeeklyContributions = functions.pubsub
    .schedule("0 0 * * 1") // Every Sunday Midnight / Monday 00:00 AM
    .timeZone("Asia/Dhaka")
    .onRun(async (context) => {
        console.log("⏰ Starting weekly contribution reset...");

        const roomsRef = db.collection("audio_rooms_v2");
        const snapshot = await roomsRef.where("isActive", "==", true).get();

        const batchSize = 500;
        let batch = db.batch();
        let operationCount = 0;

        for (const doc of snapshot.docs) {
            const roomData = doc.data();
            const contributors = roomData.contributors || {};
            let updated = false;

            const updatedContributors = {};
            for (const [userId, contributor] of Object.entries(contributors)) {
                if (contributor.weeklyContribution > 0) {
                    updatedContributors[`contributors.${userId}.weeklyContribution`] = 0;
                    updated = true;
                }
            }

            if (updated) {
                batch.update(doc.ref, updatedContributors);
                operationCount++;

                if (operationCount >= batchSize) {
                    await batch.commit();
                    batch = db.batch();
                    operationCount = 0;
                }
            }
        }

        if (operationCount > 0) {
            await batch.commit();
        }

        console.log("✅ Weekly contributions reset complete.");
        return null;
    });

/**
 * Reset Monthly Contributions on the 1st of every month at 12:00 AM
 */
exports.resetMonthlyContributions = functions.pubsub
    .schedule("0 0 1 * *") // 1st day of month
    .timeZone("Asia/Karachi")
    .onRun(async (context) => {
        console.log("⏰ Starting monthly contribution reset...");

        const roomsRef = db.collection("audio_rooms_v2");
        const snapshot = await roomsRef.where("isActive", "==", true).get();

        const batchSize = 500;
        let batch = db.batch();
        let operationCount = 0;

        for (const doc of snapshot.docs) {
            const roomData = doc.data();
            const contributors = roomData.contributors || {};
            let updated = false;

            const updatedContributors = {};
            for (const [userId, contributor] of Object.entries(contributors)) {
                if (contributor.monthlyContribution > 0) {
                    updatedContributors[`contributors.${userId}.monthlyContribution`] = 0;
                    updated = true;
                }
            }

            if (updated) {
                batch.update(doc.ref, updatedContributors);
                operationCount++;

                if (operationCount >= batchSize) {
                    await batch.commit();
                    batch = db.batch();
                    operationCount = 0;
                }
            }
        }

        if (operationCount > 0) {
            await batch.commit();
        }

        console.log("✅ Monthly contributions reset complete.");
        return null;
    });
