import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

class CarromSetupBottomSheet extends StatefulWidget {
  final AudioRoomV2 room;

  const CarromSetupBottomSheet({super.key, required this.room});

  static void show(BuildContext context, AudioRoomV2 room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CarromSetupBottomSheet(room: room),
    );
  }

  @override
  State<CarromSetupBottomSheet> createState() => _CarromSetupBottomSheetState();
}

class _CarromSetupBottomSheetState extends State<CarromSetupBottomSheet> {
  int _selectedPlayers = 2;

  void _startGame() {
    Navigator.pop(context);
    
    // Set isCarromActive to true and initialize database state
    AudioRoomsRepository().updateCarromState(
      roomId: widget.room.id,
      isActive: true,
      maxPlayers: _selectedPlayers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C1810), // Rich Wood Mahogany
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Text(
                'CARROM BOARD',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Color(0xFFD4AF37), // Metallic Gold
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Player Mode Title
          const Text(
            'Select Game Mode',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Player Selection Cards
          Row(
            children: [
              Expanded(
                child: _buildPlayerSelectCard(
                  title: '2 Players',
                  subtitle: '1 vs 1 Battle',
                  icon: Icons.group_outlined,
                  isSelected: _selectedPlayers == 2,
                  onTap: () => setState(() => _selectedPlayers = 2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPlayerSelectCard(
                  title: '4 Players',
                  subtitle: '2 vs 2 Team Play',
                  icon: Icons.groups_outlined,
                  isSelected: _selectedPlayers == 4,
                  onTap: () => setState(() => _selectedPlayers = 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37), // Metallic Gold
                foregroundColor: const Color(0xFF2C1810),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.play_arrow, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Launch Board',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildPlayerSelectCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final goldColor = const Color(0xFFD4AF37);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? goldColor : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: goldColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? goldColor : Colors.white54,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
