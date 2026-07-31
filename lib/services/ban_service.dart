import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

class BanService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID on Android
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    }
    return 'unknown_device';
  }

  static Future<bool> isDeviceBanned() async {
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore.collection('banned_devices').doc(deviceId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final bool isPermanent = data['isPermanent'] ?? false;
        final Timestamp? expiresAt = data['expiresAt'];
        
        if (isPermanent) return true;
        
        if (expiresAt != null && expiresAt.toDate().isAfter(DateTime.now())) {
          return true;
        } else if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
          // Ban expired, remove it
          await _firestore.collection('banned_devices').doc(deviceId).delete();
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking device ban: $e');
      return false; // Fail open
    }
  }

  static bool isAccountLoginBanned(User? user) {
    if (user == null) return false;
    final banStatus = user.banStatus;
    if (banStatus == null) return false;
    
    if (banStatus.isLoginBanPermanent) return true;
    
    if (banStatus.loginBanEndTime != null) {
      if (banStatus.loginBanEndTime!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  static String getLoginBanMessage(User? user) {
    if (user == null) return '';
    final banStatus = user.banStatus;
    if (banStatus == null) return '';
    
    if (banStatus.isLoginBanPermanent) {
      return 'Your account is permanently banned.';
    }
    
    if (banStatus.loginBanEndTime != null) {
      final duration = banStatus.loginBanEndTime!.difference(DateTime.now());
      if (duration.inDays > 0) {
        return 'Your account is temporarily banned. Remaining: ${duration.inDays} days, ${duration.inHours % 24} hours.';
      } else if (duration.inHours > 0) {
        return 'Your account is temporarily banned. Remaining: ${duration.inHours} hours, ${duration.inMinutes % 60} minutes.';
      } else if (duration.inMinutes > 0) {
        return 'Your account is temporarily banned. Remaining: ${duration.inMinutes} minutes.';
      }
    }
    return 'Your account is temporarily banned.';
  }

  static bool isMicBanned(User? user) {
    if (user == null) return false;
    final banStatus = user.banStatus;
    if (banStatus == null) return false;
    
    if (banStatus.isMicBanPermanent) return true;
    
    if (banStatus.micBanEndTime != null) {
      if (banStatus.micBanEndTime!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  static bool isChatBanned(User? user) {
    if (user == null) return false;
    final banStatus = user.banStatus;
    if (banStatus == null) return false;
    
    if (banStatus.isChatBanPermanent) return true;
    
    if (banStatus.chatBanEndTime != null) {
      if (banStatus.chatBanEndTime!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  static Future<void> handleBannedUser({String message = 'Your account or device has been temporarily banned.'}) async {
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed(AppRoutes.phoneSignIn);
    Get.snackbar(
      'Banned',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
  }
}
