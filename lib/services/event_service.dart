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

  // Get single event by ID
  static Future<EventModel?> getEventByEventId(String eventId) async {
    try {
      final query = await _firestore
          .collection('events')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return EventModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
