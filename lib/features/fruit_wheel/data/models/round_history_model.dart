import 'package:equatable/equatable.dart';

class RoundHistoryModel extends Equatable {
  final int roundNumber;
  final String result;
  final int timestamp;

  const RoundHistoryModel({
    required this.roundNumber,
    required this.result,
    required this.timestamp,
  });

  factory RoundHistoryModel.fromRtdb(Map<dynamic, dynamic> json) {
    return RoundHistoryModel(
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 0,
      result: json['result'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [roundNumber, result, timestamp];
}
