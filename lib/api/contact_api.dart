import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

import 'user_api.dart';

abstract class ContactApi {
  //
  // ContactApi - CRUD Operations
  //

  // Firebase instances
  static final _firestore = FirebaseFirestore.instance;

  // Send a friend request
  static Future<void> sendFriendRequest({
    required String targetUserId,
    String? roomTitle,
    String? roomId,
    bool showMsg = true,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      if (targetUserId == currentUser.userId) {
        if (showMsg) {
          DialogHelper.showSnackbarMessage(
              SnackMsgType.error, "আপনি নিজেকে ফ্রেন্ড রিকোয়েস্ট পাঠাতে পারবেন না।");
        }
        return;
      }

      // Play send sound
      try {
        AudioPlayer().play(AssetSource('sounds/sent_msg.mp3')).catchError((_) {});
      } catch (_) {}

      final Map<String, dynamic> requestData = {
        'senderId': currentUser.userId,
        'receiverId': targetUserId,
        'senderName': currentUser.fullname,
        'senderImageUrl': currentUser.photoUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (roomTitle != null && roomTitle.isNotEmpty) {
        requestData['roomTitle'] = roomTitle;
      }
      if (roomId != null && roomId.isNotEmpty) {
        requestData['roomId'] = roomId;
      }

      await Future.wait([
        _firestore
            .collection('Users')
            .doc(targetUserId)
            .collection('friend_requests')
            .doc(currentUser.userId)
            .set(requestData, SetOptions(merge: true)),
        _firestore
            .collection('friend_requests')
            .doc('${currentUser.userId}_$targetUserId')
            .set(requestData, SetOptions(merge: true)),
      ]);

      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, "Request sent successfully");
    } catch (e) {
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "Failed to send request: ${e.toString()}");
    }
  }

  // Accept friend request
  static Future<void> acceptFriendRequest({
    required String senderId,
    bool showMsg = true,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // 1. Add contact for both users
      await addContact(userId: senderId, showMsg: false);

      // 2. Clean up request records from both locations
      await Future.wait([
        _firestore
            .collection('Users')
            .doc(currentUser.userId)
            .collection('friend_requests')
            .doc(senderId)
            .delete(),
        _firestore
            .collection('friend_requests')
            .doc('${senderId}_${currentUser.userId}')
            .delete(),
      ]);

      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, "Friend request accepted!");
    } catch (e) {
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "Failed to accept request: ${e.toString()}");
    }
  }

  // Reject / delete friend request
  static Future<void> rejectFriendRequest({
    required String senderId,
    bool showMsg = true,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      await Future.wait([
        _firestore
            .collection('Users')
            .doc(currentUser.userId)
            .collection('friend_requests')
            .doc(senderId)
            .delete(),
        _firestore
            .collection('friend_requests')
            .doc('${senderId}_${currentUser.userId}')
            .delete(),
      ]);

      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, "Friend request rejected");
    } catch (e) {
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "Failed to reject request: ${e.toString()}");
    }
  }

  // Create new contact
  static Future<void> addContact({
    required String userId,
    bool showMsg = false,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      final String myId = currentUser.userId.isNotEmpty
          ? currentUser.userId
          : (AuthController.instance.firebaseUser?.uid ?? '');
      if (myId.isEmpty || userId.isEmpty) return;

      await Future.wait([
        // Save for current user
        _firestore
            .collection('Users')
            .doc(myId)
            .collection('Contacts')
            .doc(userId)
            .set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        // Save for onother user
        _firestore
            .collection('Users')
            .doc(userId)
            .collection('Contacts')
            .doc(myId)
            .set({
          'userId': myId,
          'createdAt': FieldValue.serverTimestamp()
        }),
      ]);
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, "add_contact_success".tr);
    } catch (e) {
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(SnackMsgType.error,
          "add_contact_error".trParams({'error': e.toString()}));
    }
  }

  static Future<User?> searchContactForUserId(String id) async {
    try {
      final String trimmedId = id.trim();
      if (trimmedId.isEmpty) return null;

      final querySearchId = await _firestore
          .collection('Users')
          .where('searchId', isEqualTo: trimmedId)
          .get();
      if (querySearchId.docs.isNotEmpty) {
        return User.fromMap(querySearchId.docs.first.data());
      }

      final queryUserId = await _firestore
          .collection('Users')
          .where('userId', isEqualTo: trimmedId)
          .get();
      if (queryUserId.docs.isNotEmpty) {
        return User.fromMap(queryUserId.docs.first.data());
      }

      // Try doc directly by ID
      final doc = await _firestore.collection('Users').doc(trimmedId).get();
      if (doc.exists && doc.data() != null) {
        return User.fromMap(doc.data()!);
      }

      return null;
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return null;
    }
  }

  static Future<User?> searchContactForNumber(String input, {String countryCode = '+880'}) async {
    try {
      final String raw = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      if (raw.isEmpty) return null;

      final List<String> candidates = [];

      // 1. If raw starts with '+', e.g. +8801712345678 or +14155552671
      if (raw.startsWith('+')) {
        candidates.add(raw);
        candidates.add(raw.substring(1)); // 8801712345678
      } else {
        // If raw starts with leading '0', e.g. 01712345678
        String withoutLeadingZero = raw;
        if (raw.startsWith('0')) {
          withoutLeadingZero = raw.substring(1);
          candidates.add(raw); // 01712345678
        }

        // Selected country code combinations
        final String cc = countryCode.trim();
        final String ccDigits = cc.replaceAll('+', '');

        candidates.add('$cc$withoutLeadingZero'); // +8801712345678
        candidates.add('$ccDigits$withoutLeadingZero'); // 8801712345678
        
        // If raw looks like a full international number typed without '+' e.g. 8801712345678 or 14155552671
        if (raw.length >= 10) {
          candidates.add('+$raw'); // +8801712345678
          candidates.add(raw);    // 8801712345678
        }
      }

      // De-duplicate candidates
      final uniqueCandidates = candidates.toSet().toList();

      // Query Firestore Users collection
      for (int i = 0; i < uniqueCandidates.length; i += 30) {
        final chunk = uniqueCandidates.sublist(
            i, i + 30 > uniqueCandidates.length ? uniqueCandidates.length : i + 30);
        final query = await _firestore
            .collection('Users')
            .where('number', whereIn: chunk)
            .get();
        if (query.docs.isNotEmpty) {
          return User.fromMap(query.docs.first.data());
        }
      }

      return null;
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return null;
    }
  }

  static Future<User?> searchContactForName(String name) async {
   // final User currentUser = AuthController.instance.currentUser;
    try {
      final query = await _firestore
          .collection('Users')
          // .collection('Users/${currentUser.userId}/Contacts')

          .where('fullname', isGreaterThanOrEqualTo: name)
          //.limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return User.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return null;
    }
  }

  // Get contacts list
  static Stream<List<User>> getContacts() {
    String currentUserId = AuthController.instance.currentUser.userId;
    if (currentUserId.isEmpty) {
      currentUserId = AuthController.instance.firebaseUser?.uid ?? '';
    }

    if (currentUserId.isEmpty) {
      return AuthController.instance.currentUserStream.asyncExpand((user) {
        if (user != null && user.userId.isNotEmpty) {
          return _getContactsStream(user.userId);
        }
        return Stream.value(<User>[]);
      });
    }

    return _getContactsStream(currentUserId);
  }

  static Stream<List<User>> _getContactsStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(<User>[]);

    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('Contacts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((event) async {
      List<User> users = [];
      debugPrint('--- [Diagnostic] getContacts(): Fetched ${event.docs.length} docs from Users/$userId/Contacts ---');
      for (var doc in event.docs) {
        try {
          final User? user = await UserApi.getUser(doc.id);
          debugPrint('[Diagnostic] Contact doc.id: ${doc.id} -> User found in database: ${user != null}');
          if (user != null) {
            users.add(user);
          }
        } catch (e) {
          debugPrint('Error mapping contact doc ${doc.id}: $e');
        }
      }
      return users;
    });
  }

  // Check if a user is in contacts
  static Future<bool> isContact(String targetUserId) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      final String myId = currentUser.userId.isNotEmpty
          ? currentUser.userId
          : (AuthController.instance.firebaseUser?.uid ?? '');
      if (myId.isEmpty || targetUserId.isEmpty) return false;
      if (myId == targetUserId) return true;

      final doc = await _firestore
          .collection('Users')
          .doc(myId)
          .collection('Contacts')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Delete contact from the list
  static Future<void> deleteContact(String userId) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      final String myId = currentUser.userId.isNotEmpty
          ? currentUser.userId
          : (AuthController.instance.firebaseUser?.uid ?? '');
      if (myId.isEmpty || userId.isEmpty) return;

      await _firestore
          .collection('Users')
          .doc(myId)
          .collection('Contacts')
          .doc(userId)
          .delete();
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, "delete_contact_success".tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error,
          "delete_contact_error".trParams({'error': e.toString()}));
    }
  }
}
