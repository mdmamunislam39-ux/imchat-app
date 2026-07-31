# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**imChat** is a Flutter mobile chat application (package: `chat_messenger`) targeting Android and iOS. It features 1:1/group messaging, audio rooms, live streaming, stories, an in-app economy (diamonds/beans/coins), virtual gifts, and an admin panel. Backend is Firebase (Firestore, Auth, Storage, Realtime DB, Cloud Functions, App Check) with a supplementary Node.js Express server.

**Firebase Project ID:** `imchat-84519`

## Common Commands

```bash
# Run app (with device preview in debug builds)
flutter run

# Build
flutter build apk
flutter build ios

# Static analysis (only linting tool configured)
flutter analyze

# Generate launcher icons / splash screen
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create

# Backend (Node.js Express server for Agora tokens)
cd backend && npm start

# Firebase Cloud Functions
cd functions && npm run serve          # local emulation
cd functions && npm run deploy         # deploy
cd functions && npm run lint           # ESLint (Google style)
```

No test suite exists beyond stubs. `flutter_test` is a dev dependency but there are no meaningful test files.

## Architecture

### State Management: GetX (primary) + BLoC (audio rooms only)

- **GetX** is used app-wide: `GetMaterialApp`, `GetxController`, `Rx`/`Obx` reactive state, named routing via `Get.toNamed`/`Get.to`
- **BLoC** (`flutter_bloc`) is used exclusively for Audio Rooms v2 (`screens/audio_rooms_v2/bloc/`)
- Global controllers: `AuthController.instance` (singleton), `AppController`, `PreferencesController`, `FollowController`, `ReportController`

### Layered Structure

- **`api/`** — Data access layer. Abstract classes with static methods wrapping Firestore/Firebase calls (`AuthApi`, `UserApi`, `ChatApi`, `MessageApi`, `GroupApi`, `StoryApi`, etc.)
- **`services/`** — Business logic singletons and service classes (`AgoraService`, `WalletService`, `EmojiChatService`, `EntranceEffectService`, `RailwayTokenService`, etc.)
- **`controllers/`** — Global GetX controllers for app-wide state
- **`models/`** — Plain Dart data classes with `fromMap()`/`toMap()` serialization (no code generation)
- **`screens/`** — Feature screens, some with nested `controllers/` and `components/` subdirectories
- **`tabs/`** — Bottom navigation tabs (chats, groups, calls, stories, profile), each self-contained with controllers and components
- **`components/`** — Shared reusable UI widgets
- **`helpers/`** — Abstract utility classes with static methods (`AppHelper`, `DateHelper`, `EncryptHelper`, `DialogHelper`, `RoutesHelper`, etc.)

### Navigation

Named routing via `AppRoutes` (string constants in `routes/app_routes.dart`) and `AppPages` (GetPage definitions with bindings in `routes/app_pages.dart`).

### Firebase Collections (key ones)

| Collection | Purpose |
|---|---|
| `Users/` | User profiles (diamonds, beans, coins, levels, customization, punishments) |
| `audio_rooms_v2/` | Audio rooms with `participants` array embedded in room doc |
| `audio_rooms_v2/{id}/chat/` | Room text chat (subcollection) |
| `audio_rooms_v2/{id}/entrance_effects/` | Ephemeral entrance animations |
| `gift_transactions/` | Gift sends (cleaned up by host after 60s) |
| `gift/` | Gift catalog |
| `emoji/` | Emoji catalog |
| `store_items/` | Store item catalog (frames, effects, badges, themes) |
| `user_store_items/` | User-owned store items |
| `sellers/` | Seller accounts |
| `agencies/` | Agency management |
| `hosts/` | Host profiles |
| `Reports/` | System reports |

### Real-time Audio/Video

- **Agora RTC Engine** (`agora_rtc_engine ^6.5.3`) — 1:1 calls, group calls, and audio rooms
- **Tencent Live UIKit** (`tencent_live_uikit ^3.0.0`) — Live streaming rooms
- `AgoraService` is a Dart singleton wrapping `RtcEngine` lifecycle
- Agora tokens generated via Firebase Cloud Function `generateAgoraToken` (called through `RailwayTokenService`)
- Agora UID derived from userId: `userId.hashCode.abs() % 1000000`

### Admin Panel

Separate feature module at `lib/AdminPane/` with its own models, screens, services, widgets, and routes. Single hardcoded admin user (`umxTV509JJMQ9iQAQ7z1Tlfn4n32`). Manages users, agencies, sellers, store items, gifts, emojis, and audio rooms.

## Audio Rooms v2 — Detailed Architecture

The largest and most complex feature. Uses BLoC pattern (not GetX) with a repository layer.

### Key Files

| File | Role |
|---|---|
| `screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart` (57KB) | BLoC with ~40 events, ~30 states, Agora callbacks, timers |
| `screens/audio_rooms_v2/bloc/audio_rooms_event.dart` | Event definitions |
| `screens/audio_rooms_v2/bloc/audio_rooms_state.dart` | State definitions |
| `screens/audio_rooms_v2/repository/audio_rooms_repository.dart` (65KB) | Firestore operations for rooms, seats, participants, chat |
| `screens/audio_rooms_v2/audio_room_screen.dart` (181KB) | Individual room UI (largest file in codebase) |
| `screens/audio_rooms_v2/audio_rooms_v2_screen.dart` | Room list / discovery screen |
| `models/audio_room_v2.dart` | All data models: `AudioRoomV2`, `AudioRoomParticipant`, `AudioRoomSettings`, `SeatInfo`, `ChatMessage`, `RoomContributor` |
| `services/agora_service.dart` | Agora RTC singleton |

### Data Model

- Room ID: randomly generated 7-8 digit numeric string
- `participants` array is embedded directly in the room Firestore document (not a subcollection)
- `settings.seatConfiguration` is an array of `SeatInfo` objects (seat number, locked status, occupant userId)
- `settings.adminIds` persists host/admin privileges across reconnects
- `totalRevenue` drives room level system: `level = floor(totalRevenue / 5000)`, max 20

### Room Modes (active)

- `lite` — 6 seats
- `party` — 12 seats
- `multiMic` — 15 seats

### Key Business Rules

- **One room per user**: Users can only create one room at a time
- **Room deletion is disabled**: `deleteRoom()` is intentionally no-op per client request
- **Seated = speaker**: Only seated users can unmute their microphone
- **Host transfer on creator leave**: If creator leaves with participants present, first remaining participant becomes host
- **Mute enforcement**: 2-second periodic timer checks Firestore mute state and enforces it on Agora
- **Seat config auto-fix**: BLoC detects mismatches between room mode seat count and actual seat array, auto-corrects with 2-second debounce
- **Kicked user detection**: Stream update checks if current user is no longer in participants array → forces Agora channel leave

### Agora Configuration

- Channel profile: `channelProfileLiveBroadcasting`
- Audio scenario: `audioScenarioChatroom`
- All participants join as `clientRoleBroadcaster` (not audience)
- New participants join muted by default
- Volume indication: 200ms interval, threshold of 10 for "speaking" state
- Token auto-renewal on `TokenPrivilegeWillExpire` event
- Background music: when playing, mic capture volume set to 0 instead of hard-muting the audio stream

### Chat System

Two overlapping systems exist:
- **Legacy `ChatMessage`**: via BLoC events, stored in `audio_rooms_v2/{roomId}/chat/` subcollection
- **Active `EmojiChatMessage`**: via `EmojiChatService` directly (bypasses BLoC), supports emoji-enriched messages and presence messages ("X joined/left"). Host runs cleanup every 60 seconds for messages older than 30 minutes.

### Minimize/Overlay Feature

- `MinimizedRoomController` (GetX singleton) holds minimized room state and BLoC reference
- When minimizing: `_isMinimizing = true` flag prevents Agora/stream cleanup on dispose
- `FloatingMinimizedRoom` widget must be placed in `MaterialApp.builder` Stack (above all screens) for persistence
- Restoring passes `isRestoring: true` to skip re-sending join presence message

### Gift Flow

1. User selects gift in `GiftSelectionBottomSheet`
2. Transaction written to `gift_transactions` top-level collection
3. `GiftAnimationOverlay` StreamBuilder picks up new transactions → plays animation
4. Room `totalRevenue` and `contributors` map updated
5. Host cleans up transactions older than 60 seconds (10-second timer interval)
