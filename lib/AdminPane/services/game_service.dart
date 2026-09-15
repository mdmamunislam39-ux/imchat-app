import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

class GameService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'games';

  // Get stream of all games
  static Stream<List<GameModel>> getGamesStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => GameModel.fromFirestore(doc)).toList();
    });
  }

  // Create a new game
  static Future<void> createGame(GameModel game) async {
    try {
      await _firestore.collection(_collectionName).add({
        ...game.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating game: $e');
      rethrow;
    }
  }

  // Update an existing game
  static Future<void> updateGame(GameModel game) async {
    try {
      await _firestore.collection(_collectionName).doc(game.id).update({
        ...game.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating game: $e');
      rethrow;
    }
  }

  // Delete a game
  static Future<void> deleteGame(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting game: $e');
      rethrow;
    }
  }

  // Toggle game active status
  static Future<void> toggleGameStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'isActive': isActive,
        'isEnabled': isActive,
        'status': isActive ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also sync with config if built-in system game
      if (id == 'greedy_game' || id == 'greedycat') {
        try {
          await _firestore.collection('config').doc('greedy_game').set({
            'isActive': isActive,
            'isEnabled': isActive,
            'status': isActive ? 'active' : 'inactive',
          }, SetOptions(merge: true));
        } catch (_) {}
      } else if (id == 'fruit_wheel' || id == 'eliminateslot') {
        try {
          await _firestore.collection('config').doc('fruit_wheel').set({
            'isActive': isActive,
            'isEnabled': isActive,
            'status': isActive ? 'active' : 'inactive',
          }, SetOptions(merge: true));
        } catch (_) {}
      } else if (id == 'pink_greedy_game' || id == 'pink_greedy' || id == 'pinkgreedy') {
        try {
          await _firestore.collection('config').doc('pink_greedy_game').set({
            'isActive': isActive,
            'isEnabled': isActive,
            'status': isActive ? 'active' : 'inactive',
          }, SetOptions(merge: true));
        } catch (_) {}
      } else if (id == 'food_spin_game' || id == 'food_spin' || id == 'foodspin') {
        try {
          await _firestore.collection('config').doc('food_spin_game').set({
            'isActive': isActive,
            'isEnabled': isActive,
            'status': isActive ? 'active' : 'inactive',
          }, SetOptions(merge: true));
        } catch (_) {}
      } else if (id == 'html5_greedy_market' || id == 'html5_greedy_game') {
        try {
          await _firestore.collection('config').doc('html5_greedy_game').set({
            'isActive': isActive,
            'isEnabled': isActive,
            'status': isActive ? 'active' : 'inactive',
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error toggling game status: $e');
      rethrow;
    }
  }
}
