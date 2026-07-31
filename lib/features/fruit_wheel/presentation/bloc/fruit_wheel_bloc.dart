import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/round_state_model.dart';
import '../../domain/repositories/fruit_wheel_repository.dart';
import 'fruit_wheel_event.dart';
import 'fruit_wheel_state.dart';

class FruitWheelBloc extends Bloc<FruitWheelEvent, FruitWheelState> {
  final FruitWheelRepository _repository;

  StreamSubscription? _roundSubscription;
  StreamSubscription? _historySubscription;
  Timer? _tickTimer;

  // Debounce: track last bet time to prevent rapid taps
  DateTime? _lastBetTime;
  static const _betDebounce = Duration(milliseconds: 200);

  FruitWheelBloc({
    required FruitWheelRepository repository,
  })  : _repository = repository,
        super(FruitWheelInitial()) {
    on<ConnectToGame>(_onConnectToGame);
    on<DisconnectFromGame>(_onDisconnectFromGame);
    on<RoundStateUpdated>(_onRoundStateUpdated);
    on<HistoryUpdated>(_onHistoryUpdated);
    on<PlaceBet>(_onPlaceBet);
    on<RepeatLastBet>(_onRepeatLastBet);
    on<SelectChipAmount>(_onSelectChipAmount);
    on<TickGame>(_onTickGame);
  }

  Future<void> _onConnectToGame(
    ConnectToGame event,
    Emitter<FruitWheelState> emit,
  ) async {
    emit(FruitWheelLoading());

    // First tick to make sure the game is running
    try {
      await _repository.tickGame();
    } catch (_) {
      // Ignore — game may already be running
    }

    // Listen to round state
    _roundSubscription?.cancel();
    _roundSubscription = _repository.watchCurrentRound().listen(
      (roundState) => add(RoundStateUpdated(roundState)),
    );

    // Listen to history
    _historySubscription?.cancel();
    _historySubscription = _repository.watchHistory().listen(
      (history) => add(HistoryUpdated(history)),
    );

    // Periodic tick to advance game phases
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      add(TickGame());
    });
  }

  void _onDisconnectFromGame(
    DisconnectFromGame event,
    Emitter<FruitWheelState> emit,
  ) {
    _roundSubscription?.cancel();
    _historySubscription?.cancel();
    _tickTimer?.cancel();
    _roundSubscription = null;
    _historySubscription = null;
    _tickTimer = null;
  }

  void _onRoundStateUpdated(
    RoundStateUpdated event,
    Emitter<FruitWheelState> emit,
  ) {
    final roundState = event.roundState;
    if (roundState == null) return;

    debugPrint('🎰 WHEEL DEBUG: Round ${roundState.roundNumber} | Phase: ${roundState.phase} | Result: ${roundState.result} | TotalBets: ${roundState.totalBets} | UserBets: ${roundState.userBets}');

    final currentState = state;

    Map<String, int> lastBets = {};
    int selectedChip = 500;

    if (currentState is FruitWheelActive) {
      selectedChip = currentState.selectedChipAmount;

      // If round number changed, save previous round's bets as lastBets
      if (currentState.roundState.roundNumber != roundState.roundNumber &&
          currentState.roundState.userBets.isNotEmpty) {
        lastBets = currentState.roundState.userBets;
      } else {
        lastBets = currentState.lastBets;
      }

      emit(currentState.copyWith(
        roundState: roundState,
        lastBets: lastBets,
        selectedChipAmount: selectedChip,
      ));
    } else {
      emit(FruitWheelActive(
        roundState: roundState,
        selectedChipAmount: selectedChip,
        lastBets: lastBets,
      ));
    }
  }

  void _onHistoryUpdated(
    HistoryUpdated event,
    Emitter<FruitWheelState> emit,
  ) {
    final currentState = state;
    if (currentState is FruitWheelActive) {
      emit(currentState.copyWith(history: event.history));
    }
  }

  Future<void> _onPlaceBet(
    PlaceBet event,
    Emitter<FruitWheelState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FruitWheelActive) return;
    if (!currentState.roundState.isBettingOpen) return;

    // Debounce rapid taps (200ms for snappy feel)
    final now = DateTime.now();
    if (_lastBetTime != null && now.difference(_lastBetTime!) < _betDebounce) {
      return;
    }
    _lastBetTime = now;

    // Remove client-side balance check (will let the server fail if insufficient,
    // though the UI typically hides the button anyway if they don't have enough)

    // Max 2 symbols per round — block betting on a 3rd symbol
    final bettedSymbols = currentState.roundState.userBets.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();
    // Can't bet on both watermelon and plum — only one fruit + sevens allowed
    final hasFruit = bettedSymbols.contains('watermelon') || bettedSymbols.contains('plum');
    final isBettingFruit = event.symbol == 'watermelon' || event.symbol == 'plum';
    if (isBettingFruit && hasFruit && !bettedSymbols.contains(event.symbol)) {
      emit(FruitWheelError(
        'You can only pick one fruit! Combine it with 77.',
        previousState: currentState,
      ));
      emit(currentState);
      return;
    }

    final updatedUserBets = Map<String, int>.from(currentState.roundState.userBets);
    updatedUserBets[event.symbol] = (updatedUserBets[event.symbol] ?? 0) + event.amount;

    final updatedTotalBets = Map<String, int>.from(currentState.roundState.totalBets);
    updatedTotalBets[event.symbol] = (updatedTotalBets[event.symbol] ?? 0) + event.amount;

    final optimisticRound = RoundStateModel(
      roundNumber: currentState.roundState.roundNumber,
      phase: currentState.roundState.phase,
      phaseEndTime: currentState.roundState.phaseEndTime,
      result: currentState.roundState.result,
      totalBets: updatedTotalBets,
      userBets: updatedUserBets,
      winners: currentState.roundState.winners,
    );

    emit(currentState.copyWith(
      roundState: optimisticRound,
    ));

    // Fire-and-forget — server call in background, RTDB stream will reconcile
    () async {
      try {
        debugPrint('🎰 WHEEL DEBUG: Placing bet - symbol=${event.symbol}, amount=${event.amount}');
        final betResult = await _repository.placeBet(
          symbol: event.symbol,
          amount: event.amount,
        );
        debugPrint('🎰 WHEEL DEBUG: Bet result = $betResult');
      } catch (e) {
        debugPrint('🎰 WHEEL DEBUG: Bet error = $e');
        // Let RTDB stream fix the state on error
      }
    }();
  }

  Future<void> _onRepeatLastBet(
    RepeatLastBet event,
    Emitter<FruitWheelState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FruitWheelActive) return;
    if (!currentState.roundState.isBettingOpen) return;
    if (currentState.lastBets.isEmpty) return;

    for (final entry in currentState.lastBets.entries) {
      if (entry.value > 0) {
        add(PlaceBet(symbol: entry.key, amount: entry.value));
      }
    }
  }

  void _onSelectChipAmount(
    SelectChipAmount event,
    Emitter<FruitWheelState> emit,
  ) {
    final currentState = state;
    if (currentState is FruitWheelActive) {
      emit(currentState.copyWith(selectedChipAmount: event.amount));
    }
  }

  Future<void> _onTickGame(
    TickGame event,
    Emitter<FruitWheelState> emit,
  ) async {
    try {
      final tickResult = await _repository.tickGame();
      if (tickResult['status'] != 'waiting') {
        debugPrint('🎰 WHEEL DEBUG: Tick result = $tickResult');
      }
    } catch (_) {
      // Silently ignore tick errors
    }
  }

  @override
  Future<void> close() {
    _roundSubscription?.cancel();
    _historySubscription?.cancel();
    _tickTimer?.cancel();
    return super.close();
  }
}
