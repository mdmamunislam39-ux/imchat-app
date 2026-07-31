# Audio Room Minimize Feature - Integration Guide

## Overview
This guide explains how to integrate the minimize feature for Audio Rooms v2, allowing users to minimize rooms and navigate the app with a floating room icon.

---

## ✅ What's Been Implemented

### 1. **MinimizedRoomController** (`minimized_room_controller.dart`)
- Global GetX controller to manage minimized room state
- Methods: `minimizeRoom()`, `restoreRoom()`, `clearMinimizedRoom()`, `updateMinimizedRoom()`

### 2. **FloatingMinimizedRoom Widget** (`widgets/floating_minimized_room.dart`)
- Draggable floating widget that appears globally
- Shows room icon with LIVE indicator and pulse animation
- Taps on widget restore the room
- Auto-snaps to screen edges

### 3. **Modified Exit Flow** (`audio_room_screen.dart`)
- **Leave Button**: Shows "Exit & Minimize" bottom sheet with two options:
  - 🔵 **Minimize**: Minimizes room (user stays in room)
  - 🔴 **Leave**: Actually leaves the room
- **Back Button**: Auto-minimizes the room (no dialog shown)

---

## 🚀 Integration Steps

### Step 1: Initialize MinimizedRoomController in Main App (OPTIONAL)

**The controller now auto-initializes!** You can skip this step, or optionally initialize it in `main.dart`:

```dart
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/minimized_room_controller.dart';

void main() {
  // OPTIONAL: Pre-initialize GetX controller
  // (it will auto-initialize if not found)
  Get.put(MinimizedRoomController());

  runApp(MyApp());
}
```

**Note:** The controller will automatically initialize itself when first used, so this step is optional.

---

### Step 2: Add Floating Widget to MaterialApp

Wrap your MaterialApp with a Stack that includes the floating widget:

#### Option A: Using MaterialApp's `builder` property (Recommended)

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Your App',
      builder: (context, child) {
        return Stack(
          children: [
            child!, // Your app content

            // Floating minimized room overlay
            FloatingMinimizedRoom(
              audioRoomsBloc: Get.find<AudioRoomsBloc>(), // Or however you access your bloc
            ),
          ],
        );
      },
      home: YourHomeScreen(),
    );
  }
}
```

#### Option B: Wrap Scaffold in Main Layout

If you have a common layout/scaffold, wrap it:

```dart
class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child, // Your content

        // Floating minimized room
        FloatingMinimizedRoom(
          audioRoomsBloc: Get.find<AudioRoomsBloc>(),
        ),
      ],
    );
  }
}
```

---

### Step 3: Ensure AudioRoomsBloc is Accessible

Make sure AudioRoomsBloc is globally accessible via GetX:

```dart
// In your main.dart or app initialization
Get.put(AudioRoomsBloc(repository: audioRoomsRepository));
```

---

### Step 4: Update Minimized Room on Real-time Updates (Optional but Recommended)

In your `audio_room_screen.dart`, update the minimized room when receiving updates:

```dart
// Inside BlocListener in AudioRoomScreen
if (state is AudioRoomUpdated) {
  setState(() {
    _currentRoom = state.room;
  });

  // Update minimized room if this room is minimized
  final minimizedController = Get.find<MinimizedRoomController>();
  if (minimizedController.hasMinimizedRoom &&
      minimizedController.minimizedRoom?.id == state.room.id) {
    minimizedController.updateMinimizedRoom(state.room);
  }
}
```

This ensures the floating widget shows updated participant counts and room info.

---

## 📱 User Flow

### When User Taps "Leave" Button:
1. Bottom sheet appears with **"Exit & Minimize"** title
2. Two circular buttons:
   - **Minimize** (Blue) - Room minimizes, floating icon appears
   - **Leave** (Red) - User actually leaves the room

### When User Presses Back Button:
1. Room automatically minimizes (no dialog)
2. Floating icon appears
3. User navigates back to previous screen

### When User Taps Floating Icon:
1. Room is restored
2. User navigates back to AudioRoomScreen
3. Agora connection remains active

---

## 🎨 Customization

### Change Floating Widget Appearance

Edit `widgets/floating_minimized_room.dart`:

```dart
// Change size
width: 60,  // Default
height: 60, // Default

// Change colors
gradient: const LinearGradient(
  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Default gradient
  ...
),
```

### Change Bottom Sheet Style

Edit `audio_room_screen.dart` → `_showExitConfirmationBottomSheet()`:

```dart
// Change button size
width: 100,  // Default
height: 100, // Default

// Change button colors
color: Colors.blue,  // Minimize button
color: Colors.red,   // Leave button
```

---

## 🔍 Testing Checklist

- [ ] Tap Leave button → Shows "Exit & Minimize" dialog
- [ ] Tap Minimize → Room minimizes, floating icon appears
- [ ] Floating icon is draggable
- [ ] Floating icon snaps to edges
- [ ] Tap floating icon → Returns to room
- [ ] Press Back button → Room auto-minimizes
- [ ] Tap Leave → Room is actually left (no floating icon)
- [ ] Floating icon persists across different screens
- [ ] Agora connection remains active while minimized

---

## ⚠️ Important Notes

1. **Agora Connection**: The room stays connected to Agora when minimized. This allows users to continue hearing audio while navigating the app.

2. **Memory Management**: When user actually leaves (taps Leave button), make sure to:
   - Clear minimized state
   - Leave Agora channel
   - Clean up subscriptions

3. **Navigation**: The floating widget uses GetX navigation. If you use a different navigation system, update the restore logic in `FloatingMinimizedRoom`:

   ```dart
   // Replace Get.to() with your navigation method
   Navigator.of(context).push(
     MaterialPageRoute(
       builder: (context) => AudioRoomScreen(...)
     ),
   );
   ```

---

## 🐛 Troubleshooting

### Floating Widget Not Showing
- Ensure `MinimizedRoomController` is initialized in main.dart
- Check that `FloatingMinimizedRoom` is in the widget tree (use Flutter Inspector)
- Verify `GetBuilder` is updating (check controller.hasMinimizedRoom)

### Room Not Restoring
- Ensure AudioRoomsBloc is accessible via Get.find()
- Check navigation is working correctly
- Verify room data is not null

### Multiple Floating Widgets
- Ensure `FloatingMinimizedRoom` is only added once in the widget tree
- Use `GetBuilder` to conditionally show/hide instead of creating multiple instances

---

## 📚 Files Modified

1. **New Files Created:**
   - `minimized_room_controller.dart` - Global state controller
   - `widgets/floating_minimized_room.dart` - Floating widget
   - `MINIMIZE_FEATURE_INTEGRATION.md` - This guide

2. **Modified Files:**
   - `audio_room_screen.dart`:
     - Added `_handleMinimize()` method
     - Added `_handleActualLeave()` method
     - Modified `_showExitConfirmationBottomSheet()` to show Minimize & Leave options
     - Updated `WillPopScope.onWillPop` to auto-minimize
     - Added imports for Get and MinimizedRoomController

---

## ✅ Complete Integration Example

Here's a complete example of how your `main.dart` should look:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/floating_minimized_room.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

void main() {
  // Initialize controllers
  final audioRoomsRepository = AudioRoomsRepository();
  final audioRoomsBloc = AudioRoomsBloc(repository: audioRoomsRepository);

  // MinimizedRoomController auto-initializes, but you can pre-initialize if needed
  // Get.put(MinimizedRoomController()); // OPTIONAL

  Get.put(audioRoomsBloc);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chat Messenger',
      theme: ThemeData(...),
      builder: (context, child) {
        return Stack(
          children: [
            child!,

            // Global floating minimized room widget
            FloatingMinimizedRoom(
              audioRoomsBloc: Get.find<AudioRoomsBloc>(),
            ),
          ],
        );
      },
      home: HomeScreen(),
    );
  }
}
```

---

## 🎉 You're Done!

The minimize feature is now fully integrated. Users can:
- Minimize rooms and navigate the app
- See a floating icon that persists across screens
- Tap to restore the room
- Auto-minimize with back button
- Choose to minimize or leave when tapping Leave button

Enjoy the enhanced user experience! 🚀
