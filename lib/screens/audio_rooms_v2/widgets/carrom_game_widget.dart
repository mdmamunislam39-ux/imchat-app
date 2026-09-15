import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_lobby_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_board_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_controller.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';

class CarromGameWidget extends StatefulWidget {
  final AudioRoomV2 room;
  final bool isHost;
  final AudioRoomsRepository repository;
  final String currentUserId;

  const CarromGameWidget({
    super.key,
    required this.room,
    required this.isHost,
    required this.repository,
    required this.currentUserId,
  });

  @override
  State<CarromGameWidget> createState() => _CarromGameWidgetState();
}

class _CarromGameWidgetState extends State<CarromGameWidget> {
  late final CarromController _controller;
  bool _isMuted = false;

  // Countdown state — seconds remaining in current turn (0-30)
  final RxInt _countdownSeconds = 30.obs;
  Timer? _countdownTicker;
  int _lastTurnStartTime = 0;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      CarromController(widget.room.id, widget.currentUserId, isHost: widget.isHost),
      tag: widget.room.id,
    );
    // Start watching game state to reset the countdown on each new turn
    ever(_controller.gameState, (state) {
      final ts = state.lastTurnStartTime;
      if (ts != _lastTurnStartTime) {
        _lastTurnStartTime = ts;
        _resetCountdown(ts);
      }
    });
  }

  void _resetCountdown(int turnStartMs) {
    _countdownTicker?.cancel();
    // Compute remaining immediately
    final elapsed = DateTime.now().millisecondsSinceEpoch - turnStartMs;
    _countdownSeconds.value = (30 - (elapsed / 1000).floor()).clamp(0, 30);
    if (_countdownSeconds.value <= 0) return;
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final e = DateTime.now().millisecondsSinceEpoch - turnStartMs;
      final rem = (30 - (e / 1000).floor()).clamp(0, 30);
      _countdownSeconds.value = rem;
      if (rem <= 0) _countdownTicker?.cancel();
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    Get.delete<CarromController>(tag: widget.room.id);
    super.dispose();
  }

  void _closeCarrom() {
    // If the current user is seated in the game, leave seat first
    final players = _controller.gameState.value.players;
    for (var entry in players.entries) {
      if (entry.value == widget.currentUserId) {
        _controller.leaveGame(entry.key);
        break;
      }
    }

    widget.repository.updateCarromState(
      roomId: widget.room.id,
      isActive: false,
    );
  }

  void _startGame() {
    _controller.startGame();
  }

  void _sitInSeat(String seat) {
    String? currentSeat;
    for (var entry in _controller.gameState.value.players.entries) {
      if (entry.value == widget.currentUserId) {
        currentSeat = entry.key;
        break;
      }
    }
    if (currentSeat != null) {
      _controller.leaveGame(currentSeat).then((_) {
        _controller.joinGame(widget.currentUserId, seat);
      });
    } else {
      _controller.joinGame(widget.currentUserId, seat);
    }
  }

  void _showSeatSelectionDialog(String seat) {
    if (widget.isHost) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C1810),
          title: const Text('Configure Seat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('Choose whether to join this seat yourself or add a bot.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _sitInSeat(seat);
              },
              child: const Text('Join Seat', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _controller.joinGame('bot_$seat', seat);
              },
              child: const Text('Add Bot', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      _sitInSeat(seat);
    }
  }

  void _showRemoveBotDialog(String seat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C1810),
        title: const Text('Bot Options', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to remove the bot from this seat?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.leaveGame(seat);
            },
            child: const Text('Remove Bot', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, Color goldColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C1810),
        title: Text('Carrom Rules', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold)),
        content: const Text(
          '1. Settle in the Bottom/Top seats (White Team) or Left/Right seats (Black Team).\n\n'
          '2. Settle the striker along your baseline, drag back to aim and release to strike.\n\n'
          '3. White team scores White pieces, Black team scores Black pieces.\n\n'
          '4. Queen (Red) must be covered by scoring your color piece in the very next shot.\n\n'
          '5. Pocketing the striker is a foul (loses turn, penalties apply).',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: goldColor)),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String title, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title: $message',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF2C1810),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  AudioRoomParticipant? _findParticipant(String userId) {
    try {
      return widget.room.participants.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlayerAvatar({
    required String seat,
    required String? userId,
    required Color teamColor,
    required int pocketedCount,
    required int score,
    required bool isActiveTurn,
  }) {
    final bool isFilled = userId != null;
    final bool isBot = isFilled && userId.startsWith('bot_');
    final bool isWhite = teamColor == Colors.white;
    final Color borderCol = isFilled
        ? (isActiveTurn ? const Color(0xFFD4AF37) : teamColor.withValues(alpha: 0.7))
        : Colors.white24;

    final participant = isFilled && !isBot ? _findParticipant(userId) : null;
    final String displayName = isFilled
        ? (isBot
            ? 'Bot'
            : (userId == widget.currentUserId
                ? 'You'
                : (participant?.userName ?? seat.toUpperCase())))
        : 'Add';
    // Countdown ring only for active player avatar
    const double avatarSize = 32;
    const double ringPad = 2.0;
    const double ringSize = avatarSize + ringPad * 2;
    final String? avatarUrl = participant?.userImageUrl;

    return GestureDetector(
      onTap: () {
        if (!isFilled) {
          _showSeatSelectionDialog(seat);
        } else if (isBot && widget.isHost) {
          _showRemoveBotDialog(seat);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 30-second countdown ring drawn only for active player
                if (isActiveTurn)
                  Positioned.fill(
                    child: Obx(() {
                      final secs = _countdownSeconds.value;
                      final progress = secs / 30.0;
                      return CustomPaint(
                        painter: _CountdownRingPainter(
                          progress: progress,
                          color: secs > 10
                              ? const Color(0xFF00BCD4)
                              : (secs > 5 ? Colors.orange : Colors.redAccent),
                        ),
                      );
                    }),
                  ),
                // Avatar circle
                Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Colors.white10 : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: borderCol,
                    width: isActiveTurn ? 2.2 : 1.2,
                  ),
                  boxShadow: isActiveTurn
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: isFilled
                      ? (avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedCircleAvatar(imageUrl: avatarUrl, radius: 16)
                          : Icon(
                              isBot ? Icons.smart_toy : Icons.person,
                              color: isWhite ? Colors.white70 : Colors.grey.shade400,
                              size: 17,
                            ))
                      : const Icon(Icons.add, color: Colors.white30, size: 12),
                ),
                ),

              // Turn indicator (green dot top-left)
              if (isActiveTurn)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                  ),
                ),

              // Team color dot + piece count badge (bottom-right corner)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: isWhite ? Colors.white : const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ],
                  ),
                  child: Text(
                    '$pocketedCount',
                    style: TextStyle(
                      color: isWhite ? const Color(0xFF2C1810) : Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Team color indicator dot row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isWhite ? Colors.white : const Color(0xFF444344),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$score pts',
                style: TextStyle(
                  color: isWhite ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterTurnPill(Color goldColor) {
    return Obx(() {
      final state = _controller.gameState.value;
      final currentSeat = state.currentTurn;
      final isMyTurn = state.players[currentSeat] == widget.currentUserId;
      final isSimulating = _controller.isSimulating.value;
      
      String turnLabel = '';
      if (isSimulating) {
        turnLabel = 'PIECES MOVING...';
      } else if (isMyTurn) {
        turnLabel = 'YOUR TURN';
      } else {
        turnLabel = '${currentSeat.toUpperCase()}\'S TURN';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1810), // Rich Mahogany
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSimulating
                    ? Colors.orange
                    : ((currentSeat == 'bottom' || currentSeat == 'top') 
                        ? Colors.white 
                        : const Color(0xFF151515)),
                border: Border.all(color: goldColor, width: 1.0),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              turnLabel,
              style: TextStyle(
                color: goldColor,
                fontWeight: FontWeight.bold,
                fontSize: 8,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isStarted = _controller.gameState.value.isStarted;

      if (!isStarted) {
        return Container(
          width: double.infinity,
          height: 380,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CarromLobbyWidget(
            controller: _controller,
            currentUserId: widget.currentUserId,
            onStart: _startGame,
            onClose: _closeCarrom,
            isHost: widget.isHost,
          ),
        );
      }

      // Game started: board + slider + seats
      final double boardSize = MediaQuery.of(context).size.width - 32;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Game board (square)
            SizedBox(
              width: boardSize,
              height: boardSize,
              child: _buildGameBoard(),
            ),
            // Striker position slider + player seats row below the board
            _buildBottomRow(boardSize),
          ],
        ),
      );
    });
  }

  /// Builds the slider + seat row that sits below the board
  Widget _buildBottomRow(double boardSize) {
    final goldColor = const Color(0xFFD4AF37);
    return Obx(() {
      final state = _controller.gameState.value;
      final isSimulating = _controller.isSimulating.value;
      final turnSeat = state.currentTurn;
      final String? turnUserId = state.players[turnSeat];
      final bool isMyTurn = turnUserId == widget.currentUserId;
      final is2Player = state.maxPlayers == 2;
      final whiteScore = state.scores['white'] ?? 0;
      final blackScore = state.scores['black'] ?? 0;

      // Use accumulated scores as the pocketed piece count (never resets mid-game)
      final int whitePocketed = whiteScore;
      final int blackPocketed = blackScore;

      return Container(
        width: boardSize,
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // LEFT seats (White team - bottom; 2nd white seat hidden in 2-player)
            _buildPlayerAvatar(
              seat: 'bottom',
              userId: state.players['bottom'],
              teamColor: Colors.white,
              pocketedCount: whitePocketed,
              score: whiteScore,
              isActiveTurn: state.currentTurn == 'bottom',
            ),
            if (!is2Player) ...[
              const SizedBox(width: 6),
              _buildPlayerAvatar(
                seat: 'top',
                userId: state.players['top'],
                teamColor: Colors.white,
                pocketedCount: whitePocketed,
                score: whiteScore,
                isActiveTurn: state.currentTurn == 'top',
              ),
            ],

            // CENTER: Premium wooden striker tray slider bounded inside the tray area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildStrikerSlider(
                  goldColor: goldColor,
                  isMyTurn: isMyTurn,
                  isSimulating: isSimulating,
                ),
              ),
            ),

            // RIGHT seats (Black team)
            if (is2Player)
              _buildPlayerAvatar(
                seat: 'top',
                userId: state.players['top'],
                teamColor: Colors.black87,
                pocketedCount: blackPocketed,
                score: blackScore,
                isActiveTurn: state.currentTurn == 'top',
              )
            else ...[
              _buildPlayerAvatar(
                seat: 'left',
                userId: state.players['left'],
                teamColor: Colors.black87,
                pocketedCount: blackPocketed,
                score: blackScore,
                isActiveTurn: state.currentTurn == 'left',
              ),
              const SizedBox(width: 6),
              _buildPlayerAvatar(
                seat: 'right',
                userId: state.players['right'],
                teamColor: Colors.black87,
                pocketedCount: blackPocketed,
                score: blackScore,
                isActiveTurn: state.currentTurn == 'right',
              ),
            ],
          ],
        ),
      );
    });
  }

  /// Premium wooden tray slider with a striker disc as the thumb, bounded inside the tray bar
  Widget _buildStrikerSlider({
    required Color goldColor,
    required bool isMyTurn,
    required bool isSimulating,
  }) {
    final bool active = isMyTurn && !isSimulating;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [
                  const Color(0xFF7A4A28),
                  const Color(0xFF542E18),
                  const Color(0xFF3B1D0E),
                ]
              : [
                  const Color(0xFF4A301E),
                  const Color(0xFF331E12),
                  const Color(0xFF24140B),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? goldColor : goldColor.withValues(alpha: 0.3),
          width: active ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (active)
            BoxShadow(
              color: goldColor.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wood grain line detail
            Positioned.fill(
              child: CustomPaint(painter: _WoodGrainPainter()),
            ),
            // Inner track slot guide line
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: goldColor.withValues(alpha: active ? 0.4 : 0.2),
                  width: 0.5,
                ),
              ),
            ),
            // Slider with custom striker thumb
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                trackHeight: 0,
                thumbShape: _StrikerThumbShape(
                  thumbRadius: 13,
                  isEnabled: active,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
                overlayColor: goldColor.withValues(alpha: 0.2),
              ),
              child: Obx(() => Slider(
                value: _controller.strikerPosition.value.clamp(0.27, 0.73),
                min: 0.27,
                max: 0.73,
                onChanged: active
                    ? (val) {
                        _controller.strikerPosition.value = val;
                      }
                    : null,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    final goldColor = const Color(0xFFD4AF37);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F100A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldColor.withValues(alpha: 0.5), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 1. Main Game Board
            CarromBoardWidget(
              controller: _controller,
              currentUserId: widget.currentUserId,
            ),

            // 2. Top-Left Overlay Controls (Refresh, Rules, Share)
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  _buildGlassIconButton(Icons.refresh, () {
                    if (widget.isHost) {
                      _controller.resetLobby();
                    } else {
                      _showSnackBar(
                        'Restricted',
                        'Only the host can reset the game.',
                      );
                    }
                  }),
                  const SizedBox(width: 6),
                  _buildGlassIconButton(Icons.help_outline, () {
                    _showHelpDialog(context, goldColor);
                  }),
                  const SizedBox(width: 6),
                  _buildGlassIconButton(Icons.share, () {
                    _showSnackBar(
                      'Share',
                      'Room shared successfully!',
                    );
                  }),
                ],
              ),
            ),

            // 3. Top-Right Overlay Controls (Mute/Sound, Exit/Power)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _buildGlassIconButton(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                      _showSnackBar(
                        'Sound',
                        _isMuted ? 'Game sound muted.' : 'Game sound unmuted.',
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildGlassIconButton(Icons.power_settings_new, _closeCarrom),
                ],
              ),
            ),

            // 4. Center Bottom Active Turn Indicator Pill
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: _buildCenterTurnPill(goldColor),
              ),
            ),

            // 8. Winner Celebration Overlay
            Obx(() {
              final winner = _controller.gameState.value.winner;
              if (winner != null) {
                return Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: Color(0xFFD4AF37), size: 90),
                        const SizedBox(height: 16),
                        Text(
                          '${winner.toUpperCase()}!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Color(0xFFD4AF37), blurRadius: 15, offset: Offset(0, 3)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.isHost) ...[
                              ElevatedButton.icon(
                                onPressed: () => _controller.resetLobby(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Play Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: goldColor,
                                  foregroundColor: const Color(0xFF2C1810),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            ElevatedButton.icon(
                              onPressed: _closeCarrom,
                              icon: const Icon(Icons.close),
                              label: const Text('Exit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }
}

/// Paints subtle wood grain horizontal lines on the slider tray
class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    // Horizontal wood grain lines
    for (double y = 4; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Slight inner shadow on edges
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.3),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom slider thumb that draws a carrom striker disc
class _StrikerThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final bool isEnabled;

  const _StrikerThumbShape({
    required this.thumbRadius,
    this.isEnabled = true,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbRadius * 2, thumbRadius * 2);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final double r = thumbRadius;

    final Color goldCol = isEnabled ? const Color(0xFFD4AF37) : const Color(0xFF8A7342);
    final Color cyanCol = isEnabled ? const Color(0xFF00ADB5) : const Color(0xFF4A6B6D);

    // Outer rim (gold)
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = goldCol
        ..style = PaintingStyle.fill,
    );

    // Inner fill (cyan/teal – striker color)
    canvas.drawCircle(
      center,
      r - 2.5,
      Paint()..color = cyanCol,
    );

    // Middle ring detail
    canvas.drawCircle(
      center,
      r * 0.55,
      Paint()
        ..color = goldCol
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Center jewel
    canvas.drawCircle(
      center,
      r * 0.22,
      Paint()..color = goldCol,
    );

    // Gloss highlight
    if (isEnabled) {
      canvas.drawCircle(
        center + Offset(-r * 0.28, -r * 0.28),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }
}

/// Paints a circular countdown arc (teal → orange → red) around a player avatar
class _CountdownRingPainter extends CustomPainter {
  final double progress; // 1.0 = full (30s), 0.0 = empty (0s)
  final Color color;

  const _CountdownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = (size.width / 2) - 1.5;

    // Background track (dim)
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Countdown arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      canvas.drawArc(
        rect,
        -pi / 2,               // start at 12 o'clock
        2 * pi * progress,     // sweep clockwise
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress || old.color != color;
}
