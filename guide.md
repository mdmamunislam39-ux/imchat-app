# IMChat Admin Panel - Complete Documentation

## Overview
This is a comprehensive Flutter admin panel for managing the IMChat application. The admin panel provides complete control over users, agencies, sellers, store items, and platform analytics.

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── models/                           # Data models
│   ├── agency_model.dart
│   ├── agency_notification_model.dart
│   ├── host_model.dart
│   ├── seller_model.dart
│   ├── store_item_model.dart
│   ├── transaction_model.dart
│   └── user_profile_model.dart
├── screens/                          # UI screens
│   ├── admin_dashboard.dart
│   ├── agency_management.dart
│   ├── seller_management.dart
│   ├── store_management.dart
│   └── [35+ other screens]
├── services/                         # Business logic
│   ├── auth_service.dart
│   ├── agency_service.dart
│   ├── seller_service.dart
│   ├── store_service.dart
│   └── [6+ other services]
├── routes/                          # Navigation
│   ├── app_routes.dart
│   └── route_generator.dart
├── widgets/                         # Reusable components
└── utils/                          # Utilities
    ├── auth_debug.dart
    └── firebase_debug.dart
```

## Core Features

### 1. User Management
- **User Profiles**: Complete user profile management with diamonds, beans, levels
- **User Types**: Regular, Host, Seller, Admin
- **User Status**: Active, Blocked, Suspended, Pending
- **Level System**: Sending and receiving levels with progress tracking
- **User Customization**: Badges, frames, entry effects, background themes
- **Activity Stats**: Daily, weekly, monthly diamond and voice room statistics
- **Punishment System**: Warning, temporary block, permanent block, suspension

### 2. Agency Management
- **Agency Creation**: Create and manage agencies with owners
- **Host Management**: Add/remove hosts from agencies
- **Commission System**: 10% commission on host earnings
- **Host Invitations**: Send invitations to users to join agencies
- **Agency Analytics**: Performance metrics and earnings tracking
- **Notifications**: Agency-specific notifications system

### 3. Seller Management
- **Seller Registration**: Create seller accounts with ID verification
- **Balance Management**: Add/deduct seller balances
- **Transaction History**: Complete transaction tracking
- **Recharge System**: Sellers can recharge user accounts
- **Sales Analytics**: Daily, weekly, monthly sales tracking
- **Status Management**: Activate/deactivate sellers

### 4. Store Management
- **Store Items**: Avatar frames, entry effects, badges, background themes
- **Item Categories**: Store items vs Official store items
- **Item Assignment**: Assign official store items to users
- **Bulk Operations**: Mass activate/deactivate/delete items
- **Analytics**: Store performance and user engagement metrics
- **File Management**: Support for .svga, .gif, .png, .mp4 files

### 5. Platform Management
- **Audio Rooms**: Manage voice chat rooms
- **Gifts Management**: Create and manage virtual gifts
- **Emojis Management**: Upload and organize emojis
- **Coins Management**: Platform-wide coin system
- **Reports & Analytics**: Comprehensive platform analytics

## Firebase Structure

### Collections Overview

```
Firebase Collections:
├── Users/                           # User profiles and data
├── audio_rooms_v2/                  # Voice chat rooms
├── gift/                           # Virtual gifts
├── emoji/                          # Emoji collection
├── sellers/                        # Seller accounts
├── store_items/                    # Store items catalog
├── user_store_items/              # User-owned items
├── agencies/                       # Agency management
├── hosts/                          # Host profiles
├── notifications/                  # System notifications
├── agency_notifications/          # Agency-specific notifications
├── host_invitations/              # Host invitation system
├── host_earnings/                 # Host earnings tracking
├── agency_commissions/            # Commission calculations
├── seller_transactions/           # Seller transaction history
├── seller_sales_summary/          # Seller sales analytics
├── commission_runs/               # Commission processing
└── Reports/                       # System reports
```

### Detailed Firebase Structure

#### 1. Users Collection (`Users/`)
```json
{
  "userId": "string",
  "fullname": "string",
  "searchId": "string",
  "number": "string",
  "email": "string",
  "address": "string",
  "coins": "number",
  "diamonds": "number",
  "beans": "number",
  "userType": "regular|host|seller|admin",
  "status": "active|blocked|suspended|pending",
  "isOnline": "boolean",
  "isAgency": "boolean",
  "profileImageUrl": "string",
  "bio": "string",
  "sendingLevel": {
    "level": "number",
    "currentProgress": "number",
    "requiredForNext": "number",
    "levelName": "string",
    "lastUpdated": "timestamp"
  },
  "receivingLevel": {
    "level": "number",
    "currentProgress": "number",
    "requiredForNext": "number",
    "levelName": "string",
    "lastUpdated": "timestamp"
  },
  "customization": {
    "selectedBadgeId": "string",
    "selectedFrameId": "string",
    "selectedEntryEffectId": "string",
    "selectedBackgroundThemeId": "string",
    "ownedBadges": ["string"],
    "ownedFrames": ["string"],
    "ownedEntryEffects": ["string"],
    "ownedBackgroundThemes": ["string"]
  },
  "activityStats": {
    "dailyDiamondsSent": "number",
    "dailyDiamondsReceived": "number",
    "weeklyDiamondsSent": "number",
    "weeklyDiamondsReceived": "number",
    "monthlyDiamondsSent": "number",
    "monthlyDiamondsReceived": "number",
    "dailyVoiceRoomMinutes": "number",
    "weeklyVoiceRoomMinutes": "number",
    "monthlyVoiceRoomMinutes": "number",
    "lastUpdated": "timestamp"
  },
  "agencyId": "string",
  "agencyName": "string",
  "blockedUserIds": ["string"],
  "punishments": [
    {
      "id": "string",
      "reason": "string",
      "type": "warning|temporaryBlock|permanentBlock|suspension",
      "issuedAt": "timestamp",
      "expiresAt": "timestamp",
      "issuedBy": "string",
      "isActive": "boolean"
    }
  ],
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "lastActiveAt": "timestamp"
}
```

#### 2. Agencies Collection (`agencies/`)
```json
{
  "agencyName": "string",
  "logoUrl": "string",
  "agencyIdNumber": "string",
  "owner": {
    "name": "string",
    "phone": "string",
    "email": "string",
    "profileImageUrl": "string",
    "dateOfBirth": "timestamp",
    "address": "string"
  },
  "isActive": "boolean",
  "totalCommissionEarned": "number",
  "totalHosts": "number",
  "hostIds": ["string"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### 3. Hosts Collection (`hosts/`)
```json
{
  "userId": "string",
  "agencyId": "string",
  "hostName": "string",
  "profileImageUrl": "string",
  "phone": "string",
  "email": "string",
  "joinedDate": "timestamp",
  "lastActiveDate": "timestamp",
  "isActive": "boolean",
  "status": "pending|active|suspended|terminated",
  "performance": {
    "totalEarnings": "number",
    "totalDiamonds": "number",
    "totalCoins": "number",
    "totalLiveHours": "number",
    "totalGiftsReceived": "number",
    "averageRating": "number",
    "lastUpdated": "timestamp"
  },
  "earnings": [
    {
      "id": "string",
      "hostId": "string",
      "agencyId": "string",
      "diamondsEarned": "number",
      "coinsEarned": "number",
      "commissionAmount": "number",
      "earningDate": "timestamp",
      "period": "daily|weekly|monthly",
      "description": "string"
    }
  ],
  "notes": "string"
}
```

#### 4. Sellers Collection (`sellers/`)
```json
{
  "userId": "string",
  "sellerName": "string",
  "profilePicture": "string",
  "idNumber": "string",
  "profileId": "string",
  "accountBalance": "number",
  "isActive": "boolean",
  "totalUsersRecharged": "number",
  "totalSales": "number",
  "transactionIds": ["string"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### 5. Store Items Collection (`store_items/`)
```json
{
  "name": "string",
  "description": "string",
  "type": "avatarFrame|entryEffect|badge|backgroundTheme",
  "category": "store|officialStore",
  "fileUrl": "string",
  "fileName": "string",
  "fileType": "string",
  "diamondPrice": "number",
  "expirationDuration": "number",
  "isActive": "boolean",
  "thumbnailUrl": "string",
  "metadata": "object",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### 6. User Store Items Collection (`user_store_items/`)
```json
{
  "userId": "string",
  "userProfileId": "string",
  "storeItemId": "string",
  "storeItemName": "string",
  "itemType": "avatarFrame|entryEffect|badge|backgroundTheme",
  "assignedAt": "timestamp",
  "expiresAt": "timestamp",
  "isActive": "boolean",
  "assignedBy": "string"
}
```

#### 7. Seller Transactions Collection (`seller_transactions/`)
```json
{
  "sellerId": "string",
  "userId": "string",
  "amount": "number",
  "type": "add|minus|sell|recharge",
  "description": "string",
  "adminId": "string",
  "userProfileId": "string",
  "userPhoneNumber": "string",
  "createdAt": "timestamp"
}
```

#### 8. Notifications Collection (`notifications/`)
```json
{
  "userId": "string",
  "title": "string",
  "message": "string",
  "type": "general|hostInvitation|commissionPayment|hostPerformance|systemAlert|hostRemoval",
  "data": "object",
  "createdAt": "timestamp",
  "isRead": "boolean"
}
```

#### 9. Agency Notifications Collection (`agency_notifications/`)
```json
{
  "agencyId": "string",
  "hostId": "string",
  "title": "string",
  "message": "string",
  "type": "general|hostInvitation|commissionPayment|hostPerformance|systemAlert|hostRemoval",
  "status": "unread|read|archived",
  "data": "object",
  "createdAt": "timestamp",
  "readAt": "timestamp"
}
```

#### 10. Host Invitations Collection (`host_invitations/`)
```json
{
  "agencyId": "string",
  "hostUserId": "string",
  "hostName": "string",
  "hostEmail": "string",
  "hostPhone": "string",
  "status": "pending|accepted|rejected|expired",
  "sentAt": "timestamp",
  "respondedAt": "timestamp",
  "message": "string",
  "agencyName": "string"
}
```

## Key Services

### 1. AuthService
- **Authentication**: Email/password login with hardcoded credentials
- **Authorization**: Single admin user access control
- **Session Management**: User session handling

### 2. AgencyService
- **Agency CRUD**: Create, read, update, delete agencies
- **Host Management**: Add/remove hosts from agencies
- **Commission Calculation**: 10% commission on host earnings
- **Invitation System**: Send and manage host invitations
- **Analytics**: Agency performance metrics

### 3. SellerService
- **Seller Management**: Complete seller lifecycle
- **Balance Operations**: Add/deduct seller balances
- **Transaction Tracking**: Complete transaction history
- **Recharge System**: User account recharging
- **Sales Analytics**: Performance tracking

### 4. StoreService
- **Item Management**: CRUD operations for store items
- **File Handling**: Support for multiple file types
- **Assignment System**: Assign items to users
- **Bulk Operations**: Mass item management
- **Analytics**: Store performance metrics

### 5. FirebaseDataService
- **Data Access**: Unified Firebase data access
- **Statistics**: Platform-wide statistics
- **User Management**: User data operations
- **Content Management**: Gifts, emojis, rooms management

## Screen Features

### 1. Admin Dashboard
- **Statistics Overview**: Total users, rooms, gifts, coins
- **Quick Actions**: Direct access to all management features
- **Recent Activity**: System activity tracking
- **Navigation**: Complete app navigation

### 2. User Management
- **User Profiles**: Complete user profile management
- **User Search**: Search by name, ID, phone, email
- **Status Management**: Block/unblock users
- **Level System**: Manage user levels and progression
- **Customization**: Manage user badges, frames, effects

### 3. Agency Management
- **Agency Dashboard**: Agency overview and statistics
- **Host Management**: Add/remove hosts
- **Commission Tracking**: Monitor earnings and commissions
- **Invitation System**: Send host invitations
- **Analytics**: Agency performance metrics

### 4. Seller Management
- **Seller Dashboard**: Seller overview and statistics
- **Balance Management**: Add/deduct balances
- **Transaction History**: Complete transaction tracking
- **Recharge System**: User account recharging
- **Sales Analytics**: Performance tracking

### 5. Store Management
- **Item Catalog**: Complete store item management
- **File Upload**: Support for multiple file types
- **Assignment System**: Assign items to users
- **Bulk Operations**: Mass item management
- **Analytics**: Store performance metrics

## Authentication System

### Hardcoded Authentication
```dart
// Single admin user access
static const String _allowedUserId = 'umxTV509JJMQ9iQAQ7z1Tlfn4n32';

// Simple email/password authentication
static Future<bool?> signInWithEmailAndPassword(String email, String password) async {
  // Hardcoded credentials for admin access
  return await SimpleAuthService.signInWithEmailAndPassword(email, password);
}
```

### User Types & Permissions
- **Admin**: Full access to all features
- **Agency Owner**: Manage their agency and hosts
- **Host**: View their performance and earnings
- **Seller**: Manage their sales and transactions

## File Management

### Supported File Types
- **Avatar Frames**: .png, .jpg, .jpeg
- **Entry Effects**: .svga, .gif, .mp4
- **Badges**: .png, .jpg, .jpeg
- **Background Themes**: .png, .jpg, .jpeg

### File Storage
- **Firebase Storage**: All files stored in Firebase Storage
- **Thumbnail Generation**: Automatic thumbnail creation
- **Metadata**: File dimensions, type, and other properties

## Analytics & Reporting

### Platform Statistics
- **User Metrics**: Total users, active users, new registrations
- **Revenue Metrics**: Total diamonds, coins, transactions
- **Engagement Metrics**: Voice room usage, gift sending
- **Performance Metrics**: Agency earnings, seller sales

### Real-time Updates
- **Live Statistics**: Real-time platform metrics
- **Activity Tracking**: User and system activity monitoring
- **Performance Monitoring**: System health and performance

## Integration Points

### Flutter App Integration
1. **User Authentication**: Connect with main app auth system
2. **Data Synchronization**: Real-time data sync between admin and main app
3. **Push Notifications**: Admin notifications to users
4. **File Management**: Shared file storage between admin and main app
5. **Analytics**: Shared analytics between admin and main app

### API Endpoints Needed
```dart
// User Management
GET /api/users
POST /api/users
PUT /api/users/{id}
DELETE /api/users/{id}

// Agency Management
GET /api/agencies
POST /api/agencies
PUT /api/agencies/{id}
DELETE /api/agencies/{id}

// Seller Management
GET /api/sellers
POST /api/sellers
PUT /api/sellers/{id}
DELETE /api/sellers/{id}

// Store Management
GET /api/store-items
POST /api/store-items
PUT /api/store-items/{id}
DELETE /api/store-items/{id}
```

## Development Setup

### Prerequisites
- Flutter SDK 3.9.2+
- Firebase project with Firestore enabled
- Firebase Storage enabled
- Firebase Authentication enabled

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^4.1.1
  firebase_auth: ^6.1.0
  cloud_firestore: ^6.0.2
  firebase_storage: ^13.0.2
  file_picker: ^10.3.3
  image_picker: ^1.0.7
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.10+1
```

### Firebase Configuration
1. Create Firebase project
2. Enable Firestore Database
3. Enable Firebase Storage
4. Enable Firebase Authentication
5. Add Firebase configuration files
6. Set up Firestore security rules
7. Configure Storage security rules

## Security Considerations

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /Users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Agencies collection
    match /agencies/{agencyId} {
      allow read, write: if request.auth != null;
    }
    
    // Sellers collection
    match /sellers/{sellerId} {
      allow read, write: if request.auth != null;
    }
    
    // Store items collection
    match /store_items/{itemId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Deployment

### Web Deployment
- Firebase Hosting configuration included
- Build command: `flutter build web`
- Deploy command: `firebase deploy`

### Mobile Deployment
- Android: `flutter build apk --release`
- iOS: `flutter build ios --release`

## Maintenance & Monitoring

### Performance Monitoring
- Firebase Performance Monitoring
- Real-time analytics
- Error tracking and reporting

### Data Backup
- Firestore automatic backups
- Storage file backups
- Regular data exports

### Updates & Maintenance
- Regular dependency updates
- Security patches
- Feature enhancements
- Bug fixes

## Support & Documentation

### Code Documentation
- Comprehensive inline documentation
- API documentation
- Service layer documentation
- Model documentation

### Testing
- Unit tests for services
- Widget tests for UI components
- Integration tests for complete workflows

### Error Handling
- Comprehensive error handling
- User-friendly error messages
- Debug logging
- Error reporting

This documentation provides a complete overview of the IMChat Admin Panel system. The Flutter app developer can use this to understand the complete feature set, Firebase structure, and integration requirements for connecting the admin panel with the main application.
