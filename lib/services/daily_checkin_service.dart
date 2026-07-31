import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/dialogs/daily_checkin_dialog.dart';

class DailyCheckInService {
  static final GetStorage _box = GetStorage();

  static Future<void> checkAndShowCheckIn(BuildContext context) async {
    try {
      final user = AuthController.instance.currentUser;
      if (user.userId.isEmpty) return;

      // Check if the Daily Check-in service is enabled/active in platform settings
      final configDoc = await FirebaseFirestore.instance.collection('platform_config').doc('daily_checkin').get();
      final bool isActive = configDoc.exists ? (configDoc.data()?['isActive'] as bool? ?? true) : true;
      if (!isActive) {
        return;
      }

      final String todayStr = DateTime.now().toIso8601String().substring(0, 10);
      
      // Check if the daily check-in dialog has already been shown/dismissed today
      final String lastShowDate = _box.read('last_checkin_dialog_show_date') ?? '';
      if (lastShowDate == todayStr) {
        return;
      }

      // Fetch user's check-in progress directly from Firestore to ensure freshness
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final String? lastCheckInDate = userData?['lastCheckInDate'] as String?;
      final int consecutiveDays = (userData?['consecutiveDays'] as num?)?.toInt() ?? 0;

      if (lastCheckInDate == todayStr) {
        // Already checked in today, update our local show date so we don't check again
        _box.write('last_checkin_dialog_show_date', todayStr);
        return;
      }

      // Set that the dialog has been shown for today
      _box.write('last_checkin_dialog_show_date', todayStr);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => DailyCheckInDialog(
            consecutiveDays: consecutiveDays,
            lastCheckInDate: lastCheckInDate,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in DailyCheckInService: $e');
    }
  }
}
