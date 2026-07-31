import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_path.dart';

class LudoController extends GetxController {
  final String roomId;
  final String currentUserId;
  final bool isHost;
  
  LudoController(this.roomId, this.currentUserId, {this.isHost = false});

  final Rx<LudoGameState> gameState = LudoGameState.initial().obs;
  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _turnTimer;

  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;

  @override
  void onInit() {
    super.onInit();
    _initSync();
  }

  void _initSync() {
    final docRef = _realtimeDb.ref('rooms/$roomId/ludo/state');
    
    _sub = docRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        // Realtime Database stores maps as dynamic, we need to cast or parse properly.
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        gameState.value = LudoGameState.fromJson(map);
        _handleTimer();
      } else {
        _syncState(gameState.value);
      }
    });
  }

  void _handleTimer() {
    _turnTimer?.cancel();
    if (gameState.value.winner != null) return;
    
    final int turnStartTime = gameState.value.lastTurnStartTime;
    final int elapsed = DateTime.now().millisecondsSinceEpoch - turnStartTime;
    final int remaining = 30000 - elapsed;

    if (remaining <= 0) {
      _checkAndSkipTurn(turnStartTime);
    } else {
      _turnTimer = Timer(Duration(milliseconds: remaining), () {
        _checkAndSkipTurn(turnStartTime);
      });
    }
  }

  void _checkAndSkipTurn(int turnStartTime) {
    if (gameState.value.lastTurnStartTime != turnStartTime) return;
    if (gameState.value.winner != null) return;

    // To prevent all clients writing at the same time:
    // 1. The player whose turn it is should skip themselves immediately.
    // 2. If they are offline, the host waits an extra 2 seconds and skips them.
    final bool isMyTurn = gameState.value.players[gameState.value.currentTurn] == currentUserId;
    final int elapsed = DateTime.now().millisecondsSinceEpoch - turnStartTime;

    if (isMyTurn) {
      _skipTurn();
    } else if (isHost && elapsed > 32000) {
      _skipTurn();
    }
  }

  void _skipTurn() {
    final nextTurn = _getNextTurn(gameState.value.currentTurn);
    final newState = gameState.value.copyWith(
      currentTurn: nextTurn,
      isDiceRolled: false,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
    );
    _syncState(newState);
  }

  Future<void> joinGame(String userId, LudoColor color) async {
    final Map<LudoColor, String?> newPlayers = Map.from(gameState.value.players);
    newPlayers[color] = userId;
    
    final newState = gameState.value.copyWith(players: newPlayers);
    await _syncState(newState);
  }

  Future<void> _syncState(LudoGameState newState) async {
    try {
      await _realtimeDb
          .ref('rooms/$roomId/ludo/state')
          .set(newState.toJson());
    } catch (e) {
      debugPrint('Error syncing Ludo state: $e');
    }
  }

  List<LudoColor> get _activeColors {
    if (gameState.value.maxPlayers == 2) {
      return [LudoColor.red, LudoColor.yellow];
    }
    return [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue];
  }

  LudoColor _getNextTurn(LudoColor currentTurn) {
    final colors = _activeColors;
    final idx = colors.indexOf(currentTurn);
    if (idx == -1) return colors.first;
    return colors[(idx + 1) % colors.length];
  }

  void rollDice(String userId) {
    if (gameState.value.isDiceRolled) return;
    
    // Validate turn (optional depending on strictness)
    if (gameState.value.players[gameState.value.currentTurn] != userId) {
      return; 
    }

    final dice = Random().nextInt(6) + 1;
    
    final validTokens = _getValidMoves(gameState.value.currentTurn, dice);
    
    if (validTokens.isEmpty) {
      // Auto switch turn if no moves possible
      final nextTurn = _getNextTurn(gameState.value.currentTurn);
      final newState = gameState.value.copyWith(
        diceValue: dice,
        isDiceRolled: false,
        currentTurn: nextTurn,
        lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
      );
      _syncState(newState);
    } else {
      final newState = gameState.value.copyWith(
        diceValue: dice,
        isDiceRolled: true,
      );
      _syncState(newState).then((_) {
        // Auto move if there's exactly 1 valid option
        if (validTokens.length == 1) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (gameState.value.isDiceRolled && 
                gameState.value.currentTurn == newState.currentTurn &&
                gameState.value.diceValue == dice) {
              moveToken(userId, validTokens.first);
            }
          });
        }
      });
    }
  }

  List<LudoToken> _getValidMoves(LudoColor color, int dice) {
    final myTokens = gameState.value.tokens.where((t) => t.color == color).toList();
    final validTokens = <LudoToken>[];
    for (var t in myTokens) {
      if (t.position == -1 && dice == 6) validTokens.add(t);
      else if (t.position >= 0 && t.position + dice <= 57) validTokens.add(t);
    }
    return validTokens;
  }

  void moveToken(String userId, LudoToken token) {
    if (!gameState.value.isDiceRolled) return;
    
    // Validate turn
    if (gameState.value.players[gameState.value.currentTurn] != userId) return;
    if (token.color != gameState.value.currentTurn) return;

    int newPos = token.position;
    int dice = gameState.value.diceValue;

    if (token.position == -1) {
      if (dice == 6) {
        newPos = 0;
      } else {
        return; // Invalid
      }
    } else {
      newPos += dice;
      if (newPos > 57) return; // Invalid
    }

    List<LudoToken> updatedTokens = List.from(gameState.value.tokens);
    bool gotKill = false;

    // Check for kill
    if (newPos <= 51) {
      final int myGlobalIdx = (LudoPath.startIndices[token.color]! + newPos) % 52;
      final Offset myBoardPos = LudoPath.mainPath[myGlobalIdx];
      
      if (!LudoPath.safeZones.contains(myBoardPos)) {
        // Not a safe zone, check for kills
        for (int i = 0; i < updatedTokens.length; i++) {
          final oppToken = updatedTokens[i];
          if (oppToken.color != token.color && oppToken.position >= 0 && oppToken.position <= 51) {
            final oppGlobalIdx = (LudoPath.startIndices[oppToken.color]! + oppToken.position) % 52;
            if (oppGlobalIdx == myGlobalIdx) {
              // Kill!
              updatedTokens[i] = oppToken.copyWith(position: -1);
              gotKill = true;
            }
          }
        }
      }
    }

    // Update my token
    int index = updatedTokens.indexWhere((t) => t.id == token.id);
    if (index != -1) {
      updatedTokens[index] = token.copyWith(position: newPos);
    }

    // Turn logic
    LudoColor nextTurn = gameState.value.currentTurn;
    bool keepTurn = (dice == 6) || gotKill || (newPos == 57);
    
    if (!keepTurn) {
      nextTurn = _getNextTurn(gameState.value.currentTurn);
    }

    // Check for win
    String? winner = gameState.value.winner;
    final myTokens = updatedTokens.where((t) => t.color == token.color).toList();
    if (myTokens.every((t) => t.position == 57)) {
      winner = token.color.name;
    }

    final newState = gameState.value.copyWith(
      tokens: updatedTokens,
      isDiceRolled: false,
      currentTurn: nextTurn,
      winner: winner,
      lastTurnStartTime: keepTurn ? gameState.value.lastTurnStartTime : DateTime.now().millisecondsSinceEpoch,
    );

    _syncState(newState);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
