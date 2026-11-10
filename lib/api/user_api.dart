import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chat_messenger/api/auth_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Filter;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/api/chat_api.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/helpers/country_helper.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/services/backend_engine_manager.dart';

import '../tabs/groups/controllers/group_controller.dart';

abstract class UserApi {
  //
  // UserApi - CRUD Operations
  //

  // Firebase instances
  static final _firestore = FirebaseFirestore.instance;
  static final _realtime = FirebaseDatabase.instance;
  static final _firebaseMsg = FirebaseMessaging.instance;

  static Future<dynamic> createAccount({
    File? photoFile,
    required String fullname,
    // required String username,
    required String number,
  }) async {
    try {
      final firebaseUser = AuthController.instance.firebaseUser!;

      // Get Firebase User Info:
      final String userId = firebaseUser.uid;
      final String email = firebaseUser.email ?? '';
      final String deviceToken = await _firebaseMsg.getToken() ?? '';

      // Upload profile photo
      String photoUrl = '';

      // Check file
      if (photoFile != null) {
        photoUrl = await AppHelper.uploadFile(file: photoFile, userId: userId);
      }

      String generateRandomId() {
        final random = Random();
        int min = 1000000; // 7 digits
        int max = 99999999; // 8 digits
        return (min + random.nextInt(max - min)).toString();
      }

      // Auto-detect user device location / country
      String userCountry = 'Bangladesh';
      try {
        final detected = await CountryHelper.detectDeviceCountry(userPhone: number);
        userCountry = detected.name;
      } catch (e) {
        debugPrint('⚠️ [UserApi] Error detecting country on signup: $e');
      }

      // Set profile info
      final User user = User(
        userId: userId,
        photoUrl: photoUrl,
        fullname: fullname,
        // username: username,
        email: email,
        bio: 'default_bio'.trParams({'appName': AppConfig.appName}),
        deviceToken: deviceToken,
        loginProvider: AuthController.instance.provider,
        lastActive: DateTime.now(),
        isOnline: true,
        number: number,
        country: userCountry,
        level: '1',
        searchId: generateRandomId(),
      );

      // Save data
      await _firestore.collection('Users').doc(userId).set(user.toMap());

      // Send Welcome Message from Official Team
      await OfficialTeamApi.sendWelcomeMessage(user);

      // Subscribe for Push Notifications
      _firebaseMsg.subscribeToTopic('NOTIFY_USERS');
      return true;
    } catch (e) {
      return e;
    }
  }

  static Future<dynamic> updateAccount({
    File? photoFile,
    List<File>? newBackgroundFiles,
    List<String>? retainedBackgroundUrls,
    required String fullname,
    required String bio,
    required String gender,
    required String birthday,
    required String country,
  }) async {
    try {
      // Get current user ID
      final User currentUser = AuthController.instance.currentUser;
      final String uid = currentUser.userId.isNotEmpty
          ? currentUser.userId
          : (AuthController.instance.firebaseUser?.uid ?? '');

      if (uid.isEmpty) {
        return 'User is not logged in';
      }

      // Update photo and backgrounds in parallel
      String photoUrl = currentUser.photoUrl;
      List<String> backgroundUrls = retainedBackgroundUrls != null
          ? List.from(retainedBackgroundUrls)
          : [];

      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      Future<String>? photoUploadTask;
      if (photoFile != null) {
        photoUploadTask = AppHelper.uploadFile(
          file: photoFile,
          userId: uid,
        );
      }

      final List<Future<String>> bgUploadTasks = [];
      if (newBackgroundFiles != null && newBackgroundFiles.isNotEmpty) {
        for (int i = 0; i < newBackgroundFiles.length; i++) {
          bgUploadTasks.add(AppHelper.uploadFile(
            file: newBackgroundFiles[i],
            userId: '${uid}_bg_${timestamp}_$i',
          ));
        }
      }

      if (photoUploadTask != null || bgUploadTasks.isNotEmpty) {
        final results = await Future.wait([
          if (photoUploadTask != null) photoUploadTask,
          ...bgUploadTasks,
        ]);

        int resultIdx = 0;
        if (photoUploadTask != null) {
          photoUrl = results[resultIdx++];
        }
        while (resultIdx < results.length) {
          backgroundUrls.add(results[resultIdx++]);
        }
      }

      String firstBackgroundUrl = backgroundUrls.isNotEmpty
          ? backgroundUrls.first
          : '';

      // Save user profile data to Firestore
      final Map<String, dynamic> updateData = {
        'fullname': fullname,
        'bio': bio,
        'gender': gender,
        'birthday': birthday,
        'country': country,
        'homePageBackground': firstBackgroundUrl,
        'homePageBackgrounds': backgroundUrls,
      };
      if (photoUrl.isNotEmpty) {
        updateData['photoUrl'] = photoUrl;
      }

      await _firestore
          .collection('Users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Clear local cache for this user
      clearUserCache(uid);

      // Perform secondary creator room, agency, and family sync in background without blocking UI
      unawaited(Future(() async {
        try {
          final roomsQuery = await _firestore
              .collection('audio_rooms_v2')
              .where('creatorId', isEqualTo: uid)
              .get()
              .timeout(const Duration(seconds: 8));

          for (final doc in roomsQuery.docs) {
            final Map<String, dynamic> roomUpdate = {
              'creatorName': fullname,
              if (photoUrl.isNotEmpty) 'creatorImageUrl': photoUrl,
              if (photoUrl.isNotEmpty) 'creatorPhotoUrl': photoUrl,
            };
            await doc.reference.update(roomUpdate).catchError((e) => debugPrint('Room update error: $e'));
          }
        } catch (e) {
          debugPrint('Error syncing creator rooms: $e');
        }

        try {
          final agencyQuery = await _firestore
              .collection('agencies')
              .where('ownerId', isEqualTo: uid)
              .get()
              .timeout(const Duration(seconds: 8));
          for (final doc in agencyQuery.docs) {
            await doc.reference.update({'ownerName': fullname}).catchError((_) {});
          }
        } catch (_) {}

        try {
          final familyQuery = await _firestore
              .collection('families')
              .where('creatorId', isEqualTo: uid)
              .get()
              .timeout(const Duration(seconds: 8));
          for (final doc in familyQuery.docs) {
            await doc.reference.update({'creatorName': fullname}).catchError((_) {});
          }
        } catch (_) {}
      }));

      return true;
    } catch (e) {
      debugPrint('UserApi.updateAccount error: $e');
      return e.toString();
    }
  }

  static final Map<String, User> _userCache = {};

  static void cacheUser(User user) {
    if (user.userId.isNotEmpty && user.fullname.isNotEmpty && user.fullname != 'User') {
      _userCache[user.userId] = user;
    }
  }

  static const String officialDefaultBio =
      'Official notification channel for imChat. Stay updated with the latest announcements, system notices, special events, reward distributions, and important platform updates.';

  static const String officialDefaultLogo = 'assets/images/app_logo.png';

  static User getOfficialTeamUser({String? customBio, String? customLogo, String? customName}) {
    String logo = (customLogo != null && customLogo.isNotEmpty) ? customLogo : officialDefaultLogo;
    return User(
      userId: 'official_team',
      searchId: 'official_team',
      fullname: (customName != null && customName.isNotEmpty) ? customName : 'imChat Team',
      photoUrl: logo,
      bio: (customBio != null && customBio.isNotEmpty) ? customBio : officialDefaultBio,
      isVerified: true,
      userType: 'channel',
      level: 'Official',
      gender: '',
    );
  }

  static User? getCachedUser(String userId) {
    if (userId.isEmpty) return null;
    if (userId == 'official_team') {
      return _userCache['official_team'] ?? getOfficialTeamUser();
    }
    final user = _userCache[userId];
    if (user != null && (user.fullname.isEmpty || user.fullname == 'User')) {
      _userCache.remove(userId);
      return null;
    }
    return user;
  }

  static void clearUserCache([String? userId]) {
    if (userId != null) {
      _userCache.remove(userId);
    } else {
      _userCache.clear();
    }
  }

  static Future<User?> getUser(String userId, {bool forceRefresh = false}) async {
    if (userId.isEmpty) return null;
    if (!forceRefresh && _userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    if (userId == 'official_team') {
      try {
        final doc = await _firestore
            .collection('official_channels')
            .doc('official_team')
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final user = getOfficialTeamUser(
            customName: data['name'],
            customLogo: data['logo'],
            customBio: data['description'],
          );
          _userCache['official_team'] = user;
          return user;
        }
      } catch (e) {
        debugPrint('Error getting official team: $e');
      }
      final fallbackUser = getOfficialTeamUser();
      _userCache['official_team'] = fallbackUser;
      return fallbackUser;
    }

    if (userId.startsWith('official_channel_')) {
      try {
        final doc = await _firestore
            .collection('official_channels')
            .doc(userId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final user = User(
            userId: userId,
            fullname: data['name'] ?? 'Official Channel',
            photoUrl: data['logo'] ?? officialDefaultLogo,
            bio: data['description'] ?? officialDefaultBio,
            isVerified: data['isVerified'] ?? true,
            userType: 'channel',
            level: 'Max',
          );
          _userCache[userId] = user;
          return user;
        }
      } catch (e) {
        debugPrint('Error getting official channel details for user: $e');
      }
      return User(
        userId: userId,
        fullname: 'Official Channel',
        photoUrl: officialDefaultLogo,
        bio: officialDefaultBio,
        isVerified: true,
        userType: 'channel',
        level: 'Max',
      );
    }

    if (BackendEngineManager.isVps) {
      try {
        final vpsData = await BackendEngineManager.instance.apiService.getUserProfile(userId);
        if (vpsData != null) {
          vpsData['userId'] = vpsData['id'] ?? userId;
          final user = User.fromMap(vpsData);
          _userCache[userId] = user;
          return user;
        }
      } catch (e) {
        debugPrint('[UserApi] VPS getUser error: $e');
      }
    }

    final doc = await _firestore.collection('Users').doc(userId).get();
    if (doc.exists) {
      try {
        final data = doc.data()!;
        data['userId'] = doc.id;
        final user = User.fromMap(data);
        _userCache[userId] = user;

        // In VPS mode, auto-sync this user to VPS database in background so future reads hit VPS directly
        if (BackendEngineManager.isVps) {
          unawaited(Future(() async {
            try {
              await BackendEngineManager.instance.apiService.syncUserProfile(
                fullname: user.fullname,
                email: user.email,
                photoUrl: user.photoUrl,
                phoneNumber: user.number,
                gender: user.gender,
                country: user.country,
                fcmToken: user.deviceToken,
              );
            } catch (_) {}
          }));
        }

        return user;
      } catch (e) {
        debugPrint('Error parsing user data: $e');
        // Return a minimal fallback user to prevent login loops
        return User(
          userId: userId,
          fullname: doc.data()?['fullname'] ?? doc.data()?['name'] ?? 'User',
          number: doc.data()?['number'] ?? '',
          loginProvider: LoginProvider.email,
        );
      }
    }
    return null;
  }

  /// Searches for a user document in Firestore by email or user_email
  static Future<User?> getUserByEmail(String email) async {
    if (email.trim().isEmpty) return null;
    try {
      final query = await _firestore
          .collection('Users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        data['userId'] = query.docs.first.id;
        return User.fromMap(data);
      }
      final queryOld = await _firestore
          .collection('Users')
          .where('user_email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (queryOld.docs.isNotEmpty) {
        final data = queryOld.docs.first.data();
        data['userId'] = queryOld.docs.first.id;
        return User.fromMap(data);
      }
    } catch (e) {
      debugPrint('[UserApi] getUserByEmail error: $e');
    }
    return null;
  }

  static Stream<User> getUserUpdates(String userId) {
    if (userId == 'official_team') {
      return _firestore
          .collection('official_channels')
          .doc('official_team')
          .snapshots()
          .map((doc) {
            if (doc.exists) {
              final data = doc.data() ?? {};
              return getOfficialTeamUser(
                customName: data['name'],
                customLogo: data['logo'],
                customBio: data['description'],
              );
            } else {
              return getOfficialTeamUser();
            }
          });
    }

    if (userId.startsWith('official_channel_')) {
      return _firestore
          .collection('official_channels')
          .doc(userId)
          .snapshots()
          .map((doc) {
            final data = doc.data() ?? {};
            return User(
              userId: userId,
              fullname: data['name'] ?? 'Official Channel',
              photoUrl: data['logo'] ?? officialDefaultLogo,
              bio: data['description'] ?? officialDefaultBio,
              isVerified: data['isVerified'] ?? true,
              userType: 'channel',
              level: 'Max',
            );
          });
    }

    return _firestore.collection('Users').doc(userId).snapshots().map((event) {
      if (event.exists && event.data() != null) {
        final data = event.data()!;
        data['userId'] = event.id;
        return User.fromMap(data);
      } else {
        return User(userId: userId);
      }
    });
  }

  // Check username availability in database
  static Future<bool> checkUsername({
    required String fullname,
    bool showMsg = true,
  }) async {
    final query = await _firestore
        .collection('Users')
        .where('fullname', isEqualTo: fullname)
        .limit(1)
        .get();
    final bool result = query.docs.isEmpty;

    if (result) {
      if (showMsg) {
        DialogHelper.showSnackbarMessage(
          SnackMsgType.success,
          "username_success".tr,
        );
      }
      return true;
    }
    if (showMsg) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, "username_taken".tr);
    }
    return false;
  }

  // Update user data
  static Future<void> updateUserData({
    required String userId,
    required Map<String, dynamic> data,
    bool isSet = false,
  }) async {
    if (isSet) {
      await _firestore
          .collection('Users')
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } else {
      await _firestore.collection('Users').doc(userId).update(data);
    }
  }

  static Future<void> updateDiamonds(String userId, int amount) async {
    await _firestore.collection('Users').doc(userId).update({
      'diamonds': FieldValue.increment(amount),
    });
  }

  static Future<void> updateUserInfo(User user) async {
    final firebaseUser = AuthController.instance.firebaseUser!;

    // Get device token
    final String deviceToken = await _firebaseMsg.getToken() ?? '';

    var data = {
      'deviceToken': deviceToken,
      'lastActive': DateTime.now().millisecondsSinceEpoch,
      'isOnline': true,
    };

    if (user.createdAt == null) {
      final DateTime? creationTime = firebaseUser.metadata.creationTime;
      // Update creation date
      data['createdAt'] = creationTime == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(creationTime);
    }

    // Save data
    await updateUserData(userId: user.userId, data: data, isSet: true);
    // Subscribe for Push Notifications
    _firebaseMsg.subscribeToTopic('NOTIFY_USERS');
  }

  // Delete all the files upload by user
  static Future<void> deleteUserStorageFiles() async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      final ListResult listResult = await FirebaseStorage.instance
          .ref('uploads/users/${currentUser.userId}')
          .listAll();
      final List<Future<void>> references = listResult.items
          .map((e) => e.delete())
          .toList();
      // Check result
      if (references.isNotEmpty) {
        await Future.wait(references);
        debugPrint('_deleteUserStorageFiles() -> success');
      } else {
        debugPrint('_deleteUserStorageFiles() -> no files');
      }
    } catch (e) {
      debugPrint('_deleteUserStorageFiles() -> error: $e');
    }
  }

  static Future<void> deleteUserAccount() async {
    try {
      // Get current user model
      final User currentUer = AuthController.instance.currentUser;

      DialogHelper.showProcessingDialog(
        title: 'deleting_profile_account'.tr,
        barrierDismissible: false,
      );

      // Delete all user-uploaded files
      AppHelper.deleteStorageFiles('uploads/${currentUer.userId}');

      // Get User Groups
      final List<Group> userGroups = GroupController.instance.groups
          .where((group) => group.createdBy == currentUer.userId)
          .toList();

      // Delete user's groups
      final groupFutures = userGroups.map(
        (e) => _firestore.collection('Groups').doc(e.groupId).delete(),
      );
      if (groupFutures.isNotEmpty) {
        await Future.wait(groupFutures);
      }

      // Delete profile account data
      await _firestore.collection('Users').doc(currentUer.userId).delete();

      // Close previous dialog
      DialogHelper.closeDialog();

      // Show confirm dialog
      DialogHelper.showAlertDialog(
        icon: const Icon(Icons.check_circle, color: primaryColor),
        title: Text('success'.tr),
        content: Text(
          'profile_account_successfully_deleted'.tr,
          style: const TextStyle(fontSize: 16),
        ),
        actionText: 'sign_out'.tr.toUpperCase(),
        action: () => AuthApi.signOut(),
        showCancelButton: false,
        barrierDismissible: false,
      );
    } catch (e) {
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(
        SnackMsgType.error,
        "failed_to_delete_user_account".trParams({'error': e.toString()}),
      );
    }
  }

  ///
  /// <-- User Presense features -->
  ///

  static Map<String, dynamic> _isUserOnline(bool value) {
    var data = {
      'isOnline': value,
      'lastActive': Timestamp.now().millisecondsSinceEpoch,
    };
    if (!value) {
      data['isTyping'] = false;
      data['isRecording'] = false;
    }
    return data;
  }

  // Update User Presence in Realtime Database.
  static Future<void> updateUserPresenceInRealtimeDb() async {
    final User currentUer = AuthController.instance.currentUser;

    // Get Realtime database reference
    final DatabaseReference connectedRef = _realtime.ref('.info/connected');
    // Listen to updates
    connectedRef.onValue.listen((event) async {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        _realtime.ref().child(currentUer.userId).update(_isUserOnline(true));
      } else {
        _realtime
            .ref()
            .child(currentUer.userId)
            .onDisconnect()
            .update(_isUserOnline(false));
      }
    });
  }

  // Update User presence
  static Future<void> updateUserPresence(bool isOnline) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateUserData(
        userId: currentUer.userId,
        data: _isUserOnline(isOnline),
        isSet: true,
      );
      debugPrint('updateUserPresence() -> success');
    } catch (e) {
      debugPrint('updateUserPresence() -> error: $e');
    }
  }

  /// Update User typing status
  static Future<void> updateUserTypingStatus(
    bool isTyping,
    String receiverId,
  ) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateUserData(
        userId: currentUer.userId,
        data: {
          'isTyping': isTyping,
          'typingTo': receiverId,
          'isRecording': false,
        },
        isSet: true,
      );
      // Also update chat node typing status
      await ChatApi.updateChatTypingStatus(isTyping, receiverId);
      debugPrint('updateUserTypingStatus() -> success');
    } catch (e) {
      debugPrint('updateUserTypingStatus() -> error: $e');
    }
  }

  /// Update User recording status
  static Future<void> updateUserRecordingStatus(
    bool isRecording,
    String receiverId,
  ) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateUserData(
        userId: currentUer.userId,
        data: {
          'isRecording': isRecording,
          'recordingTo': receiverId,
          'isTyping': false,
        },
        isSet: true,
      );
      // Also update chat node recording status
      await ChatApi.updateChatRecordingStatus(isRecording, receiverId);
      debugPrint('updateUserRecordingStatus() -> success');
    } catch (e) {
      debugPrint('updateUserRecordingStatus() -> error: $e');
    }
  }

  /// Close User typing or recording status
  static Future<void> closeTypingOrRecordingStatus() async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await updateUserData(
        userId: currentUer.userId,
        data: {'isTyping': false, 'isRecording': false},
        isSet: true,
      );
      debugPrint('closeTypingOrRecordingStatus() -> success');
    } catch (e) {
      debugPrint('closeTypingOrRecordingStatus() -> error: $e');
    }
  }

  static Future<void> muteGroup(String groupId, bool isMuted) async {
    try {
      final User currentUer = AuthController.instance.currentUser;

      await UserApi.updateUserData(
        userId: currentUer.userId,
        data: {
          'mutedGroups': isMuted
              ? FieldValue.arrayRemove([groupId])
              : FieldValue.arrayUnion([groupId]),
        },
      );
      debugPrint('muteGroup() -> success');
    } catch (e) {
      debugPrint('muteGroup() -> error: $e');
    }
  }
}
