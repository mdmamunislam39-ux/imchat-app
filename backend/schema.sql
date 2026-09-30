-- ============================================================================
-- IMCHAT POSTGRESQL DATABASE SCHEMA (VPS BACKEND)
-- Supports: 1v1 Chats, Voice Rooms, Seats, Gifts, Store Assets (Frames, Badges,
-- Emojis, Themes), Wallets, Transactions, and Realtime Events.
-- Compatible with Firebase Auth (users.id = Firebase UID).
-- ============================================================================

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. USERS TABLE (Mirrors Firebase Auth UID & Profile)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(128) PRIMARY KEY,                  -- Firebase Auth UID
    search_id VARCHAR(32) UNIQUE,                 -- Short user ID (e.g. 100234)
    fullname VARCHAR(100) NOT NULL DEFAULT '',
    email VARCHAR(150),
    phone_number VARCHAR(30),
    photo_url TEXT DEFAULT '',
    gender VARCHAR(20) DEFAULT 'unknown',
    bio TEXT DEFAULT '',
    birthdate DATE,
    country VARCHAR(100) DEFAULT '',
    
    -- Currency & Economy
    coins BIGINT NOT NULL DEFAULT 0,
    diamonds BIGINT NOT NULL DEFAULT 0,
    
    -- Status & Roles
    user_type VARCHAR(50) DEFAULT 'regular',      -- 'regular', 'agency', 'seller', 'admin'
    roles TEXT[] DEFAULT ARRAY['regular'],
    is_banned BOOLEAN NOT NULL DEFAULT FALSE,
    ban_until TIMESTAMP WITH TIME ZONE,
    
    -- Active Equipped Assets (Foreign keys to store_assets)
    active_frame_id VARCHAR(100),
    active_badge_id VARCHAR(100),
    active_entrance_id VARCHAR(100),
    active_bubble_id VARCHAR(100),
    active_theme_id VARCHAR(100),
    active_nameplate_id VARCHAR(100),
    active_nameplate_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    active_mic_refill_id VARCHAR(100),
    active_room_profile_bg_id VARCHAR(100),
    active_short_profile_theme_id VARCHAR(100),

    -- Owned Inventory Assets
    owned_badges TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_frames TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_entry_effects TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_nameplates TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_mic_refills TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_room_profile_bgs TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_short_profile_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    owned_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Level & VIP
    level INT NOT NULL DEFAULT 1,
    level_progress BIGINT NOT NULL DEFAULT 0,
    vip_level INT NOT NULL DEFAULT 0,
    vip_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- FCM Push Notification Token
    fcm_token TEXT DEFAULT '',
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_live_notification_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Safe migrations for existing databases
DO $$
BEGIN
    ALTER TABLE users ADD COLUMN IF NOT EXISTS last_live_notification_at TIMESTAMP WITH TIME ZONE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS active_nameplate_id VARCHAR(100);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS active_nameplate_ids TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS active_mic_refill_id VARCHAR(100);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS active_room_profile_bg_id VARCHAR(100);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS active_short_profile_theme_id VARCHAR(100);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_badges TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_frames TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_entry_effects TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_nameplates TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_mic_refills TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_room_profile_bgs TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_short_profile_themes TEXT[] DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE users ADD COLUMN IF NOT EXISTS owned_themes TEXT[] DEFAULT ARRAY[]::TEXT[];
EXCEPTION WHEN OTHERS THEN
    -- Ignore error if column already exists
END $$;

CREATE INDEX IF NOT EXISTS idx_users_search_id ON users(search_id);
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);

-- ----------------------------------------------------------------------------
-- 2. DIRECT 1-ON-1 CHATS & MESSAGES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS direct_conversations (
    id VARCHAR(128) PRIMARY KEY,                  -- E.g. uid1_uid2 (alphabetically sorted)
    user1_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_text TEXT DEFAULT '',
    last_message_type VARCHAR(30) DEFAULT 'text', -- 'text', 'voice', 'image', 'gift', 'emoji'
    last_message_sender_id VARCHAR(128),
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    unread_count_user1 INT DEFAULT 0,
    unread_count_user2 INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_conv_user1 ON direct_conversations(user1_id);
CREATE INDEX IF NOT EXISTS idx_conv_user2 ON direct_conversations(user2_id);

CREATE TABLE IF NOT EXISTS direct_messages (
    id VARCHAR(64) PRIMARY KEY,
    conversation_id VARCHAR(128) NOT NULL REFERENCES direct_conversations(id) ON DELETE CASCADE,
    sender_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_type VARCHAR(30) NOT NULL DEFAULT 'text', -- 'text', 'voice', 'image', 'gift', 'emoji'
    content TEXT NOT NULL DEFAULT '',
    media_url TEXT DEFAULT '',
    media_duration INT DEFAULT 0,                  -- For voice messages (seconds)
    gift_id VARCHAR(100),
    gift_count INT DEFAULT 1,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_direct_msg_conv ON direct_messages(conversation_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 2.2 USER FOLLOWS & RELATIONSHIPS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_follows (
    id VARCHAR(128) PRIMARY KEY,                  -- E.g. followerId_userId
    follower_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_follows_user ON user_follows(user_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);

-- ----------------------------------------------------------------------------
-- 2.5 GROUP CHATS & GROUP MESSAGES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS groups (
    id VARCHAR(128) PRIMARY KEY,
    name VARCHAR(150) NOT NULL DEFAULT '',
    description TEXT DEFAULT '',
    cover_url TEXT DEFAULT '',
    creator_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_text TEXT DEFAULT '',
    last_message_type VARCHAR(30) DEFAULT 'text',
    last_message_sender_id VARCHAR(128),
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    member_count INT NOT NULL DEFAULT 1,
    is_broadcast BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS group_members (
    group_id VARCHAR(128) NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL DEFAULT 'member', -- 'creator', 'admin', 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS group_messages (
    id VARCHAR(64) PRIMARY KEY,
    group_id VARCHAR(128) NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    sender_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_type VARCHAR(30) NOT NULL DEFAULT 'text',
    content TEXT NOT NULL DEFAULT '',
    media_url TEXT DEFAULT '',
    media_duration INT DEFAULT 0,
    gift_id VARCHAR(100),
    gift_count INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_group_msg ON group_messages(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);


-- ----------------------------------------------------------------------------
-- 3. AUDIO / VOICE ROOMS & SEAT MANAGEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audio_rooms (
    id VARCHAR(64) PRIMARY KEY,
    owner_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    description TEXT DEFAULT '',
    cover_url TEXT DEFAULT '',
    background_url TEXT DEFAULT '',
    category VARCHAR(50) DEFAULT 'chat',          -- 'chat', 'gaming', 'music', 'dating'
    room_type VARCHAR(30) DEFAULT 'public',       -- 'public', 'private', 'vip'
    password VARCHAR(50) DEFAULT '',
    
    -- Seat layout
    seat_count INT NOT NULL DEFAULT 8,            -- 8, 10, 12, etc.
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    is_live BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Agora or LiveKit Room Channel
    rtc_channel VARCHAR(100),
    
    total_participants INT NOT NULL DEFAULT 0,
    total_room_diamonds BIGINT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rooms_is_live ON audio_rooms(is_live, created_at DESC);

-- Realtime Room Seats
CREATE TABLE IF NOT EXISTS room_seats (
    id VARCHAR(64) PRIMARY KEY,                   -- E.g. room123_seat_0
    room_id VARCHAR(64) NOT NULL REFERENCES audio_rooms(id) ON DELETE CASCADE,
    seat_index INT NOT NULL,
    user_id VARCHAR(128) REFERENCES users(id) ON DELETE SET NULL,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(room_id, seat_index)
);

CREATE INDEX IF NOT EXISTS idx_seats_room ON room_seats(room_id);

-- Room Live Chat Messages
CREATE TABLE IF NOT EXISTS room_messages (
    id VARCHAR(64) PRIMARY KEY,
    room_id VARCHAR(64) NOT NULL REFERENCES audio_rooms(id) ON DELETE CASCADE,
    sender_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_type VARCHAR(30) NOT NULL DEFAULT 'text', -- 'text', 'emoji', 'gift_notice', 'system', 'entry'
    content TEXT NOT NULL DEFAULT '',
    extra_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_room_messages_room ON room_messages(room_id, created_at DESC);

-- Room Gifts & Gift Wall Transactions
CREATE TABLE IF NOT EXISTS room_gifts (
    id VARCHAR(64) PRIMARY KEY,
    room_id VARCHAR(64) NOT NULL REFERENCES audio_rooms(id) ON DELETE CASCADE,
    sender_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gift_id VARCHAR(100) NOT NULL,
    gift_name VARCHAR(100) NOT NULL,
    gift_icon TEXT NOT NULL,
    gift_svga_url TEXT DEFAULT '',
    gift_coins BIGINT NOT NULL DEFAULT 0,
    gift_count INT NOT NULL DEFAULT 1,
    total_coins BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_room_gifts_room ON room_gifts(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_room_gifts_receiver ON room_gifts(receiver_id);

-- ----------------------------------------------------------------------------
-- 4. STORE & VIRTUAL ASSETS (Frames, Badges, Emojis, Entrance, Themes)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_assets (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,                -- 'frame', 'badge', 'entrance', 'bubble', 'room_theme', 'gift', 'emoji'
    icon_url TEXT NOT NULL,
    svga_url TEXT DEFAULT '',
    animation_url TEXT DEFAULT '',
    price_coins BIGINT NOT NULL DEFAULT 0,
    price_diamonds BIGINT NOT NULL DEFAULT 0,
    validity_days INT NOT NULL DEFAULT 30,        -- 0 for permanent
    is_vip_only BOOLEAN NOT NULL DEFAULT FALSE,
    required_vip_level INT DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_store_assets_cat ON store_assets(category, is_active);

-- User Inventory of Purchased/Owned Assets
CREATE TABLE IF NOT EXISTS user_assets (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    asset_id VARCHAR(100) NOT NULL REFERENCES store_assets(id) ON DELETE CASCADE,
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    is_permanent BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP WITH TIME ZONE,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_user_assets_user ON user_assets(user_id);

-- ----------------------------------------------------------------------------
-- 5. WALLET & FINANCIAL TRANSACTIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,                    -- 'recharge', 'send_gift', 'receive_gift', 'buy_asset', 'daily_checkin', 'admin_reward'
    currency_type VARCHAR(20) NOT NULL,           -- 'coins', 'diamonds'
    amount BIGINT NOT NULL,                       -- Positive for credit, negative for debit
    balance_after BIGINT NOT NULL,
    reference_id VARCHAR(128) DEFAULT '',         -- E.g. room_id or gift_id or payment_id
    description TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON wallet_transactions(user_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 6. RELATIONSHIPS (Followers, Friends, Blocks)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_relationships (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_type VARCHAR(30) NOT NULL,       -- 'following', 'friend', 'blocked'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, target_user_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_user_rel_user ON user_relationships(user_id);
CREATE INDEX IF NOT EXISTS idx_user_rel_target ON user_relationships(target_user_id);

-- ----------------------------------------------------------------------------
-- 7. GROUP CHATS & GROUP MESSAGES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS groups (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT DEFAULT '',
    cover_url TEXT DEFAULT '',
    creator_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_text TEXT DEFAULT '',
    last_message_type VARCHAR(30) DEFAULT 'text',
    last_message_sender_id VARCHAR(128),
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    member_count INT NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS group_members (
    id VARCHAR(128) PRIMARY KEY, -- group_id + '_' + user_id
    group_id VARCHAR(64) NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL DEFAULT 'member', -- 'creator', 'admin', 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);

CREATE TABLE IF NOT EXISTS group_messages (
    id VARCHAR(64) PRIMARY KEY,
    group_id VARCHAR(64) NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    sender_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_type VARCHAR(30) NOT NULL DEFAULT 'text',
    content TEXT NOT NULL DEFAULT '',
    media_url TEXT DEFAULT '',
    media_duration INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_group_messages_group ON group_messages(group_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- 8. SELLER DIAMOND REQUESTS & ADMIN CREDITS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seller_diamond_requests (
    id VARCHAR(64) PRIMARY KEY,
    seller_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seller_name VARCHAR(100) DEFAULT '',
    seller_phone VARCHAR(30) DEFAULT '',
    requested_diamonds BIGINT NOT NULL DEFAULT 0,
    amount_paid NUMERIC(12, 2) DEFAULT 0,
    payment_method VARCHAR(50) DEFAULT '',
    transaction_id VARCHAR(100) DEFAULT '',
    proof_image_url TEXT DEFAULT '',
    note TEXT DEFAULT '',
    admin_note TEXT DEFAULT '',
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_seller_req_seller ON seller_diamond_requests(seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_seller_req_status ON seller_diamond_requests(status);

-- ----------------------------------------------------------------------------
-- 9. EVENTS & BANNERS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_events (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT DEFAULT '',
    banner_url TEXT NOT NULL,
    target_url TEXT DEFAULT '',
    start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 10. CHAT MOMENTS / NEWS FEED POSTS, COMMENTS, LIKES & SHARES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_feed_posts (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name VARCHAR(100) NOT NULL DEFAULT 'User',
    user_avatar TEXT DEFAULT '',
    user_frame_id VARCHAR(100),
    user_level INT NOT NULL DEFAULT 1,
    content TEXT DEFAULT '',
    media JSONB DEFAULT '[]'::jsonb,                 -- Array of PostMedia objects [{url, type, thumbnailUrl, aspectRatio}]
    media_urls TEXT[] DEFAULT ARRAY[]::TEXT[],
    media_types TEXT[] DEFAULT ARRAY[]::TEXT[],
    location VARCHAR(150) DEFAULT '',
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    like_count INT NOT NULL DEFAULT 0,
    liked_by TEXT[] DEFAULT ARRAY[]::TEXT[],
    comment_count INT NOT NULL DEFAULT 0,
    share_count INT NOT NULL DEFAULT 0,
    reactions JSONB DEFAULT '{}'::jsonb,             -- {like: 5, love: 2, etc.}
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    visibility VARCHAR(30) NOT NULL DEFAULT 'public',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_posts_user ON news_feed_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON news_feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_pinned ON news_feed_posts(is_pinned, created_at DESC);

CREATE TABLE IF NOT EXISTS news_feed_comments (
    id VARCHAR(64) PRIMARY KEY,
    post_id VARCHAR(64) NOT NULL REFERENCES news_feed_posts(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name VARCHAR(100) NOT NULL DEFAULT 'User',
    user_avatar TEXT DEFAULT '',
    user_frame_id VARCHAR(100),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    text TEXT NOT NULL DEFAULT '',
    image_url TEXT DEFAULT '',
    like_count INT NOT NULL DEFAULT 0,
    liked_by TEXT[] DEFAULT ARRAY[]::TEXT[],
    reply_to_id VARCHAR(64),
    reply_to_user_name VARCHAR(100),
    is_edited BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON news_feed_comments(post_id, created_at ASC);

CREATE TABLE IF NOT EXISTS news_feed_likes (
    id VARCHAR(128) PRIMARY KEY, -- post_id + '_' + user_id
    post_id VARCHAR(64) NOT NULL REFERENCES news_feed_posts(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction_type VARCHAR(30) NOT NULL DEFAULT 'like',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_post ON news_feed_likes(post_id);


