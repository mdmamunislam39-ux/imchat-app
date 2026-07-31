import '../../data/models/round_state_model.dart';
import '../../data/models/round_history_model.dart';
import '../../data/models/user_bet_history_model.dart';

abstract class FruitWheelRepository {
  /// Stream of current round state from Realtime DB.
  Stream<RoundStateModel?> watchCurrentRound();

  /// Place a bet by calling the Cloud Function.
  Future<Map<String, dynamic>> placeBet({
    required String symbol,
    required int amount,
  });

  /// Tick the game loop (advance phase if expired).
  Future<Map<String, dynamic>> tickGame();

  /// Get last N round history entries.
  Future<List<RoundHistoryModel>> getHistory({int limit = 10});

  /// Stream of round history from Realtime DB.
  Stream<List<RoundHistoryModel>> watchHistory({int limit = 10});


  /// Get user's bet history from Firestore, ordered by most recent.
  Future<List<UserBetHistoryModel>> getUserBetHistory({int limit = 20});
}
