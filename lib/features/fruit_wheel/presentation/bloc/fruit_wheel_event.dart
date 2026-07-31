import 'package:equatable/equatable.dart';

import '../../data/models/round_history_model.dart';
import '../../data/models/round_state_model.dart';

abstract class FruitWheelEvent extends Equatable {
  const FruitWheelEvent();

  @override
  List<Object?> get props => [];
}

/// Connect to the game — start listening to RTDB streams.
class ConnectToGame extends FruitWheelEvent {}

/// Disconnect from the game — cancel streams.
class DisconnectFromGame extends FruitWheelEvent {}

/// Place a bet on a symbol.
class PlaceBet extends FruitWheelEvent {
  final String symbol;
  final int amount;

  const PlaceBet({required this.symbol, required this.amount});

  @override
  List<Object?> get props => [symbol, amount];
}

/// Repeat the last bet from the previous round.
class RepeatLastBet extends FruitWheelEvent {}

/// Select the chip amount for betting.
class SelectChipAmount extends FruitWheelEvent {
  final int amount;

  const SelectChipAmount(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Internal: round state updated from RTDB stream.
class RoundStateUpdated extends FruitWheelEvent {
  final RoundStateModel? roundState;

  const RoundStateUpdated(this.roundState);

  @override
  List<Object?> get props => [roundState];
}

/// Internal: history updated from RTDB stream.
class HistoryUpdated extends FruitWheelEvent {
  final List<RoundHistoryModel> history;

  const HistoryUpdated(this.history);

  @override
  List<Object?> get props => [history];
}

/// Tick the game (call Cloud Function to advance phase if needed).
class TickGame extends FruitWheelEvent {}

