import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/call_history.dart';
import 'package:chat_messenger/models/user.dart';

import 'user_api.dart';

class CallHistoryApi {
  ///
  /// Call History - CRUD Operations
  ///
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> saveCall({
    required bool isVideo,
    required User receiver,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // 1. Outgoing call for current user
      final CallHistory outgoingCall = CallHistory(
        receiver: receiver,
        isVideo: isVideo,
        isNew: false,
        type: CallType.outgoing,
      );
      // 2. Incoming call for onother user
      final CallHistory incomingCall = CallHistory(
        receiver: currentUser,
        isVideo: isVideo,
        isNew: true,
        type: CallType.incoming,
      );

      await Future.wait([
        // Save for current user
        _firestore
            .collection('Users/${currentUser.userId}/CallHistory')
            .doc(receiver.userId)
            .set(outgoingCall.toMap()),

        // Save for another user
        _firestore
            .collection('Users/${receiver.userId}/CallHistory')
            .doc(currentUser.userId)
            .set(incomingCall.toMap()),
      ]);
      debugPrint('saveMissedCall() -> success!');
    } catch (e) {
      debugPrint('saveMissedCall() -> success!');
    }
  }

  static Future<void> saveMissedCall({
    required bool isVideo,
    required User receiver,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // Missed call for onother user
      final CallHistory missedCall = CallHistory(
        receiver: receiver,
        isVideo: isVideo,
        isNew: true,
        type: CallType.missed,
      );

      // Save for another user
      await _firestore
          .collection('Users/${receiver.userId}/CallHistory')
          .doc(currentUser.userId)
          .set(missedCall.toMap());

      debugPrint('saveMissedCall() -> success!');
    } catch (e) {
      debugPrint('saveMissedCall() -> success!');
    }
  }

  static Stream<List<CallHistory>> getCallHistory() {
    String currentUserId = AuthController.instance.currentUser.userId;
    if (currentUserId.isEmpty) {
      currentUserId = AuthController.instance.firebaseUser?.uid ?? '';
    }

    if (currentUserId.isEmpty) {
      return AuthController.instance.currentUserStream.asyncExpand((user) {
        if (user != null && user.userId.isNotEmpty) {
          return _getCallHistoryStream(user.userId);
        }
        return Stream.value(<CallHistory>[]);
      });
    }

    return _getCallHistoryStream(currentUserId);
  }

  static Stream<List<CallHistory>> _getCallHistoryStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(<CallHistory>[]);

    // Build query
    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('CallHistory')
        .orderBy('ceatedAt', descending: true)
        .snapshots()
        .asyncMap((event) async {
      final List<CallHistory> calls = [];

      for (var doc in event.docs) {
        final data = doc.data();
        // Fetch user profile
        final User? receiver = await UserApi.getUser(doc.id);
        // Add call to the list
        if (receiver != null) {
          calls.add(
            CallHistory.fromMap(
              data: data,
              receiver: receiver,
              docRef: doc.reference,
            ),
          );
        }
      }
      return calls;
    });
  }

  static Future<void> viewCalls(List<CallHistory> newCalls) async {
    try {
      final List<Future<void>> futures =
          newCalls.map((call) => call.viewCall()).toList();
      if (futures.isNotEmpty) {
        await Future.wait(futures);
        debugPrint('viewCalls() -> success');
        return;
      }
      debugPrint('viewCalls() -> no new calls');
    } catch (e) {
      debugPrint('viewCalls() -> error: $e');
    }
  }

  static Future<void> clearCallLog(List<CallHistory> calls) async {
    try {
      final List<Future<void>> futures =
          calls.map((call) => call.clearCallLog()).toList();
      if (futures.isNotEmpty) {
        await Future.wait(futures);
        debugPrint('clearCallLog() -> success');
        return;
      }
      debugPrint('clearCallLog() -> no calls');
    } catch (e) {
      debugPrint('clearCallLog() -> error: $e');
    }
  }
}
