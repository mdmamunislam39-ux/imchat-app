# AGENTS.md

This file guides AI coding agents working in the `imchat-soban_new_branch_v1` Flutter repository.

## Primary guidance
- Use `CLAUDE.md` as the canonical project summary and architecture reference.
- Prefer existing code patterns over introducing new architectural styles.
- Keep changes small and consistent with the app's current use of GetX, named routing, and Firebase.
- Do not assume tests are present: static analysis and code review are the primary validation tools.

## Key project facts
- Flutter mobile app targeting Android and iOS.
- Main package is `chat_messenger`.
- Backend is Firebase (Firestore, Auth, Storage, Realtime DB, Cloud Functions, App Check) plus a Node.js Express helper server in `backend/`.
- Primary state management is GetX.
- Audio Rooms v2 uses BLoC only in `lib/screens/audio_rooms_v2/bloc/`.
- Global controllers live in `lib/controllers/`.
- API wrappers are in `lib/api/`.
- Business logic services are in `lib/services/`.
- Shared models are in `lib/models/`.
- UI screens are under `lib/screens/` and tab content under `lib/tabs/`.

## Important files and folders
- `lib/main.dart` — app entrypoint
- `lib/firebase_options.dart` — generated Firebase config
- `lib/routes/app_routes.dart` & `lib/routes/app_pages.dart` — named routing definitions
- `lib/screens/audio_rooms_v2/` — largest and most complex feature area
- `lib/AdminPane/` — admin panel module
- `backend/` — Node.js server for Agora token generation
- `functions/` — Firebase Cloud Functions

## Build and run commands
- `flutter run`
- `flutter build apk`
- `flutter build ios`
- `flutter analyze`
- `flutter pub run flutter_launcher_icons`
- `flutter pub run flutter_native_splash:create`
- `cd backend && npm start`
- `cd functions && npm run serve`
- `cd functions && npm run deploy`

## What agents should do first
1. Read `CLAUDE.md` before making non-trivial changes.
2. Identify whether the work is in GetX or BLoC code paths.
3. Preserve existing state management and routing conventions.
4. Use `flutter analyze` to catch issues after edits.

## Notes for safety and consistency
- Avoid adding new architectural frameworks or changing the global state management strategy.
- Avoid rewriting large modules unless the change is explicitly requested.
- Prefer small, incremental updates that align with current patterns.

## Existing documentation links
- `CLAUDE.md` — main project overview
- `README.md` — repository overview
- `MOBILE_APP_GUIDE.md` — mobile-specific guidance
- `STORE_AND_ECONOMY_GUIDE.md` — in-app economy details
- `AUDIO_ROOMS_V2_DOCUMENTATION.md` — audio room architecture details
