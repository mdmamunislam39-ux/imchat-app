import 'dart:async';
import 'package:chat_messenger/models/channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChannelController extends GetxController {
  static ChannelController get instance => Get.find<ChannelController>();

  final RxBool isLoading = RxBool(true);
  final RxList<OfficialChannel> channels = RxList();
  StreamSubscription<QuerySnapshot>? _stream;

  @override
  void onInit() {
    _getChannels();
    super.onInit();
  }

  @override
  void onClose() {
    _stream?.cancel();
    super.onClose();
  }

  void _getChannels() {
    _stream = FirebaseFirestore.instance
        .collection('official_channels')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final List<OfficialChannel> newChannels = [];
      for (var doc in snapshot.docs) {
        newChannels.add(OfficialChannel.fromDocument(doc));
      }
      channels.value = newChannels;
      isLoading.value = false;
    }, onError: (e) => debugPrint(e.toString()));
  }
}
