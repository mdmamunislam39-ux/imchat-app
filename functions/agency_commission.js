const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const db = admin.firestore();

/**
 * Send an official imChat team message and FCM push notification to a user
 * @param {string} receiverId The receiver user id
 * @param {string} messageText The notification text
 * @return {Promise<void>}
 */
async function sendOfficialNotification(receiverId, messageText) {
  try {
    const userDoc = await db.collection("Users").doc(receiverId).get();
    let deviceToken = "";
    if (userDoc.exists) {
      deviceToken = userDoc.data().deviceToken || "";
    }

    const msgId = db.collection("dummy").doc().id;
    const sentAt = admin.firestore.FieldValue.serverTimestamp();

    const messageData = {
      "msgId": msgId,
      "senderId": "official_team",
      "type": "text",
      "textMsg": messageText,
      "sentAt": sentAt,
    };

    // 1. Save message in receiver's chat
    await db.collection(`Users/${receiverId}/Chats/official_team/Messages`)
        .doc(msgId)
        .set(messageData);

    // 2. Save message in dedicated official_notifications subcollection
    await db.collection(`Users/${receiverId}/official_notifications`)
        .doc(msgId)
        .set(messageData);

    // 3. Update Chat node
    const chatData = {
      "senderId": "official_team",
      "msgType": "text",
      "lastMsg": messageText,
      "msgId": msgId,
      "time": sentAt,
      "sentAt": sentAt,
    };
    await db.collection(`Users/${receiverId}/Chats`)
        .doc("official_team")
        .set(chatData, {merge: true});

    // 4. Log the notification in official_notification_logs
    await db.collection("official_notification_logs").doc(msgId).set({
      "msgId": msgId,
      "senderId": "official_team",
      "receiverId": receiverId,
      "textMsg": messageText,
      "sentAt": sentAt,
    });

    // 5. Send Push Notification if deviceToken is present
    if (deviceToken) {
      const payload = {
        token: deviceToken,
        notification: {
          title: "imChat Official team",
          body: messageText,
        },
        data: {
          type: "message",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          status: "done",
        },
        android: {
          priority: "high",
          notification: {
            color: "#0A5AFF",
            sound: "default",
            channelId: "default_channel",
          },
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

      await admin.messaging().send(payload);
      console.log(`Successfully sent push notification to user ${receiverId}`);
    }
  } catch (error) {
    console.error(
        `Error sending official notification to user ${receiverId}:`,
        error,
    );
  }
}

/**
 * Scheduled Cloud Function to process weekly commissions
 * Runs every Sunday night at 12:15 AM (Monday 00:15 Dhaka time)
 */
exports.processWeeklyCommissions = functions.pubsub
    .schedule("15 0 * * 1") // 12:15 AM Sunday Midnight / Monday 00:15 AM (Dhaka Time UTC+6)
    .timeZone("Asia/Dhaka")
    .onRun(async (context) => {
      console.log("⏰ Starting weekly commission processing...");

      try {
        const now = new Date();
        // Adjust timezone to Dhaka to safely determine date boundaries
        const dhakaOffset = 6 * 60 * 60 * 1000;
        const dhakaNow = new Date(now.getTime() + dhakaOffset);

        const year = dhakaNow.getUTCFullYear();
        const month = dhakaNow.getUTCMonth();
        const day = dhakaNow.getUTCDate();

        // End date: Today (Sunday) at 22:00:00 Dhaka time = 16:00:00 UTC
        const weekEnd = new Date(Date.UTC(year, month, day, 16, 0, 0));
        // Start date: Exactly 7 days ago at 22:00:00 Dhaka time = 16:00:00 UTC
        const weekStart = new Date(weekEnd.getTime() - 7 * 24 * 60 * 60 * 1000);

        const weekStartTs = admin.firestore.Timestamp.fromDate(weekStart);
        const weekEndTs = admin.firestore.Timestamp.fromDate(weekEnd);

        console.log(
            `Weekly Commission Range: ${weekStart.toISOString()} ` +
            `to ${weekEnd.toISOString()}`,
        );

        // Get all active agencies
        const agenciesQuery = await db.collection("agencies")
            .where("isActive", "==", true)
            .get();

        if (agenciesQuery.empty) {
          console.log("No active agencies found.");
          return null;
        }

        console.log(
            `Processing commission for ${agenciesQuery.docs.length} ` +
            `active agencies...`,
        );

        for (const agencyDoc of agenciesQuery.docs) {
          const agencyId = agencyDoc.id;
          const agencyData = agencyDoc.data();
          const agencyName = agencyData.agencyName || "Unknown Agency";
          const ownerUserId = agencyData.ownerUserId ||
              (agencyData.owner ? agencyData.owner.userId : null);

          console.log(
              `Calculating commission for Agency: ${agencyName} (${agencyId})`,
          );

          // Get agency hosts
          const hostsSnapshot = await db.collection("hosts")
              .where("agencyId", "==", agencyId)
              .where("isActive", "==", true)
              .get();

          if (hostsSnapshot.empty) {
            console.log(`Agency ${agencyName} has no active hosts. Skipping.`);
            continue;
          }

          const hostMap = {};
          const hostsList = [];
          hostsSnapshot.forEach((doc) => {
            const hostData = doc.data();
            const hostInfo = {
              id: doc.id,
              userId: hostData.userId || "",
              hostName: hostData.hostName || "Unknown",
              agencyId: agencyId,
              diamondsEarned: 0,
            };

            // Deduplicate to prevent double-paying
            if (hostInfo.userId && hostMap[hostInfo.userId]) {
              console.log(`Duplicate host document found for userId: ${hostInfo.userId}. Skipping duplicate.`);
              return;
            }

            hostsList.push(hostInfo);
            if (hostInfo.userId) {
              hostMap[hostInfo.userId] = hostInfo;
            }
            hostMap[hostInfo.id] = hostInfo;
          });

          // Query all earnings for this agency during this week (excluding end boundary for rollover)
          const earningsQuery = await db.collection("host_earnings")
              .where("agencyId", "==", agencyId)
              .where("earningDate", ">=", weekStartTs)
              .where("earningDate", "<", weekEndTs)
              .get();

          earningsQuery.forEach((doc) => {
            const data = doc.data();
            const diamonds = parseFloat(data.diamondsEarned || 0);
            const hostId = data.hostId;

            if (hostMap[hostId]) {
              hostMap[hostId].diamondsEarned += diamonds;
            }
          });

          let totalAgencyCommission = 0.0;
          const batch = db.batch();

          for (const host of hostsList) {
            if (host.diamondsEarned > 0) {
              const hostCommission = host.diamondsEarned * 0.10; // 10%
              totalAgencyCommission += hostCommission;

              // Record host commission
              const hostCommissionRef = db.collection("host_commissions").doc();
              batch.set(hostCommissionRef, {
                "hostId": host.id,
                "agencyId": host.agencyId,
                "weekStart": weekStartTs,
                "weekEnd": weekEndTs,
                "commissionAmount": hostCommission,
                "commissionRate": 0.10,
                "createdAt": admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }

          if (totalAgencyCommission > 0) {
            console.log(
                `Agency ${agencyName} earned total commission: ` +
                `${totalAgencyCommission} beans`,
            );

            // 1. Update agency total commission
            const agencyRef = db.collection("agencies").doc(agencyId);
            batch.update(agencyRef, {
              "totalCommissionEarned":
                  admin.firestore.FieldValue.increment(totalAgencyCommission),
              "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
            });

            // 2. Record commission payment transaction
            const paymentRef = db.collection("commission_payments").doc();
            batch.set(paymentRef, {
              "agencyId": agencyId,
              "amount": totalAgencyCommission,
              "paymentDate": admin.firestore.FieldValue.serverTimestamp(),
              "weekStart": weekStartTs,
              "weekEnd": weekEndTs,
              "status": "completed",
              "createdAt": admin.firestore.FieldValue.serverTimestamp(),
            });

            // 3. Increment owner's user account beans balance
            if (ownerUserId) {
              const userRef = db.collection("Users").doc(ownerUserId);
              batch.update(userRef, {
                "beans":
                    admin.firestore.FieldValue.increment(totalAgencyCommission),
              });
            }

            // Commit database writes
            await batch.commit();
            console.log(
                `Committed commission payouts for agency: ${agencyName}`,
            );

            // 4. Send imChat official team message and push notification
            if (ownerUserId) {
              const messageText =
                  `🎉 Congratulations! You have received a weekly ` +
                  `commission reward of ${totalAgencyCommission.toFixed(2)} ` +
                  `beans for your agency "${agencyName}".`;
              await sendOfficialNotification(ownerUserId, messageText);
              console.log(`Sent payout notification to owner: ${ownerUserId}`);
            }
          } else {
            console.log(`Agency ${agencyName} has 0 commission this week.`);
          }
        }

        console.log("✅ Weekly commission processing completed successfully.");
      } catch (error) {
        console.error("❌ Error in weekly commission processing: ", error);
      }

      return null;
    });
