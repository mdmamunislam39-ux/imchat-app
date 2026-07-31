# AdminPane - Gift Management System

A complete admin panel for managing gifts in the audio room application.

## Features

- **Gift Management**: Add, edit, delete gifts with PNG icons and SVGA animations
- **Category System**: Organize gifts by categories (love, moods, artists, etc.)
- **Firebase Integration**: Store gifts in Firebase Storage and Firestore
- **Real-time Updates**: Live gift transactions and notifications
- **Clean Architecture**: Modular design for easy integration

## Structure

```
lib/AdminPane/
├── models/
│   └── gift.dart              # Gift and GiftTransaction models
├── services/
│   └── gift_service.dart      # Firebase operations
├── screens/
│   └── admin_gifts_screen.dart # Main admin interface
├── widgets/
│   ├── gift_form_dialog.dart  # Add/Edit gift dialog
│   └── gift_card.dart         # Gift display card
└── admin_pane.dart           # Entry point
```

## Usage

### 1. Admin Panel
```dart
import 'package:your_app/AdminPane/admin_pane.dart';

// Navigate to admin panel
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const AdminPane()),
);
```

### 2. Gift Integration in Rooms
The gift system is automatically integrated into audio rooms:
- Tap on a participant to select them
- Tap the gift button in room controls
- Select and send gifts from the bottom sheet
- Watch gift animations in real-time

## Gift Categories

- ❤️ **Love** - Romantic gifts
- 😊 **Moods** - Emotional expressions
- 🎨 **Artists** - Creative gifts
- 🏆 **Collectibles** - Rare items
- 🎮 **Games** - Gaming related
- 👨‍👩‍👧‍👦 **Family** - Family friendly
- ⭐ **Classic** - Traditional gifts
- 🎯 **3D** - 3D animated gifts
- 👑 **VIP** - Premium gifts

## Firebase Collections

### `gifts`
```json
{
  "id": "gift_id",
  "name": "Gift Name",
  "category": "love",
  "credits": 100,
  "pngUrl": "https://...",
  "svgaUrl": "https://...",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isActive": true
}
```

### `gift_transactions`
```json
{
  "id": "transaction_id",
  "giftId": "gift_id",
  "senderId": "user_id",
  "senderName": "Sender Name",
  "receiverId": "user_id",
  "receiverName": "Receiver Name",
  "roomId": "room_id",
  "credits": 100,
  "sentAt": "timestamp"
}
```

## File Upload

- **PNG Files**: Used as gift icons in the selection UI
- **SVGA Files**: Used for gift animations in the room
- Files are automatically uploaded to Firebase Storage
- Paths: `gifts/{giftId}/icon.png` and `gifts/{giftId}/animation.svga`

## Real-time Features

- Live gift transaction updates
- Animated gift overlays in rooms
- Real-time participant selection
- Instant gift sending feedback

## Customization

The AdminPane is designed to be easily portable to other projects:

1. Copy the entire `AdminPane` folder
2. Update imports in your project
3. Add Firebase configuration
4. Integrate with your existing user system

## Performance

- Optimized Firebase queries with pagination
- Cached network images for gift icons
- Efficient real-time listeners
- Clean state management
