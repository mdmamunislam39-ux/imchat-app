import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/entrance_effect.dart';

/// Service for managing entrance effect animations in audio rooms
class EntranceEffectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trigger entrance effect when user joins room
  Future<void> triggerEntranceEffect({
    required String roomId,
    required String userId,
    required String userName,
    String? userAvatar,
    required String effectId,
    required String effectUrl,
  }) async {
    try {
      debugPrint('🎬 [EntranceEffect] Triggering effect for $userName');

      final effect = EntranceEffect(
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        effectId: effectId,
        effectUrl: effectUrl,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('entrance_effects')
          .add(effect.toJson());

      debugPrint('✅ [EntranceEffect] Effect triggered successfully');
    } catch (e) {
      debugPrint('❌ [EntranceEffect] Error triggering effect: $e');
    }
  }

  /// Get entrance effects stream for a room
  Stream<List<EntranceEffect>> getEntranceEffects(String roomId) {
    return _firestore
        .collection('audio_rooms_v2')
        .doc(roomId)
        .collection('entrance_effects')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return EntranceEffect.fromJson(doc.data());
            } catch (e) {
              debugPrint('❌ [EntranceEffect] Error parsing effect: $e');
              return null;
            }
          })
          .whereType<EntranceEffect>()
          .toList();
    });
  }

  /// Delete entrance effect after animation completes
  Future<void> deleteEntranceEffect(String roomId, String effectId) async {
    try {
      final querySnapshot = await _firestore
          .collection('audio_rooms_v2')
          .doc(roomId)
          .collection('entrance_effects')
          .where('effectId', isEqualTo: effectId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete().timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      debugPrint('❌ [EntranceEffect] Error deleting effect: $e');
    }
  }
}
