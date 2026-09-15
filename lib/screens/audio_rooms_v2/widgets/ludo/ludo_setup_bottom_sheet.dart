import 'package:flutter/material.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

class LudoSetupBottomSheet extends StatefulWidget {
  final AudioRoomV2 room;

  const LudoSetupBottomSheet({super.key, required this.room});

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

    // 1. Activate Ludo Room Mode
    final user = AuthController.instance.currentUser;
    AudioRoomsRepository().updateLudoState(
      roomId: widget.room.id,
      isActive: true,
      maxPlayers: _selectedPlayers,
      hostUserId: user.userId,
      hostUserName: user.fullname.isNotEmpty ? user.fullname : 'Host',
      hostUserAvatar: user.photoUrl,
    );

    // 2. Broadcast Room Chat Announcement
    try {
      final user = AuthController.instance.currentUser;
      final userId = user.userId.isNotEmpty ? user.userId : 'system';
      final userName = user.fullname.isNotEmpty ? user.fullname : 'Room Owner';
      final userAvatar = user.photoUrl;

      AudioRoomsRepository().sendChatMessage(
        widget.room.id,
        userId,
        userName,
        userAvatar,
        '🎮 Room owner started Ludo',
      );
    } catch (e) {
      debugPrint('Error sending Ludo start announcement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF34076C), // Deep Indigo-Purple from Picture 1
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header: Close button, 3D "LuDo" Logo, Help (?) button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close (X) button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),

              // 3D "LuDo" Bubbly Title Logo
              _build3DLudoLogo(),

              // Help (?) button
              GestureDetector(
                onTap: _showHelpDialog,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Player Selection Cards (2 Players vs 4 Players)
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  playerCount: 2,
                  title: '2 Players',
                  isSelected: _selectedPlayers == 2,
                  onTap: () => setState(() => _selectedPlayers = 2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildModeCard(
                  playerCount: 4,
                  title: '4 Players',
                  isSelected: _selectedPlayers == 4,
                  onTap: () => setState(() => _selectedPlayers = 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Magic Mode Toggle Bar
          GestureDetector(
            onTap: () => setState(() => _isMagicEnabled = !_isMagicEnabled),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  // White 3D dice icon with purple pips
                  _build3DDiceIcon(),
                  const SizedBox(width: 12),
                  const Text(
                    'Magic',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.help_outline, color: Colors.white54, size: 16),
                  const Spacer(),
                  // Circular toggle ring
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isMagicEnabled ? const Color(0xFFFF9E00) : Colors.white54,
                        width: 2,
                      ),
                      color: _isMagicEnabled ? const Color(0xFFFF9E00) : Colors.transparent,
                    ),
                    child: _isMagicEnabled
                        ? const Center(
                            child: Icon(Icons.check, size: 16, color: Colors.white),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),

          // Orange Gradient "✓ Start" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFA500), // Vibrant amber/orange
                    Color(0xFFFF8500), // Deep warm orange
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 3D Playful "LuDo" Logo widget
  Widget _build3DLudoLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLudoLetter('L', const Color(0xFFFF4E6A), const Color(0xFFD6183B)),
          _buildLudoLetter('u', const Color(0xFFFFD422), const Color(0xFFDE9F00)),
          _buildLudoLetter('D', const Color(0xFF4BD36C), const Color(0xFF229A40)),
          _buildLudoLetter('o', const Color(0xFF8E71FE), const Color(0xFF5939D8)),
        ],
      ),
    );
  }

  Widget _buildLudoLetter(String char, Color topColor, Color shadowColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        char,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: topColor,
          shadows: [
            Shadow(
              color: shadowColor,
              offset: const Offset(1, 3),
              blurRadius: 0,
            ),
            const Shadow(
              color: Colors.black26,
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // 2-Player & 4-Player Selection Cards
  Widget _buildModeCard({
    required int playerCount,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Avatars with VS effect
            SizedBox(
              height: 52,
              child: playerCount == 2 ? _buildTwoPlayerGraphic() : _buildFourPlayerGraphic(),
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
          ],
        ),
      ),
    );
  }

  // 2 Player Avatar Graphic
  Widget _buildTwoPlayerGraphic() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAvatarDisc(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDD00), Color(0xFFFF9500)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ),
        _buildAvatarDisc(),
      ],
    );
  }

  // 4 Player Avatar Graphic
  Widget _buildFourPlayerGraphic() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarDisc(size: 22),
            const SizedBox(height: 3),
            _buildAvatarDisc(size: 22),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDD00), Color(0xFFFF9500)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarDisc(size: 22),
            const SizedBox(height: 3),
            _buildAvatarDisc(size: 22),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarDisc({double size = 38}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8F7CF6), Color(0xFF634CD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white.withValues(alpha: 0.9),
          size: size * 0.65,
        ),
      ),
    );
  }

  // 3D White Dice Icon
  Widget _build3DDiceIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 5,
            left: 5,
            child: _buildPip(),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: _buildPip(),
          ),
          Positioned(
            child: _buildPip(),
          ),
        ],
      ),
    );
  }

  Widget _buildPip() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF5A2594),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF260558),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ludo Game Rules', style: TextStyle(color: Colors.white)),
        content: const Text(
          '• Choose 2 or 4 players mode.\n'
          '• Enable Magic mode for special dice power-ups and animations.\n'
          '• Move tokens into home column to win the game!',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }
}
