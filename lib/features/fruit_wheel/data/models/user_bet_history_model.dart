import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserBetHistoryModel extends Equatable {
  final int roundNumber;
  final Map<String, int> bets;
  final String result;
  final int payout;
  final int totalBet;
  final int timestamp;

  const UserBetHistoryModel({
    required this.roundNumber,
    required this.bets,
    required this.result,
    required this.payout,
    required this.totalBet,
    required this.timestamp,
  });

  factory UserBetHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final betsRaw = data['bets'] as Map<String, dynamic>? ?? {};
    final bets = betsRaw.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
    return UserBetHistoryModel(
      roundNumber: (data['roundNumber'] as num?)?.toInt() ?? 0,
      bets: bets,
      result: data['result'] as String? ?? '',
      payout: (data['payout'] as num?)?.toInt() ?? 0,
      totalBet: (data['totalBet'] as num?)?.toInt() ?? 0,
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  int get netResult => payout - totalBet;

  @override
  List<Object?> get props => [roundNumber, bets, result, payout, totalBet, timestamp];
}
