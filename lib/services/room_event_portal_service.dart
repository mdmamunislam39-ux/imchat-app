import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_event_portal_model.dart';

class RoomEventPortalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'room_event_portal';

  // Get only active portals for the app
  Stream<List<RoomEventPortalModel>> getActivePortals() {
    return _firestore
        .collection(_collectionPath)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RoomEventPortalModel.fromFirestore(doc))
          .toList();
          
      // Sort locally to avoid Firestore composite index requirement
      list.sort((a, b) {
        int orderCompare = a.orderIndex.compareTo(b.orderIndex);
        if (orderCompare != 0) return orderCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return list;
    });
  }
}
