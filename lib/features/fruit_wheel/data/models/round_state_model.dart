import 'package:equatable/equatable.dart';

class WinnerEntry extends Equatable {
  final String userId;
  final String name;
  final String photo;
  final int payout;

  const WinnerEntry({
    required this.userId,
    required this.name,
    required this.photo,
    required this.payout,
  });

  @override
  List<Object?> get props => [userId, name, photo, payout];
}

class RoundStateModel extends Equatable {
  final int roundNumber;
  final String phase; // "betting", "spinning", "result", "cooldown"
  final int phaseEndTime; // milliseconds since epoch
  final String? result; // "watermelon", "plum", "sevens"
  final Map<String, int> totalBets; // { watermelon: 500, plum: 200, sevens: 100 }
  final Map<String, int> userBets; // current user's bets { watermelon: 100 }
  final List<WinnerEntry> winners;

  const RoundStateModel({
    required this.roundNumber,
    required this.phase,
    required this.phaseEndTime,
    this.result,
    this.totalBets = const {},
    this.userBets = const {},
    this.winners = const [],
  });

  factory RoundStateModel.fromRtdb(Map<dynamic, dynamic> json, String? currentUserId) {
    // Parse total bets
    final totalBetsRaw = json['totalBets'] as Map<dynamic, dynamic>? ?? {};
    final totalBets = totalBetsRaw.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );

    // Parse current user's bets
    Map<String, int> userBets = {};
    if (currentUserId != null && json['bets'] != null) {
      final betsMap = json['bets'] as Map<dynamic, dynamic>;
      if (betsMap.containsKey(currentUserId)) {
        final userBetsRaw = betsMap[currentUserId] as Map<dynamic, dynamic>;
        userBets = userBetsRaw.map(
          (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
        );
      }
    }

    // Parse winners: { userId: { payout: int, name: string } }
    final winnersRaw = json['winners'] as Map<dynamic, dynamic>? ?? {};
    final winners = <WinnerEntry>[];
    for (final entry in winnersRaw.entries) {
      final uid = entry.key.toString();
      final val = entry.value;
      if (val is Map) {
        winners.add(WinnerEntry(
          userId: uid,
          name: (val['name'] as String?) ?? 'Player',
          photo: (val['photo'] as String?) ?? '',
          payout: (val['payout'] as num?)?.toInt() ?? 0,
        ));
      } else {
        // Backwards compatibility: old format { userId: payoutAmount }
        winners.add(WinnerEntry(
          userId: uid,
          name: 'Player',
          photo: '',
          payout: (val as num?)?.toInt() ?? 0,
        ));
      }
    }
    // Sort by payout descending
    winners.sort((a, b) => b.payout.compareTo(a.payout));

    return RoundStateModel(
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      phase: json['phase'] as String? ?? 'betting',
      phaseEndTime: (json['phaseEndTime'] as num?)?.toInt() ?? 0,
      result: json['result'] as String?,
      totalBets: totalBets,
      userBets: userBets,
      winners: winners,
    );
  }

  int get remainingMs {
    final remaining = phaseEndTime - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  bool get isBettingOpen => phase == 'betting' && remainingMs > 0;

  int get userTotalBet => userBets.values.fold(0, (sum, v) => sum + v);

  @override
  List<Object?> get props => [
        roundNumber,
        phase,
        phaseEndTime,
        result,
        totalBets,
        userBets,
        winners,
      ];
}
