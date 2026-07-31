import 'package:cloud_firestore/cloud_firestore.dart';
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
    bool showMsg = true,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      await _firestore
          .collection('Users')
          .doc(targetUserId)
          .collection('friend_requests')
          .doc(currentUser.userId)
          .set({
        'senderId': currentUser.userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(SnackMsgType.success, "Request sent successfully");
    } catch (e) {
      if (!showMsg) return;
      DialogHelper.showSnackbarMessage(
          SnackMsgType.error, "Failed to send request: ${e.toString()}");
    }
  }

  // Create new contact
  static Future<void> addContact({
    required String userId,
    bool showMsg = false,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      Future.wait([
        // Save for current user
        _firestore
            .collection('Users/${currentUser.userId}/Contacts')
            .doc(userId)
            .set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        // Save for onother user
        _firestore
            .collection('Users/$userId/Contacts')
            .doc(currentUser.userId)
            .set({
          'userId': currentUser.userId,
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

  static Future<User?> searchContactForNumber(String number) async {
    try {
      final query = await _firestore
          .collection('Users')
          .where('number', isEqualTo: number)
          // .limit(1)
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
    final User currentUser = AuthController.instance.currentUser;

    return _firestore
        .collection('Users/${currentUser.userId}/Contacts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((event) async {
      List<User> users = [];
      for (var doc in event.docs) {
        final User? user = await UserApi.getUser(doc.id);
        if (user != null) {
          users.add(user);
        }
      }
      return users;
    });
  }

  // Check if a user is in contacts
  static Future<bool> isContact(String targetUserId) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      if (currentUser.userId == targetUserId) return true;
      final doc = await _firestore
          .collection('Users/${currentUser.userId}/Contacts')
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

      await _firestore
          .collection('Users/${currentUser.userId}/Contacts')
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
