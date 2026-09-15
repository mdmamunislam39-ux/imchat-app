const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

/**
 * Scheduled Cloud Function to calculate trending scores for Audio Rooms and Moments
 * Uses 10 core metrics:
 * 1. trendingScore
 * 2. onlineCount
 * 3. uniqueJoiners10m
 * 4. giftCoins10m
 * 5. likes10m
 * 6. messages10m
 * 7. activeSpeakers
 * 8. avgStayTime
 * 9. growthRate
 * 10. lastCalculated
 */
exports.calculateTrendingScores = functions.pubsub
  .schedule("every 30 minutes")
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = Date.now();

    console.log("Starting scheduled calculateTrendingScores job with 10 metrics...");

    try {
      // ==========================================
      // 1. AUDIO ROOMS 10-METRIC TRENDING SCORE CALCULATION
      // ==========================================
      const roomsSnap = await db
        .collection("audio_rooms_v2")
        .where("isActive", "==", true)
        .get();

      if (!roomsSnap.empty) {
        const roomBatch = db.batch();
        let roomUpdateCount = 0;

        roomsSnap.docs.forEach((doc) => {
          const data = doc.data();

          // Skip banned rooms or private rooms excluded from ranking
          if (data.isBanned || data.excludeFromRanking) {
            roomBatch.update(doc.ref, {
              trendingScore: 0.0,
              lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
            });
            roomUpdateCount++;
            return;
          }

          const onlineCount = Number(data.onlineCount || (Array.isArray(data.participants) ? data.participants.length : 0));
          const activeSpeakers = Number(data.activeSpeakers || (Array.isArray(data.participants)
            ? data.participants.filter((p) => p.isSeated || p.isSpeaker || p.isMicOn).length
            : 0));

          const uniqueJoiners10m = Number(data.uniqueJoiners10m || 0);
          const giftCoins10m = Number(data.giftCoins10m || data.recentGiftsDiamonds || 0);
          const likes10m = Number(data.likes10m || 0);
          const messages10m = Number(data.messages10m || 0);
          const avgStayTime = Number(data.avgStayTime || 5.0);

          const previousOnlineCount = Number(data.previousOnlineCount || onlineCount || 1);
          const growthRate = Number((onlineCount / Math.max(1, previousOnlineCount)).toFixed(2));

          // Hours live (min 0.1)
          const createdAtMs = data.createdAt ? (data.createdAt.toMillis ? data.createdAt.toMillis() : now) : now;
          const hoursLive = Math.max(0.1, (now - createdAtMs) / (1000 * 60 * 60));

          // 10-Metric Weighted Formula:
          const numerator =
            (onlineCount * 15) +
            (uniqueJoiners10m * 10) +
            (activeSpeakers * 20) +
            (giftCoins10m * 5) +
            (likes10m * 1) +
            (messages10m * 2) +
            (avgStayTime * 3) +
            (growthRate * 50);

          const timeDecay = Math.pow(hoursLive + 1, 1.1);
          const trendingScore = Number((numerator / timeDecay).toFixed(2));

          roomBatch.update(doc.ref, {
            trendingScore: trendingScore,
            onlineCount: onlineCount,
            uniqueJoiners10m: 0, // Reset window after cycle calculation
            giftCoins10m: 0,     // Reset window after cycle calculation
            likes10m: 0,         // Reset window after cycle calculation
            messages10m: 0,      // Reset window after cycle calculation
            activeSpeakers: activeSpeakers,
            avgStayTime: avgStayTime,
            growthRate: growthRate,
            previousOnlineCount: onlineCount,
            lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
          });

          roomUpdateCount++;
        });

        await roomBatch.commit();
        console.log(`Updated 10-metric trendingScore for ${roomUpdateCount} audio rooms.`);
      }

      // ==========================================
      // 2. MOMENTS / NEWS FEED TRENDING SCORE CALCULATION
      // ==========================================
      const threeDaysAgo = new Date(now - (72 * 60 * 60 * 1000));
      const postsSnap = await db
        .collection("news_feed_posts")
        .where("createdAt", ">=", threeDaysAgo)
        .where("isDeleted", "==", false)
        .get();

      if (!postsSnap.empty) {
        const postBatch = db.batch();
        let postUpdateCount = 0;

        postsSnap.docs.forEach((doc) => {
          const data = doc.data();

          const likes = Number(data.likeCount || 0);
          const comments = Number(data.commentCount || 0);
          const shares = Number(data.shareCount || 0);
          const views = Number(data.viewCount || 0);

          const createdAtMs = data.createdAt ? (data.createdAt.toMillis ? data.createdAt.toMillis() : now) : now;
          const hoursOld = Math.max(0.1, (now - createdAtMs) / (1000 * 60 * 60));

          // Formula: ((likes * 1) + (comments * 3) + (shares * 5) + (views * 0.1)) / (hoursOld + 2)^1.5
          const numerator = (likes * 1) + (comments * 3) + (shares * 5) + (views * 0.1);
          const gravityDecay = Math.pow(hoursOld + 2, 1.5);
          const trendingScore = Number((numerator / gravityDecay).toFixed(4));

          postBatch.update(doc.ref, {
            trendingScore: trendingScore,
            lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
          });

          postUpdateCount++;
        });

        await postBatch.commit();
        console.log(`Updated trendingScore for ${postUpdateCount} news feed posts.`);
      }

      console.log("Successfully completed 10-metric calculateTrendingScores job.");
      return null;
    } catch (error) {
      console.error("Error running calculateTrendingScores:", error);
      return null;
    }
  });
