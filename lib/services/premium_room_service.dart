import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/premium_room_id_model.dart';

class PremiumRoomService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to prevent continuous hits
  final Map<String, Rxn<PremiumRoomIdModel>> _roomIds = {};

  // Get real-time stream of a room's premium ID
  Rxn<PremiumRoomIdModel> streamRoomId(String originalRoomId) {
    if (!_roomIds.containsKey(originalRoomId)) {
      _roomIds[originalRoomId] = Rxn<PremiumRoomIdModel>();
      
      _firestore
          .collection('premium_room_ids')
          .doc(originalRoomId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final model = PremiumRoomIdModel.fromMap(snapshot.data()!, snapshot.id);
          // Auto-revert if expired
          if (model.isExpired) {
            _roomIds[originalRoomId]!.value = null;
          } else {
            _roomIds[originalRoomId]!.value = model;
          }
        } else {
          _roomIds[originalRoomId]!.value = null;
        }
      });
    }
    return _roomIds[originalRoomId]!;
  }

  /// Returns the short/custom display ID if one exists and is not expired,
  /// otherwise returns the original room ID.
  /// This is reactive — wrap calls in Obx() for real-time updates.
  String getDisplayId(String originalRoomId) {
    final rxModel = streamRoomId(originalRoomId);
    final model = rxModel.value;
    if (model != null && model.customId.isNotEmpty && !model.isExpired) {
      return model.customId;
    }
    return originalRoomId;
  }

  /// Look up a room by either its full Firestore ID or its short custom ID.
  /// Returns the original Firestore room ID, or null if not found.
  Future<String?> resolveRoomId(String query) async {
    // 1. Check if the query matches a full room ID directly
    final directDoc = await _firestore
        .collection('audio_rooms_v2')
        .doc(query)
        .get();
    if (directDoc.exists) {
      return query;
    }

    // 2. Check if the query matches a custom/short premium room ID
    final premiumQuery = await _firestore
        .collection('premium_room_ids')
        .where('customId', isEqualTo: query)
        .limit(1)
        .get();
    if (premiumQuery.docs.isNotEmpty) {
      // The document ID in premium_room_ids IS the original room ID
      return premiumQuery.docs.first.id;
    }

    return null;
  }
}
