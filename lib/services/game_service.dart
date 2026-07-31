import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/game_model.dart';
import '../api/user_api.dart'; // Assume this handles user wallet
import '../controllers/auth_controller.dart';

class GameService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Real-time list of available games
  final RxList<GameModel> games = <GameModel>[].obs;

  Future<GameService> init() async {
    _firestore.collection('games').snapshots().listen((snapshot) {
      games.value = snapshot.docs
          .map((doc) => GameModel.fromMap(doc.data(), doc.id))
          .where((game) => game.isEnabled)
          .toList();
    });
    return this;
  }

  // Play Game: Deduct diamonds automatically
  Future<bool> placeBet(String gameId, int betAmount) async {
    try {
      final user = AuthController.instance.currentUser;
      if (user.diamonds < betAmount) {
        Get.snackbar('Insufficient Balance', 'You do not have enough diamonds to place this bet.');
        return false;
      }

      // Deduct bet amount from user's wallet securely
      await UserApi.updateDiamonds(user.userId, -betAmount);
      
      // Log transaction if needed
      await _logTransaction(user.userId, gameId, -betAmount, 'bet');
      return true;
    } catch (e) {
      debugPrint('Error placing bet: $e');
      return false;
    }
  }

  // Handle Win: Add diamonds automatically
  Future<void> processWin(String gameId, int winAmount) async {
    try {
      final user = AuthController.instance.currentUser;
      
      // Add win amount to user's wallet
      await UserApi.updateDiamonds(user.userId, winAmount);
      
      // Log transaction
      await _logTransaction(user.userId, gameId, winAmount, 'win');
    } catch (e) {
      debugPrint('Error processing win: $e');
    }
  }

  Future<void> _logTransaction(String userId, String gameId, int amount, String type) async {
    await _firestore.collection('game_transactions').add({
      'userId': userId,
      'gameId': gameId,
      'amount': amount,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
