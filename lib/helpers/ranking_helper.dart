import 'package:intl/intl.dart';

class RankingHelper {
  /// Base time for resets - using UTC+6 (Bangladesh standard time) as default app time
  static DateTime _getAppTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 6));
  }

  /// Gets the suffix for the current day, e.g., '2026_07_04'
  static String get dailySuffix {
    final now = _getAppTime();
    return DateFormat('yyyy_MM_dd').format(now);
  }

  /// Gets the suffix for the current week starting on Sunday.
  /// Generates a unique week ID based on days since a known Sunday (Jan 4, 1970).
  static String get weeklySuffix {
    final now = _getAppTime();
    // Creating the anchor with noon to avoid DST/timezone shift issues in difference()
    final anchor = DateTime.utc(1970, 1, 4, 12, 0); 
    final current = DateTime.utc(now.year, now.month, now.day, 12, 0);
    final daysSinceAnchor = current.difference(anchor).inDays;
    final weekId = daysSinceAnchor ~/ 7;
    return 'wk_$weekId';
  }

  /// Gets the suffix for the current month, e.g., '2026_07'
  static String get monthlySuffix {
    final now = _getAppTime();
    return DateFormat('yyyy_MM').format(now);
  }

  /// Gets Monday 00:00:00 of the current week (Monday to Monday cycle)
  static DateTime get currentMondayStart {
    final now = _getAppTime();
    final daysSinceMonday = now.weekday - 1;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
  }

  /// Gets the next Monday 00:00:00 ending the current cycle
  static DateTime get nextMondayStart {
    return currentMondayStart.add(const Duration(days: 7));
  }

  /// Format current Monday to Monday date range string (e.g. "Mon 27 Jul - Mon 03 Aug")
  static String get mondayToMondayRangeString {
    final start = currentMondayStart;
    final end = nextMondayStart;
    final startStr = DateFormat('EEE dd MMM').format(start);
    final endStr = DateFormat('EEE dd MMM').format(end);
    return '$startStr - $endStr';
  }

  /// Gets the suffix for Monday to Monday week, e.g., 'mon_2026_07_27'
  static String get mondayWeeklySuffix {
    final monday = currentMondayStart;
    return 'mon_${DateFormat('yyyy_MM_dd').format(monday)}';
  }
}
