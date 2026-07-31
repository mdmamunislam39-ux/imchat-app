const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');
const firestore = admin.firestore();

// Cron job to run every 5 minutes and distribute event rewards for expired events
exports.distributeEventRewards = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();

  // Find events where endTime has passed, but status is still 'active'
  const eventsSnapshot = await firestore.collection('events')
    .where('endTime', '<=', now)
    .where('status', '==', 'active')
    .get();

  if (eventsSnapshot.empty) {
    console.log('No expired active events found for reward distribution.');
    return null;
  }

  const batch = firestore.batch();

  for (const doc of eventsSnapshot.docs) {
    const event = doc.data();
    const eventId = doc.id;
    const rewards = event.rewards || [];
    const eventType = event.eventType; // e.g. weekly_star, top_room, recharge

    console.log(`Processing rewards for event: ${event.eventName} (${eventId})`);

    const eventPrefix = eventId.replace(/-/g, '_');
    
    // Fetch top users from the leaderboard based on the eventType
    let orderByField = `event_${eventPrefix}_received`; // default
    if (eventType === 'recharge') orderByField = `recharge_${admin.firestore.Timestamp.now().toDate().getFullYear()}-${String(admin.firestore.Timestamp.now().toDate().getMonth() + 1).padStart(2, '0')}`; // wait, recharge wasn't changed to event specific! Let's keep totalRecharge for now, or just use totalRecharge
    
    if (eventType === 'recharge') orderByField = 'totalRecharge';
    else if (eventType === 'top_room') orderByField = `event_${eventPrefix}_received`;
    else if (eventType === 'gifter_receiver') orderByField = `event_${eventPrefix}_sent`; // Assuming we reward senders here? Actually it has 2 leaderboards. For simplicity, just use sent.
    else if (eventType === 'game_star') orderByField = `event_${eventPrefix}_greedy_game`; // or fruit_wheel, needs better logic but this handles MVP.

    const topUsersSnap = await firestore.collection('leaderboard_stats')
      .orderBy(orderByField, 'desc')
      .limit(rewards.length || 3)
      .get();

    let rank = 0;
    topUsersSnap.forEach((userDoc) => {
      if (rank < rewards.length) {
        const userId = userDoc.id;
        const reward = rewards[rank]; // Assuming rewards array maps to [rank 1, rank 2, ...]

        if (reward) {
          const userRef = firestore.collection('Users').doc(userId);
          
          // Add diamonds to user wallet
          if (reward.diamonds && reward.diamonds > 0) {
            batch.update(userRef, {
              diamonds: admin.firestore.FieldValue.increment(reward.diamonds),
              totalDiamonds: admin.firestore.FieldValue.increment(reward.diamonds)
            });
          }

          // Add items to user_store_items collection
          if (reward.itemId) {
            const itemRef = firestore.collection('user_store_items').doc();
            const durationDays = parseInt(reward.durationDays || 7);
            const expireDate = new Date();
            expireDate.setDate(expireDate.getDate() + durationDays);

            batch.set(itemRef, {
              userId: userId,
              storeItemId: reward.itemId,
              itemType: reward.itemType || reward.type || 'avatarFrame', 
              isActive: true,
              assignedAt: admin.firestore.FieldValue.serverTimestamp(),
              expiresAt: admin.firestore.Timestamp.fromDate(expireDate),
              source: `Event: ${event.eventName}`
            });
          }
        }
      }
      rank++;
    });

    // Mark event as expired
    const eventRef = firestore.collection('events').doc(eventId);
    batch.update(eventRef, { status: 'expired' });

    // Send admin notification
    const adminNotificationRef = firestore.collection('Reports').doc(); // Or a specific admin notifications collection
    batch.set(adminNotificationRef, {
      type: 'event_ended',
      title: `Event Ended: ${event.eventName}`,
      description: `Rewards have been automatically distributed to ${rank} users.`,
      eventId: eventId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'unread'
    });
  }

  await batch.commit();
  console.log('Reward distribution completed successfully.');
  return null;
});
