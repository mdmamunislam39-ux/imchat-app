import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

void dumpGiftDocs() async {
  final snap = await FirebaseFirestore.instance.collection('gift').get();
  for (var doc in snap.docs) {
    debugPrint('DUMP GIFT [${doc.id}]: ${doc.data()}');
  }
}
