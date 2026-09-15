import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    // Current user info
    final currentUser = AuthController.instance.currentUser;
    final hostAvatar = currentUser.photoUrl;
    final hostName = currentUser.fullname.isNotEmpty ? currentUser.fullname : 'Alone Boy';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF531192), // Rich vibrant violet top from Picture 2
            Color(0xFF28034E), // Deep dark purple bottom
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Action Bar: Share, Help, Power/Close
            Padding(
              padding: const EdgeInsets.only(top: 14, right: 16, left: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildTopIcon(Icons.share_outlined, () {}),
                  const SizedBox(width: 12),
                  _buildTopIcon(Icons.help_outline, () => _showHelpDialog(context)),
                  const SizedBox(width: 12),
                  _buildTopIcon(Icons.power_settings_new, onClose),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Center: 3D Pawns Clash & "LuDo" Logo
            _buildPawnsWithLogo(),

            const SizedBox(height: 14),

            // Subtitle Banner: "Win by moving pieces according to dice rolls."
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Win by moving pieces according to dice rolls.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Players Row (Host Avatar + Opponent "+" Slot)
            Obx(() {
              final state = controller.gameState.value;
              final opponentId = state.players[LudoColor.yellow];
              final opponentName = state.playerNames[LudoColor.yellow] ?? 'Player';
              final opponentAvatar = state.playerAvatars[LudoColor.yellow];
              final isOpponentFilled = opponentId != null && opponentId.isNotEmpty;

              final hostRealName = state.playerNames[LudoColor.red] ?? hostName;
              final hostRealAvatar = state.playerAvatars[LudoColor.red] ?? hostAvatar;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Host Slot (Slot 1 - Red)
                  _buildHostSlot(hostRealName, hostRealAvatar),

                  const SizedBox(width: 44),

                  // Opponent Slot (Slot 2 - Yellow "+ Player")
                  _buildOpponentSlot(
                    isFilled: isOpponentFilled,
                    opponentName: opponentName,
                    opponentAvatar: opponentAvatar,
                    onTap: () {
                      if (!isOpponentFilled) {
                        controller.joinGame(
                          currentUserId,
                          LudoColor.yellow,
                          name: currentUser.fullname.isNotEmpty ? currentUser.fullname : 'Player',
                          avatar: currentUser.photoUrl,
                        );
                      }
                    },
                  ),
                ],
              );
            }),

            const SizedBox(height: 28),

            // Two Action Buttons: "Start" & "Match"
            Obx(() {
              final state = controller.gameState.value;
              final opponentId = state.players[LudoColor.yellow];
              final isOpponentFilled = opponentId != null && opponentId.isNotEmpty;
              final canStart = isHost && isOpponentFilled;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Start Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: canStart
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFFA500),
                                      Color(0xFFFF7700),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFE2E6EE),
                                      Color(0xFFBAC3D2),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: canStart
                                    ? const Color(0xFFFF8500).withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: canStart ? onStart : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(
                              'Start',
                              style: TextStyle(
                                color: canStart ? Colors.white : const Color(0xFF8C96A5),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Match Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFA500),
                                Color(0xFFFF7700),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8500).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (!isOpponentFilled && !isHost) {
                                controller.joinGame(
                                  currentUserId,
                                  LudoColor.yellow,
                                  name: currentUser.fullname.isNotEmpty ? currentUser.fullname : 'Player',
                                  avatar: currentUser.photoUrl,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Match',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Top header icon circular button
  Widget _buildTopIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // 3D Pawns with "LuDo" Logo in Center
  Widget _buildPawnsWithLogo() {
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background clashing pawns
          Positioned(
            top: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Green Pawn
                _build3DPawn(const Color(0xFF32CD32), const Color(0xFF1E841E)),
                const SizedBox(width: 8),
                // Clash spark star
                const Icon(Icons.star, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                // Blue Pawn
                _build3DPawn(const Color(0xFF4169E1), const Color(0xFF1E3A8A)),
              ],
            ),
          ),

          // Front 3D "LuDo" Logo
          Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLudoChar('L', const Color(0xFFFF4E6A), const Color(0xFFD6183B)),
                _buildLudoChar('u', const Color(0xFFFFD422), const Color(0xFFDE9F00)),
                _buildLudoChar('D', const Color(0xFF4BD36C), const Color(0xFF229A40)),
                _buildLudoChar('o', const Color(0xFF8E71FE), const Color(0xFF5939D8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DPawn(Color mainColor, Color darkColor) {
    return Container(
      width: 28,
      height: 38,
      decoration: BoxDecoration(
        color: mainColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(14),
          bottom: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: darkColor,
            offset: const Offset(1, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildLudoChar(String char, Color topColor, Color shadowColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Text(
        char,
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: topColor,
          shadows: [
            Shadow(
              color: shadowColor,
              offset: const Offset(1, 3),
              blurRadius: 0,
            ),
            const Shadow(
              color: Colors.black38,
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // Host Slot with Profile Picture
  Widget _buildHostSlot(String hostName, String? hostAvatar) {
    final displayName = hostName.length > 8 ? '${hostName.substring(0, 7)}...' : hostName;

    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: hostAvatar != null && hostAvatar.isNotEmpty
                ? Image.network(
                    hostAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.purple[800],
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 36),
      ),
    );
  }

  // Opponent Slot ("+ Player")
  Widget _buildOpponentSlot({
    required bool isFilled,
    String opponentName = 'Player',
    String? opponentAvatar,
    required VoidCallback onTap,
  }) {
    final displayName = opponentName.length > 8 ? '${opponentName.substring(0, 7)}...' : opponentName;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: isFilled && opponentAvatar != null && opponentAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      opponentAvatar,
                      fit: BoxFit.cover,
                      width: 62,
                      height: 62,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 36),
                    ),
                  )
                : (isFilled
                    ? const Center(child: Icon(Icons.person, color: Colors.white, size: 36))
                    : const Center(child: Icon(Icons.add, color: Colors.white, size: 36))),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFilled ? displayName : 'Player',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF28034E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ludo Voice Room Mode', style: TextStyle(color: Colors.white)),
        content: const Text(
          '• Tap "Match" or "Start" to begin the match.\n'
          '• Roll dice in turn and guide all tokens safely to the center finish line!',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }
}
