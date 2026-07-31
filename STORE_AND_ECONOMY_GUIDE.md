# imChat - Store & Economy System Guide

## Table of Contents

1. [Currency System](#currency-system)
2. [Store / Shop System](#store--shop-system)
3. [Gift Economy](#gift-economy)
4. [Agency & Host System](#agency--host-system)
5. [Withdrawal System](#withdrawal-system)
6. [Beans to Coins Conversion](#beans-to-coins-conversion)
7. [Firestore Collections Reference](#firestore-collections-reference)

---

## Currency System

| Currency | Purpose | Earned By | Spent On |
|----------|---------|-----------|----------|
| **Coins** | Primary spending currency | Purchased with real money, bean exchange | Sending gifts, buying store items |
| **Beans** | Earnings currency | Receiving gifts (split %) | Exchange to coins, withdraw |
| **Diamonds** (`totalDiamonds`) | Lifetime gift value tracker | Receiving gifts (full value) | Not spent — used for level/ranking |

---

## Store / Shop System

### Item Types

| Type | Equip Field | Description |
|------|-------------|-------------|
| `badge` | `customization.selectedBadgeId` | Profile badges |
| `avatarFrame` | `customization.selectedFrameId` | Avatar frame overlays |
| `entryEffect` | `customization.selectedEntryEffectId` | Audio room entrance animations |

### Firestore Structure

**Catalog** — `market_items/{itemId}`

```
{
  id: "abc123",
  name: "Golden Frame",
  type: "avatarFrame",
  category: "premium",
  coinPrice: 500,
  diamondPrice: 500,          // legacy, coins used for all purchases
  imageUrl: "https://...",
  fileUrl: "https://...",      // SVGA/animation file for effects
  expirationDuration: 30,     // days (null = permanent)
  isActive: true,
  createdAt: Timestamp
}
```

**User Inventory** — `user_store_items/{docId}`

```
{
  id: "uuid-v4",
  userId: "user123",
  storeItemId: "abc123",       // ref to market_items
  storeItemName: "Golden Frame",
  itemType: "avatarFrame",
  assignedAt: Timestamp,
  expiresAt: Timestamp | null, // assignedAt + expirationDuration days
  isActive: true,
  assignedBy: "user_purchase"  // or admin username
}
```

### Purchase Flow

All operations run inside a **single Firestore transaction** (atomic — all succeed or all rollback):

```
User taps "Buy"
  |
  v
1. Validate: user.coins >= item.coinPrice
  |
  v
2. FIRESTORE TRANSACTION:
   a) Users/{userId}        → coins: -cost
   b) user_store_items/new  → ownership record (with expiresAt if applicable)
   c) wallet_transactions/new → audit: type='purchase', coins=-cost
  |
  v
3. UI update: add to _ownedItemIds, show "Equip" button
```

### Equip / Unequip

**Equip** — updates user doc:
```
Users/{userId}/customization.selectedFrameId = "itemId"
```

**Unequip** — deletes the field:
```
Users/{userId}/customization.selectedFrameId = FieldValue.delete()
```

Only **one item per type** can be equipped at a time. Equipping a new item replaces the previous one.

### Entry Effects in Audio Rooms

When a user joins an audio room:
1. Read `Users/{userId}/customization.selectedEntryEffectId`
2. Fetch effect from `market_items/{effectId}` to get `fileUrl`
3. Write to `audio_rooms_v2/{roomId}/entrance_effects/` subcollection
4. Room UI plays the SVGA animation

### Notes

- All purchases use **coins**, not diamonds (despite some UI labels)
- Items with `expirationDuration` get an `expiresAt` but **no auto-expiry cleanup exists** — expired items remain in DB
- Admin can assign items to users without purchase via `assignStoreItemToUser()`

---

## Gift Economy

### User Types

| Type | `userType` field | Bean Split |
|------|------------------|------------|
| Normal User | `regular` | 50% receiver / 50% platform |
| Registered Host | `host` | 70% receiver / 10% agency / 20% platform |

### Config Source

Rates are read from `platform_config/gift_conversion` (cached 5 minutes):

```
{
  hostReceiverRate: 0.70,
  hostAgencyRate: 0.10,
  normalReceiverRate: 0.50,
  beanToDiamondRate: 1.0
}
```

Falls back to these defaults if the Firestore doc doesn't exist.

### Gift Send Flow

**Example: 1000-credit gift sent to a host**

```
User taps "Send Gift"
  |
  v
1. Validate: sender.coins >= gift.credits (1000)
  |
  v
2. Read receiver's userType and agencyId from Users/{receiverId}
   Read config from platform_config/gift_conversion
   If host: query hosts collection for hostDocId
  |
  v
3. Calculate split:
   Host:   beansToReceiver = 700, beansToAgency = 100, platform = 200
   Normal: beansToReceiver = 500, platform = 500
  |
  v
4. FIRESTORE BATCH (atomic):
   a) Users/{senderId}           → coins: -1000
   b) Users/{receiverId}         → beans: +700, totalDiamonds: +1000
   c) agencies/{agencyId}        → beans: +100 (host only)
   d) gift_transactions/new      → full transaction record + economy fields
   e) host_earnings/new          → earnings record (host only)
   f) hosts/{hostDocId}          → performance.totalEarnings: +700
                                    performance.totalDiamonds: +1000
                                    performance.totalGiftsReceived: +1
   g) audio_rooms_v2/{roomId}    → totalRevenue: +1000
                                    contributors.{senderId} stats updated
  |
  v
5. Send chat notification in room (emoji chat message)
6. Gift animation overlay plays via StreamBuilder on gift_transactions
```

### What Gets Written Where

| Document | Fields Updated |
|----------|---------------|
| `Users/{senderId}` | `coins: -gift.credits` |
| `Users/{receiverId}` | `beans: +splitAmount`, `totalDiamonds: +gift.credits` |
| `agencies/{agencyId}` | `beans: +agencyShare` (host with agency only) |
| `gift_transactions/{id}` | Full record: sender/receiver info, gift info, `receiverType`, `beansToReceiver`, `beansToAgency`, `platformShare`, `agencyId`, `diamondAmount` |
| `host_earnings/{id}` | `hostId`, `diamondsEarned`, `beansEarned`, `agencyId`, `source: 'gift'`, `giftName` (host only) |
| `hosts/{hostDocId}` | `performance.totalEarnings`, `.totalDiamonds`, `.totalGiftsReceived`, `.lastUpdated` (host only) |
| `audio_rooms_v2/{roomId}` | `totalRevenue`, `lastGiftSent/Sender/Name`, `contributors.{senderId}` daily/weekly/monthly stats |

---

## Agency & Host System

### Data Model

```
agencies/{agencyId}
  ├── agencyName, ownerUserId, ownerName
  ├── totalHosts, hostIds: [hostId1, hostId2, ...]
  ├── beans (agency commission balance)
  └── totalCommissionEarned

hosts/{hostDocId}          ← auto-generated ID, NOT userId
  ├── userId, agencyId, hostName
  ├── isActive, status: "active"
  ├── joinedDate
  └── performance:
      ├── totalEarnings      ← beans earned (after 70% split)
      ├── totalDiamonds      ← full gift value received
      ├── totalGiftsReceived ← gift count
      ├── totalLiveHours     ← accumulated from room sessions
      ├── totalCoins
      ├── averageRating
      └── lastUpdated
```

### Agency Screen Views

**Host View** — shows "Your Performance" grid:
- Earnings (totalEarnings)
- Diamonds (totalDiamonds)
- Gifts (totalGiftsReceived)
- Live Hours (totalLiveHours)

**Owner View** — shows list of all hosts with mini-stats per host:
- Diamond count, gift count, live hours

**Owner Analytics** — aggregates all host stats across the agency.

### Live Hours Tracking

Tracked automatically when a **host** leaves an audio room:

```
Host leaves room
  |
  v
1. Check: was leaving participant the host? (isHost == true || isCreator)
  |
  v
2. Calculate: sessionHours = (now - participant.joinedAt) in hours
  |
  v
3. Query hosts collection by userId + isActive to find hostDocId
  |
  v
4. Update: hosts/{hostDocId}/performance.totalLiveHours += sessionHours
```

- Only tracked for **registered hosts** (users with a record in `hosts` collection)
- Non-host room creators or regular users are skipped
- Runs in try/catch — never blocks the room leave flow

---

## Withdrawal System

### Flow

```
User taps "Withdraw" on Bean Management page
  |
  v
1. Enter: amount (min 10,000 beans), account number, optional note
  |
  v
2. Validate:
   - Sufficient beans
   - No existing pending withdrawal
   - Minimum amount met
  |
  v
3. FIRESTORE TRANSACTION:
   a) Users/{userId}     → beans: -amount (escrow)
   b) withdrawals/new    → status: 'pending', amount, accountNumber, note
  |
  v
4. Admin reviews in Admin Panel → approves or rejects
  |
  v
5. User can create new withdrawal after previous is completed/rejected
```

### Withdrawal Document — `withdrawals/{id}`

```
{
  id: "uuid-v4",
  userId: "user123",
  username: "John",
  userType: "host",
  amount: 50000,
  accountNumber: "1234567890",
  note: "Monthly withdrawal",
  status: "pending",          // pending | approved | rejected
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### UI Display (Bean Management Page)

- **Withdrawal Beans**: total amount currently in pending withdrawals
- **Beans to be confirmed**: same pending amount
- **Withdrawal History**: list with color-coded status badges
  - Pending = orange
  - Approved = green
  - Rejected = red

---

## Beans to Coins Conversion

### Flow

```
User taps "Exchange Beans" on Bean Management page
  |
  v
1. Validate: beans >= 100,000 (minimum)
  |
  v
2. Calculate:
   - eligibleBeans = (beans / 100) * 100  (multiples of 100)
   - coinsGained = (eligibleBeans * exchangeRate) / 100
   - Exchange rate read from platform_config/gift_conversion (beanToDiamondRate)
  |
  v
3. FIRESTORE TRANSACTION:
   a) Users/{userId}             → beans: -eligibleBeans, coins: +coinsGained
   b) wallet_transactions/new    → type: 'exchange', beans: -amount, coins: +amount
   c) bean_conversions/new       → userId, username, beansSpent, diamondsReceived, rate
```

### Exchange Rate

- Read dynamically from `platform_config/gift_conversion.beanToDiamondRate`
- Default: `1.0` (100 beans = 100 coins)
- Displayed on the Bean Management page exchange rate card

---

## Firestore Collections Reference

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `Users` | User profiles | coins, beans, totalDiamonds, userType, agencyId, customization |
| `market_items` | Store catalog | name, type, coinPrice, imageUrl, expirationDuration |
| `user_store_items` | User inventory | userId, storeItemId, expiresAt, isActive, assignedBy |
| `wallet_transactions` | All wallet activity | userId, type, coins, beans, description |
| `gift` | Gift catalog | name, credits, pngUrl, svgaUrl |
| `gift_transactions` | Gift sends | sender/receiver info, credits, beansToReceiver, platformShare |
| `host_earnings` | Per-gift host earnings | hostId, diamondsEarned, beansEarned, agencyId, source |
| `hosts` | Host profiles (agency members) | userId, agencyId, performance.* |
| `agencies` | Agency profiles | ownerUserId, totalHosts, hostIds, beans |
| `withdrawals` | Withdrawal requests | userId, amount, status, accountNumber |
| `bean_conversions` | Bean exchange audit | userId, beansSpent, diamondsReceived |
| `platform_config` | App configuration | gift_conversion doc: rates and splits |
| `audio_rooms_v2` | Audio rooms | totalRevenue, contributors, participants |

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/AdminPane/services/gift_service.dart` | Gift sending with bean splits |
| `lib/services/gift_economy_service.dart` | Config reader + withdrawal service |
| `lib/services/wallet_service.dart` | Purchases, exchanges, balance ops |
| `lib/services/store_service.dart` | Store catalog, ownership, equip/unequip |
| `lib/services/agency_service.dart` | Agency/host management |
| `lib/screens/room/wallet_screen.dart` | Wallet UI + Bean Management Page |
| `lib/screens/room/store_screen.dart` | Store UI |
| `lib/screens/room/agency_screen.dart` | Agency screen (host/owner views) |
| `lib/screens/audio_rooms_v2/repository/audio_rooms_repository.dart` | Room ops + live hours tracking |
| `lib/models/audio_room_v2.dart` | Room, participant, seat models |
| `lib/models/user.dart` | User model (coins, beans, userType, customization) |
