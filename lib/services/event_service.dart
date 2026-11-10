import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream active events
  static Stream<List<EventModel>> getActiveEventsStream() {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .where((event) =>
              event.startTime.isBefore(now) && event.endTime.isAfter(now))
          .toList();
    });
  }

  // Get single event by ID, customSlug, or doc ID
  static Future<EventModel?> getEventByEventId(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) return null;

    try {
      // 1. Search by customSlug
      final slugQuery = await _firestore
          .collection('events')
          .where('customSlug', isEqualTo: cleanId)
          .limit(1)
          .get();
      if (slugQuery.docs.isNotEmpty) {
        return EventModel.fromMap(slugQuery.docs.first.data(), slugQuery.docs.first.id);
      }

      // 2. Search by eventId
      final eventIdQuery = await _firestore
          .collection('events')
          .where('eventId', isEqualTo: cleanId)
          .limit(1)
          .get();
      if (eventIdQuery.docs.isNotEmpty) {
        return EventModel.fromMap(eventIdQuery.docs.first.data(), eventIdQuery.docs.first.id);
      }

      // 3. Search directly by Firestore doc ID
      final docSnap = await _firestore.collection('events').doc(cleanId).get();
      if (docSnap.exists && docSnap.data() != null) {
        return EventModel.fromMap(docSnap.data()!, docSnap.id);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
