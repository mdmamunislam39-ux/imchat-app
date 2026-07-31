# Mobile App Developer Guide — Gift Economy System

This guide covers the Firestore collections, field names, and logic the mobile app must implement for the gift economy features: gift receiving, bean-to-diamond conversion, and withdrawals.

---

## 1. Firestore Collections & Schemas

### `platform_config/gift_conversion` (single document)

Config doc that both admin and mobile app read. Admin updates these rates.

| Field | Type | Default | Description |
|---|---|---|---|
| `hostReceiverRate` | double | 0.70 | Host gets 70% of diamond value as beans |
| `hostAgencyRate` | double | 0.10 | Agency gets 10% (paid weekly Sunday 10PM) |
| `normalReceiverRate` | double | 0.50 | Normal user gets 50% as beans |
| `beanToDiamondRate` | double | 1.0 | 1 bean = 1 diamond |
| `updatedAt` | Timestamp | — | Last update time |

### `gift_transactions` (auto-ID docs)

Each gift event with full bean split breakdown.

| Field | Type | Description |
|---|---|---|
| `senderId` | String | UID of the sender |
| `senderName` | String | Display name of sender |
| `receiverId` | String | UID of the receiver |
| `receiverName` | String | Display name of receiver |
| `receiverType` | String | `"host"` or `"normalUser"` |
| `diamondAmount` | double | Diamond value of the gift |
| `beansToReceiver` | double | Beans credited to receiver |
| `beansToAgency` | double | Beans credited to agency (0 if normalUser) |
| `platformShare` | double | Platform's cut |
| `agencyId` | String? | Agency ID (null if normalUser) |
| `giftName` | String | Name of the gift sent |
| `createdAt` | Timestamp | When the gift was processed |

### `host_earnings` (auto-ID docs)

Written when a host receives a gift. CommissionService reads this weekly.

| Field | Type | Description |
|---|---|---|
| `hostId` | String | UID of the host |
| `diamondsEarned` | double | Diamond value of the gift |
| `beansEarned` | double | Beans credited to host |
| `agencyId` | String? | Host's agency |
| `earningDate` | Timestamp | When earned |
| `source` | String | `"gift"` |
| `giftName` | String | Gift name |
| `createdAt` | Timestamp | Record creation time |

### `bean_conversions` (auto-ID docs)

Each bean-to-diamond conversion.

| Field | Type | Description |
|---|---|---|
| `userId` | String | UID of the user |
| `username` | String | Display name |
| `beansSpent` | double | Beans deducted |
| `diamondsReceived` | double | Diamonds (coins) added |
| `createdAt` | Timestamp | When conversion happened |

### `withdrawals` (auto-ID docs)

Withdrawal request lifecycle.

| Field | Type | Description |
|---|---|---|
| `userId` | String | UID of the requester |
| `username` | String | Display name |
| `userType` | String | `"host"` or `"user"` |
| `amount` | double | Beans to withdraw |
| `accountNumber` | String | Payment account number |
| `note` | String? | Optional note from user |
| `status` | String | `"pending"`, `"approved"`, or `"rejected"` |
| `createdAt` | Timestamp | Request time |
| `reviewedAt` | Timestamp? | When admin reviewed |
| `reviewedBy` | String? | Admin UID |
| `rejectionReason` | String? | Reason if rejected |

### `Users/{userId}` (existing collection)

Relevant fields for this feature:

| Field | Type | Description |
|---|---|---|
| `beans` | double | User's bean balance |
| `coins` | double | User's diamond balance |

### `notifications` (existing collection)

| Field | Type | Description |
|---|---|---|
| `userId` | String | Target user |
| `title` | String | Notification title |
| `message` | String | Notification body |
| `type` | String | e.g. `"general"` |
| `data` | Map? | Extra data (withdrawalId, amount, etc.) |
| `createdAt` | Timestamp | When sent |
| `isRead` | bool | Read status |
| `readAt` | Timestamp? | When read |

---

## 2. Gift Receiving Logic

When a user sends a gift to another user in a live room:

### Step 1: Read config

```dart
final configDoc = await FirebaseFirestore.instance
    .collection('platform_config')
    .doc('gift_conversion')
    .get();

final config = configDoc.data() ?? {};
final hostReceiverRate = (config['hostReceiverRate'] ?? 0.70).toDouble();
final hostAgencyRate = (config['hostAgencyRate'] ?? 0.10).toDouble();
final normalReceiverRate = (config['normalReceiverRate'] ?? 0.50).toDouble();
```

### Step 2: Calculate splits

```dart
double beansToReceiver;
double beansToAgency = 0.0;
double platformShare;

if (receiverIsHost) {
  beansToReceiver = diamondAmount * hostReceiverRate;  // 70%
  beansToAgency = diamondAmount * hostAgencyRate;       // 10%
  platformShare = diamondAmount - beansToReceiver - beansToAgency; // 20%
} else {
  beansToReceiver = diamondAmount * normalReceiverRate; // 50%
  platformShare = diamondAmount - beansToReceiver;      // 50%
}
```

### Step 3: Atomic Firestore transaction

```dart
await FirebaseFirestore.instance.runTransaction((transaction) async {
  // 1. Update receiver's beans
  final receiverRef = FirebaseFirestore.instance.collection('Users').doc(receiverId);
  transaction.update(receiverRef, {
    'beans': FieldValue.increment(beansToReceiver),
  });

  // 2. Write gift_transactions record
  final txnRef = FirebaseFirestore.instance.collection('gift_transactions').doc();
  transaction.set(txnRef, {
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'receiverType': receiverIsHost ? 'host' : 'normalUser',
    'diamondAmount': diamondAmount,
    'beansToReceiver': beansToReceiver,
    'beansToAgency': beansToAgency,
    'platformShare': platformShare,
    'agencyId': agencyId,  // null if not a host
    'giftName': giftName,
    'createdAt': Timestamp.now(),
  });

  // 3. Write host_earnings (only if receiver is a host)
  if (receiverIsHost) {
    final earningRef = FirebaseFirestore.instance.collection('host_earnings').doc();
    transaction.set(earningRef, {
      'hostId': receiverId,
      'diamondsEarned': diamondAmount,
      'beansEarned': beansToReceiver,
      'agencyId': agencyId,
      'earningDate': Timestamp.now(),
      'source': 'gift',
      'giftName': giftName,
      'createdAt': Timestamp.now(),
    });
  }
});
```

**Important:** The `host_earnings` collection is read by the existing CommissionService every Sunday at 10PM to calculate the 10% agency commission. Writing to it ensures the weekly pipeline picks up new earnings automatically.

---

## 3. Bean-to-Diamond Conversion

Users can convert their beans to diamonds (coins) at the configured rate (default 1:1).

```dart
final config = await FirebaseFirestore.instance
    .collection('platform_config')
    .doc('gift_conversion')
    .get();
final rate = (config.data()?['beanToDiamondRate'] ?? 1.0).toDouble();
final diamondsReceived = beansAmount * rate;

await FirebaseFirestore.instance.runTransaction((transaction) async {
  final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
  final userDoc = await transaction.get(userRef);

  final currentBeans = (userDoc.data()?['beans'] ?? 0.0).toDouble();
  if (currentBeans < beansAmount) {
    throw Exception('Insufficient beans');
  }

  // Deduct beans, add diamonds (coins)
  transaction.update(userRef, {
    'beans': FieldValue.increment(-beansAmount),
    'coins': FieldValue.increment(diamondsReceived),
  });

  // Write conversion record
  final convRef = FirebaseFirestore.instance.collection('bean_conversions').doc();
  transaction.set(convRef, {
    'userId': userId,
    'username': username,
    'beansSpent': beansAmount,
    'diamondsReceived': diamondsReceived,
    'createdAt': Timestamp.now(),
  });
});
```

---

## 4. Withdrawal Request Flow

### Check eligibility first

Only one active (pending) withdrawal per user at a time:

```dart
Future<bool> canUserWithdraw(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('withdrawals')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .get();
  return snapshot.docs.isEmpty;
}
```

### Create withdrawal request

Beans are deducted immediately (escrow). If rejected by admin, beans are refunded automatically.

```dart
await FirebaseFirestore.instance.runTransaction((transaction) async {
  final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
  final userDoc = await transaction.get(userRef);

  final currentBeans = (userDoc.data()?['beans'] ?? 0.0).toDouble();
  if (currentBeans < amount) {
    throw Exception('Insufficient beans');
  }

  // Deduct beans (escrow)
  transaction.update(userRef, {
    'beans': FieldValue.increment(-amount),
  });

  // Create withdrawal document
  final withdrawalRef = FirebaseFirestore.instance.collection('withdrawals').doc();
  transaction.set(withdrawalRef, {
    'userId': userId,
    'username': username,
    'userType': userType,  // "host" or "user"
    'amount': amount,
    'accountNumber': accountNumber,
    'note': note,
    'status': 'pending',
    'createdAt': Timestamp.now(),
    'reviewedAt': null,
    'reviewedBy': null,
    'rejectionReason': null,
  });
});
```

### Withdrawal lifecycle

1. **User creates request** -> status = `pending`, beans deducted
2. **Admin approves** -> status = `approved` (this is the final state, equivalent to "complete")
3. **Admin rejects** -> status = `rejected`, beans refunded to user, rejection reason provided

The admin handles approve/reject from the admin panel. The mobile app only needs to:
- Create the request
- Display the current status
- Listen for notifications about status changes

---

## 5. Reading Config

The mobile app should read the config on app start or before processing gifts:

```dart
final doc = await FirebaseFirestore.instance
    .collection('platform_config')
    .doc('gift_conversion')
    .get();

if (doc.exists) {
  final data = doc.data()!;
  // Use data['hostReceiverRate'], data['normalReceiverRate'], etc.
} else {
  // Use fallback defaults: hostReceiverRate=0.70, normalReceiverRate=0.50, etc.
}
```

You can also listen for real-time config changes:

```dart
FirebaseFirestore.instance
    .collection('platform_config')
    .doc('gift_conversion')
    .snapshots()
    .listen((snapshot) {
  if (snapshot.exists) {
    // Update local config
  }
});
```

---

## 6. Notification Handling

The admin sends notifications when withdrawals are approved/rejected. The mobile app should listen for notifications:

```dart
FirebaseFirestore.instance
    .collection('notifications')
    .where('userId', isEqualTo: currentUserId)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .listen((snapshot) {
  for (final doc in snapshot.docs) {
    final data = doc.data();
    // data['title'], data['message'], data['type'], data['data']
    // data['isRead'] — show badge if false
  }
});
```

Mark as read:

```dart
await FirebaseFirestore.instance
    .collection('notifications')
    .doc(notificationId)
    .update({
  'isRead': true,
  'readAt': Timestamp.now(),
});
```

---

## 7. Summary of User-Facing Fields

| User Field | Purpose |
|---|---|
| `beans` | Earned from receiving gifts. Used for conversion and withdrawal. |
| `coins` | Diamonds. Obtained by converting beans or through purchases. |

### Key Business Rules

- **Host** receives 70% beans, agency 10% (weekly), platform 20%
- **Normal user** receives 50% beans, platform 50%
- **Bean-to-Diamond** conversion is 1:1 (configurable)
- **Withdrawal** deducts beans on request, refunds on rejection
- **One pending withdrawal** per user at a time
- **Agency commission** (10%) is processed every Sunday at 10PM Bangladesh Time automatically
