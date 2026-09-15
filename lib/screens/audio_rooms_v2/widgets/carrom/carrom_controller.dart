import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_models.dart';

class CarromController extends GetxController {
  final String roomId;
  final String currentUserId;
  final bool isHost;

  CarromController(this.roomId, this.currentUserId, {this.isHost = false});

  final Rx<CarromGameState> gameState = CarromGameState.initial().obs;
  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _turnTimer;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;

  // Local physics ticker / simulation variables
  final RxList<CarromPiece> localPieces = <CarromPiece>[].obs;
  final RxBool isSimulating = false.obs;
  Timer? _simTimer;

  // Aiming state for current user
  final RxDouble strikerPosition = 0.5.obs; // 0.25 to 0.75 along baseline
  final RxDouble aimX = 0.0.obs;
  final RxDouble aimY = 0.0.obs;
  final RxDouble aimPower = 0.0.obs; // 0.0 to 1.0

  @override
  void onInit() {
    super.onInit();
    _initSync();
  }

  void _initSync() {
    final ref = _realtimeDb.ref('rooms/$roomId/carrom/state');
    _sub = ref.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        final newState = CarromGameState.fromJson(map);
        
        final oldState = gameState.value;
        gameState.value = newState;

        // Sync local pieces representation when not simulating
        if (!isSimulating.value) {
          localPieces.assignAll(newState.pieces);
        }

        // Listen for new shots fired
        if (newState.shotState != null && 
            (oldState.shotState == null || 
             newState.shotState!['timestamp'] != oldState.shotState?['timestamp'])) {
          _triggerLocalSimulation(newState.shotState!);
        }

        _handleTimer();
        _checkBotTurn();
      } else {
        _syncState(gameState.value);
      }
    });
  }

  void _handleTimer() {
    _turnTimer?.cancel();
    if (gameState.value.winner != null || !gameState.value.isStarted) return;

    final int turnStartTime = gameState.value.lastTurnStartTime;
    final int elapsed = DateTime.now().millisecondsSinceEpoch - turnStartTime;
    final int remaining = 30000 - elapsed; // 30 second turns

    // Normally host handles turn expiry at 30s. If host disconnected (>35s), any client can trigger skip.
    if (!isHost && elapsed < 35000) return;

    if (remaining <= 0 || elapsed >= 35000) {
      _skipTurn();
    } else {
      _turnTimer = Timer(Duration(milliseconds: max(100, remaining)), () {
        _skipTurn();
      });
    }
  }

  void _skipTurn() {
    if (isSimulating.value) return; // Wait for simulation to finish
    final next = _getNextTurn(gameState.value.currentTurn);
    
    // Respawn striker in case it was not placed
    final updatedPieces = _cleanPiecesListAfterShot(gameState.value.pieces);

    final newState = gameState.value.copyWith(
      currentTurn: next,
      pieces: updatedPieces,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
    );
    _syncState(newState);
  }

  String _getNextTurn(String current) {
    final maxP = gameState.value.maxPlayers;
    if (maxP == 2) {
      return (current == 'bottom') ? 'top' : 'bottom';
    } else {
      // 4 Players clockwise: bottom -> left -> top -> right -> bottom
      final order = ['bottom', 'left', 'top', 'right'];
      final idx = order.indexOf(current);
      return order[(idx + 1) % 4];
    }
  }

  Future<void> joinGame(String userId, String seat) async {
    final Map<String, String?> newPlayers = Map.from(gameState.value.players);
    newPlayers[seat] = userId;

    final newState = gameState.value.copyWith(players: newPlayers);
    await _syncState(newState);
  }

  Future<void> leaveGame(String seat) async {
    final Map<String, String?> newPlayers = Map.from(gameState.value.players);
    newPlayers.remove(seat);

    final newState = gameState.value.copyWith(players: newPlayers);
    await _syncState(newState);
  }

  Future<void> startGame() async {
    final cleanState = CarromGameState.initial(maxPlayers: gameState.value.maxPlayers);
    final newState = cleanState.copyWith(
      players: gameState.value.players,
      isStarted: true,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
    );
    await _syncState(newState);
  }

  Future<void> resetLobby() async {
    final newState = CarromGameState.initial(maxPlayers: gameState.value.maxPlayers).copyWith(
      players: gameState.value.players,
    );
    await _syncState(newState);
  }

  Future<void> _syncState(CarromGameState newState) async {
    try {
      await _realtimeDb.ref('rooms/$roomId/carrom/state').set(newState.toJson());
    } catch (e) {
      debugPrint('Error syncing Carrom state: $e');
    }
  }

  // Shoot the striker
  void fireShot({double? positionVal, double? powerVal, double? dirX, double? dirY}) {
    if (gameState.value.shotState != null || isSimulating.value) return;

    final String turnSeat = gameState.value.currentTurn;
    final String? turnUserId = gameState.value.players[turnSeat];

    // Validate turn
    final bool isBot = turnUserId != null && turnUserId.startsWith('bot_');
    if (isBot) {
      if (!isHost) return; // Only host handles bot shots
    } else {
      if (turnUserId != currentUserId) return; // not my turn
    }

    // Calculate initial striker position depending on turn
    double startX = 0.5;
    double startY = 0.5;
    double val = positionVal ?? strikerPosition.value;

    switch (turnSeat) {
      case 'bottom':
        startX = val;
        startY = 0.815;
        break;
      case 'top':
        startX = 1.0 - val; // Mirror position
        startY = 0.185;
        break;
      case 'left':
        startX = 0.185;
        startY = val;
        break;
      case 'right':
        startX = 0.815;
        startY = 1.0 - val;
        break;
    }

    // Striker initial velocity (Aiming vector * power * multiplier)
    // Speed mapped to smooth board velocity response
    double pVal = (powerVal ?? aimPower.value).clamp(0.0, 1.0);
    double speedMult = 0.088 * (0.40 * pVal + 0.60 * pVal * pVal);
    double vx = (dirX ?? aimX.value) * speedMult;
    double vy = (dirY ?? aimY.value) * speedMult;

    // Send shot to database
    final shot = {
      'strikerX': startX,
      'strikerY': startY,
      'vx': vx,
      'vy': vy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _realtimeDb.ref('rooms/$roomId/carrom/state/shotState').set(shot);
  }

  // Runs the deterministic local 60FPS simulation on all clients
  void _triggerLocalSimulation(Map<String, dynamic> shot) {
    _simTimer?.cancel();
    isSimulating.value = true;

    double strikerX = (shot['strikerX'] as num).toDouble();
    double strikerY = (shot['strikerY'] as num).toDouble();
    double vx = (shot['vx'] as num).toDouble();
    double vy = (shot['vy'] as num).toDouble();

    // Prepare simulation pieces list (including placing the striker on the board)
    List<CarromPiece> simPieces = gameState.value.pieces
        .where((p) => !p.isPocketed && p.color != CarromColor.striker)
        .toList();

    // Add active striker
    simPieces.add(CarromPiece(
      id: 'striker',
      x: strikerX,
      y: strikerY,
      vx: vx,
      vy: vy,
      radius: 0.032, // striker is larger
      color: CarromColor.striker,
    ));

    localPieces.assignAll(simPieces);

    // Run the game loop at 60 FPS (approx 16ms interval)
    const double dt = 1.0;
    int frameCount = 0;
    
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      bool moving = _physicsStep(dt);
      frameCount++;

      // Force stop after 8 seconds (500 frames) to prevent infinite simulation crashes
      if (!moving || frameCount > 500) {
        timer.cancel();
        _onSimulationFinished();
      }
    });
  }

  // Local physics step, returns true if pieces are still moving
  bool _physicsStep(double dt) {
    const double friction = 0.015; // Slow down rate (smooth realistic carrom surface)
    const double borderMin = 0.07;
    const double borderMax = 0.93;
    const double restCoeff = 0.74; // Wall elasticity
    const double pieceRestCoeff = 0.78; // Piece-to-piece elasticity
 
    final pockets = const [
      Offset(0.10, 0.10),  // Top Left
      Offset(0.90, 0.10),  // Top Right
      Offset(0.10, 0.90),  // Bottom Left
      Offset(0.90, 0.90),  // Bottom Right
    ];
    const double pocketRad = 0.045;

    bool stillMoving = false;

    // Create a plain local list to perform calculations on this frame to prevent redundant Rx notifications
    final List<CarromPiece> list = List.from(localPieces);

    // 1. Move pieces & apply friction
    for (int i = 0; i < list.length; i++) {
      var p = list[i];
      if (p.isPocketed) continue;

      if (p.vx != 0.0 || p.vy != 0.0) {
        double newX = p.x + p.vx * dt;
        double newY = p.y + p.vy * dt;

        // Apply friction
        double speed = sqrt(p.vx * p.vx + p.vy * p.vy);
        double newVx = p.vx * (1.0 - friction);
        double newVy = p.vy * (1.0 - friction);

        if (speed < 0.001) {
          newVx = 0.0;
          newVy = 0.0;
        } else {
          stillMoving = true;
        }

        list[i] = p.copyWith(x: newX, y: newY, vx: newVx, vy: newVy);
      }
    }

    // 2. Wall Collisions
    for (int i = 0; i < list.length; i++) {
      var p = list[i];
      if (p.isPocketed) continue;

      double px = p.x;
      double py = p.y;
      double pvx = p.vx;
      double pvy = p.vy;

      bool hit = false;
      if (px - p.radius < borderMin) {
        px = borderMin + p.radius;
        pvx = -pvx * restCoeff;
        hit = true;
      } else if (px + p.radius > borderMax) {
        px = borderMax - p.radius;
        pvx = -pvx * restCoeff;
        hit = true;
      }

      if (py - p.radius < borderMin) {
        py = borderMin + p.radius;
        pvy = -pvy * restCoeff;
        hit = true;
      } else if (py + p.radius > borderMax) {
        py = borderMax - p.radius;
        pvy = -pvy * restCoeff;
        hit = true;
      }

      if (hit) {
        list[i] = p.copyWith(x: px, y: py, vx: pvx, vy: pvy);
      }
    }

    // 3. Piece-to-Piece Collisions
    for (int i = 0; i < list.length; i++) {
      var pA = list[i];
      if (pA.isPocketed) continue;

      for (int j = i + 1; j < list.length; j++) {
        var pB = list[j];
        if (pB.isPocketed) continue;

        double dx = pB.x - pA.x;
        double dy = pB.y - pA.y;
        double distSq = dx * dx + dy * dy;
        double minDist = pA.radius + pB.radius;

        if (distSq < minDist * minDist) {
          double dist = sqrt(distSq);
          if (dist == 0.0) continue;

          // Push apart to resolve overlaps
          double overlap = minDist - dist;
          double nx = dx / dist;
          double ny = dy / dist;

          double pushX = nx * overlap * 0.5;
          double pushY = ny * overlap * 0.5;

          pA = pA.copyWith(x: pA.x - pushX, y: pA.y - pushY);
          pB = pB.copyWith(x: pB.x + pushX, y: pB.y + pushY);

          // Elastic collision calculation (mass: striker=2.5, normal=1.0)
          double massA = (pA.color == CarromColor.striker) ? 2.5 : 1.0;
          double massB = (pB.color == CarromColor.striker) ? 2.5 : 1.0;

          double rvx = pB.vx - pA.vx;
          double rvy = pB.vy - pA.vy;
          double velAlongNormal = rvx * nx + rvy * ny;

          if (velAlongNormal < 0.0) {
            double impulse = -(1.0 + pieceRestCoeff) * velAlongNormal / (1.0 / massA + 1.0 / massB);
            
            pA = pA.copyWith(
              vx: pA.vx - (impulse / massA) * nx,
              vy: pA.vy - (impulse / massA) * ny,
            );
            pB = pB.copyWith(
              vx: pB.vx + (impulse / massB) * nx,
              vy: pB.vy + (impulse / massB) * ny,
            );
            stillMoving = true;
          }

          list[i] = pA;
          list[j] = pB;
        }
      }
    }

    // 4. Pocket check
    for (int i = 0; i < list.length; i++) {
      var p = list[i];
      if (p.isPocketed) continue;

      for (var pocket in pockets) {
        double dx = p.x - pocket.dx;
        double dy = p.y - pocket.dy;
        double dist = sqrt(dx * dx + dy * dy);

        // Center of piece goes inside the pocket
        if (dist < pocketRad) {
          list[i] = p.copyWith(
            x: pocket.dx,
            y: pocket.dy,
            vx: 0.0,
            vy: 0.0,
            isPocketed: true,
          );
          stillMoving = true;
          break;
        }
      }
    }

    // Update the reactive RxList EXACTLY ONCE at the end of the physics frame
    localPieces.assignAll(list);

    return stillMoving;
  }

  // Simulation finished: active player computes the final game state and syncs to Firebase
  void _onSimulationFinished() {
    isSimulating.value = false;

    final String turnSeat = gameState.value.currentTurn;
    final String? turnUserId = gameState.value.players[turnSeat];
    final bool isBot = turnUserId != null && turnUserId.startsWith('bot_');
    final bool isMyTurn = turnUserId == currentUserId;

    if (isMyTurn || (isBot && isHost)) {
      // 1. Identify which pieces were pocketed this turn
      final List<CarromPiece> beforeShotPieces = gameState.value.pieces;
      final List<CarromPiece> afterShotPieces = localPieces.toList();

      List<CarromPiece> pocketedThisTurn = [];
      for (var pAfter in afterShotPieces) {
        if (pAfter.isPocketed && pAfter.color != CarromColor.striker) {
          CarromPiece? pBefore;
          for (var p in beforeShotPieces) {
            if (p.id == pAfter.id) {
              pBefore = p;
              break;
            }
          }
          if (pBefore != null && !pBefore.isPocketed) {
            pocketedThisTurn.add(pAfter);
          }
        }
      }

      // Check if striker was pocketed (Foul)
      CarromPiece? strikerPiece;
      for (var p in afterShotPieces) {
        if (p.color == CarromColor.striker) {
          strikerPiece = p;
          break;
        }
      }
      final bool strikerPocketed = strikerPiece?.isPocketed ?? false;

      // Determine active player's color team: bottom/top (White) vs left/right (Black)
      final CarromColor myTeamColor = (gameState.value.maxPlayers == 2)
          ? (turnSeat == 'bottom' ? CarromColor.white : CarromColor.black)
          : ((turnSeat == 'bottom' || turnSeat == 'top') ? CarromColor.white : CarromColor.black);

      int myPocketedCount = pocketedThisTurn.where((p) => p.color == myTeamColor).length;
      bool queenPocketed = pocketedThisTurn.any((p) => p.color == CarromColor.red);

      // Score additions
      int whiteScoreAdd = pocketedThisTurn.where((p) => p.color == CarromColor.white).length;
      int blackScoreAdd = pocketedThisTurn.where((p) => p.color == CarromColor.black).length;

      // Rules logic
      String nextTurn = turnSeat;
      bool keepTurn = false;
      String newQueenStatus = gameState.value.queenStatus;
      String? newQueenOwner = gameState.value.queenOwner;

      List<CarromPiece> finalPiecesList = [];
      
      // Filter out striker from the saved pieces (we respawn striker on baseline next turn)
      for (var p in afterShotPieces) {
        if (p.color != CarromColor.striker) {
          finalPiecesList.add(p);
        }
      }

      // Foul check
      if (strikerPocketed) {
        // Penalty: return one of player's pocketed pieces to center (if they scored any previously)
        final myPocketedPieces = finalPiecesList.where((p) => p.color == myTeamColor && p.isPocketed).toList();
        if (myPocketedPieces.isNotEmpty) {
          // Return one piece to center (0.5, 0.5)
          final pieceToReturn = myPocketedPieces.first;
          final idx = finalPiecesList.indexWhere((p) => p.id == pieceToReturn.id);
          if (idx != -1) {
            finalPiecesList[idx] = pieceToReturn.copyWith(x: 0.5, y: 0.5, isPocketed: false);
          }
          if (myTeamColor == CarromColor.white) whiteScoreAdd--;
          else blackScoreAdd--;
        }

        // Penalty: Lose turn
        keepTurn = false;
        
        // If Queen was pocketed in this shot but striker fell in, Queen returns to center
        if (queenPocketed) {
          final qIdx = finalPiecesList.indexWhere((p) => p.id == 'queen');
          if (qIdx != -1) {
            finalPiecesList[qIdx] = finalPiecesList[qIdx].copyWith(x: 0.5, y: 0.5, isPocketed: false);
          }
          queenPocketed = false;
        }
        
        // If Queen was waiting cover, and we fouled, Queen goes back to center
        if (newQueenStatus == 'pocketed_waiting_cover' && newQueenOwner == turnSeat) {
          final qIdx = finalPiecesList.indexWhere((p) => p.id == 'queen');
          if (qIdx != -1) {
            finalPiecesList[qIdx] = finalPiecesList[qIdx].copyWith(x: 0.5, y: 0.5, isPocketed: false);
          }
          newQueenStatus = 'none';
          newQueenOwner = null;
        }
      } else {
        // No striker foul
        if (newQueenStatus == 'pocketed_waiting_cover' && newQueenOwner == turnSeat) {
          // We were waiting for a cover on this shot
          if (myPocketedCount > 0) {
            // Covered successfully!
            newQueenStatus = 'covered';
          } else {
            // Failed to cover! Queen goes back to center (0.5, 0.5)
            final qIdx = finalPiecesList.indexWhere((p) => p.id == 'queen');
            if (qIdx != -1) {
              finalPiecesList[qIdx] = finalPiecesList[qIdx].copyWith(x: 0.5, y: 0.5, isPocketed: false);
            }
            newQueenStatus = 'none';
            newQueenOwner = null;
          }
        }

        if (queenPocketed) {
          // Queen pocketed just now
          newQueenStatus = 'pocketed_waiting_cover';
          newQueenOwner = turnSeat;
          keepTurn = true; // Gets another shot to try to cover
        } else if (myPocketedCount > 0) {
          // Pocketed own color piece
          keepTurn = true;
        }
      }

      if (!keepTurn) {
        nextTurn = _getNextTurn(turnSeat);
      }

      // Calculate new scores
      int newWhiteScore = gameState.value.scores['white']! + whiteScoreAdd;
      int newBlackScore = gameState.value.scores['black']! + blackScoreAdd;

      // Clean overlapping pieces in the center if any returned
      finalPiecesList = _cleanPiecesListAfterShot(finalPiecesList);

      // Check Winner
      String? winner;
      final int totalWhite = finalPiecesList.where((p) => p.color == CarromColor.white).length;
      final int totalBlack = finalPiecesList.where((p) => p.color == CarromColor.black).length;
      final int pocketedWhite = finalPiecesList.where((p) => p.color == CarromColor.white && p.isPocketed).length;
      final int pocketedBlack = finalPiecesList.where((p) => p.color == CarromColor.black && p.isPocketed).length;

      // Win condition: pocketed all pieces + queen must be covered (or pocketed by winner)
      if (pocketedWhite == totalWhite && (newQueenStatus == 'covered' || newQueenOwner == 'bottom' || newQueenOwner == 'top')) {
        winner = 'White Team';
      } else if (pocketedBlack == totalBlack && (newQueenStatus == 'covered' || newQueenOwner == 'left' || newQueenOwner == 'right')) {
        winner = 'Black Team';
      }

      final newState = gameState.value.copyWith(
        pieces: finalPiecesList,
        currentTurn: nextTurn,
        winner: winner,
        scores: {'white': newWhiteScore, 'black': newBlackScore},
        queenStatus: newQueenStatus,
        queenOwner: newQueenOwner,
        lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Save official final state & clear shotState to trigger stopped screen for everyone
      _realtimeDb.ref('rooms/$roomId/carrom/state').set(newState.toJson()).then((_) {
        // Force sync locally
        localPieces.assignAll(finalPiecesList);
        _checkBotTurn();
      });
    }
  }

  // Prevent multiple returned pieces stacking exactly on top of center (0.5, 0.5)
  List<CarromPiece> _cleanPiecesListAfterShot(List<CarromPiece> list) {
    List<CarromPiece> output = List.from(list);
    final double cx = 0.5;
    final double cy = 0.5;

    for (int i = 0; i < output.length; i++) {
      final pA = output[i];
      if (pA.isPocketed) continue;
      
      // If it is in the center and overlaps other active pieces, nudge it
      for (int j = 0; j < output.length; j++) {
        if (i == j) continue;
        final pB = output[j];
        if (pB.isPocketed) continue;

        double dx = pB.x - pA.x;
        double dy = pB.y - pA.y;
        double distSq = dx * dx + dy * dy;
        double minDist = pA.radius + pB.radius;

        if (distSq < minDist * minDist) {
          // Overlap! Nudge piece A randomly
          double angle = Random().nextDouble() * 2 * pi;
          double nudgeX = cos(angle) * (minDist * 1.1);
          double nudgeY = sin(angle) * (minDist * 1.1);
          output[i] = pA.copyWith(x: cx + nudgeX, y: cy + nudgeY);
        }
      }
    }
    return output;
  }

  Timer? _botTimer;

  void _checkBotTurn() {
    _botTimer?.cancel();
    if (!gameState.value.isStarted || 
        gameState.value.winner != null || 
        gameState.value.shotState != null || 
        isSimulating.value) return;

    final String turnSeat = gameState.value.currentTurn;
    final String? turnUserId = gameState.value.players[turnSeat];
    final bool isBot = turnUserId != null && turnUserId.startsWith('bot_');

    if (isBot && isHost) {
      _botTimer = Timer(const Duration(milliseconds: 2000), () {
        _runBotShot();
      });
    }
  }

  void _runBotShot() {
    if (!gameState.value.isStarted || 
        gameState.value.winner != null || 
        gameState.value.shotState != null || 
        isSimulating.value) return;

    final String turnSeat = gameState.value.currentTurn;
    
    // Choose team color
    final CarromColor teamColor = (turnSeat == 'bottom' || turnSeat == 'top') 
        ? CarromColor.white 
        : CarromColor.black;

    // Find a target piece
    List<CarromPiece> targets = gameState.value.pieces
        .where((p) => !p.isPocketed && p.color == teamColor)
        .toList();

    // If no own pieces, target the queen
    if (targets.isEmpty) {
      targets = gameState.value.pieces
          .where((p) => !p.isPocketed && p.color == CarromColor.red)
          .toList();
    }

    // If still no queen, target any remaining piece (like opponent's) to strike something
    if (targets.isEmpty) {
      targets = gameState.value.pieces
          .where((p) => !p.isPocketed && p.color != CarromColor.striker)
          .toList();
    }

    if (targets.isEmpty) return; // No targets left

    // Pick a random target piece
    final CarromPiece target = targets[Random().nextInt(targets.length)];

    // Bot striker placement: pick a random position between 0.35 and 0.65
    double botStrikerPos = 0.35 + Random().nextDouble() * 0.3;

    // Get striker starting position
    double startX = 0.5;
    double startY = 0.5;
    switch (turnSeat) {
      case 'bottom':
        startX = botStrikerPos;
        startY = 0.73;
        break;
      case 'top':
        startX = 1.0 - botStrikerPos;
        startY = 0.27;
        break;
      case 'left':
        startX = 0.27;
        startY = botStrikerPos;
        break;
      case 'right':
        startX = 0.73;
        startY = 1.0 - botStrikerPos;
        break;
    }

    // Aim from striker to target
    double dx = target.x - startX;
    double dy = target.y - startY;
    double dist = sqrt(dx * dx + dy * dy);

    if (dist == 0.0) return;

    // Add random error angle offset to make bot human-like (-10 to +10 degrees)
    double angleOffsetRad = (Random().nextDouble() * 20 - 10) * pi / 180;
    double currentAngle = atan2(dy, dx);
    double botAngle = currentAngle + angleOffsetRad;

    double botAimX = cos(botAngle);
    double botAimY = sin(botAngle);

    // Random power between 0.45 and 0.8
    double botAimPower = 0.45 + Random().nextDouble() * 0.35;

    // Fire the shot
    fireShot(
      positionVal: botStrikerPos,
      powerVal: botAimPower,
      dirX: botAimX,
      dirY: botAimY,
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    _simTimer?.cancel();
    _turnTimer?.cancel();
    _botTimer?.cancel();
    super.onClose();
  }
}
