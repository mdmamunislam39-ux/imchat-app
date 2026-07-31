import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_lobby_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_board_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_dice_widget.dart';


class LudoGameWidget extends StatefulWidget {
  final AudioRoomV2 room;
  final bool isHost;
  final AudioRoomsRepository repository;
  final String currentUserId;

  const LudoGameWidget({
    super.key,
    required this.room,
    required this.isHost,
    required this.repository,
    required this.currentUserId,
  }) ;

  @override
  State<LudoGameWidget> createState() => _LudoGameWidgetState();
}

class _LudoGameWidgetState extends State<LudoGameWidget> {
  bool _isGameStarted = false;
  late final LudoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(LudoController(widget.room.id, widget.currentUserId, isHost: widget.isHost), tag: widget.room.id);
  }

  @override
  void dispose() {
    Get.delete<LudoController>(tag: widget.room.id);
    super.dispose();
  }

  void _closeLudo() {
    if (widget.isHost) {
      widget.repository.updateLudoState(
        roomId: widget.room.id,
        isActive: false,
      );
    }
  }

  void _startGame() {
    setState(() {
      _isGameStarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Adjust height based on whether game has started to fit the board properly
      height: _isGameStarted ? MediaQuery.of(context).size.width + 40 : 380,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _isGameStarted
          ? _buildGameBoard()
          : LudoLobbyWidget(
              controller: _controller,
              currentUserId: widget.currentUserId,
              onStart: _startGame,
              onClose: _closeLudo,
              isHost: widget.isHost,
            ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ludo King Board',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.isHost)
                  GestureDetector(
                    onTap: _closeLudo,
                    child: const Icon(Icons.close, color: Colors.black, size: 20),
                  ),
              ],
            ),
          ),
          // Game Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  Center(
                    child: LudoBoardWidget(
                      controller: _controller,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                  // Dice Overlay (Top Left for now)
                  Positioned(
                    left: 20,
                    top: 20,
                    child: LudoDiceWidget(
                      controller: _controller,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                  
                  // Winner Celebration Overlay
                  Obx(() {
                    final winner = _controller.gameState.value.winner;
                    if (winner != null) {
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Golden Cup
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 100),
                              const SizedBox(height: 16),
                              
                              // Winner Text
                              Text(
                                '${winner.toUpperCase()} WINS!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(color: Colors.amber, blurRadius: 15, offset: Offset(0, 4)),
                                    Shadow(color: Colors.redAccent, blurRadius: 30, offset: Offset(0, 0)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                              
                              if (widget.isHost)
                                ElevatedButton.icon(
                                  onPressed: _closeLudo,
                                  icon: const Icon(Icons.power_settings_new),
                                  label: const Text('Close Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
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
          ),
        ],
      ),
    );
  }
}
