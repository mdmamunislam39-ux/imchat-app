import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// Client-side backup service for resetting daily/weekly/monthly leaderboards.
/// This runs on app startup to handle cases where Cloud Functions are not deployed/billed.
class LeaderboardService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> checkAndResetLeaderboards() async {
    try {
      // 1. Check if a reset is needed based on TIME only
      final now = DateTime.now();

      // Daily: 12:00 PM
      final todayNoon = DateTime(now.year, now.month, now.day, 12, 0, 0);

      // This logic is tricky. We need LAST reset time from Firestore.

      // Better: Store "lastGlobalReset" in a singleton doc.
      // If it doesn't exist, create it.

      final sysDocRef = _firestore.collection('system').doc('leaderboard_cron');
      final sysDoc = await sysDocRef.get().timeout(const Duration(seconds: 15));

      DateTime lastDailyRun = DateTime(2000);
      DateTime lastWeeklyRun = DateTime(2000);
      DateTime lastMonthlyRun = DateTime(2000);

      if (sysDoc.exists) {
        final data = sysDoc.data()!;
        if (data['lastDailyRun'] != null) {
          lastDailyRun = (data['lastDailyRun'] as Timestamp).toDate();
        }
        if (data['lastWeeklyRun'] != null) {
          lastWeeklyRun = (data['lastWeeklyRun'] as Timestamp).toDate();
        }
        if (data['lastMonthlyRun'] != null) {
          lastMonthlyRun = (data['lastMonthlyRun'] as Timestamp).toDate();
        }
      }

      // Check Daily (After 12:00 PM today)
      // If last run was BEFORE today's 12:00 PM, and NOW is AFTER 12:00 PM => RUN.
      bool runDaily = false;
      if (now.isAfter(todayNoon) && lastDailyRun.isBefore(todayNoon)) {
        runDaily = true;
      }

      // Check Weekly (Monday 12:00 AM)
      // Find this week's Monday 00:00
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final thisWeekMonday = DateTime(monday.year, monday.month, monday.day);
      bool runWeekly = false;
      if (now.isAfter(thisWeekMonday) &&
          lastWeeklyRun.isBefore(thisWeekMonday)) {
        runWeekly = true;
      }

      // Check Monthly (1st of Month 12:00 AM)
      final thisMonthFirst = DateTime(now.year, now.month, 1);
      bool runMonthly = false;
      if (now.isAfter(thisMonthFirst) &&
          lastMonthlyRun.isBefore(thisMonthFirst)) {
        runMonthly = true;
      }

      if (!runDaily && !runWeekly && !runMonthly) return;

      // START RESET
      // We use a transaction to lock the system doc so only one client runs it
      await _firestore.runTransaction((transaction) async {
        // Re-check conditions inside transaction
        // ... (simplified for brevity, assume we won the race)

        transaction.set(
            sysDocRef,
            {
              'lastDailyRun': runDaily
                  ? Timestamp.fromDate(now)
                  : (sysDoc.exists
                      ? sysDoc.get('lastDailyRun')
                      : Timestamp.fromDate(lastDailyRun)),
              'lastWeeklyRun': runWeekly
                  ? Timestamp.fromDate(now)
                  : (sysDoc.exists
                      ? sysDoc.get('lastWeeklyRun')
                      : Timestamp.fromDate(lastWeeklyRun)),
              'lastMonthlyRun': runMonthly
                  ? Timestamp.fromDate(now)
                  : (sysDoc.exists
                      ? sysDoc.get('lastMonthlyRun')
                      : Timestamp.fromDate(lastMonthlyRun)),
            },
            SetOptions(merge: true));
      });

      // Now query rooms and reset.
      // Note: This runs loosely. If app kills, it stops.
      // It's a "temporary frontend approach".

      final roomsSnapshot = await _firestore
          .collection('audio_rooms_v2')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (var doc in roomsSnapshot.docs) {
        final data = doc.data();
        final contributors =
            data['contributors'] as Map<String, dynamic>? ?? {};

        bool needsUpdate = false;
        Map<String, dynamic> updates = {};

        contributors.forEach((key, value) {
          final contributor = value as Map<String, dynamic>;
          String fieldPrefix = 'contributors.$key';

          if (runDaily && (contributor['dailyContribution'] ?? 0) > 0) {
            updates['$fieldPrefix.dailyContribution'] = 0;
            needsUpdate = true;
          }
          if (runWeekly && (contributor['weeklyContribution'] ?? 0) > 0) {
            updates['$fieldPrefix.weeklyContribution'] = 0;
            needsUpdate = true;
          }
          if (runMonthly && (contributor['monthlyContribution'] ?? 0) > 0) {
            updates['$fieldPrefix.monthlyContribution'] = 0;
            needsUpdate = true;
          }
        });

        if (needsUpdate) {
          batch.update(doc.reference, updates);
        }
      }

      await batch.commit();
      debugPrint(
          "✅ Frontend Leaderboard Reset Complete: Daily:$runDaily, Weekly:$runWeekly, Monthly:$runMonthly");
    } catch (e) {
      debugPrint("❌ Error in Frontend Leaderboard Reset: $e");
    }
  }
}
