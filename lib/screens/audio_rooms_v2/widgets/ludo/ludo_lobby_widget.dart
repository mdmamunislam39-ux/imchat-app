import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';

class LudoLobbyWidget extends StatelessWidget {
  final LudoController controller;
  final String currentUserId;
  final VoidCallback onStart;
  final VoidCallback onClose;
  final bool isHost;
  
  const LudoLobbyWidget({
    super.key,
    required this.controller,
    required this.currentUserId,
    required this.onStart,
    required this.onClose,
    required this.isHost,
  }) ;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5B1A8C), // Deep purple top
            Color(0xFF2E0952), // Darker purple bottom
          ],
        ),
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
                    _buildTopIcon(Icons.share, () {}),
                    const SizedBox(width: 12),
                    _buildTopIcon(Icons.help_outline, () {}),
                    const SizedBox(width: 12),
                    _buildTopIcon(Icons.power_settings_new, onClose),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Ludo Logo Text
              const Text(
                'LUDO',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Colors.pinkAccent,
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.black.withValues(alpha: 0.2),
                child: const Text(
                  'Join a color to start playing Ludo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Players row (Reactive)
              Obx(() {
                final state = controller.gameState.value;
                final maxPlayers = state.maxPlayers;
                
                // Colors available depend on maxPlayers (2 or 4)
                final colors = maxPlayers == 2 
                    ? [LudoColor.red, LudoColor.yellow] // Red vs Yellow in 2 player
                    : [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue];

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: colors.map((color) {
                    final userId = state.players[color];
                    final isFilled = userId != null;
                    return GestureDetector(
                      onTap: () {
                        if (!isFilled) {
                          controller.joinGame(currentUserId, color);
                        }
                      },
                      child: _buildPlayerSlot(
                        isFilled, 
                        isFilled ? (userId == currentUserId ? 'You' : 'Player') : 'Join',
                        color,
                      ),
                    );
                  }).toList(),
                );
              }),
              
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: isHost ? onStart : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isHost ? Colors.white.withValues(alpha: 0.9) : Colors.white30,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Start Game',
                      style: TextStyle(
                        color: isHost ? Colors.deepPurple : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildPlayerSlot(bool isFilled, String name, LudoColor color) {
    Color slotColor;
    switch (color) {
      case LudoColor.red: slotColor = Colors.red; break;
      case LudoColor.green: slotColor = Colors.green; break;
      case LudoColor.yellow: slotColor = Colors.amber; break;
      case LudoColor.blue: slotColor = Colors.blue; break;
      default: slotColor = Colors.grey;
    }

    return Column(
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : slotColor.withValues(alpha: 0.2),
            border: Border.all(
              color: slotColor,
              width: 2,
            ),
          ),
          child: isFilled
              ? Center(child: Icon(Icons.person, color: slotColor, size: 36))
              : Center(child: Icon(Icons.add, color: slotColor.withValues(alpha: 0.8), size: 30)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: isFilled ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
