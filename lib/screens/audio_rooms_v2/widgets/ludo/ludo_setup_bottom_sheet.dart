import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

class LudoSetupBottomSheet extends StatefulWidget {
  final AudioRoomV2 room;

  const LudoSetupBottomSheet({super.key, required this.room}) ;

  static void show(BuildContext context, AudioRoomV2 room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LudoSetupBottomSheet(room: room),
    );
  }

  @override
  State<LudoSetupBottomSheet> createState() => _LudoSetupBottomSheetState();
}

class _LudoSetupBottomSheetState extends State<LudoSetupBottomSheet> {
  int _selectedPlayers = 2;
  bool _isMagicEnabled = false;

  void _startGame() {
    Navigator.pop(context);
    // Setting isLudoActive to true will trigger the LudoGameWidget (Step 2) in the background
    AudioRoomsRepository().updateLudoState(
      roomId: widget.room.id,
      isActive: true,
      maxPlayers: _selectedPlayers,
    );
    // Later we can pass _selectedPlayers and _isMagicEnabled to the Firestore state
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3C096C), // Deep Purple
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Logo
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Text(
                'LUDO',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Colors.pink,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Player Selection Cards
          Row(
            children: [
              Expanded(
                child: _buildPlayerSelectCard(
                  title: '2 Players',
                  icon: Icons.group,
                  isSelected: _selectedPlayers == 2,
                  onTap: () => setState(() => _selectedPlayers = 2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPlayerSelectCard(
                  title: '4 Players',
                  icon: Icons.groups,
                  isSelected: _selectedPlayers == 4,
                  onTap: () => setState(() => _selectedPlayers = 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Magic Mode Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Magic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.help_outline, color: Colors.white54, size: 16),
                const Spacer(),
                Switch(
                  value: _isMagicEnabled,
                  onChanged: (val) => setState(() => _isMagicEnabled = val),
                  activeThumbColor: Colors.orange,
                  activeTrackColor: Colors.white30,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Start Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9933),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPlayerSelectCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue[300] : Colors.white54,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
