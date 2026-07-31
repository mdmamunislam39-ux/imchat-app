import 'package:equatable/equatable.dart';

enum RouletteStatus { idle, spinning, ended }

class RouletteState extends Equatable {
  final String id;
  final List<String> options;
  final RouletteStatus status;
  final int resultIndex;
  final int startTime;

  const RouletteState({
    required this.id,
    this.options = const [],
    this.status = RouletteStatus.idle,
    this.resultIndex = -1,
    this.startTime = 0,
  });

  factory RouletteState.fromJson(Map<String, dynamic> json) {
    return RouletteState(
      id: json['id'] as String? ?? '',
      options: List<String>.from(json['options'] ?? []),
      status: RouletteStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RouletteStatus.idle,
      ),
      resultIndex: json['resultIndex'] as int? ?? -1,
      startTime: json['startTime'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'options': options,
      'status': status.name,
      'resultIndex': resultIndex,
      'startTime': startTime,
    };
  }

  RouletteState copyWith({
    String? id,
    List<String>? options,
    RouletteStatus? status,
    int? resultIndex,
    int? startTime,
  }) {
    return RouletteState(
      id: id ?? this.id,
      options: options ?? this.options,
      status: status ?? this.status,
      resultIndex: resultIndex ?? this.resultIndex,
      startTime: startTime ?? this.startTime,
    );
  }

  bool get isActive => (status == RouletteStatus.spinning || status == RouletteStatus.ended) && options.isNotEmpty;

  @override
  List<Object?> get props => [id, options, status, resultIndex, startTime];
}
