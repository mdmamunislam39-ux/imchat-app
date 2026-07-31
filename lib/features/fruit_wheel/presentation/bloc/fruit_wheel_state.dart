import 'package:equatable/equatable.dart';

import '../../data/models/round_history_model.dart';
import '../../data/models/round_state_model.dart';

abstract class FruitWheelState extends Equatable {
  final int selectedChipAmount;
  final Map<String, int> lastBets; // bets from previous round for "repeat"
  const FruitWheelState({
    this.selectedChipAmount = 500,
    this.lastBets = const {},
  });

  @override
  List<Object?> get props => [selectedChipAmount, lastBets];
}

class FruitWheelInitial extends FruitWheelState {}

class FruitWheelLoading extends FruitWheelState {}

class FruitWheelActive extends FruitWheelState {
  final RoundStateModel roundState;
  final List<RoundHistoryModel> history;
  final bool isBetting; // true while a bet request is in-flight

  const FruitWheelActive({
    required this.roundState,
    this.history = const [],
    this.isBetting = false,
    super.selectedChipAmount,
    super.lastBets,
  });

  FruitWheelActive copyWith({
    RoundStateModel? roundState,
    List<RoundHistoryModel>? history,
    bool? isBetting,
    int? selectedChipAmount,
    Map<String, int>? lastBets,
  }) {
    return FruitWheelActive(
      roundState: roundState ?? this.roundState,
      history: history ?? this.history,
      isBetting: isBetting ?? this.isBetting,
      selectedChipAmount: selectedChipAmount ?? this.selectedChipAmount,
      lastBets: lastBets ?? this.lastBets,
    );
  }

  @override
  List<Object?> get props => [
        roundState,
        history,
        isBetting,
        selectedChipAmount,
        lastBets,
      ];
}

class FruitWheelError extends FruitWheelState {
  final String message;
  final FruitWheelActive? previousState;

  const FruitWheelError(this.message, {this.previousState});

  @override
  List<Object?> get props => [message, previousState];
}
