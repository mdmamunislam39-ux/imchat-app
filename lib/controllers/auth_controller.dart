import 'dart:async';

import 'package:chat_messenger/services/role_service.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/services/svip_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/services/device_session_service.dart';
import 'package:chat_messenger/services/ban_service.dart';
import 'package:chat_messenger/helpers/frame_helper.dart';
import 'package:chat_messenger/helpers/country_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud_firestore;

import 'app_controller.dart';

class AuthController extends GetxController {
  // Get the current instance
  static AuthController get instance => Get.find<AuthController>();

  final StoreService _storeService = StoreService();
  final RxString currentFrameUrl = ''.obs;

  // Firebase Auth
  final _firebaseAuth = auth.FirebaseAuth.instance;
  // Firebase User
  auth.User? get firebaseUser => _firebaseAuth.currentUser;

  // Hold login provider
  LoginProvider provider = LoginProvider.email;

  // Current User Model
  final Rxn<User> _currentUser = Rxn();
  StreamSubscription<User>? _stream;
  StreamSubscription<cloud_firestore.DocumentSnapshot>? _deviceBanStream;

  // Premium vars
  final RxBool _isPremium = false.obs;
  final RxBool _isPremiumMember = false.obs;
  final RxString _premiumPlanId = ''.obs;
  final RxBool _showPremiumRestoreMsg = false.obs;

  // <-- GETTERS -->
  User get currentUser => _currentUser.value ?? User();
  bool get isPremium => _isPremium.value;
  bool get isPremiumMember => _isPremiumMember.value;
  String get premiumPlanId => _premiumPlanId.value;
  bool get showPremiumRestoreMsg => _showPremiumRestoreMsg.value;

  // Expose stream for real-time reactivity in Blocs
  Stream<User?> get currentUserStream => _currentUser.stream;

  /// Optimistically deduct diamonds for immediate UI/combo validation
  /// Returns true if deduction succeeded, false if balance is insufficient.
  bool deductDiamonds(int amount) {
    if (_currentUser.value == null || amount <= 0) return true;
    if (_currentUser.value!.diamonds < amount) return false;
    _currentUser.value!.diamonds -= amount;
    _currentUser.refresh();
    return true;
  }

  /// Refund diamonds if an asynchronous operation failed
  void refundDiamonds(int amount) {
    if (_currentUser.value == null || amount <= 0) return;
    _currentUser.value!.diamonds += amount;
    _currentUser.refresh();
  }

  @override
  void onClose() {
    _stream?.cancel();
    _deviceBanStream?.cancel();
    // Stop role listener on controller close
    if (Get.isRegistered<RoleService>()) {
      Get.find<RoleService>().stopListening();
    }
    super.onClose();
  }

  void updatePremium(bool value) {
    _isPremium.value = value;
    _isPremiumMember.value = value;
  }

  void allowFreeAccess(bool value) {
    _isPremium.value = value;
  }

  void updatePremiumPlanID(String value) {
    _premiumPlanId.value = value;
  }

  void updateRestorePremiumMsg(bool value) {
    _showPremiumRestoreMsg.value = value;
  }

  // Update Current User Model
  void _updateCurrentUser(User user) {
    _currentUser.value = user;
    _updateFrameUrl(user);
    _checkAndAutoSetUserCountry(user);
    SvipService.checkAndCleanupExpiredVipAndSvip(user.userId);
    _storeService.checkAndCleanupExpiredUserItems(user.userId);
    // Get user updates
    _stream = UserApi.getUserUpdates(user.userId).listen((event) {
      _currentUser.value = event;
      _updateFrameUrl(event);
      _checkRealTimeBans(event);
      SvipService.checkAndCleanupExpiredVipAndSvip(event.userId);
      _storeService.checkAndCleanupExpiredUserItems(event.userId);
    }, onError: (e) => debugPrint(e.toString()));

    // Start real-time role listener — fires instantly when role changes in Firestore
    RoleService.instance.listenToUserRole(user.userId);

    // Listen to device ban in real time
    _listenToDeviceBan();
  }

  /// If user country is unset or empty, auto-detect device location and save to user profile
  void _checkAndAutoSetUserCountry(User user) {
    if (user.country.trim().isEmpty || user.country.trim().toLowerCase() == 'select') {
      unawaited(Future(() async {
        try {
          final detected = await CountryHelper.detectDeviceCountry(userPhone: user.number);
          if (detected.name.isNotEmpty) {
            user.country = detected.name;
            await cloud_firestore.FirebaseFirestore.instance
                .collection('Users')
                .doc(user.userId)
                .set({'country': detected.name}, cloud_firestore.SetOptions(merge: true));
            _currentUser.value = user;
            _currentUser.refresh();
            debugPrint('📍 [AuthController] Auto-assigned user country: ${detected.name} (${detected.code})');
          }
        } catch (e) {
          debugPrint('⚠️ [AuthController] Failed to auto-set country: $e');
        }
      }));
    }
  }

  void _checkRealTimeBans(User user) {
    if (BanService.isAccountLoginBanned(user)) {
      final message = BanService.getLoginBanMessage(user);
      BanService.handleBannedUser(message: message);
    }
  }

  void _listenToDeviceBan() async {
    _deviceBanStream?.cancel();
    try {
      final deviceId = await BanService.getDeviceId();
      _deviceBanStream = cloud_firestore.FirebaseFirestore.instance
          .collection('banned_devices')
          .doc(deviceId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final bool isPermanent = data['isPermanent'] ?? false;
          final cloud_firestore.Timestamp? expiresAt = data['expiresAt'];
          
          bool isBanned = false;
          if (isPermanent) {
            isBanned = true;
          } else if (expiresAt != null && expiresAt.toDate().isAfter(DateTime.now())) {
            isBanned = true;
          }

          if (isBanned) {
            BanService.handleBannedUser(message: 'This device has been banned from accessing the app.');
          }
        }
      });
    } catch (e) {
      debugPrint('Error setting up device ban listener: $e');
    }
  }

  Future<void> _updateFrameUrl(User user) async {
    final frameId = user.customization?.selectedFrameId;
    if (frameId != null && frameId.isNotEmpty) {
      try {
        final frameDetails = await _storeService.getStoreItemDetails(frameId);
        if (frameDetails != null) {
          final url = (frameDetails['fileUrl'] ??
              frameDetails['thumbnailUrl'] ??
              frameDetails['imageUrl'] ??
              frameDetails['image'] ??
              '') as String;
          if (url.isNotEmpty) {
            currentFrameUrl.value = url;
            FrameHelper.setCachedUserFrame(
              userId: user.userId,
              frameId: frameId,
              frameUrl: url,
            );
            return;
          }
        }
        final resolved = await FrameHelper.getFrameUrl(frameId);
        if (resolved != null && resolved.isNotEmpty) {
          currentFrameUrl.value = resolved;
          FrameHelper.setCachedUserFrame(
            userId: user.userId,
            frameId: frameId,
            frameUrl: resolved,
          );
          return;
        }
      } catch (e) {
        debugPrint('❌ Error loading frame: $e');
      }
    } else {
      currentFrameUrl.value = '';
      FrameHelper.setCachedUserFrame(
        userId: user.userId,
        frameId: null,
        frameUrl: null,
      );
    }
  }

  // Handle user auth
  Future<void> checkUserAccount({Duration minDelay = Duration.zero}) async {
    final stopwatch = Stopwatch()..start();

    Future<void> safeNavigate(VoidCallback navAction) async {
      if (minDelay > Duration.zero) {
        final remaining = minDelay - stopwatch.elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
      }
      navAction();
    }

    try {
      // Check logged in firebase user
      if (firebaseUser == null) {
        await safeNavigate(() => Get.offAllNamed(AppRoutes.phoneSignIn));
        return;
      }

      // Init app controller
      if (!Get.isRegistered<AppController>()) {
        Get.put(AppController(), permanent: true);
      }

      // Parallelize user fetching and device ban check with safe timeout
      final results = await Future.wait([
        UserApi.getUser(firebaseUser!.uid).timeout(const Duration(seconds: 8)),
        BanService.isDeviceBanned().timeout(const Duration(seconds: 8)),
      ]);

      User? user = results[0] as User?;
      final isDeviceBanned = results[1] as bool;

      // Check device ban
      if (isDeviceBanned) {
        try {
          await _firebaseAuth.signOut();
        } catch (_) {}
        await safeNavigate(() => Get.offAllNamed(AppRoutes.phoneSignIn));
        Get.snackbar(
          'Device Banned',
          'This device has been temporarily banned from logging in.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // Check if account exists with this email (e.g. bound account)
      if (user == null && firebaseUser!.email != null && firebaseUser!.email!.isNotEmpty) {
        try {
          user = await UserApi.getUserByEmail(firebaseUser!.email!).timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('⚠️ [AuthController] getUserByEmail error: $e');
        }
      }

      // Check user
      if (user == null) {
        final phone = firebaseUser!.phoneNumber ?? '';
        await safeNavigate(() => Get.offAllNamed(AppRoutes.signUp, arguments: {'number': phone}));
        return;
      }

      // Check blocked account status
      if (user.status == 'blocked') {
        await safeNavigate(() => Get.offAllNamed(AppRoutes.blockedAccount));
        return;
      }

      // Check login ban
      if (BanService.isAccountLoginBanned(user)) {
        final message = BanService.getLoginBanMessage(user);
        try {
          await _firebaseAuth.signOut();
        } catch (_) {}
        await safeNavigate(() => Get.offAllNamed(AppRoutes.phoneSignIn));
        Get.snackbar(
          'Account Banned',
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      // Update the current user model
      _updateCurrentUser(user);

      // Update current user info & device session in background without delaying navigation
      unawaited(UserApi.updateUserInfo(user));
      unawaited(DeviceSessionService.registerSession(firebaseUser!.uid));

      // Go to home page smoothly
      await safeNavigate(() => Get.offAllNamed(AppRoutes.home));
      Future.delayed(const Duration(milliseconds: 300), () {
        DeepLinkService.checkPendingDeepLinks();
      });
    } catch (e) {
      debugPrint('⚠️ [AuthController] Error in checkUserAccount: $e');
      // If an error occurs, do not get stuck on splash screen forever!
      if (_currentUser.value != null && _currentUser.value!.userId.isNotEmpty) {
        await safeNavigate(() => Get.offAllNamed(AppRoutes.home));
      } else {
        await safeNavigate(() => Get.offAllNamed(AppRoutes.phoneSignIn));
      }
    }
  }

  Future<void> getCurrentUserAndLoadData() async {
    final user = await UserApi.getUser(firebaseUser!.uid);
    // Update the current user model
    _updateCurrentUser(user!);
    // Update current user info
    UserApi.updateUserInfo(user);
  }
}
