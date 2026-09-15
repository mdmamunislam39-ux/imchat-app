import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

class ContactController extends GetxController {
  // Get the current instance
  static ContactController get instance => Get.find<ContactController>();

  RxBool isLoading = RxBool(true);
  RxList<User> contacts = RxList();
  RxInt pendingRequestsCount = 0.obs;
  RxBool sortByOnline = true.obs;

  StreamSubscription<List<User>>? _stream;
  StreamSubscription<QuerySnapshot>? _requestsStream;

  @override
  void onInit() {
    _getContacts();
    _listenToPendingRequests();
    super.onInit();
  }

  @override
  void dispose() {
    _stream?.cancel();
    _requestsStream?.cancel();
    super.dispose();
  }

  void _getContacts() {
    _stream = ContactApi.getContacts().listen((event) {
      contacts.value = event;
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }

  void _listenToPendingRequests() {
    try {
      final User currentUser = AuthController.instance.currentUser;
      if (currentUser.userId.isNotEmpty) {
        _requestsStream = FirebaseFirestore.instance
            .collection('Users')
            .doc(currentUser.userId)
            .collection('friend_requests')
            .snapshots()
            .listen((snapshot) {
          pendingRequestsCount.value = snapshot.docs.length;
        }, onError: (e) => debugPrint('Error listening to friend requests: $e'));
      }
    } catch (e) {
      debugPrint('Error initiating friend requests stream: $e');
    }
  }

  void toggleSort() {
    sortByOnline.toggle();
  }

  List<User> get sortedContacts {
    final list = List<User>.from(contacts);
    if (sortByOnline.value) {
      list.sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.fullname.toLowerCase().compareTo(b.fullname.toLowerCase());
      });
    } else {
      list.sort((a, b) => a.fullname.toLowerCase().compareTo(b.fullname.toLowerCase()));
    }
    return list;
  }

  Future<void> deleteContact(User contact) async {
    final String title = 'delete_contact_from_your_contact_list'.trParams({
      'contactName': contact.fullname,
    });

    DialogHelper.showAlertDialog(
      barrierDismissible: false,
      titleColor: errorColor,
      title: Text('delete_this_contact'.tr),
      icon: const Icon(IconlyLight.delete, color: errorColor),
      content: Text('$title ${'this_action_cannot_be_reversed'.tr}'),
      actionText: 'DELETE'.tr,
      action: () {
        Get.back();
        ContactApi.deleteContact(contact.userId);
      },
    );
  }
}
