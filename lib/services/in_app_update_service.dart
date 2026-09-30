import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  /// Checks for Google Play In-App Updates and prompts user
  static Future<void> checkForUpdate({bool isImmediate = false}) async {
    // In-App Update is only supported on Android devices
    if (!Platform.isAndroid) return;

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (isImmediate && updateInfo.immediateUpdateAllowed) {
          // 1. Immediate Update: Fullscreen mandatory update
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          // 2. Flexible Update: Background download with banner / bottom sheet
          final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            // Once downloaded, complete and install the update
            _notifyAndCompleteUpdate();
          }
        }
      }
    } catch (e) {
      debugPrint('[InAppUpdateService] Check update error: $e');
    }
  }

  /// Completes flexible update installation
  static Future<void> _notifyAndCompleteUpdate() async {
    try {
      Get.snackbar(
        'update_available'.tr.isNotEmpty ? 'update_available'.tr : 'Update Ready',
        'update_ready_message'.tr.isNotEmpty 
            ? 'update_ready_message'.tr 
            : 'A new update has been downloaded. Restarting to complete update...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () => InAppUpdate.completeFlexibleUpdate(),
          child: Text('install'.tr.isNotEmpty ? 'install'.tr : 'INSTALL',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

      // Trigger completion
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[InAppUpdateService] Complete update error: $e');
    }
  }
}
