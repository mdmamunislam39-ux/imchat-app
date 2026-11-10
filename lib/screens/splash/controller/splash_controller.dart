import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chat_messenger/services/leaderboard_service.dart';

class SplashController extends GetxController {
  // Init or retrieve Auth controller
  late final AuthController auth;

  @override
  void onInit() {
    super.onInit();
    auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController(), permanent: true);

    _loadData();
    _getAppVersion();

    // Check leaderboards in background without delaying splash navigation
    unawaited(Future(() {
      try {
        if (!Get.isRegistered<LeaderboardService>()) {
          Get.put(LeaderboardService());
        }
        Get.find<LeaderboardService>().checkAndResetLeaderboards();
      } catch (e) {
        debugPrint('⚠️ [SplashController] Leaderboard check error: $e');
      }
    }));
  }

  Future<void> _loadData() async {
    // Safety watchdog: if checkUserAccount takes longer than 4.5 seconds or fails,
    // ensure splash always transitions gracefully.
    final Timer safetyTimer = Timer(const Duration(milliseconds: 4500), () {
      if (Get.currentRoute == AppRoutes.splash) {
        debugPrint('⏱️ [SplashController] Safety watchdog triggered navigation fallback.');
        if (auth.firebaseUser != null) {
          Get.offAllNamed(AppRoutes.home);
        } else {
          Get.offAllNamed(AppRoutes.phoneSignIn);
        }
      }
    });

    try {
      // Auth user account with guaranteed minimum display duration of 2.2 seconds
      await auth.checkUserAccount(minDelay: const Duration(milliseconds: 2200));
    } catch (e) {
      debugPrint('⚠️ [SplashController] Error during splash auth check: $e');
      if (Get.currentRoute == AppRoutes.splash) {
        if (auth.firebaseUser != null) {
          Get.offAllNamed(AppRoutes.home);
        } else {
          Get.offAllNamed(AppRoutes.phoneSignIn);
        }
      }
    } finally {
      safetyTimer.cancel();
    }
  }

  // App version checker
  final box = GetStorage();
  String? _version;

  void _getAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version;
      box.write('version', _version);
    } catch (e) {
      debugPrint('⚠️ [SplashController] Error getting app version: $e');
    }
  }
}
