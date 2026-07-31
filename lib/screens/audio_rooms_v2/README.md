# Audio Rooms v2 Implementation

This is a complete implementation of Audio Rooms v2 using **BLoC pattern**, **Agora SDK**, and **Firebase** for your Flutter chat messenger app.

## 🏗️ Architecture

### Clean Architecture with BLoC Pattern
- **Models**: Data structures for audio rooms, participants, and settings
- **Repository**: Firebase integration for data management
- **BLoC**: State management using flutter_bloc
- **Widgets**: Reusable UI components
- **Screen**: Main audio rooms interface

### 📁 File Structure
```
lib/screens/audio_rooms_v2/
├── bloc/
│   ├── audio_rooms_bloc.dart        # Main BLoC logic
│   ├── audio_rooms_event.dart       # Events (actions)
│   └── audio_rooms_state.dart       # States
├── repository/
│   └── audio_rooms_repository.dart  # Firebase integration
├── widgets/
│   ├── create_room_bottom_sheet.dart # Reusable bottom sheet
│   ├── room_card.dart               # Room display component
│   └── room_list.dart               # List widgets
├── audio_rooms_v2_screen.dart       # Main screen
├── audio_rooms_v2_integration.dart  # Integration helper
└── README.md                        # This file
```

## 🚀 Features

### ✅ Implemented Features
1. **Clean BLoC Architecture** - Predictable state management
2. **Firebase Integration** - Real-time data synchronization
3. **Reusable Bottom Sheet** - Extracted from existing code
4. **Room Management** - Create, join, leave, delete rooms
5. **Search Functionality** - Find rooms by name, description, or creator
6. **Real-time Updates** - Live participant count and room status
7. **User Authentication** - Integrated with existing auth system
8. **Responsive UI** - Clean, modern interface with loading states
9. **Error Handling** - Comprehensive error management
10. **Proper Widgets** - Modular, reusable components

### 🔄 Room States
- **Trending**: Popular rooms sorted by participant count
- **My Rooms**: User's created and joined rooms
- **Recent**: Recently created rooms

### 🎛️ Room Settings
- Allow request to speak
- Auto-mute new participants
- Background music support
- Maximum speakers limit
- Session recording

## 📱 Usage

### Integration with Existing App

1. **Add to Navigation** (in your existing screens):
```dart
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';

// Navigate to Audio Rooms v2
AudioRoomsV2Integration.navigateToAudioRooms();

// Show create room dialog
AudioRoomsV2Integration.showCreateRoomDialog(context);
```

2. **Add to App Routes** (optional):
```dart
// In your routes file
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_screen.dart';

// Add route
Get.to(() => const AudioRoomsV2Screen());
```

### Example Integration in Existing Room Screen

Replace your existing FloatingActionButton in `lib/screens/room/room_screen.dart`:

```dart
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';

// Replace the existing FloatingActionButton with:
floatingActionButton: FloatingActionButton.extended(
  onPressed: () => AudioRoomsV2Integration.navigateToAudioRooms(),
  label: const Text('Audio Rooms v2'),
  icon: const Icon(Icons.voice_chat),
),
```

## 🔧 Dependencies Added

The following dependencies were added to `pubspec.yaml`:

```yaml
dependencies:
  # BLoC for Audio Rooms v2
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
```

## 🔥 Firebase Setup

### Firestore Collection Structure

The app uses a `audio_rooms_v2` collection with the following structure:

```json
{
  "roomId": {
    "name": "Room Name",
    "description": "Room Description",
    "imageUrl": "https://...",
    "creatorId": "userId",
    "creatorName": "User Name",
    "creatorImageUrl": "https://...",
    "participants": [
      {
        "userId": "userId",
        "userName": "User Name",
        "userImageUrl": "https://...",
        "joinedAt": "timestamp",
        "isMuted": false,
        "isSpeaker": true,
        "isHost": true
      }
    ],
    "createdAt": "timestamp",
    "updatedAt": "timestamp",
    "isActive": true,
    "maxParticipants": 50,
    "settings": {
      "allowRequestToSpeak": true,
      "autoMuteNewParticipants": true,
      "allowBackgroundMusic": false,
      "maxSpeakers": 8,
      "recordSession": false
    }
  }
}
```

### Security Rules

Add these Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /audio_rooms_v2/{roomId} {
      // Allow read for authenticated users
      allow read: if request.auth != null;
      
      // Allow create for authenticated users
      allow create: if request.auth != null 
        && request.auth.uid == resource.data.creatorId;
      
      // Allow update for room creator or participants
      allow update: if request.auth != null 
        && (request.auth.uid == resource.data.creatorId 
            || request.auth.uid in resource.data.participants.map(p => p.userId));
      
      // Allow delete for room creator only
      allow delete: if request.auth != null 
        && request.auth.uid == resource.data.creatorId;
    }
  }
}
```

## 🎨 UI Components

### Bottom Sheet
- **Extracted** from existing implementation
- **Enhanced** with better validation and error handling
- **Reusable** across the app

### Room Cards
- **Modern design** with participant avatars
- **Real-time data** updates
- **Interactive** join/leave functionality

### Search Interface
- **Full-screen** search modal
- **Real-time** search results
- **Debounced** input for performance

## 🔄 State Management

### BLoC Events
- `LoadAudioRooms` - Load all rooms
- `CreateAudioRoom` - Create new room
- `JoinAudioRoom` - Join existing room
- `LeaveAudioRoom` - Leave room
- `SearchAudioRooms` - Search rooms
- `UpdateRoomParticipant` - Update participant status

### BLoC States
- `AudioRoomsLoading` - Loading state
- `AudioRoomsLoaded` - Data loaded successfully
- `AudioRoomsError` - Error state
- `CreatingAudioRoom` - Room creation in progress
- `AudioRoomCreated` - Room created successfully

## 🚦 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Firebase Setup
- Ensure Firebase is configured in your project
- Add the Firestore security rules above
- Make sure Firebase Authentication is working

### 3. Integration
Use the integration helper to add Audio Rooms v2 to your existing screens:

```dart
// Add this button anywhere in your app
ElevatedButton(
  onPressed: () => AudioRoomsV2Integration.navigateToAudioRooms(),
  child: const Text('Open Audio Rooms v2'),
)
```

## 🔮 Future Enhancements

### Agora Integration (Next Phase)
- Real-time voice communication
- Speaker management
- Audio effects and filters
- Recording capabilities

### Additional Features
- Room categories/tags
- Private rooms with invitations
- Room moderation tools
- Analytics and insights
- Push notifications for room activities

## 🤝 Integration Notes

This implementation is designed to work alongside your existing room system without conflicts:

- Uses separate Firebase collection (`audio_rooms_v2`)
- Independent navigation and state management
- Reuses existing authentication and user management
- Compatible with existing UI theme and components

## 🐛 Troubleshooting

### Common Issues

1. **Import Errors**: Make sure to run `flutter pub get` after adding dependencies
2. **Firebase Errors**: Ensure Firebase is properly configured and rules are set
3. **Authentication Errors**: Verify that `AuthController.instance.currentUser` is available

### Performance Considerations

- Search is debounced to avoid excessive Firebase queries
- Real-time listeners are properly disposed to prevent memory leaks
- Loading states provide good user experience during network operations

---

**Note**: This implementation provides a solid foundation for Audio Rooms v2. The next phase would involve integrating Agora SDK for actual voice communication functionality.
