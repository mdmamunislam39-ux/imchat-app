import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LevelHelper {
  static final Map<int, String> _sendingLevelsCache = {};
  static final Map<int, String> _receivingLevelsCache = {};
  static bool _hasLoadedSending = false;
  static bool _hasLoadedReceiving = false;

  /// Fetch sending level URL directly using level number
  static Future<String?> getSendingLevelUrl(int? level) async {
    if (level == null) return null;

    if (!_hasLoadedSending) {
      await _loadSendingLevels();
    }
    return _sendingLevelsCache[level];
  }

  /// Fetch receiving level URL directly using level number
  static Future<String?> getReceivingLevelUrl(int? level) async {
    if (level == null) return null;

    if (!_hasLoadedReceiving) {
      await _loadReceivingLevels();
    }
    return _receivingLevelsCache[level];
  }

  static Future<void> _loadSendingLevels() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('level_configurations')
          .doc('sending_config')
          .get();

      if (doc.exists) {
        final levels = doc.data()?['levels'] as List<dynamic>?;
        if (levels != null) {
          for (final lvl in levels) {
            final lvlNum = lvl['levelNumber'] as int?;
            final url = lvl['imageUrl'] as String?;
            if (lvlNum != null && url != null) {
              _sendingLevelsCache[lvlNum] = url;
            }
          }
        }
      }
      _hasLoadedSending = true;
    } catch (e) {
      debugPrint('❌ [LevelHelper] Error loading sending levels: $e');
    }
  }

  static Future<void> _loadReceivingLevels() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('level_configurations')
          .doc('receiving_config')
          .get();

      if (doc.exists) {
        final levels = doc.data()?['levels'] as List<dynamic>?;
        if (levels != null) {
          for (final lvl in levels) {
            final lvlNum = lvl['levelNumber'] as int?;
            final url = lvl['imageUrl'] as String?;
            if (lvlNum != null && url != null) {
              _receivingLevelsCache[lvlNum] = url;
            }
          }
        }
      }
      _hasLoadedReceiving = true;
    } catch (e) {
      debugPrint('❌ [LevelHelper] Error loading receiving levels: $e');
    }
  }
}
