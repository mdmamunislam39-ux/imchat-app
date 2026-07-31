import 'package:equatable/equatable.dart';

class VotingState extends Equatable {
  final String id;
  final String question;
  final List<String> options;
  // Map of userId -> optionIndex
  final Map<String, int> votes;
  final int startTime;
  final int durationSeconds;
  final bool isActive;

  const VotingState({
    required this.id,
    this.question = '',
    this.options = const [],
    this.votes = const {},
    this.startTime = 0,
    this.durationSeconds = 60,
    this.isActive = false,
  });

  factory VotingState.fromJson(Map<String, dynamic> json) {
    return VotingState(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      votes: (json['votes'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          {},
      startTime: (json['startTime'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 60,
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'votes': votes,
      'startTime': startTime,
      'durationSeconds': durationSeconds,
      'isActive': isActive,
    };
  }

  VotingState copyWith({
    String? id,
    String? question,
    List<String>? options,
    Map<String, int>? votes,
    int? startTime,
    int? durationSeconds,
    bool? isActive,
  }) {
    return VotingState(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isActive: isActive ?? this.isActive,
    );
  }

  int get totalVotes => votes.length;

  int getVotesForOption(int optionIndex) {
    return votes.values.where((v) => v == optionIndex).length;
  }

  double getPercentageForOption(int optionIndex) {
    if (totalVotes == 0) return 0.0;
    return getVotesForOption(optionIndex) / totalVotes;
  }

  @override
  List<Object?> get props => [id, question, options, votes, startTime, durationSeconds, isActive];
}
