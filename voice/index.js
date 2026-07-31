// const functions = require("firebase-functions");
// const admin = require('firebase-admin');
// admin.initializeApp();

// //const storage = _storage().bucket();
// //const firestore = _firestore();


// export const sendPushNotification = https.onCall(async (data, context) => {
// 	try {
// 		const { type, title, body, deviceToken, senderId, call } = data;

// 		// Check auth
// 		if (!context.auth) {
// 			throw new https.HttpsError('unauthenticated', 'Authentication required.');
// 		}

// 		// Validate parameters
// 		if (!type || !title || !body || !deviceToken || !senderId) {
// 			throw new https.HttpsError("invalid-argument", "Invalid parameters.");
// 		}

// 		// Build notification message
// 		const message = {
// 			token: deviceToken,
// 			notification: {
// 				title: title,
// 				body: body,
// 			},
// 			data: {
// 				type: type,
// 				call: JSON.stringify(call || {}),
// 				senderId: senderId,
// 				click_action: "FLUTTER_NOTIFICATION_CLICK",
// 				status: "done",
// 			},
// 			android: {
// 				priority: "high",
// 				notification: {
// 					color: "#0A5AFF",
// 				},
// 			},
// 			apns: {
// 				payload: {
// 					aps: {
// 						contentAvailable: true,
// 						sound: "default",
// 					},
// 				},
// 			},
// 		};

// 		const response = await messaging().send(message);
// 		const successMsg = `Send push notification success. Response: ${response}`;
// 		console.log(successMsg);
// 		return successMsg;
// 	} catch (error) {
// 		const errorMsg = `Failed to send push notification. ${error}`;
// 		console.error(errorMsg);
// 		throw new https.HttpsError('internal', errorMsg);
// 	}
// });


// export const updateUserPresence = database.ref('/{uid}/isOnline').onUpdate(
// 	async (change, context) => {
// 		const isOnline = change.after.val();
// 		const userRef = firestore.doc(`Users/${context.params.uid}`);

// 		var data = { isOnline: isOnline, lastActive: Date.now() }

// 		if (isOnline === false) {
// 			data.isTyping = false;
// 			data.isRecording = false;
// 		}

// 		return userRef.update(data);
// 	}
// );


// //
// // <-- STORIES section -->
// //

// async function deleteFileFromStorage(fileUrl) {
// 	try {
// 		// Extract the file path from the URL
// 		const filePath = new URL(fileUrl).pathname.split('/').pop().replace(/%2F/g, '/');

// 		// Delete the file from Firebase Storage
// 		await storage.file(filePath).delete();
// 	} catch (error) {
// 		console.error('Error deleting file from storage:', error);
// 	}
// }

// /**
//  * 
//  * @param {Array} files 
//  * @param {Number} currentTime 
//  * @param {Number} expirationTime 
//  * @returns Array
//  */
// function filterAndDeleteExpiredFiles(files, currentTime, expirationTime) {
// 	const expiredFiles = files.filter(file => file.createdAt < currentTime - expirationTime);

// 	for (const file of expiredFiles) {
// 		if (file.imageUrl !== undefined) {
// 			deleteFileFromStorage(file.imageUrl);
// 		} else {
// 			deleteFileFromStorage(file.videoUrl);
// 			deleteFileFromStorage(file.thumbnailUrl);
// 		}
// 	}

// 	return files.filter(file => file.createdAt >= currentTime - expirationTime);
// }


// export const deleteExpiredStories = pubsub.schedule('every 1 hours')
// 	.timeZone('UTC').onRun(async (context) => {
// 		const expirationTime = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
// 		const currentTime = new Date().getTime();

// 		const stories = await firestore.collection('Stories').get();

// 		if (stories.empty) {
// 			return null;
// 		}

// 		const batch = firestore.batch();

// 		stories.forEach(doc => {
// 			const story = doc.data();

// 			// Filter out expired story texts
// 			const texts = story.texts
// 				.filter(text => text.createdAt >= currentTime - expirationTime);

// 			// Filter out and delete expired image files
// 			const images = filterAndDeleteExpiredFiles(story.images, currentTime, expirationTime);

// 			// Filter out and delete expired video files
// 			const videos = filterAndDeleteExpiredFiles(story.videos, currentTime, expirationTime);


// 			// If any of the arrays were modified, update the story
// 			if (texts.length !== story.texts.length ||
// 				images.length !== story.images.length ||
// 				videos.length !== story.videos.length) {

// 				const totalStories = (texts.length + images.length + videos.length);

// 				if (totalStories === 0) {
// 					batch.delete(doc.ref);
// 				} else {
// 					batch.update(doc.ref, {
// 						texts: texts,
// 						images: images,
// 						videos: videos,
// 					});
// 				}
// 			}
// 		});

// 		// Commit the batch to Firestore
// 		await batch.commit();

// 		return null;
// 	});

// //
// // <-- END STORIES section -->
// //

const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');
admin.initializeApp();


const storage = admin.storage().bucket();
const firestore = admin.firestore();


//////////
const { RtcTokenBuilder, RtcRole } = require("agora-token");

const APP_ID = "f90a38dda7b74dc7967f7d9440509cf6";
const APP_CERTIFICATE = "dceb6b34aa07490e9c1ea2c864e98761";

exports.generateAgoraToken = functions.https.onRequest((req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  
  const channelName = req.query.channelName;
  if (!channelName) {
    return res.status(400).send("channelName is required");
  }

  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;

  const expirationTimeInSeconds = 86400;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID,
    APP_CERTIFICATE,
    channelName,
    uid,
    role,
    privilegeExpiredTs
  );

  res.json({ token: token });
});
/////////////


exports.sendPushNotification = functions.https.onCall(async (data, context) => {
	try {
		const { type, title, body, deviceToken, senderId, call } = data;

		// Check auth
		if (!context.auth) {
			throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
		}

		// Validate parameters
		if (!type || !title || !body || !deviceToken || !senderId) {
			throw new functions.https.HttpsError("invalid-argument", "Invalid parameters.");
		}
        const isCallNotification = type === 'call';
		// Build notification message
		const message = {
			token: deviceToken,
			notification: {
				title: title,
				body: body,
			},
			data: {
				type: type,
				call: JSON.stringify(call || {}),
				senderId: senderId,
				click_action: "FLUTTER_NOTIFICATION_CLICK",
				status: "done",
			},
			android: {
				priority: "high",
				notification: {
					color: "#0A5AFF",
					sound: isCallNotification ? 'sound' : 'default', // Use custom sound only for 'call'
                    channelId: isCallNotification ? "custom_sound_channel" : "default_channel"
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

		const response = await admin.messaging().send(message);
		const successMsg = `Send push notification success. Response: ${response}`;
		console.log(successMsg);
		return successMsg;
	} catch (error) {
		const errorMsg = `Failed to send push notification. ${error}`;
		console.error(errorMsg);
		throw new functions.https.HttpsError('internal', errorMsg);
	}
});


exports.updateUserPresence = functions.database.ref('/{uid}/isOnline').onUpdate(
	async (change, context) => {
		const isOnline = change.after.val();
		const userRef = firestore.doc(`Users/${context.params.uid}`);

		var data = { isOnline: isOnline, lastActive: Date.now() }

		if (isOnline === false) {
			data.isTyping = false;
			data.isRecording = false;
		}

		return userRef.update(data);
	}
);


//
// <-- STORIES section -->
//

async function deleteFileFromStorage(fileUrl) {
	try {
		// Extract the file path from the URL
		const filePath = new URL(fileUrl).pathname.split('/').pop().replace(/%2F/g, '/');

		// Delete the file from Firebase Storage
		await storage.file(filePath).delete();
	} catch (error) {
		console.error('Error deleting file from storage:', error);
	}
}

/**
 * 
 * @param {Array} files 
 * @param {Number} currentTime 
 * @param {Number} expirationTime 
 * @returns Array
 */
function filterAndDeleteExpiredFiles(files, currentTime, expirationTime) {
	const expiredFiles = files.filter(file => file.createdAt < currentTime - expirationTime);

	for (const file of expiredFiles) {
		if (file.imageUrl !== undefined) {
			deleteFileFromStorage(file.imageUrl);
		} else {
			deleteFileFromStorage(file.videoUrl);
			deleteFileFromStorage(file.thumbnailUrl);
		}
	}

	return files.filter(file => file.createdAt >= currentTime - expirationTime);
}


exports.deleteExpiredStories = functions.pubsub.schedule('every 1 hours')
	.timeZone('UTC').onRun(async (context) => {
		const expirationTime = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
		const currentTime = new Date().getTime();

		const stories = await firestore.collection('Stories').get();

		if (stories.empty) {
			return null;
		}

		const batch = firestore.batch();

		stories.forEach(doc => {
			const story = doc.data();

			// Filter out expired story texts
			const texts = story.texts
				.filter(text => text.createdAt >= currentTime - expirationTime);

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