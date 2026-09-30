import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:chat_messenger/services/backend_engine_manager.dart';
import 'package:chat_messenger/services/push_notification_service.dart';

/// Clean, robust service to notify active followers when a user opens or joins a room.
/// Fully supports both VPS PostgreSQL Mode and Firebase Cloud Functions Mode.
class LiveNotificationService {
  static final Map<String, DateTime> _lastSentTimestamps = {};

  /// Notify active followers that the user has gone live / opened / joined a voice room.
  static Future<void> notifyActiveFollowersOnLive({
    required String creatorId,
    required String creatorName,
    required String creatorAvatar,
    required String roomId,
    String? roomName,
  }) async {
    if (creatorId.isEmpty || roomId.isEmpty) return;

    // 1. User Cooldown check: Prevent spamming followers if user hops rooms (A -> B -> C) frequently.
    // 1 hour (60 minutes) cooldown between broadcast alerts.
    final storage = GetStorage();
    final storageKey = 'last_live_notification_$creatorId';
    final int? lastSentMs = storage.read<int>(storageKey) ?? _lastSentTimestamps[creatorId]?.millisecondsSinceEpoch;

    if (lastSentMs != null) {
      final diffMinutes = (DateTime.now().millisecondsSinceEpoch - lastSentMs) / 60000;
      if (diffMinutes < 60) {
        debugPrint('ℹ️ [LiveNotificationService] Cooldown active for user $creatorId (${diffMinutes.toStringAsFixed(1)} min ago). Rapid room hopping will not spam followers.');
        return;
      }
    }

    _lastSentTimestamps[creatorId] = DateTime.now();
    try {
      storage.write(storageKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    final finalRoomName = roomName ?? "${creatorName.isNotEmpty ? creatorName : 'User'}'s Room";
    final finalCreatorName = creatorName.isNotEmpty ? creatorName : 'User';

    debugPrint('🚀 [LiveNotificationService] Initiating live room notification for $finalCreatorName in room: $roomId');

    // 2. VPS MODE DISPATCH
    if (BackendEngineManager.isVps) {
      try {
        final vpsApi = BackendEngineManager.instance.apiService;
        final res = await vpsApi.post('/api/rooms/notify-followers-live', body: {
          'creatorId': creatorId,
          'creatorName': finalCreatorName,
          'creatorAvatar': creatorAvatar,
          'roomId': roomId,
          'roomName': finalRoomName,
        });

        debugPrint('✅ [LiveNotificationService] Sent via VPS Backend Server successfully. Response: $res');
        return;
      } catch (vpsErr) {
        debugPrint('⚠️ [LiveNotificationService] VPS notification error: $vpsErr. Falling back to Firebase mode...');
      }
    }

    // 3. FIREBASE MODE DISPATCH (Cloud Functions / Firestore + FCM)
    try {
      // 3.1 Try Firebase Cloud Functions Callable
      final callable = FirebaseFunctions.instance.httpsCallable('notifyActiveFollowersOnLive');
      final result = await callable.call({
        'creatorId': creatorId,
        'creatorName': finalCreatorName,
        'creatorAvatar': creatorAvatar,
        'roomId': roomId,
        'roomName': finalRoomName,
      });

      debugPrint('✅ [LiveNotificationService] Firebase Cloud Function notified followers. Result: ${result.data}');
    } catch (functionsErr) {
      debugPrint('⚠️ [LiveNotificationService] Cloud Functions failed ($functionsErr). Falling back to direct client dispatch...');

      // 3.2 Client-Side Direct Firestore + PushNotificationService Fallback
      unawaited(Future(() async {
        try {
          final followersSnap = await FirebaseFirestore.instance
              .collection('Users')
              .doc(creatorId)
              .collection('followers')
              .get()
              .timeout(const Duration(seconds: 10));

          if (followersSnap.docs.isEmpty) return;

          final List<String> followerIds = followersSnap.docs
              .map((d) => d.id)
              .where((id) => id.isNotEmpty && id != creatorId)
              .toList();

          // Query followers in chunks of 10
          for (int i = 0; i < followerIds.length; i += 10) {
            final chunk = followerIds.sublist(
              i,
              i + 10 > followerIds.length ? followerIds.length : i + 10,
            );

            final usersQuery = await FirebaseFirestore.instance
                .collection('Users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get()
                .timeout(const Duration(seconds: 8));

            for (var userDoc in usersQuery.docs) {
              final data = userDoc.data();
              final deviceToken = data['deviceToken']?.toString() ?? '';

              // Send push notification to all followers with a valid device token
              if (deviceToken.isNotEmpty) {
                PushNotificationService.sendNotification(
                  type: NotificationType.follower_room,
                  title: '$finalCreatorName is on live!',
                  body: "Let's have fun together!!🤘🤟",
                  deviceToken: deviceToken,
                  call: {
                    'type': 'follower_room',
                    'roomId': roomId,
                    'roomName': finalRoomName,
                    'creatorId': creatorId,
                    'creatorName': finalCreatorName,
                    'creatorAvatar': creatorAvatar,
                  },
                );
              }
            }
          }
        } catch (e) {
          debugPrint('❌ [LiveNotificationService] Direct fallback failed: $e');
        }
      }));
    }
  }
}
