const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

if (!admin.apps.length) {
  admin.initializeApp();
}

// In-memory cache for dynamic Agora credentials from Firestore
let cachedCredentials = null;
let lastCredentialsFetchTime = 0;
const CREDENTIALS_CACHE_TTL_MS = 10000; // 10 seconds cache to pick up real-time admin changes quickly

/**
 * Fetch dynamic Agora App ID & Certificate from Firestore with fallback defaults.
 */
async function getAgoraCredentials() {
  const now = Date.now();
  if (cachedCredentials && (now - lastCredentialsFetchTime) < CREDENTIALS_CACHE_TTL_MS) {
    return cachedCredentials;
  }

  let appId = 'c74eafbb98784225bae6be9b7e7f6225'; // Default fallback
  let appCertificate = 'eb4c5875fba74804b9d348882d7365f0'; // Default fallback

  try {
    const settingsDoc = await admin.firestore().collection('global_settings').doc('app_settings').get();
    if (settingsDoc.exists) {
      const data = settingsDoc.data() || {};
      if (data.agoraAppId && typeof data.agoraAppId === 'string' && data.agoraAppId.trim()) {
        appId = data.agoraAppId.trim();
      }
      const cert = data.agoraAppCertificate || data.agoraCertificate;
      if (cert && typeof cert === 'string' && cert.trim()) {
        appCertificate = cert.trim();
      }
    }
  } catch (err) {
    console.warn('⚠️ Could not fetch Agora credentials from Firestore global_settings/app_settings:', err.message);
  }

  cachedCredentials = { appId, appCertificate };
  lastCredentialsFetchTime = now;
  return cachedCredentials;
}

/**
 * Simple Agora Token Generator - No Authentication Required
 * This is the ONLY function you need for token generation
 */
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  try {
    console.log('🔥 Token generation request received:', data);

    // Fetch dynamic credentials from Firestore (or fallback defaults)
    const credentials = await getAgoraCredentials();
    const APP_ID = (data && data.appId && typeof data.appId === 'string' && data.appId.trim())
      ? data.appId.trim()
      : credentials.appId;
    const APP_CERTIFICATE = credentials.appCertificate;

    // Extract parameters with safe defaults

    // Extract parameters with safe defaults
    const channelName = data.channelName;
    const uid = data.uid || 0;
    const expirationTimeInSeconds = data.expirationTimeInSeconds || 3600;

    // Basic validation
    if (!channelName) {
      console.log('❌ Missing channelName');
      throw new functions.https.HttpsError(
        'invalid-argument',
        'channelName is required'
      );
    }

    // Convert uid to number if needed
    let numericUid = uid;
    if (typeof uid === 'string') {
      numericUid = parseInt(uid, 10);
    }
    if (typeof numericUid !== 'number' || isNaN(numericUid)) {
      numericUid = 0;
    }

    console.log('🔥 Generating token with params:', {
      channelName,
      uid: numericUid,
      expirationTimeInSeconds
    });

    // Calculate expiration timestamp
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    // Generate the token (always as publisher for audio rooms)
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      numericUid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs
    );

    if (!token) {
      console.log('❌ Token generation failed');
      throw new functions.https.HttpsError(
        'internal',
        'Failed to generate token'
      );
    }

    console.log('✅ Token generated successfully:', {
      channelName,
      uid: numericUid,
      tokenLength: token.length,
      expiresAt: privilegeExpiredTs
    });

    // Return success response
    return {
      success: true,
      token: token,
      uid: numericUid,
      channelName: channelName,
      expiresAt: privilegeExpiredTs * 1000 // Convert to milliseconds
    };

  } catch (error) {
    console.error('❌ Token generation error:', error);

    // If it's already a HttpsError, re-throw it
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Otherwise, throw a generic internal error
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate token: ' + error.message
    );
  }
});