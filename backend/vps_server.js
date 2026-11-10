/**
 * ============================================================================
 * IMCHAT VPS BACKEND SERVER
 * Built with: Express + PostgreSQL + Socket.io + Firebase Admin (Auth & FCM)
 * Provides ultra low-latency 1v1 chat, voice rooms, seat state, gifts, and assets
 * ============================================================================
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');
const { Pool } = require('pg');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const { AccessToken } = require('livekit-server-sdk');

// Global in-memory map for real-time connected user socket sessions (uid -> socket.id)
global.connectedUsers = global.connectedUsers || new Map();
const connectedUsers = global.connectedUsers;

// ----------------------------------------------------------------------------
// 1. FIREBASE ADMIN SDK (For Auth Verification & FCM Push Notifications)
// ----------------------------------------------------------------------------
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin initialized via env service account');
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp();
    console.log('✅ Firebase Admin initialized via GOOGLE_APPLICATION_CREDENTIALS');
  } else {
    // Default application credentials or mock fallback in local dev
    try {
      admin.initializeApp();
      console.log('✅ Firebase Admin initialized with default credentials');
    } catch (e) {
      console.warn('⚠️ Firebase Admin running without service account. Auth verification will accept tokens in mock/dev mode.');
    }
  }
} catch (e) {
  console.warn('⚠️ Firebase Admin init warning:', e.message);
}

// ----------------------------------------------------------------------------
// 2. POSTGRESQL CONNECTION POOL
// ----------------------------------------------------------------------------
const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL })
  : new Pool({
      host: process.env.PG_HOST || process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.PG_PORT || process.env.DB_PORT || '5432', 10),
      database: process.env.PG_DATABASE || process.env.POSTGRES_DB || process.env.DB_NAME || 'imchat_db',
      user: process.env.PG_USER || process.env.POSTGRES_USER || process.env.DB_USER || 'postgres',
      password: process.env.PG_PASSWORD || process.env.POSTGRES_PASSWORD || process.env.DB_PASSWORD || 'postgres',
      max: 30,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });

pool.on('error', (err) => {
  console.error('❌ Unexpected PostgreSQL client error', err);
});

// Test DB Connection & Auto-initialize Schema
(async () => {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log('✅ PostgreSQL connected successfully at:', res.rows[0].now);

    // Auto-run schema.sql to ensure all tables, indexes, and constraints exist
    const schemaPath = path.join(__dirname, 'schema.sql');
    if (fs.existsSync(schemaPath)) {
      try {
        const schemaSql = fs.readFileSync(schemaPath, 'utf8');
        await pool.query(schemaSql);
        console.log('✅ Database schema tables & indexes verified/initialized successfully.');
      } catch (schemaErr) {
        console.warn('⚠️ Schema auto-migration notice:', schemaErr.message);
      }
    }
  } catch (err) {
    console.error('⚠️ PostgreSQL connection failed:', err.message);
  }
})();

// Global Process Safety Handlers (Prevent Server Crashes)
process.on('uncaughtException', (err) => {
  console.error('⚠️ UNCAUGHT EXCEPTION PREVENTED:', err.message, err.stack);
});
process.on('unhandledRejection', (reason, promise) => {
  console.error('⚠️ UNHANDLED REJECTION PREVENTED:', reason);
});

// ----------------------------------------------------------------------------
// 3. EXPRESS APP & SOCKET.IO SETUP
// ----------------------------------------------------------------------------
const app = express();
app.use(cors({ origin: '*' }));
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 60000,
  pingInterval: 25000,
  allowEIO3: true,
  transports: ['websocket', 'polling'],
});

// ----------------------------------------------------------------------------
// 4. AUTHENTICATION MIDDLEWARE (Firebase JWT Verification)
// ----------------------------------------------------------------------------
async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  const explicitUid = req.headers['x-user-id'];

  let token = '';
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split('Bearer ')[1].trim();
  }

  if (!token && !explicitUid) {
    return res.status(401).json({ success: false, error: 'Missing or invalid Authorization / x-user-id header' });
  }

  try {
    if (admin.apps.length > 0 && token && token.length > 100) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        req.user = decodedToken; // req.user.uid
        return next();
      } catch (authErr) {
        // Fallback: If verification fails, proceed with explicitUid or fallback
      }
    }

    const resolvedUid = explicitUid || (token.length <= 128 ? token : null);
    if (!resolvedUid) {
      return res.status(401).json({ success: false, error: 'Unable to resolve authenticated user identity' });
    }

    req.user = { uid: resolvedUid };
    next();
  } catch (error) {
    console.error('Auth verification error:', error.message);
    return res.status(401).json({ success: false, error: 'Authentication failed' });
  }
}

// ----------------------------------------------------------------------------
// 5. REST APIS
// ----------------------------------------------------------------------------

// 5.1 Health Check (Used by Admin Panel)
app.get('/health', async (req, res) => {
  try {
    const dbRes = await pool.query('SELECT 1');
    const socketCount = (io.sockets && io.sockets.sockets) ? io.sockets.sockets.size : 0;
    res.json({
      status: 'ok',
      engine: 'VPS_POSTGRESQL',
      timestamp: new Date().toISOString(),
      databaseConnected: dbRes.rowCount > 0,
      activeSockets: socketCount,
    });
  } catch (err) {
    res.status(500).json({
      status: 'error',
      engine: 'VPS_POSTGRESQL',
      databaseError: err.message,
    });
  }
});

// 5.1.1 LiveKit WebRTC Token Generator (Dynamic Admin/Firestore Keys)
app.post('/api/rtc/livekit-token', async (req, res) => {
  const identity = req.body.identity || (req.user ? req.user.uid : null);
  const { roomName, userName } = req.body;
  if (!roomName || !identity) {
    return res.status(400).json({ success: false, error: 'roomName and identity are required' });
  }

  try {
    let apiKey = process.env.LIVEKIT_API_KEY || 'imchat_prod';
    let apiSecret = process.env.LIVEKIT_API_SECRET || 'Lk9pR4vT7xQ2mN8cY6sJ3wH5zA1dF0gB';

    // Check if dynamic keys exist in Firestore
    try {
      if (admin.apps.length > 0) {
        const firestore = admin.firestore();
        const [doc1, doc2] = await Promise.all([
          firestore.collection('system_configs').doc('rtc_engine_settings').get().catch(() => null),
          firestore.collection('global_settings').doc('server_config').get().catch(() => null),
        ]);

        const data1 = doc1 && doc1.exists ? doc1.data() : null;
        const data2 = doc2 && doc2.exists ? doc2.data() : null;

        if (data1?.livekitApiKey?.trim()) apiKey = data1.livekitApiKey.trim();
        else if (data2?.livekitApiKey?.trim()) apiKey = data2.livekitApiKey.trim();

        if (data1?.livekitApiSecret?.trim()) apiSecret = data1.livekitApiSecret.trim();
        else if (data2?.livekitApiSecret?.trim()) apiSecret = data2.livekitApiSecret.trim();
      }
    } catch (fsErr) {
      // Non-blocking warning if firestore is not reachable directly
    }

    const at = new AccessToken(apiKey, apiSecret, {
      identity: String(identity),
      name: userName || 'User',
      ttl: '24h',
    });

    at.addGrant({
      roomJoin: true,
      room: String(roomName),
      canPublish: true,
      canSubscribe: true,
    });

    const token = await at.toJwt();
    return res.json({
      success: true,
      token,
      apiKey,
      roomName,
      identity: String(identity),
    });
  } catch (err) {
    console.error('LiveKit token generation error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 5.2 Sync / Create User Profile
app.post('/api/user/sync', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { fullname, email, photoUrl, phoneNumber, gender, country, fcmToken } = req.body;

  try {
    const query = `
      INSERT INTO users (id, fullname, email, photo_url, phone_number, gender, country, fcm_token, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      ON CONFLICT (id) DO UPDATE SET
        fullname = COALESCE(EXCLUDED.fullname, users.fullname),
        photo_url = COALESCE(EXCLUDED.photo_url, users.photo_url),
        fcm_token = COALESCE(EXCLUDED.fcm_token, users.fcm_token),
        updated_at = NOW()
      RETURNING *;
    `;
    const values = [uid, fullname || '', email || '', photoUrl || '', phoneNumber || '', gender || 'unknown', country || '', fcmToken || ''];
    const result = await pool.query(query, values);
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    console.error('User sync error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.3 Get User Profile & Wallet
app.get('/api/user/profile', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  try {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [uid]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.4 Get Store Assets (Frames, Badges, Emojis, Gifts, Themes)
app.get('/api/store/assets', async (req, res) => {
  const { category } = req.query;
  try {
    let query = 'SELECT * FROM store_assets WHERE is_active = TRUE';
    const params = [];
    if (category) {
      query += ' AND category = $1';
      params.push(category);
    }
    query += ' ORDER BY sort_order ASC, created_at DESC';

    const result = await pool.query(query, params);
    res.json({ success: true, assets: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.5 Equip User Asset (Frame, Badge, Entrance, Theme, Nameplate, Mic Refill, Room Profile BG, Short Profile Theme)
app.post('/api/store/equip', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { assetId, category } = req.body;

  try {
    let columnToUpdate = 'active_frame_id';
    if (category === 'badge') columnToUpdate = 'active_badge_id';
    if (category === 'entrance' || category === 'entry') columnToUpdate = 'active_entrance_id';
    if (category === 'theme' || category === 'room_theme') columnToUpdate = 'active_theme_id';
    if (category === 'bubble' || category === 'room_entry') columnToUpdate = 'active_bubble_id';
    if (category === 'nameplate') columnToUpdate = 'active_nameplate_id';
    if (category === 'mic_refill') columnToUpdate = 'active_mic_refill_id';
    if (category === 'room_profile_bg') columnToUpdate = 'active_room_profile_bg_id';
    if (category === 'short_profile_theme') columnToUpdate = 'active_short_profile_theme_id';

    const query = `UPDATE users SET ${columnToUpdate} = $1, updated_at = NOW() WHERE id = $2 RETURNING *`;
    const result = await pool.query(query, [assetId || null, uid]);

    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.6 Get Voice / Audio Rooms List
app.get('/api/rooms', async (req, res) => {
  try {
    const query = `
      SELECT r.*, u.fullname AS owner_name, u.photo_url AS owner_avatar
      FROM audio_rooms r
      LEFT JOIN users u ON r.owner_id = u.id
      WHERE r.is_live = TRUE
      ORDER BY r.total_participants DESC, r.created_at DESC
      LIMIT 100;
    `;
    const result = await pool.query(query);
    res.json({ success: true, rooms: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.7 Get Single Room Details with Seats
app.get('/api/rooms/:roomId', async (req, res) => {
  const { roomId } = req.params;
  try {
    const roomRes = await pool.query('SELECT * FROM audio_rooms WHERE id = $1', [roomId]);
    if (roomRes.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Room not found' });
    }

    const seatsRes = await pool.query(`
      SELECT s.*, u.fullname, u.photo_url, u.active_frame_id, u.level
      FROM room_seats s
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.room_id = $1
      ORDER BY s.seat_index ASC
    `, [roomId]);

    res.json({
      success: true,
      room: roomRes.rows[0],
      seats: seatsRes.rows,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.7.1 Notify active followers when a user goes live / opens / joins a room
app.post('/api/rooms/notify-followers-live', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { roomId, roomName, creatorId, creatorName, creatorAvatar } = req.body;

  const targetCreatorId = creatorId || uid;
  const finalRoomId = roomId;

  if (!finalRoomId) {
    return res.status(400).json({ success: false, error: 'Missing roomId' });
  }

  try {
    // 1. Check user cooldown (1 hour = 60 minutes cooldown) to prevent spamming when user hops rooms
    let hostName = creatorName;
    let hostAvatar = creatorAvatar;

    const cooldownRes = await pool.query(
      `SELECT fullname, photo_url, last_live_notification_at FROM users WHERE id = $1`,
      [targetCreatorId]
    );

    if (cooldownRes.rows.length > 0) {
      const uData = cooldownRes.rows[0];
      hostName = hostName || uData.fullname || 'User';
      hostAvatar = hostAvatar || uData.photo_url || '';

      const lastSentAt = uData.last_live_notification_at ? new Date(uData.last_live_notification_at).getTime() : 0;
      const oneHourMs = 60 * 60 * 1000;
      if (Date.now() - lastSentAt < oneHourMs) {
        console.log(`⏳ [VPS Live Notification] Cooldown active for user ${targetCreatorId} (${Math.round((Date.now() - lastSentAt) / 60000)} min ago). Room hopping will not spam followers.`);
        return res.json({ success: true, skipped: true, reason: 'cooldown_active' });
      }
    }
    hostName = hostName || 'User';

    // Update last_live_notification_at timestamp
    await pool.query('UPDATE users SET last_live_notification_at = NOW() WHERE id = $1', [targetCreatorId]);

    // 2. Query all ACTIVE followers of targetCreatorId
    // A follower is active if: is_online = TRUE OR connected to socket OR last_seen in last 15 minutes
    const followersRes = await pool.query(`
      SELECT DISTINCT u.id, u.fullname, u.fcm_token, u.is_online
      FROM users u
      JOIN (
        SELECT user_id AS follower_id FROM user_relationships WHERE target_user_id = $1 AND relationship_type = 'following'
        UNION
        SELECT follower_id FROM user_follows WHERE user_id = $1
      ) f ON u.id = f.follower_id
      WHERE u.id != $1
        AND (u.is_online = TRUE OR u.last_seen > NOW() - INTERVAL '15 minutes')
    `, [targetCreatorId]);

    const activeFollowers = followersRes.rows;
    console.log(`📢 [VPS Live Notification] Found ${activeFollowers.length} active followers for creator ${targetCreatorId} (${hostName})`);

    const title = `${hostName} is on live!`;
    const body = `Let's have fun together!!🤘🤟`;
    const callData = {
      type: 'follower_room',
      roomId: finalRoomId,
      roomName: roomName || `${hostName}'s Room`,
      creatorId: targetCreatorId,
      creatorName: hostName,
      creatorAvatar: hostAvatar,
    };

    // 3. Send notifications in parallel
    const sendTasks = activeFollowers.map(async (follower) => {
      // 3.1 Send FCM Push if token exists
      if (follower.fcm_token) {
        await sendPushNotificationPayload({
          deviceToken: follower.fcm_token,
          title,
          body,
          type: 'follower_room',
          call: callData,
          senderId: targetCreatorId,
          senderAvatar: hostAvatar,
        });
      }

      // 3.2 Emit Socket Event if connected
      const socketId = connectedUsers.get(follower.id);
      if (socketId) {
        io.to(socketId).emit('follower_live_notification', {
          title,
          body,
          senderId: targetCreatorId,
          senderName: hostName,
          senderAvatar: hostAvatar,
          roomId: finalRoomId,
          roomName: roomName || `${hostName}'s Room`,
          timestamp: new Date().toISOString(),
        });
      }
    });

    await Promise.allSettled(sendTasks);

    res.json({
      success: true,
      notifiedCount: activeFollowers.length,
      creatorName: hostName,
      roomId: finalRoomId,
    });
  } catch (err) {
    console.error('Notify followers live error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.7.2 Push notification forwarding endpoint
app.post('/api/notification/send', authMiddleware, async (req, res) => {
  const { type, title, body, deviceToken, call, senderId, senderAvatar } = req.body;
  if (!deviceToken || !title || !body) {
    return res.status(400).json({ success: false, error: 'Missing deviceToken, title, or body' });
  }

  try {
    await sendPushNotificationPayload({
      deviceToken,
      title,
      body,
      type: type || 'alert',
      call: call || {},
      senderId: senderId || req.user.uid,
      senderAvatar: senderAvatar || '',
    });
    res.json({ success: true });
  } catch (err) {
    console.error('Push notification send error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8 Get Specific User Profile by ID
app.get('/api/user/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT id, search_id, fullname, email, photo_url, gender, bio, country, coins, diamonds, user_type, roles, is_banned, active_frame_id, active_badge_id, active_entrance_id, active_bubble_id, active_theme_id, level, level_progress, vip_level, is_online, last_seen FROM users WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.1 Update User Profile
app.post('/api/user/update', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { fullname, bio, photoUrl, gender, country, birthdate } = req.body;
  try {
    const query = `
      UPDATE users SET
        fullname = COALESCE($1, fullname),
        bio = COALESCE($2, bio),
        photo_url = COALESCE($3, photo_url),
        gender = COALESCE($4, gender),
        country = COALESCE($5, country),
        birthdate = COALESCE($6, birthdate),
        updated_at = NOW()
      WHERE id = $7
      RETURNING *;
    `;
    const result = await pool.query(query, [fullname, bio, photoUrl, gender, country, birthdate, uid]);
    res.json({ success: true, user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.2 Search Users
app.get('/api/users/search', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (!q) return res.json({ success: true, users: [] });

  try {
    const result = await pool.query(`
      SELECT id, search_id, fullname, photo_url, level, vip_level, active_frame_id, active_badge_id, is_online
      FROM users
      WHERE search_id ILIKE $1 OR fullname ILIKE $1 OR id = $2
      LIMIT 30;
    `, [`%${q}%`, q]);
    res.json({ success: true, users: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.3 Follow / Unfollow User
app.post('/api/user/follow', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { targetUserId } = req.body;
  if (!targetUserId || targetUserId === uid) {
    return res.status(400).json({ success: false, error: 'Invalid target user' });
  }

  try {
    const id = `${uid}_${targetUserId}_following`;
    await pool.query(`
      INSERT INTO user_relationships (id, user_id, target_user_id, relationship_type)
      VALUES ($1, $2, $3, 'following')
      ON CONFLICT (user_id, target_user_id, relationship_type) DO NOTHING;
    `, [id, uid, targetUserId]);

    res.json({ success: true, following: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/user/unfollow', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { targetUserId } = req.body;
  try {
    await pool.query('DELETE FROM user_relationships WHERE user_id = $1 AND target_user_id = $2 AND relationship_type = $3', [uid, targetUserId, 'following']);
    res.json({ success: true, following: false });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/user/:id/followers', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(`
      SELECT u.id, u.search_id, u.fullname, u.photo_url, u.level, u.vip_level, u.active_frame_id, u.active_badge_id
      FROM user_relationships r
      JOIN users u ON r.user_id = u.id
      WHERE r.target_user_id = $1 AND r.relationship_type = 'following'
      ORDER BY r.created_at DESC;
    `, [id]);
    res.json({ success: true, followers: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/user/:id/following', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(`
      SELECT u.id, u.search_id, u.fullname, u.photo_url, u.level, u.vip_level, u.active_frame_id, u.active_badge_id
      FROM user_relationships r
      JOIN users u ON r.target_user_id = u.id
      WHERE r.user_id = $1 AND r.relationship_type = 'following'
      ORDER BY r.created_at DESC;
    `, [id]);
    res.json({ success: true, following: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.4 1-on-1 Conversations & Messages API
app.get('/api/chats', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  try {
    const query = `
      SELECT c.*,
        CASE WHEN c.user1_id = $1 THEN u2.id ELSE u1.id END AS other_user_id,
        CASE WHEN c.user1_id = $1 THEN u2.fullname ELSE u1.fullname END AS other_user_name,
        CASE WHEN c.user1_id = $1 THEN u2.photo_url ELSE u1.photo_url END AS other_user_avatar,
        CASE WHEN c.user1_id = $1 THEN u2.active_frame_id ELSE u1.active_frame_id END AS other_user_frame,
        CASE WHEN c.user1_id = $1 THEN u2.is_online ELSE u1.is_online END AS other_user_online,
        CASE WHEN c.user1_id = $1 THEN c.unread_count_user1 ELSE c.unread_count_user2 END AS unread_count
      FROM direct_conversations c
      LEFT JOIN users u1 ON c.user1_id = u1.id
      LEFT JOIN users u2 ON c.user2_id = u2.id
      WHERE c.user1_id = $1 OR c.user2_id = $1
      ORDER BY c.last_message_at DESC;
    `;
    const result = await pool.query(query, [uid]);
    res.json({ success: true, chats: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/chats/:otherUserId/messages', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { otherUserId } = req.params;
  const limit = Math.min(parseInt(req.query.limit || '60', 10), 150);
  const before = req.query.before ? new Date(req.query.before) : null;
  const convId = [uid, otherUserId].sort().join('_');

  try {
    let query = `
      SELECT * FROM direct_messages
      WHERE (conversation_id = $1 OR (sender_id = $3 AND receiver_id = $4) OR (sender_id = $4 AND receiver_id = $3))
    `;
    const params = [convId, limit, uid, otherUserId];
    if (before) {
      params.push(before);
      query += ` AND created_at < $5`;
    }
    query += ` ORDER BY created_at DESC LIMIT $2;`;

    const result = await pool.query(query, params);
    res.json({ success: true, messages: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/messages/send', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { receiverId, messageType = 'text', content = '', mediaUrl = '', mediaDuration = 0, giftId, giftCount = 1 } = req.body;
  if (!receiverId) return res.status(400).json({ success: false, error: 'receiverId is required' });

  const convId = [uid, receiverId].sort().join('_');
  const msgId = uuidv4();

  try {
    // 0. Ensure user rows exist in DB to prevent foreign key errors
    await pool.query(`INSERT INTO users (id, updated_at) VALUES ($1, NOW()) ON CONFLICT (id) DO NOTHING;`, [uid]);
    await pool.query(`INSERT INTO users (id, updated_at) VALUES ($1, NOW()) ON CONFLICT (id) DO NOTHING;`, [receiverId]);

    // 1. Upsert Conversation
    await pool.query(`
      INSERT INTO direct_conversations (id, user1_id, user2_id, last_message_text, last_message_type, last_message_sender_id, last_message_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      ON CONFLICT (id) DO UPDATE SET
        last_message_text = EXCLUDED.last_message_text,
        last_message_type = EXCLUDED.last_message_type,
        last_message_sender_id = EXCLUDED.last_message_sender_id,
        last_message_at = NOW(),
        updated_at = NOW();
    `, [convId, uid, receiverId, content || `[${messageType}]`, messageType, uid]);

    // 2. Insert Direct Message
    const msgRes = await pool.query(`
      INSERT INTO direct_messages (id, conversation_id, sender_id, receiver_id, message_type, content, media_url, media_duration, gift_id, gift_count, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
      RETURNING *;
    `, [msgId, convId, uid, receiverId, messageType, content, mediaUrl, mediaDuration, giftId || null, giftCount]);

    const messageObj = msgRes.rows[0];

    // 3. Emit to receiver socket if connected
    const receiverSocketId = connectedUsers.get(receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('direct_message_received', messageObj);
    }

    // 4. Emit to sender socket
    const senderSocketId = connectedUsers.get(uid);
    if (senderSocketId) {
      io.to(senderSocketId).emit('direct_message_sent', messageObj);
    }

    // 5. Auto-dispatch push notification if receiver has FCM token registered
    sendFcmMessage(receiverId, {
      title: req.user ? (req.user.name || req.user.fullname || 'New Message') : 'New Message',
      body: content || `[${messageType}]`,
      data: {
        type: 'message',
        senderId: uid,
        messageId: msgId,
      }
    }).catch(() => {});

    res.json({ success: true, message: messageObj });
  } catch (err) {
    console.error('Send message error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.5 Group Chats API
app.get('/api/groups', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  try {
    const result = await pool.query(`
      SELECT g.*, gm.role
      FROM groups g
      JOIN group_members gm ON g.id = gm.group_id
      WHERE gm.user_id = $1
      ORDER BY g.last_message_at DESC;
    `, [uid]);
    res.json({ success: true, groups: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/groups/create', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { name, description = '', coverUrl = '', memberIds = [] } = req.body;
  if (!name) return res.status(400).json({ success: false, error: 'Group name is required' });

  const groupId = uuidv4();
  try {
    const groupRes = await pool.query(`
      INSERT INTO groups (id, name, description, cover_url, creator_id, member_count, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      RETURNING *;
    `, [groupId, name, description, coverUrl, uid, memberIds.length + 1]);

    // Add creator as admin
    await pool.query(`
      INSERT INTO group_members (id, group_id, user_id, role)
      VALUES ($1, $2, $3, 'creator');
    `, [`${groupId}_${uid}`, groupId, uid]);

    // Add other members
    for (const memberId of memberIds) {
      if (memberId && memberId !== uid) {
        await pool.query(`
          INSERT INTO group_members (id, group_id, user_id, role)
          VALUES ($1, $2, $3, 'member')
          ON CONFLICT DO NOTHING;
        `, [`${groupId}_${memberId}`, groupId, memberId]);
      }
    }

    res.json({ success: true, group: groupRes.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/groups/:groupId/messages', authMiddleware, async (req, res) => {
  const { groupId } = req.params;
  const limit = Math.min(parseInt(req.query.limit || '60', 10), 150);
  const before = req.query.before ? new Date(req.query.before) : null;
  try {
    let query = `
      SELECT gm.*, u.fullname AS sender_name, u.photo_url AS sender_avatar
      FROM group_messages gm
      JOIN users u ON gm.sender_id = u.id
      WHERE gm.group_id = $1
    `;
    const params = [groupId, limit];
    if (before) {
      params.push(before);
      query += ` AND gm.created_at < $3`;
    }
    query += ` ORDER BY gm.created_at DESC LIMIT $2;`;

    const result = await pool.query(query, params);
    res.json({ success: true, messages: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/groups/:groupId/send', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { groupId } = req.params;
  const { messageType = 'text', content = '', mediaUrl = '', mediaDuration = 0 } = req.body;
  const msgId = uuidv4();

  try {
    const msgRes = await pool.query(`
      INSERT INTO group_messages (id, group_id, sender_id, message_type, content, media_url, media_duration, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
      RETURNING *;
    `, [msgId, groupId, uid, messageType, content, mediaUrl, mediaDuration]);

    await pool.query(`
      UPDATE groups SET
        last_message_text = $1,
        last_message_type = $2,
        last_message_sender_id = $3,
        last_message_at = NOW(),
        updated_at = NOW()
      WHERE id = $4;
    `, [content || `[${messageType}]`, messageType, uid, groupId]);

    // Broadcast to socket room
    io.to(`group_${groupId}`).emit('new_group_message', msgRes.rows[0]);

    res.json({ success: true, message: msgRes.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.6 Audio Room Management (Create / Update / Close)
app.post('/api/rooms/create', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { title, description = '', coverUrl = '', backgroundUrl = '', category = 'chat', roomType = 'public', password = '', seatCount = 8 } = req.body;
  if (!title) return res.status(400).json({ success: false, error: 'Room title is required' });

  const roomId = uuidv4();
  try {
    const roomRes = await pool.query(`
      INSERT INTO audio_rooms (id, owner_id, title, description, cover_url, background_url, category, room_type, password, seat_count, is_live, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, TRUE, NOW(), NOW())
      RETURNING *;
    `, [roomId, uid, title, description, coverUrl, backgroundUrl, category, roomType, password, seatCount]);

    // Initialize seats
    for (let i = 0; i < seatCount; i++) {
      await pool.query(`
        INSERT INTO room_seats (id, room_id, seat_index, user_id, joined_at)
        VALUES ($1, $2, $3, $4, $5)
      `, [`${roomId}_seat_${i}`, roomId, i, i === 0 ? uid : null, i === 0 ? new Date() : null]);
    }

    res.json({ success: true, room: roomRes.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/rooms/:roomId/update', authMiddleware, async (req, res) => {
  const { roomId } = req.params;
  const { title, description, coverUrl, backgroundUrl, isLocked, password } = req.body;
  try {
    const query = `
      UPDATE audio_rooms SET
        title = COALESCE($1, title),
        description = COALESCE($2, description),
        cover_url = COALESCE($3, cover_url),
        background_url = COALESCE($4, background_url),
        is_locked = COALESCE($5, is_locked),
        password = COALESCE($6, password),
        updated_at = NOW()
      WHERE id = $7
      RETURNING *;
    `;
    const result = await pool.query(query, [title, description, coverUrl, backgroundUrl, isLocked, password, roomId]);
    res.json({ success: true, room: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/rooms/:roomId/close', authMiddleware, async (req, res) => {
  const { roomId } = req.params;
  try {
    await pool.query('UPDATE audio_rooms SET is_live = FALSE, updated_at = NOW() WHERE id = $1', [roomId]);
    io.to(`room_${roomId}`).emit('room_closed', { roomId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/rooms/:roomId/gifts', async (req, res) => {
  const { roomId } = req.params;
  try {
    const result = await pool.query(`
      SELECT g.*, u1.fullname AS sender_name, u1.photo_url AS sender_avatar, u2.fullname AS receiver_name
      FROM room_gifts g
      JOIN users u1 ON g.sender_id = u1.id
      JOIN users u2 ON g.receiver_id = u2.id
      WHERE g.room_id = $1
      ORDER BY g.created_at DESC
      LIMIT 100;
    `, [roomId]);
    res.json({ success: true, gifts: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.7 Wallet & Balance & Transactions
app.get('/api/wallet/balance', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  try {
    const result = await pool.query('SELECT coins, diamonds FROM users WHERE id = $1', [uid]);
    if (result.rows.length === 0) return res.status(404).json({ success: false, error: 'User not found' });
    res.json({ success: true, coins: result.rows[0].coins || 0, diamonds: result.rows[0].diamonds || 0 });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/wallet/transactions', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const limit = parseInt(req.query.limit || '50', 10);
  try {
    const result = await pool.query(`
      SELECT * FROM wallet_transactions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT $2;
    `, [uid, limit]);
    res.json({ success: true, transactions: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/wallet/admin-credit', authMiddleware, async (req, res) => {
  const { targetUserId, amount, currencyType = 'diamonds', note = '' } = req.body;
  if (!targetUserId || !amount) return res.status(400).json({ success: false, error: 'Target user and amount required' });

  const numAmount = parseInt(amount, 10);
  const txId = uuidv4();

  try {
    const col = currencyType === 'coins' ? 'coins' : 'diamonds';
    const updateRes = await pool.query(`
      UPDATE users SET ${col} = ${col} + $1, updated_at = NOW() WHERE id = $2 RETURNING ${col};
    `, [numAmount, targetUserId]);

    const balanceAfter = updateRes.rows[0] ? updateRes.rows[0][col] : 0;

    await pool.query(`
      INSERT INTO wallet_transactions (id, user_id, type, currency_type, amount, balance_after, description, created_at)
      VALUES ($1, $2, 'admin_reward', $3, $4, $5, $6, NOW());
    `, [txId, targetUserId, currencyType, numAmount, balanceAfter, note || 'Admin Credit']);

    res.json({ success: true, balanceAfter });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.8 Seller Diamond Requests
app.post('/api/seller/request-diamonds', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { sellerName, sellerPhone, requestedDiamonds, amountPaid, paymentMethod, transactionId, proofImageUrl, note } = req.body;
  const reqId = uuidv4();

  try {
    const result = await pool.query(`
      INSERT INTO seller_diamond_requests (id, seller_id, seller_name, seller_phone, requested_diamonds, amount_paid, payment_method, transaction_id, proof_image_url, note, status, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending', NOW(), NOW())
      RETURNING *;
    `, [reqId, uid, sellerName || '', sellerPhone || '', requestedDiamonds || 0, amountPaid || 0, paymentMethod || '', transactionId || '', proofImageUrl || '', note || '']);

    res.json({ success: true, request: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/seller/requests', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { status, all } = req.query;

  try {
    let query = 'SELECT * FROM seller_diamond_requests';
    const params = [];

    if (all !== 'true') {
      query += ' WHERE seller_id = $1';
      params.push(uid);
      if (status) {
        query += ' AND status = $2';
        params.push(status);
      }
    } else if (status) {
      query += ' WHERE status = $1';
      params.push(status);
    }
    query += ' ORDER BY created_at DESC LIMIT 100';

    const result = await pool.query(query, params);
    res.json({ success: true, requests: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/seller/requests/:id/action', authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { action, adminNote = '' } = req.body; // action: 'approve' or 'reject'
  const newStatus = action === 'approve' ? 'approved' : 'rejected';

  try {
    const reqRes = await pool.query('SELECT * FROM seller_diamond_requests WHERE id = $1', [id]);
    if (reqRes.rows.length === 0) return res.status(404).json({ success: false, error: 'Request not found' });

    const item = reqRes.rows[0];

    // If approving, credit seller diamonds
    if (newStatus === 'approved') {
      const diamonds = parseInt(item.requested_diamonds, 10);
      await pool.query('UPDATE users SET diamonds = diamonds + $1 WHERE id = $2', [diamonds, item.seller_id]);
      await pool.query(`
        INSERT INTO wallet_transactions (id, user_id, type, currency_type, amount, balance_after, description, created_at)
        VALUES ($1, $2, 'recharge', 'diamonds', $3, (SELECT diamonds FROM users WHERE id = $2), $4, NOW());
      `, [uuidv4(), item.seller_id, diamonds, `Seller Diamond Request Approved: ${adminNote}`]);
    }

    await pool.query(`
      UPDATE seller_diamond_requests SET status = $1, admin_note = $2, updated_at = NOW() WHERE id = $3;
    `, [newStatus, adminNote, id]);

    res.json({ success: true, status: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.9 Rankings & Leaderboards
app.get('/api/rankings/:type', async (req, res) => {
  const { type } = req.params; // 'gifters', 'receivers', 'rooms'
  try {
    if (type === 'gifters') {
      const result = await pool.query(`
        SELECT u.id, u.fullname, u.photo_url, u.level, u.vip_level, u.active_frame_id, u.active_badge_id,
               COALESCE(SUM(g.total_coins), 0) AS total_score
        FROM room_gifts g
        JOIN users u ON g.sender_id = u.id
        GROUP BY u.id
        ORDER BY total_score DESC
        LIMIT 50;
      `);
      return res.json({ success: true, rankings: result.rows });
    } else if (type === 'receivers') {
      const result = await pool.query(`
        SELECT u.id, u.fullname, u.photo_url, u.level, u.vip_level, u.active_frame_id, u.active_badge_id,
               COALESCE(SUM(g.total_coins), 0) AS total_score
        FROM room_gifts g
        JOIN users u ON g.receiver_id = u.id
        GROUP BY u.id
        ORDER BY total_score DESC
        LIMIT 50;
      `);
      return res.json({ success: true, rankings: result.rows });
    } else if (type === 'rooms') {
      const result = await pool.query(`
        SELECT r.id, r.title, r.cover_url, r.total_room_diamonds AS total_score, u.fullname AS owner_name
        FROM audio_rooms r
        JOIN users u ON r.owner_id = u.id
        ORDER BY r.total_room_diamonds DESC
        LIMIT 50;
      `);
      return res.json({ success: true, rankings: result.rows });
    }
    res.status(400).json({ success: false, error: 'Invalid ranking type' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.10 Store Inventory (User Owned Items) & Purchase
app.get('/api/store/my-assets', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  try {
    const result = await pool.query(`
      SELECT ua.*, sa.name, sa.category, sa.icon_url, sa.svga_url, sa.animation_url
      FROM user_assets ua
      JOIN store_assets sa ON ua.asset_id = sa.id
      WHERE ua.user_id = $1;
    `, [uid]);
    res.json({ success: true, assets: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/store/buy', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { assetId } = req.body;
  if (!assetId) return res.status(400).json({ success: false, error: 'assetId is required' });

  try {
    const assetRes = await pool.query('SELECT * FROM store_assets WHERE id = $1', [assetId]);
    if (assetRes.rows.length === 0) return res.status(404).json({ success: false, error: 'Asset not found' });

    const asset = assetRes.rows[0];
    const price = parseInt(asset.price_coins || '0', 10);

    // Check user balance
    const userRes = await pool.query('SELECT coins FROM users WHERE id = $1', [uid]);
    if ((userRes.rows[0]?.coins || 0) < price) {
      return res.status(400).json({ success: false, error: 'Insufficient coins' });
    }

    // Debit coins
    await pool.query('UPDATE users SET coins = coins - $1 WHERE id = $2', [price, uid]);

    // Insert into user_assets
    const uaId = `${uid}_${assetId}`;
    const validityDays = asset.validity_days || 30;
    const expiresAt = validityDays > 0 ? new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000) : null;

    await pool.query(`
      INSERT INTO user_assets (id, user_id, asset_id, is_permanent, expires_at, purchased_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
      ON CONFLICT (user_id, asset_id) DO UPDATE SET
        expires_at = EXCLUDED.expires_at,
        purchased_at = NOW();
    `, [uaId, uid, assetId, validityDays === 0, expiresAt]);

    res.json({ success: true, message: 'Purchased successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.11 App Events / Banners
app.get('/api/events', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM app_events WHERE is_active = TRUE ORDER BY created_at DESC LIMIT 20');
    res.json({ success: true, events: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5.8.12 Moments / News Feed APIs (Posts, Likes, Comments, Shares)
app.get('/api/moments/posts', async (req, res) => {
  const { limit = 20, offset = 0, type = 'latest' } = req.query;
  const numLimit = parseInt(limit, 10) || 20;
  const numOffset = parseInt(offset, 10) || 0;

  try {
    let orderBy = 'is_pinned DESC, created_at DESC';
    if (type === 'trending') {
      orderBy = 'is_pinned DESC, (like_count * 3 + comment_count * 5 + share_count * 8) DESC, created_at DESC';
    }

    const query = `
      SELECT p.*, u.fullname, u.photo_url, u.active_frame_id, u.level
      FROM news_feed_posts p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.is_deleted = FALSE
      ORDER BY ${orderBy}
      LIMIT $1 OFFSET $2;
    `;
    const result = await pool.query(query, [numLimit, numOffset]);
    res.json({ success: true, posts: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/moments/posts/:postId', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await pool.query(`
      SELECT p.*, u.fullname, u.photo_url, u.active_frame_id, u.level
      FROM news_feed_posts p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.id = $1 AND p.is_deleted = FALSE;
    `, [postId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Post not found' });
    }
    res.json({ success: true, post: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/moments/posts/create', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const {
    id: clientPostId,
    content = '',
    media = [],
    mediaUrls = [],
    mediaTypes = [],
    location = '',
    tags = [],
    userName = '',
    userAvatar = '',
    userFrameId = '',
    userLevel = 1,
  } = req.body;

  const postId = clientPostId || uuidv4();

  try {
    // Ensure user row
    await pool.query(`INSERT INTO users (id, fullname, updated_at) VALUES ($1, $2, NOW()) ON CONFLICT (id) DO NOTHING;`, [uid, userName || 'User']);

    const query = `
      INSERT INTO news_feed_posts (
        id, user_id, user_name, user_avatar, user_frame_id, user_level,
        content, media, media_urls, media_types, location, tags,
        created_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
      RETURNING *;
    `;
    const result = await pool.query(query, [
      postId,
      uid,
      userName || 'User',
      userAvatar || '',
      userFrameId || null,
      userLevel || 1,
      content,
      JSON.stringify(media || []),
      mediaUrls || [],
      mediaTypes || [],
      location || '',
      tags || [],
    ]);

    const createdPost = result.rows[0];

    // Broadcast realtime event
    io.emit('new_moment_post', createdPost);

    res.json({ success: true, post: createdPost });
  } catch (err) {
    console.error('Create moment error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/moments/posts/:postId/like', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { postId } = req.params;
  const { reactionType = 'like' } = req.body;
  const likeId = `${postId}_${uid}`;

  try {
    // Check if already liked
    const existing = await pool.query('SELECT * FROM news_feed_likes WHERE post_id = $1 AND user_id = $2', [postId, uid]);

    let isLiked = false;
    if (existing.rows.length > 0) {
      // Unlike
      await pool.query('DELETE FROM news_feed_likes WHERE post_id = $1 AND user_id = $2', [postId, uid]);
      await pool.query(`
        UPDATE news_feed_posts SET
          like_count = GREATEST(0, like_count - 1),
          liked_by = array_remove(liked_by, $1),
          updated_at = NOW()
        WHERE id = $2;
      `, [uid, postId]);
      isLiked = false;
    } else {
      // Like
      await pool.query(`
        INSERT INTO news_feed_likes (id, post_id, user_id, reaction_type, created_at)
        VALUES ($1, $2, $3, $4, NOW())
        ON CONFLICT (post_id, user_id) DO NOTHING;
      `, [likeId, postId, uid, reactionType]);

      await pool.query(`
        UPDATE news_feed_posts SET
          like_count = like_count + 1,
          liked_by = array_append(liked_by, $1),
          updated_at = NOW()
        WHERE id = $2;
      `, [uid, postId]);
      isLiked = true;
    }

    const postRes = await pool.query('SELECT id, like_count, liked_by FROM news_feed_posts WHERE id = $1', [postId]);
    const postData = postRes.rows[0] || {};

    io.emit('moment_liked', {
      postId,
      userId: uid,
      isLiked,
      reactionType,
      likeCount: postData.like_count || 0,
      likedBy: postData.liked_by || [],
    });

    res.json({ success: true, isLiked, likeCount: postData.like_count || 0, likedBy: postData.liked_by || [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/moments/posts/:postId/comments', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { postId } = req.params;
  const {
    id: clientCommentId,
    text = '',
    userName = '',
    userAvatar = '',
    userFrameId = '',
    imageUrl = '',
    replyToId = null,
    replyToUserName = null,
  } = req.body;

  if (!text && !imageUrl) {
    return res.status(400).json({ success: false, error: 'Text or image is required' });
  }

  const commentId = clientCommentId || uuidv4();

  try {
    const commentRes = await pool.query(`
      INSERT INTO news_feed_comments (
        id, post_id, user_id, user_name, user_avatar, user_frame_id,
        text, image_url, reply_to_id, reply_to_user_name, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
      RETURNING *;
    `, [commentId, postId, uid, userName || 'User', userAvatar || '', userFrameId || null, text, imageUrl || '', replyToId, replyToUserName]);

    await pool.query(`
      UPDATE news_feed_posts SET
        comment_count = comment_count + 1,
        updated_at = NOW()
      WHERE id = $1;
    `, [postId]);

    const createdComment = commentRes.rows[0];

    io.emit('new_moment_comment', {
      postId,
      comment: createdComment,
    });

    res.json({ success: true, comment: createdComment });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/moments/posts/:postId/comments', async (req, res) => {
  const { postId } = req.params;
  try {
    const result = await pool.query(`
      SELECT c.*, u.photo_url AS author_avatar, u.fullname AS author_name
      FROM news_feed_comments c
      LEFT JOIN users u ON c.user_id = u.id
      WHERE c.post_id = $1
      ORDER BY c.created_at ASC
      LIMIT 100;
    `, [postId]);

    res.json({ success: true, comments: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/moments/posts/:postId/share', async (req, res) => {
  const { postId } = req.params;
  try {
    await pool.query('UPDATE news_feed_posts SET share_count = share_count + 1, updated_at = NOW() WHERE id = $1', [postId]);
    io.emit('moment_shared', { postId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/moments/posts/:postId', authMiddleware, async (req, res) => {
  const uid = req.user.uid;
  const { postId } = req.params;
  try {
    await pool.query('UPDATE news_feed_posts SET is_deleted = TRUE, updated_at = NOW() WHERE id = $1 AND (user_id = $2 OR $3 = ANY(SELECT unnest(roles) FROM users WHERE id = $2))', [postId, uid, 'admin']);
    io.emit('moment_deleted', { postId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});


// ----------------------------------------------------------------------------
// 6. REAL-TIME SOCKET.IO ENGINE
// ----------------------------------------------------------------------------
io.use(async (socket, next) => {
  const explicitUid = socket.handshake.auth?.uid || socket.handshake.query?.uid;
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;

  if (explicitUid && explicitUid !== 'guest' && !explicitUid.startsWith('guest_')) {
    socket.user = { uid: explicitUid };
    return next();
  }

  if (!token) {
    socket.user = { uid: 'guest_' + socket.id.substring(0, 8) };
    return next();
  }

  try {
    if (admin.apps.length > 0) {
      try {
        const decoded = await admin.auth().verifyIdToken(token);
        socket.user = decoded;
      } catch (authErr) {
        socket.user = { uid: explicitUid || (token.length > 128 ? 'user_' + token.substring(0, 16) : token) };
      }
    } else {
      socket.user = { uid: explicitUid || token };
    }
    next();
  } catch (err) {
    socket.user = { uid: explicitUid || ('user_' + socket.id.substring(0, 8)) };
    next();
  }
});

io.on('connection', (socket) => {
  let uid = socket.user?.uid || socket.handshake.auth?.uid || socket.handshake.query?.uid || socket.id;
  socket.user = socket.user || { uid };
  connectedUsers.set(uid, socket.id);
  socket.join(`user_${uid}`);
  console.log(`🔌 User connected: ${uid} (Socket: ${socket.id})`);

  // Update online status in DB
  if (uid && !uid.startsWith('guest_') && uid !== 'guest') {
    pool.query(`
      INSERT INTO users (id, fullname, is_online, last_seen, created_at, updated_at)
      VALUES ($1, 'User', TRUE, NOW(), NOW(), NOW())
      ON CONFLICT (id) DO UPDATE SET is_online = TRUE, last_seen = NOW();
    `, [uid]).catch(() => {});
  }

  // Allow client to authenticate or update UID after connecting
  socket.on('authenticate', async ({ uid: newUid, token }) => {
    if (newUid && newUid !== 'guest') {
      connectedUsers.delete(uid);
      socket.leave(`user_${uid}`);
      uid = newUid;
      socket.user = { uid: newUid };
      connectedUsers.set(newUid, socket.id);
      socket.join(`user_${newUid}`);
      console.log(`🔑 Socket ${socket.id} authenticated as user_${newUid}`);
      await pool.query(`
        INSERT INTO users (id, fullname, is_online, last_seen, created_at, updated_at)
        VALUES ($1, 'User', TRUE, NOW(), NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET is_online = TRUE, last_seen = NOW();
      `, [newUid]).catch(() => {});
      socket.emit('authenticated', { uid: newUid });
    }
  });

  // --------------------------------------------------------------------------
  // 6.1 DIRECT 1-ON-1 MESSAGING
  // --------------------------------------------------------------------------
  socket.on('send_direct_message', async (data) => {
    // data: { id, msgId, receiverId, messageType, content, mediaUrl, mediaDuration, giftId, giftCount }
    const { receiverId, messageType = 'text', content = '', mediaUrl = '', mediaDuration = 0, giftId, giftCount = 1 } = data;
    if (!receiverId) return;

    // Generate deterministic conversation id
    const convId = [uid, receiverId].sort().join('_');
    const msgId = data.id || data.msgId || uuidv4();

    try {
      // 0. Ensure user rows exist in DB to prevent foreign key constraint errors
      await pool.query(`INSERT INTO users (id, updated_at) VALUES ($1, NOW()) ON CONFLICT (id) DO NOTHING;`, [uid]);
      await pool.query(`INSERT INTO users (id, updated_at) VALUES ($1, NOW()) ON CONFLICT (id) DO NOTHING;`, [receiverId]);

      // 1. Ensure conversation exists
      await pool.query(`
        INSERT INTO direct_conversations (id, user1_id, user2_id, last_message_text, last_message_type, last_message_sender_id, last_message_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET
          last_message_text = EXCLUDED.last_message_text,
          last_message_type = EXCLUDED.last_message_type,
          last_message_sender_id = EXCLUDED.last_message_sender_id,
          last_message_at = NOW(),
          updated_at = NOW()
      `, [convId, uid, receiverId, content || `[${messageType}]`, messageType, uid]);

      // 2. Insert message
      const msgRes = await pool.query(`
        INSERT INTO direct_messages (id, conversation_id, sender_id, receiver_id, message_type, content, media_url, media_duration, gift_id, gift_count, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
        ON CONFLICT (id) DO NOTHING
        RETURNING *;
      `, [msgId, convId, uid, receiverId, messageType, content, mediaUrl, mediaDuration, giftId || null, giftCount]);

      const messageObj = (msgRes.rows && msgRes.rows.length > 0)
        ? msgRes.rows[0]
        : {
            id: msgId,
            conversation_id: convId,
            sender_id: uid,
            receiver_id: receiverId,
            message_type: messageType,
            content,
            media_url: mediaUrl,
            media_duration: mediaDuration,
            gift_id: giftId || null,
            gift_count: giftCount,
            created_at: new Date().toISOString(),
          };

      // 3. Send to sender (acknowledgement)
      socket.emit('direct_message_sent', messageObj);
      io.to(`user_${uid}`).emit('direct_message_sent', messageObj);

      // 4. Send to receiver room and specific socket if online
      io.to(`user_${receiverId}`).emit('direct_message_received', messageObj);
      const receiverSocketId = connectedUsers.get(receiverId);
      if (receiverSocketId && receiverSocketId !== socket.id) {
        io.to(receiverSocketId).emit('direct_message_received', messageObj);
      }

      // 5. Send FCM Push Notification if offline
      sendFcmMessage(receiverId, {
        title: 'New Message',
        body: content || `Sent you a ${messageType}`,
        data: { type: 'chat', conversationId: convId, senderId: uid },
      }).catch(() => {});
    } catch (err) {
      console.error('Direct message error:', err);
      socket.emit('error', { message: 'Failed to send message: ' + err.message });
    }
  });

  // --------------------------------------------------------------------------
  // 6.2 VOICE ROOMS & SEATS REALTIME EVENTS
  // --------------------------------------------------------------------------
  socket.on('join_room', async ({ roomId }) => {
    if (!roomId) return;
    const normalizedRoomId = String(roomId).trim();
    socket.join(`room_${normalizedRoomId}`);
    console.log(`🎙️ User ${uid} joined room: ${normalizedRoomId}`);

    try {
      await pool.query(`
        INSERT INTO users (id, fullname, created_at, updated_at)
        VALUES ($1, 'User', NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [uid]);

      await pool.query(`
        INSERT INTO audio_rooms (id, owner_id, title, is_live, created_at, updated_at)
        VALUES ($1, $2, 'Room ' || $1, TRUE, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [normalizedRoomId, uid]);

      // Increment room total participants
      await pool.query('UPDATE audio_rooms SET total_participants = total_participants + 1 WHERE id = $1', [normalizedRoomId]);
    } catch (err) {
      console.error('join_room DB update non-fatal error:', err);
    }

    // Broadcast user entry notice to the room
    io.to(`room_${normalizedRoomId}`).emit('room_user_joined', {
      roomId: normalizedRoomId,
      userId: uid,
      timestamp: new Date().toISOString(),
    });
  });

  socket.on('leave_room', async ({ roomId }) => {
    if (!roomId) return;
    const normalizedRoomId = String(roomId).trim();
    socket.leave(`room_${normalizedRoomId}`);

    // If user was on a seat, release it
    await pool.query('UPDATE room_seats SET user_id = NULL WHERE room_id = $1 AND user_id = $2', [normalizedRoomId, uid]).catch(() => {});

    // Decrement participants
    pool.query('UPDATE audio_rooms SET total_participants = GREATEST(0, total_participants - 1) WHERE id = $1', [normalizedRoomId]).catch(() => {});

    io.to(`room_${normalizedRoomId}`).emit('room_user_left', { roomId: normalizedRoomId, userId: uid });
  });

  socket.on('take_seat', async ({ roomId, seatIndex }) => {
    const normalizedRoomId = String(roomId).trim();
    try {
      await pool.query(`
        INSERT INTO audio_rooms (id, owner_id, title, is_live, created_at, updated_at)
        VALUES ($1, $2, 'Room ' || $1, TRUE, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [normalizedRoomId, uid]);

      // Check if seat is free
      const seatCheck = await pool.query('SELECT * FROM room_seats WHERE room_id = $1 AND seat_index = $2', [normalizedRoomId, seatIndex]);
      if (seatCheck.rows.length > 0 && seatCheck.rows[0].user_id && seatCheck.rows[0].user_id !== uid) {
        return socket.emit('seat_error', { message: 'Seat is already occupied' });
      }

      // Assign seat
      await pool.query(`
        INSERT INTO room_seats (id, room_id, seat_index, user_id, joined_at)
        VALUES ($1, $2, $3, $4, NOW())
        ON CONFLICT (room_id, seat_index) DO UPDATE SET
          user_id = EXCLUDED.user_id,
          joined_at = NOW();
      `, [`${normalizedRoomId}_seat_${seatIndex}`, normalizedRoomId, seatIndex, uid]);

      // Broadcast seat update to everyone in room
      io.to(`room_${normalizedRoomId}`).emit('seat_updated', {
        roomId: normalizedRoomId,
        seatIndex,
        userId: uid,
        isMuted: false,
        isLocked: false,
      });
    } catch (err) {
      console.error('take_seat error:', err);
      socket.emit('seat_error', { message: err.message });
    }
  });

  socket.on('leave_seat', async ({ roomId, seatIndex }) => {
    const normalizedRoomId = String(roomId).trim();
    try {
      await pool.query('UPDATE room_seats SET user_id = NULL WHERE room_id = $1 AND seat_index = $2 AND user_id = $3', [normalizedRoomId, seatIndex, uid]);
      io.to(`room_${normalizedRoomId}`).emit('seat_updated', {
        roomId: normalizedRoomId,
        seatIndex,
        userId: null,
        isMuted: false,
        isLocked: false,
      });
    } catch (err) {
      socket.emit('seat_error', { message: err.message });
    }
  });

  // --------------------------------------------------------------------------
  // 6.3 ROOM CHAT & GIFTS BROADCASTING
  // --------------------------------------------------------------------------
  socket.on('send_room_message', async ({ roomId, content, messageType = 'text', extraData = {} }) => {
    if (!roomId || !content) return;
    const normalizedRoomId = String(roomId).trim();
    const msgId = extraData?.id || uuidv4();
    const nowIso = new Date().toISOString();

    // Ensure sender is in room socket channel
    socket.join(`room_${normalizedRoomId}`);

    const messagePayload = {
      id: msgId,
      roomId: normalizedRoomId,
      senderId: uid,
      messageType,
      content,
      extraData,
      createdAt: nowIso,
    };

    // Broadcast immediately to entire room and back to sender
    io.to(`room_${normalizedRoomId}`).emit('new_room_message', messagePayload);
    socket.emit('new_room_message', messagePayload);

    // Asynchronously persist to database
    try {
      await pool.query(`
        INSERT INTO users (id, fullname, created_at, updated_at)
        VALUES ($1, $2, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET fullname = CASE WHEN users.fullname = '' OR users.fullname = 'User' THEN EXCLUDED.fullname ELSE users.fullname END;
      `, [uid, extraData?.username || 'User']);

      await pool.query(`
        INSERT INTO audio_rooms (id, owner_id, title, is_live, created_at, updated_at)
        VALUES ($1, $2, 'Room ' || $1, TRUE, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [normalizedRoomId, uid]);

      await pool.query(`
        INSERT INTO room_messages (id, room_id, sender_id, message_type, content, extra_data, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW())
      `, [msgId, normalizedRoomId, uid, messageType, content, JSON.stringify(extraData)]);
    } catch (err) {
      console.error('Room message persistence error (non-fatal):', err);
    }
  });

  socket.on('send_room_gift', async ({ roomId, receiverId, giftId, giftName, giftIcon, giftSvgaUrl, giftCoins, giftCount = 1 }) => {
    if (!roomId || !receiverId || !giftId) return;
    const totalCoins = (giftCoins || 0) * giftCount;
    const giftTransactionId = uuidv4();

    // Ensure sender is in room channel
    socket.join(`room_${roomId}`);

    // Broadcast instant gift animation to entire room
    io.to(`room_${roomId}`).emit('room_gift_animation', {
      transactionId: giftTransactionId,
      roomId,
      senderId: uid,
      receiverId,
      giftId,
      giftName,
      giftIcon,
      giftSvgaUrl,
      giftCount,
      totalCoins,
      createdAt: new Date().toISOString(),
    });

    try {
      await pool.query(`
        INSERT INTO users (id, fullname, created_at, updated_at)
        VALUES ($1, 'User', NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [uid]);

      await pool.query(`
        INSERT INTO users (id, fullname, created_at, updated_at)
        VALUES ($1, 'User', NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [receiverId]);

      await pool.query(`
        INSERT INTO audio_rooms (id, owner_id, title, is_live, created_at, updated_at)
        VALUES ($1, $2, 'Room ' || $1, TRUE, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      `, [roomId, uid]);

      // 1. Debit sender coins, credit receiver diamonds
      await pool.query('UPDATE users SET coins = GREATEST(0, coins - $1) WHERE id = $2', [totalCoins, uid]);
      await pool.query('UPDATE users SET diamonds = diamonds + $1 WHERE id = $2', [totalCoins, receiverId]);
      await pool.query('UPDATE audio_rooms SET total_room_diamonds = total_room_diamonds + $1 WHERE id = $2', [totalCoins, roomId]);

      // 2. Insert gift record
      await pool.query(`
        INSERT INTO room_gifts (id, room_id, sender_id, receiver_id, gift_id, gift_name, gift_icon, gift_svga_url, gift_coins, gift_count, total_coins, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
      `, [giftTransactionId, roomId, uid, receiverId, giftId, giftName, giftIcon, giftSvgaUrl || '', giftCoins, giftCount, totalCoins]);
    } catch (err) {
      console.error('Room gift DB error (non-fatal):', err);
    }
  });

  // --------------------------------------------------------------------------
  // 6.4 GROUP CHATS REALTIME EVENTS
  // --------------------------------------------------------------------------
  socket.on('join_group', ({ groupId }) => {
    if (!groupId) return;
    socket.join(`group_${groupId}`);
    console.log(`👥 User ${uid} joined group room: ${groupId}`);
  });

  socket.on('leave_group', ({ groupId }) => {
    if (!groupId) return;
    socket.leave(`group_${groupId}`);
  });

  socket.on('send_group_message', async ({ groupId, content, messageType = 'text', mediaUrl = '', mediaDuration = 0 }) => {
    if (!groupId || !content) return;
    const msgId = uuidv4();
    try {
      const msgRes = await pool.query(`
        INSERT INTO group_messages (id, group_id, sender_id, message_type, content, media_url, media_duration, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        RETURNING *;
      `, [msgId, groupId, uid, messageType, content, mediaUrl, mediaDuration]);

      await pool.query(`
        UPDATE groups SET
          last_message_text = $1,
          last_message_type = $2,
          last_message_sender_id = $3,
          last_message_at = NOW(),
          updated_at = NOW()
        WHERE id = $4;
      `, [content || `[${messageType}]`, messageType, uid, groupId]);

      io.to(`group_${groupId}`).emit('new_group_message', msgRes.rows[0]);
    } catch (err) {
      console.error('Group socket message error:', err);
    }
  });

  // --------------------------------------------------------------------------
  // 6.5 CHAT MOMENTS / NEWS FEED REALTIME EVENTS
  // --------------------------------------------------------------------------
  socket.on('publish_moment', async (data) => {
    // data: { id, content, media, mediaUrls, mediaTypes, location, tags, userName, userAvatar, userFrameId, userLevel }
    const postId = data.id || uuidv4();
    try {
      await pool.query(`INSERT INTO users (id, fullname, updated_at) VALUES ($1, $2, NOW()) ON CONFLICT (id) DO NOTHING;`, [uid, data.userName || 'User']);
      const res = await pool.query(`
        INSERT INTO news_feed_posts (
          id, user_id, user_name, user_avatar, user_frame_id, user_level,
          content, media, media_urls, media_types, location, tags,
          created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
        RETURNING *;
      `, [
        postId,
        uid,
        data.userName || 'User',
        data.userAvatar || '',
        data.userFrameId || null,
        data.userLevel || 1,
        data.content || '',
        JSON.stringify(data.media || []),
        data.mediaUrls || [],
        data.mediaTypes || [],
        data.location || '',
        data.tags || [],
      ]);

      const postObj = (res.rows && res.rows[0]) ? res.rows[0] : { id: postId, user_id: uid, ...data, created_at: new Date().toISOString() };
      io.emit('new_moment_post', postObj);
    } catch (err) {
      console.error('Socket publish_moment error:', err);
    }
  });

  socket.on('like_moment', async ({ postId, reactionType = 'like' }) => {
    if (!postId) return;
    try {
      const existing = await pool.query('SELECT * FROM news_feed_likes WHERE post_id = $1 AND user_id = $2', [postId, uid]);
      let isLiked = false;
      if (existing.rows.length > 0) {
        await pool.query('DELETE FROM news_feed_likes WHERE post_id = $1 AND user_id = $2', [postId, uid]);
        await pool.query('UPDATE news_feed_posts SET like_count = GREATEST(0, like_count - 1), liked_by = array_remove(liked_by, $1), updated_at = NOW() WHERE id = $2', [uid, postId]);
        isLiked = false;
      } else {
        await pool.query('INSERT INTO news_feed_likes (id, post_id, user_id, reaction_type, created_at) VALUES ($1, $2, $3, $4, NOW()) ON CONFLICT DO NOTHING', [`${postId}_${uid}`, postId, uid, reactionType]);
        await pool.query('UPDATE news_feed_posts SET like_count = like_count + 1, liked_by = array_append(liked_by, $1), updated_at = NOW() WHERE id = $2', [uid, postId]);
        isLiked = true;
      }
      const postRes = await pool.query('SELECT id, like_count, liked_by FROM news_feed_posts WHERE id = $1', [postId]);
      const postData = postRes.rows[0] || {};
      io.emit('moment_liked', {
        postId,
        userId: uid,
        isLiked,
        reactionType,
        likeCount: postData.like_count || 0,
        likedBy: postData.liked_by || [],
      });
    } catch (err) {
      console.error('Socket like_moment error:', err);
    }
  });

  socket.on('comment_moment', async ({ postId, commentId, text, userName, userAvatar, userFrameId, imageUrl, replyToId, replyToUserName }) => {
    if (!postId || (!text && !imageUrl)) return;
    const cId = commentId || uuidv4();
    try {
      const res = await pool.query(`
        INSERT INTO news_feed_comments (id, post_id, user_id, user_name, user_avatar, user_frame_id, text, image_url, reply_to_id, reply_to_user_name, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW())
        RETURNING *;
      `, [cId, postId, uid, userName || 'User', userAvatar || '', userFrameId || null, text || '', imageUrl || '', replyToId, replyToUserName]);

      await pool.query('UPDATE news_feed_posts SET comment_count = comment_count + 1, updated_at = NOW() WHERE id = $1', [postId]);
      io.emit('new_moment_comment', { postId, comment: res.rows[0] });
    } catch (err) {
      console.error('Socket comment_moment error:', err);
    }
  });

  // Socket event for broadcasting live status to followers
  socket.on('notify_followers_live', async ({ roomId, roomName, creatorName, creatorAvatar }) => {
    if (!roomId) return;
    try {
      const hostName = creatorName || 'User';
      const title = `${hostName} is on live!`;
      const body = `Let's have fun together!!🤘🤟`;
      const hostAvatar = creatorAvatar || '';

      const followersRes = await pool.query(`
        SELECT DISTINCT u.id, u.fcm_token
        FROM users u
        JOIN (
          SELECT user_id AS follower_id FROM user_relationships WHERE target_user_id = $1 AND relationship_type = 'following'
          UNION
          SELECT follower_id FROM user_follows WHERE user_id = $1
        ) f ON u.id = f.follower_id
        WHERE u.id != $1
          AND (u.is_online = TRUE OR u.last_seen > NOW() - INTERVAL '15 minutes')
      `, [uid]);

      for (const follower of followersRes.rows) {
        if (follower.fcm_token) {
          sendPushNotificationPayload({
            deviceToken: follower.fcm_token,
            title,
            body,
            type: 'follower_room',
            call: { type: 'follower_room', roomId, roomName, creatorId: uid },
            senderId: uid,
            senderAvatar: hostAvatar,
          });
        }
        const sId = connectedUsers.get(follower.id);
        if (sId) {
          io.to(sId).emit('follower_live_notification', {
            title,
            body,
            senderId: uid,
            senderName: hostName,
            senderAvatar: hostAvatar,
            roomId,
            roomName: roomName || `${hostName}'s Room`,
            timestamp: new Date().toISOString(),
          });
        }
      }
    } catch (err) {
      console.error('Socket notify_followers_live error:', err);
    }
  });

  // Disconnect handler
  socket.on('disconnect', () => {
    connectedUsers.delete(uid);
    console.log(`🔌 User disconnected: ${uid}`);
    pool.query('UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1', [uid]).catch(() => {});
  });
});

// Helper for FCM Push Notifications
async function sendPushNotificationPayload({ deviceToken, title, body, type = 'follower_room', call = {}, senderId = '', senderAvatar = '' }) {
  if (admin.apps.length === 0 || !deviceToken) return;
  try {
    const message = {
      token: deviceToken,
      data: {
        type: String(type),
        call: typeof call === 'string' ? call : JSON.stringify(call || {}),
        senderId: String(senderId),
        senderAvatar: String(senderAvatar),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        status: 'done',
        title: String(title),
        body: String(body),
      },
      android: {
        priority: 'high',
        ttl: 3600 * 1000,
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            contentAvailable: true,
            sound: 'default',
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
    };

    await admin.messaging().send(message);
  } catch (err) {
    console.warn('FCM send warning:', err.message);
  }
}

async function sendFcmMessage(targetUserId, { title, body, data = {} }) {
  if (admin.apps.length === 0) return;
  try {
    const userRes = await pool.query('SELECT fcm_token FROM users WHERE id = $1', [targetUserId]);
    if (userRes.rows.length === 0 || !userRes.rows[0].fcm_token) return;

    const fcmToken = userRes.rows[0].fcm_token;
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    });
  } catch (err) {
    console.warn('FCM send warning:', err.message);
  }
}

// ----------------------------------------------------------------------------
// 7. START SERVER
// ----------------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 ImChat VPS Backend running at http://localhost:${PORT}`);
  console.log(`📡 Socket.io WebSocket ready for connections.`);
});
