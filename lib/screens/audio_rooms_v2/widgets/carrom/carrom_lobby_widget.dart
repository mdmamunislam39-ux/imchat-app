import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/carrom/carrom_controller.dart';

class CarromLobbyWidget extends StatelessWidget {
  final CarromController controller;
  final String currentUserId;
  final VoidCallback onStart;
  final VoidCallback onClose;
  final bool isHost;

  const CarromLobbyWidget({
    super.key,
    required this.controller,
    required this.currentUserId,
    required this.onStart,
    required this.onClose,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final goldColor = const Color(0xFFD4AF37);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C1810), // Rich Mahogany
            Color(0xFF1E100A), // Deep dark brown
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Action Bar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildTopIcon(Icons.help_outline, () {
                    // Quick rule info dialog
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
                  }),
                  const SizedBox(width: 12),
                  _buildTopIcon(Icons.power_settings_new, onClose),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Carrom Logo Text
            Text(
              'CARROM',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: goldColor,
                    blurRadius: 15,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Premium Board Game',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 16),

            // Subtitle Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black.withValues(alpha: 0.25),
              child: const Text(
                'Join a baseline to start the game.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Players layout (Reactive)
            Obx(() {
              final state = controller.gameState.value;
              final maxPlayers = state.maxPlayers;

              // Arrange seats logically
              final List<Widget> seatWidgets = [];

              if (maxPlayers == 2) {
                // Bottom vs Top
                seatWidgets.add(_buildSeatSlot(context, 'bottom', 'White Team (Bottom)', state.players['bottom']));
                seatWidgets.add(const SizedBox(width: 30));
                seatWidgets.add(_buildSeatSlot(context, 'top', 'White Team (Top)', state.players['top']));
              } else {
                // 4 Players grid: Bottom & Top (White Team) vs Left & Right (Black Team)
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSeatSlot(context, 'bottom', 'White Team (Bottom)', state.players['bottom']),
                        _buildSeatSlot(context, 'top', 'White Team (Top)', state.players['top']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSeatSlot(context, 'left', 'Black Team (Left)', state.players['left']),
                        _buildSeatSlot(context, 'right', 'Black Team (Right)', state.players['right']),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: seatWidgets,
              );
            }),

            const SizedBox(height: 40),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Leave Seat Button (if already seated)
                  Obx(() {
                    final players = controller.gameState.value.players;
                    String? mySeat;
                    for (var entry in players.entries) {
                      if (entry.value == currentUserId) {
                        mySeat = entry.key;
                        break;
                      }
                    }

                    if (mySeat != null) {
                      final String seatKey = mySeat;
                      return Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => controller.leaveGame(seatKey),
                          icon: const Icon(Icons.exit_to_app, size: 18),
                          label: const Text('Leave Seat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  
                  // Spacer if Leave Seat button is visible
                  Obx(() {
                    final players = controller.gameState.value.players;
                    final isSeated = players.values.contains(currentUserId);
                    if (isSeated) return const SizedBox(width: 12);
                    return const SizedBox.shrink();
                  }),

                  // Start Game Button
                  Expanded(
                    child: Obx(() {
                      final players = controller.gameState.value.players;
                      // Ensure at least bottom & top (in 2p) or at least 2 players are present
                      final isReadyToStart = players.values.where((v) => v != null).length >= 2;

                      return ElevatedButton(
                        onPressed: (isHost && isReadyToStart) ? onStart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: const Color(0xFF2C1810),
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white30,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          isHost ? 'Start Game' : 'Waiting for Host',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  void _handleSeatTap(BuildContext context, String seat, bool isFilled, String? userId) {
    if (isFilled) {
      final bool isBot = userId != null && userId.startsWith('bot_');
      if (isBot && isHost) {
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
                  controller.leaveGame(seat);
                },
                child: const Text('Remove Bot', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (isHost) {
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
                controller.joinGame('bot_$seat', seat);
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

  void _sitInSeat(String seat) {
    String? currentSeat;
    for (var entry in controller.gameState.value.players.entries) {
      if (entry.value == currentUserId) {
        currentSeat = entry.key;
        break;
      }
    }
    if (currentSeat != null) {
      controller.leaveGame(currentSeat).then((_) {
        controller.joinGame(currentUserId, seat);
      });
    } else {
      controller.joinGame(currentUserId, seat);
    }
  }

  Widget _buildSeatSlot(BuildContext context, String seat, String label, String? userId) {
    final goldColor = const Color(0xFFD4AF37);
    final isFilled = userId != null;
    final isBot = isFilled && userId.startsWith('bot_');

    // White Team vs Black Team color styling
    final isWhiteTeam = (seat == 'bottom' || seat == 'top');
    final borderCol = isWhiteTeam ? Colors.white60 : Colors.black87;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _handleSeatTap(context, seat, isFilled, userId),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? Colors.white10 : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isFilled ? goldColor : borderCol,
                width: 2.5,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: goldColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: isFilled
                  ? Icon(
                      isBot ? Icons.smart_toy : Icons.person,
                      color: Colors.amber,
                      size: 36,
                    )
                  : Icon(
                      Icons.add_circle_outline,
                      color: isWhiteTeam ? Colors.white38 : Colors.white24,
                      size: 28,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFilled
              ? (isBot
                  ? 'Bot'
                  : (userId == currentUserId ? 'You' : 'Joined'))
              : 'Empty',
          style: TextStyle(
            color: isFilled ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isWhiteTeam ? Colors.white54 : Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
